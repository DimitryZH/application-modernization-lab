[CmdletBinding()]
param(
    [string]$DotnetPath = "dotnet",
    [string]$PostgresPassword = "demo",
    [int]$StartupTimeoutSeconds = 180
)

$ErrorActionPreference = "Stop"

function Resolve-Tool {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name
    )

    if (Test-Path -LiteralPath $Name) {
        return (Resolve-Path -LiteralPath $Name).Path
    }

    $command = Get-Command $Name -ErrorAction SilentlyContinue
    if ($command) {
        return $command.Source
    }

    throw "Required tool not found: $Name"
}

function Resolve-SmokeBash {
    $isWindows = $IsWindows -or $env:OS -eq "Windows_NT"

    if ($isWindows) {
        $gitBashCandidates = @(
            (Join-Path ${env:ProgramFiles} "Git\bin\bash.exe"),
            (Join-Path ${env:ProgramFiles(x86)} "Git\bin\bash.exe")
        ) | Where-Object { $_ -and (Test-Path -LiteralPath $_) }

        if ($gitBashCandidates.Count -gt 0) {
            return $gitBashCandidates[0]
        }
    }

    return Resolve-Tool "bash"
}

function Test-JsonHealth {
    param(
        [Parameter(Mandatory = $true)]
        [string]$Url
    )

    try {
        $response = Invoke-RestMethod -Uri $Url -TimeoutSec 2
        return $response.status -eq "ok"
    }
    catch {
        return $false
    }
}

function Invoke-Checked {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    & $FilePath @Arguments
    if ($LASTEXITCODE -ne 0) {
        throw "Command failed with exit code ${LASTEXITCODE}: $FilePath $($Arguments -join ' ')"
    }
}

function Invoke-NativeQuiet {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $nativePreference = Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
    if ($nativePreference) {
        $previousNativePreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        & $FilePath @Arguments *> $null
        return $LASTEXITCODE
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference

        if ($nativePreference) {
            $PSNativeCommandUseErrorActionPreference = $previousNativePreference
        }
    }
}

function Invoke-NativeOutput {
    param(
        [Parameter(Mandatory = $true)]
        [string]$FilePath,

        [Parameter(Mandatory = $true)]
        [string[]]$Arguments
    )

    $nativePreference = Get-Variable -Name PSNativeCommandUseErrorActionPreference -ErrorAction SilentlyContinue
    if ($nativePreference) {
        $previousNativePreference = $PSNativeCommandUseErrorActionPreference
        $PSNativeCommandUseErrorActionPreference = $false
    }

    $previousErrorActionPreference = $ErrorActionPreference
    $ErrorActionPreference = "Continue"

    try {
        $output = @(& $FilePath @Arguments 2>$null)
        return [pscustomobject]@{
            ExitCode = $LASTEXITCODE
            Output = $output
        }
    }
    finally {
        $ErrorActionPreference = $previousErrorActionPreference

        if ($nativePreference) {
            $PSNativeCommandUseErrorActionPreference = $previousNativePreference
        }
    }
}

$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot "..")).Path
$appHostProject = Join-Path $repoRoot "src\AppHost\AppHost.csproj"
$dotnet = Resolve-Tool $DotnetPath
$bash = Resolve-SmokeBash
$docker = Get-Command docker -ErrorAction SilentlyContinue

if (-not (Test-Path -LiteralPath $appHostProject)) {
    throw "AppHost project not found: $appHostProject"
}

$previousPassword = [Environment]::GetEnvironmentVariable("Parameters__postgres-password", "Process")
$hadPreviousPassword = $null -ne $previousPassword
$appHost = $null
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("aspire-validation-" + [Guid]::NewGuid().ToString("N"))
$stdoutPath = Join-Path $tempDir "apphost.out.log"
$stderrPath = Join-Path $tempDir "apphost.err.log"
$createdContainers = @()
$beforeContainers = @()
$dockerReady = $false

New-Item -ItemType Directory -Force $tempDir | Out-Null

try {
    Push-Location $repoRoot

    [Environment]::SetEnvironmentVariable("Parameters__postgres-password", $PostgresPassword, "Process")

    Write-Host "Building Aspire AppHost..."
    Invoke-Checked $dotnet @("build")

    if (-not $docker) {
        throw "Docker CLI not found. Install/start Docker before running Aspire validation."
    }

    $dockerInfoExitCode = Invoke-NativeQuiet $docker.Source @("info")
    if ($dockerInfoExitCode -ne 0) {
        throw "Docker daemon is not accessible. Start Docker Desktop or another Docker-compatible runtime before running Aspire validation."
    }

    $dockerReady = $true
    $beforeResult = Invoke-NativeOutput $docker.Source @("ps", "-a", "--format", "{{.Names}}")
    if ($beforeResult.ExitCode -ne 0) {
        throw "Unable to list Docker containers before validation."
    }
    $beforeContainers = @($beforeResult.Output)

    Write-Host "Starting Aspire AppHost..."
    $appHost = Start-Process `
        -FilePath $dotnet `
        -ArgumentList @("run", "--project", $appHostProject, "--launch-profile", "http") `
        -WorkingDirectory $repoRoot `
        -RedirectStandardOutput $stdoutPath `
        -RedirectStandardError $stderrPath `
        -WindowStyle Hidden `
        -PassThru

    $deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
    $ready = $false

    while ((Get-Date) -lt $deadline) {
        if ($appHost.HasExited) {
            throw "AppHost exited before validation completed. Exit code: $($appHost.ExitCode)"
        }

        $apiReady = Test-JsonHealth "http://localhost:8080/health"
        $frontendReady = Test-JsonHealth "http://localhost:3000/health"

        if ($apiReady -and $frontendReady) {
            $ready = $true
            break
        }

        Start-Sleep -Seconds 2
    }

    if (-not $ready) {
        throw "Aspire AppHost did not become ready within $StartupTimeoutSeconds seconds."
    }

    Write-Host "Running existing smoke test with $bash..."
    Invoke-Checked $bash @("./tests/smoke.sh")

    Write-Host "Aspire validation passed."
}
catch {
    Write-Host "Aspire validation failed." -ForegroundColor Red

    if (Test-Path -LiteralPath $stdoutPath) {
        Write-Host "--- AppHost stdout tail ---"
        Get-Content -LiteralPath $stdoutPath -Tail 120 -ErrorAction SilentlyContinue
    }

    if (Test-Path -LiteralPath $stderrPath) {
        Write-Host "--- AppHost stderr tail ---"
        Get-Content -LiteralPath $stderrPath -Tail 120 -ErrorAction SilentlyContinue
    }

    throw
}
finally {
    if ($appHost -and -not $appHost.HasExited) {
        Stop-Process -Id $appHost.Id -Force -ErrorAction SilentlyContinue
        Wait-Process -Id $appHost.Id -Timeout 20 -ErrorAction SilentlyContinue
    }

    if ($docker -and $dockerReady) {
        $afterResult = Invoke-NativeOutput $docker.Source @("ps", "-a", "--format", "{{.Names}}")
        $afterContainers = @()
        if ($afterResult.ExitCode -eq 0) {
            $afterContainers = @($afterResult.Output)
        }

        $createdContainers = $afterContainers | Where-Object {
            $beforeContainers -notcontains $_ -and $_ -match "^(api|worker|frontend|postgres|redis)-[a-z]+$"
        }

        if ($createdContainers.Count -gt 0) {
            Write-Host "Cleaning Aspire containers created during validation..."
            Invoke-NativeQuiet $docker.Source (@("stop") + $createdContainers) | Out-Null
            Invoke-NativeQuiet $docker.Source (@("rm") + $createdContainers) | Out-Null
        }
    }

    if ($hadPreviousPassword) {
        [Environment]::SetEnvironmentVariable("Parameters__postgres-password", $previousPassword, "Process")
    }
    else {
        [Environment]::SetEnvironmentVariable("Parameters__postgres-password", $null, "Process")
    }

    Pop-Location

    if (Test-Path -LiteralPath $tempDir) {
        Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction SilentlyContinue
    }
}
