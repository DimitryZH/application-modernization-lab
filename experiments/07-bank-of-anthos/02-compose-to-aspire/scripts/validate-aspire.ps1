param(
    [string]$BaseUrl = "http://127.0.0.1:8080",
    [int]$StartupTimeoutSeconds = 300,
    [int]$StableSeconds = 30,
    [string]$AppHostProject = "./src/BankOfAnthos.AppHost/BankOfAnthos.AppHost.csproj",
    [switch]$StartAppHost,
    [switch]$SkipCleanup,
    [switch]$IdentityOnly
)

$ErrorActionPreference = "Stop"

$script:ExpectedServices = @(
    @{ Name = "accounts-db"; Image = "us-central1-docker.pkg.dev/bank-of-anthos-ci/bank-of-anthos/accounts-db:v0.6.10@sha256:d95c4094c75f69069b915ef3adc99a8f95e43077885140cdeeb90d807ea74eff"; Env = @("POSTGRES_DB=accounts-db", "POSTGRES_USER=accounts-admin", "POSTGRES_PASSWORD=accounts-pwd"); VolumeTarget = "/var/lib/postgresql/data" },
    @{ Name = "ledger-db"; Image = "us-central1-docker.pkg.dev/bank-of-anthos-ci/bank-of-anthos/ledger-db:v0.6.10@sha256:891cb7afe34f358ce7ed7002a1923b25e113b30bca44fecb10cc8b116d665a03"; Env = @("POSTGRES_DB=postgresdb", "POSTGRES_USER=admin", "POSTGRES_PASSWORD=password"); VolumeTarget = "/var/lib/postgresql/data" },
    @{ Name = "userservice"; Image = "us-central1-docker.pkg.dev/bank-of-anthos-ci/bank-of-anthos/userservice:v0.6.10@sha256:d8c4412edc46ab105000f721788b73301651cc43b19cee7e7302739f81882dcc"; Env = @("ACCOUNTS_DB_URI=postgresql://accounts-admin:accounts-pwd@accounts-db:5432/accounts-db", "PRIV_KEY_PATH=/tmp/.ssh/privatekey", "PUB_KEY_PATH=/tmp/.ssh/publickey") },
    @{ Name = "contacts"; Image = "us-central1-docker.pkg.dev/bank-of-anthos-ci/bank-of-anthos/contacts:v0.6.10@sha256:90d47594270e64f8dafa6da52c89ff70c2483cca0821dff2cc38b1450ac7a6b9"; Env = @("ACCOUNTS_DB_URI=postgresql://accounts-admin:accounts-pwd@accounts-db:5432/accounts-db", "PUB_KEY_PATH=/tmp/.ssh/publickey") },
    @{ Name = "balancereader"; Image = "us-central1-docker.pkg.dev/bank-of-anthos-ci/bank-of-anthos/balancereader:v0.6.10@sha256:feae443c650786c253bbfa3447d0902dd1689122c13962f97ccc37068d73733b"; Env = @("SPRING_DATASOURCE_URL=jdbc:postgresql://ledger-db:5432/postgresdb", "POLL_MS=100", "CACHE_SIZE=1000000", "HOSTNAME=balancereader-local-1", "JAVA_TOOL_OPTIONS=-XX:-UseContainerSupport") },
    @{ Name = "transactionhistory"; Image = "us-central1-docker.pkg.dev/bank-of-anthos-ci/bank-of-anthos/transactionhistory:v0.6.10@sha256:109cdad9c29a46af2708574ac4635dd73afa30cc020a4fef0266abcde87db744"; Env = @("SPRING_DATASOURCE_URL=jdbc:postgresql://ledger-db:5432/postgresdb", "POLL_MS=100", "CACHE_SIZE=1000", "HISTORY_LIMIT=100", "HOSTNAME=transactionhistory-local-1", "JAVA_TOOL_OPTIONS=-XX:-UseContainerSupport") },
    @{ Name = "ledgerwriter"; Image = "us-central1-docker.pkg.dev/bank-of-anthos-ci/bank-of-anthos/ledgerwriter:v0.6.10@sha256:eae37de0d9b28fec7534c1ea860868c87279b0a85b405f8fd66c3d7734e3e42f"; Env = @("SPRING_DATASOURCE_URL=jdbc:postgresql://ledger-db:5432/postgresdb", "TRANSACTIONS_API_ADDR=ledgerwriter:8080", "BALANCES_API_ADDR=balancereader:8080", "USERSERVICE_API_ADDR=userservice:8080", "HOSTNAME=ledgerwriter-local-1") },
    @{ Name = "frontend"; Image = "us-central1-docker.pkg.dev/bank-of-anthos-ci/bank-of-anthos/frontend:v0.6.10@sha256:076294ce717309f711743fa3b72a9809c7f156edf1c4fa58505fd9f436d65345"; Env = @("TRANSACTIONS_API_ADDR=ledgerwriter:8080", "BALANCES_API_ADDR=balancereader:8080", "HISTORY_API_ADDR=transactionhistory:8080", "CONTACTS_API_ADDR=contacts:8080", "USERSERVICE_API_ADDR=userservice:8080", "DEFAULT_USERNAME=testuser", "DEFAULT_PASSWORD=bankofanthos") }
)

$script:ExperimentDir = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$script:CookieJar = Join-Path $script:ExperimentDir ".local/validation/cookies.txt"
$script:PrivateKey = Join-Path $script:ExperimentDir ".local/jwt/jwtRS256.key"
$script:PublicKey = Join-Path $script:ExperimentDir ".local/jwt/jwtRS256.key.pub"

function Invoke-Step {
    param([string]$Name, [scriptblock]$Action)
    Write-Host "[validate-aspire] $Name"
    & $Action
}

function Fail { param([string]$Message) throw $Message }

function Require-Command {
    param([string]$Name)
    if (-not (Get-Command $Name -ErrorAction SilentlyContinue)) { Fail "missing required command: $Name" }
}

function Assert-Contains {
    param([string]$Text, [string]$Expected, [string]$Message)
    if ($Text -notmatch [regex]::Escape($Expected)) { Fail $Message }
}

function Convert-ImageReference {
    param([string]$Image)
    $digestIndex = $Image.IndexOf("@sha256:")
    if ($digestIndex -lt 0) { return $Image }
    $repositoryAndTag = $Image.Substring(0, $digestIndex)
    $digest = $Image.Substring($digestIndex)
    $lastSlash = $repositoryAndTag.LastIndexOf("/")
    $lastColon = $repositoryAndTag.LastIndexOf(":")
    if ($lastColon -gt $lastSlash) { $repositoryAndTag = $repositoryAndTag.Substring(0, $lastColon) }
    return "$repositoryAndTag$digest"
}

function Get-InspectValue {
    param([string]$ContainerId, [string]$Format)
    docker inspect --format $Format $ContainerId
}

function Get-ServiceDefinition {
    param([string]$Name)
    $service = $script:ExpectedServices | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
    if (-not $service) { Fail "unknown service definition: $Name" }
    return $service
}

function Get-ContainerIdForService {
    param([hashtable]$Service, [string]$AspireCreatorIdentity = $null)

    $expectedImage = Convert-ImageReference -Image $Service.Image
    $containerMatches = @()
    foreach ($id in (docker ps -q)) {
        $dcpName = Get-InspectValue $id '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.name" }}'
        $dcpGroupVersion = Get-InspectValue $id '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.group-version" }}'
        $dcpCreatorProcessId = Get-InspectValue $id '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.creatorProcessId" }}'
        $dcpCreatorProcessStartTime = Get-InspectValue $id '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.creatorProcessStartTime" }}'

        if ([string]::IsNullOrWhiteSpace($dcpName) -or $dcpName -notmatch "^$([regex]::Escape($Service.Name))-[a-z0-9]+$") { continue }
        if ($dcpGroupVersion -ne "usvc-dev.developer.microsoft.com/v1") { continue }
        if ([string]::IsNullOrWhiteSpace($dcpCreatorProcessId) -or [string]::IsNullOrWhiteSpace($dcpCreatorProcessStartTime)) { continue }

        $creatorIdentity = "$dcpCreatorProcessId|$dcpCreatorProcessStartTime"
        if ($AspireCreatorIdentity -and $creatorIdentity -ne $AspireCreatorIdentity) { continue }

        $image = Get-InspectValue $id '{{.Config.Image}}'
        if ((Convert-ImageReference -Image $image) -eq $expectedImage) {
            $containerMatches += [pscustomobject]@{ Id = $id; CreatorIdentity = $creatorIdentity; ResourceLabel = $dcpName }
        }
    }

    if ($containerMatches.Count -gt 1) {
        $matchList = ($containerMatches | ForEach-Object { "$($_.Id):$($_.ResourceLabel)" }) -join ", "
        Fail "multiple Aspire containers matched $($Service.Name): $matchList"
    }
    if ($containerMatches.Count -eq 0) { return $null }
    return $containerMatches[0]
}

function Assert-ServiceContainer {
    param([hashtable]$Service, [string]$AspireCreatorIdentity = $null)

    $container = Get-ContainerIdForService -Service $Service -AspireCreatorIdentity $AspireCreatorIdentity
    if (-not $container) { Fail "missing running Aspire-managed container for $($Service.Name)" }

    $state = Get-InspectValue $container.Id '{{.State.Running}} {{.State.Restarting}} {{.RestartCount}} {{.State.ExitCode}}'
    $parts = $state -split ' '
    if ($parts[0] -ne "true" -or $parts[1] -ne "false" -or $parts[3] -ne "0") { Fail "container $($Service.Name) is not stable: $state" }

    $env = Get-InspectValue $container.Id '{{range .Config.Env}}{{println .}}{{end}}'
    foreach ($expected in $Service.Env) { Assert-Contains -Text $env -Expected $expected -Message "container $($Service.Name) is missing expected environment value $expected" }

    if ($Service.VolumeTarget) {
        $mounts = Get-InspectValue $container.Id '{{range .Mounts}}{{println .Name ":" .Destination}}{{end}}'
        Assert-Contains -Text $mounts -Expected $Service.VolumeTarget -Message "container $($Service.Name) is missing persistent mount $($Service.VolumeTarget)"
    }

    return $container
}

function Assert-AspireContainerSet {
    $frontend = Assert-ServiceContainer -Service (Get-ServiceDefinition "frontend")
    $creatorIdentity = $frontend.CreatorIdentity
    foreach ($service in $script:ExpectedServices) { [void](Assert-ServiceContainer -Service $service -AspireCreatorIdentity $creatorIdentity) }
    return $creatorIdentity
}

function Assert-NoTrackedLocalState {
    Push-Location $script:ExperimentDir
    try {
        git rev-parse --show-toplevel *> $null
        if ($LASTEXITCODE -ne 0) { return }
        $top = (git rev-parse --show-toplevel).Trim()
        $relative = [System.IO.Path]::GetRelativePath($top, $script:ExperimentDir).Replace("\", "/")
        $tracked = git ls-files -- "$relative/.local" "$relative/validation-output"
        if ($tracked) { Fail "generated local state is tracked by git: $($tracked -join ', ')" }
    }
    finally { Pop-Location }
}

function Invoke-FrontendRequest {
    param([string]$Uri, [string]$Method = "GET", [hashtable]$Body = $null, [Microsoft.PowerShell.Commands.WebRequestSession]$Session)
    $params = @{ Uri = $Uri; Method = $Method; WebSession = $Session; UseBasicParsing = $true; TimeoutSec = 30 }
    if ($Body) { $params.Body = $Body; $params.ContentType = "application/x-www-form-urlencoded" }
    Invoke-WebRequest @params
}

function Wait-ForFrontend {
    $deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
    do {
        try {
            $ready = Invoke-WebRequest -Uri "$BaseUrl/ready" -UseBasicParsing -TimeoutSec 5
            if ($ready.StatusCode -eq 200) { return }
        }
        catch { Start-Sleep -Seconds 3 }
    } while ((Get-Date) -lt $deadline)
    Fail "frontend did not become reachable at $BaseUrl/ready within $StartupTimeoutSeconds seconds"
}


function Wait-ForHttpFromFrontend {
    param([string]$Label, [string]$Url)
    $frontend = Get-ContainerIdForService -Service (Get-ServiceDefinition "frontend")
    if (-not $frontend) { Fail "cannot probe $Label because the Aspire frontend container was not found" }

    $pythonReady = 'import sys, urllib.request; urllib.request.urlopen(sys.argv[1], timeout=5).read()'
    $deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
    do {
        docker exec $frontend.Id python -c $pythonReady $Url *> $null
        if ($LASTEXITCODE -eq 0) {
            Write-Host "[validate-aspire] $Label ready"
            return
        }
        Start-Sleep -Seconds 5
    } while ((Get-Date) -lt $deadline)

    Fail "$Label did not become ready at $Url within $StartupTimeoutSeconds seconds"
}

function Wait-ForBackendReadiness {
    Wait-ForHttpFromFrontend -Label "userservice" -Url "http://userservice:8080/ready"
    Wait-ForHttpFromFrontend -Label "contacts" -Url "http://contacts:8080/ready"
    Wait-ForHttpFromFrontend -Label "balancereader" -Url "http://balancereader:8080/ready"
    Wait-ForHttpFromFrontend -Label "transactionhistory" -Url "http://transactionhistory:8080/ready"
    Wait-ForHttpFromFrontend -Label "ledgerwriter" -Url "http://ledgerwriter:8080/ready"
}

function Invoke-SqlScalar {
    param([string]$ServiceName, [string]$User, [string]$Database, [string]$Password, [string]$Sql)
    $container = Get-ContainerIdForService -Service (Get-ServiceDefinition $ServiceName)
    if (-not $container) { Fail "cannot run SQL because Aspire container $ServiceName was not found" }
    $result = docker exec -e "PGPASSWORD=$Password" $container.Id psql -X -A -t -v ON_ERROR_STOP=1 -U $User -d $Database -c $Sql
    return ($result -join "").Trim()
}

function Invoke-BankWorkflow {
    New-Item -ItemType Directory -Force -Path (Split-Path $script:CookieJar) | Out-Null
    if (Test-Path $script:CookieJar) { Remove-Item $script:CookieJar -Force }

    $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
    [void](Invoke-FrontendRequest -Uri "$BaseUrl/login" -Method "POST" -Body @{ username = "testuser"; password = "bankofanthos" } -Session $session)
    $homeResponse = Invoke-FrontendRequest -Uri "$BaseUrl/home" -Session $session
    if ($homeResponse.Content -notmatch "Test|User|Balance|Transactions|Deposit|Payment") { Fail "authenticated home page did not contain expected account content" }

    $query = "SELECT COUNT(*) FROM TRANSACTIONS WHERE FROM_ACCT='9099791699' AND FROM_ROUTE='808889588' AND TO_ACCT='1011226111' AND TO_ROUTE='883745000' AND AMOUNT=1234;"
    $beforeMatching = [int](Invoke-SqlScalar -ServiceName "ledger-db" -User "admin" -Database "postgresdb" -Password "password" -Sql $query)
    $uuid = "aspire-validate-$((Get-Date).ToUniversalTime().ToString("yyyyMMddHHmmss"))-$PID"
    [void](Invoke-FrontendRequest -Uri "$BaseUrl/deposit" -Method "POST" -Body @{ account = '{"account_num": "9099791699", "routing_num": "808889588" }'; amount = "12.34"; uuid = $uuid } -Session $session)

    $deadline = (Get-Date).AddSeconds(90)
    do {
        $afterMatching = [int](Invoke-SqlScalar -ServiceName "ledger-db" -User "admin" -Database "postgresdb" -Password "password" -Sql $query)
        if ($afterMatching -gt $beforeMatching) {
            Write-Host "[validate-aspire] deterministic deposit evidence count $beforeMatching -> $afterMatching"
            return $afterMatching
        }
        Start-Sleep -Seconds 3
    } while ((Get-Date) -lt $deadline)

    Fail "deposit transaction was not persisted in ledger-db"
}

function Assert-SeedData {
    $users = Invoke-SqlScalar -ServiceName "accounts-db" -User "accounts-admin" -Database "accounts-db" -Password "accounts-pwd" -Sql "SELECT COUNT(*) FROM users WHERE username IN ('testuser','alice','bob','eve');"
    if ($users -ne "4") { Fail "expected four seeded demo users, found $users" }
    $transactions = Invoke-SqlScalar -ServiceName "ledger-db" -User "admin" -Database "postgresdb" -Password "password" -Sql "SELECT COUNT(*) FROM TRANSACTIONS;"
    if ($transactions -notmatch "^[0-9]+$" -or [int]$transactions -le 0) { Fail "ledger-db did not contain seeded transactions" }
    Write-Host "[validate-aspire] database initialization present: users=$users, transactions=$transactions"
}

function Assert-FrontendOnlyPublished {
    $creatorIdentity = Assert-AspireContainerSet
    foreach ($service in $script:ExpectedServices) {
        $container = Assert-ServiceContainer -Service $service -AspireCreatorIdentity $creatorIdentity
        $ports = Get-InspectValue $container.Id '{{range $p, $conf := .NetworkSettings.Ports}}{{if $conf}}{{println $p}}{{end}}{{end}}'
        if ($service.Name -eq "frontend") {
            Assert-Contains -Text $ports -Expected "8080/tcp" -Message "frontend is not host-published"
            continue
        }
        if (-not [string]::IsNullOrWhiteSpace($ports)) { Fail "internal service $($service.Name) has host-published ports: $ports" }
    }
}

Require-Command docker
Require-Command dotnet
Require-Command git
Require-Command openssl

$appHostProcess = $null
$appHostLog = Join-Path ([System.IO.Path]::GetTempPath()) "bank-of-anthos-aspire-apphost.log"
$appHostErrorLog = Join-Path ([System.IO.Path]::GetTempPath()) "bank-of-anthos-aspire-apphost.err.log"

try {
    Invoke-Step "generate local JWT keys" {
        & (Join-Path $PSScriptRoot "generate-jwt-keys.sh")
        if (-not (Test-Path $script:PrivateKey) -or -not (Test-Path $script:PublicKey)) { Fail "required JWT key files were not generated" }
    }

    Invoke-Step "assert local state is untracked" { Assert-NoTrackedLocalState }

    Invoke-Step "build AppHost" {
        dotnet build $AppHostProject
        if ($LASTEXITCODE -ne 0) { Fail "dotnet build failed for $AppHostProject" }
    }

    if ($StartAppHost) {
        Invoke-Step "start AppHost" {
            Remove-Item $appHostLog, $appHostErrorLog -Force -ErrorAction SilentlyContinue
            $appHostProcess = Start-Process -FilePath "dotnet" -ArgumentList @("run", "--project", $AppHostProject, "--no-build") -NoNewWindow -RedirectStandardOutput $appHostLog -RedirectStandardError $appHostErrorLog -PassThru
            Start-Sleep -Seconds 5
            if ($appHostProcess.HasExited) {
                $log = if (Test-Path $appHostLog) { Get-Content $appHostLog -Raw } else { "" }
                $errorLog = if (Test-Path $appHostErrorLog) { Get-Content $appHostErrorLog -Raw } else { "" }
                Fail "AppHost exited during startup. Log: $log $errorLog"
            }
        }
    }
    else { Write-Host "[validate-aspire] validating an already running AppHost. Pass -StartAppHost to start it from this script." }

    Invoke-Step "wait for frontend readiness" { Wait-ForFrontend }

    Invoke-Step "assert Aspire-managed container identity" {
        $creatorIdentity = Assert-AspireContainerSet
        Write-Host "[validate-aspire] Aspire creator identity $creatorIdentity"
    }

    if (-not $IdentityOnly) {
        Invoke-Step "wait for backend readiness" { Wait-ForBackendReadiness }
        Invoke-Step "assert service data and persistence mounts" { Assert-SeedData }
        Invoke-Step "login and deterministic deposit workflow" { [void](Invoke-BankWorkflow) }
        Invoke-Step "host exposure check" { Assert-FrontendOnlyPublished }
        Invoke-Step "container stability window" { Start-Sleep -Seconds $StableSeconds; [void](Assert-AspireContainerSet) }
    }

    Invoke-Step "resolved image inventory" {
        $creatorIdentity = Assert-AspireContainerSet
        foreach ($service in $script:ExpectedServices) {
            $container = Assert-ServiceContainer -Service $service -AspireCreatorIdentity $creatorIdentity
            $image = Get-InspectValue $container.Id '{{.Config.Image}}'
            Write-Host "[validate-aspire] image $($service.Name)=$image label=$($container.ResourceLabel)"
        }
    }

    Write-Host "[validate-aspire] PASS"
}
finally {
    if ($appHostProcess -and -not $SkipCleanup) {
        Write-Host "[validate-aspire] cleanup AppHost process"
        if (-not $appHostProcess.HasExited) {
            $appHostProcess.CloseMainWindow() | Out-Null
            Start-Sleep -Seconds 5
        }
        if (-not $appHostProcess.HasExited) { Stop-Process -Id $appHostProcess.Id -Force }
    }
}
