param(
    [string]$BaseUrl = "http://localhost:8080",
    [int]$StartupTimeoutSeconds = 180,
    [int]$StableSeconds = 30,
    [string]$AppHostProject = "./src/OnlineBoutique.AppHost/OnlineBoutique.AppHost.csproj",
    [switch]$StartAppHost,
    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"

$requiredServices = @(
    @{ Name = "redis-cart"; Image = "redis:alpine@sha256:9d317178eceac8454a2284a9e6df2466b93c745529947f0cd42a0fa9609d7005"; Env = @() },
    @{ Name = "adservice"; Image = "us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/adservice:v0.10.6@sha256:f580c4853e896dd2083f0c270c4b7aa5feda6dd56058a93b87d0c88334a4c07d"; Env = @("PORT=9555") },
    @{ Name = "cartservice"; Image = "us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/cartservice:v0.10.6@sha256:b5c29ddb3238474ea8d1842f07004fedeeae47f660627ab111a613a681cd0356"; Env = @("REDIS_ADDR=redis-cart:6379") },
    @{ Name = "checkoutservice"; Image = "us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/checkoutservice:v0.10.6@sha256:ab40699b6d9e45c9a93b5427008f327fbe912465361e2ff7a1a1be7111e36134"; Env = @("PORT=5050", "PRODUCT_CATALOG_SERVICE_ADDR=productcatalogservice:3550", "SHIPPING_SERVICE_ADDR=shippingservice:50051", "PAYMENT_SERVICE_ADDR=paymentservice:50051", "EMAIL_SERVICE_ADDR=emailservice:8080", "CURRENCY_SERVICE_ADDR=currencyservice:7000", "CART_SERVICE_ADDR=cartservice:7070") },
    @{ Name = "currencyservice"; Image = "us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/currencyservice:v0.10.6@sha256:7b2f3f804555c926861d67cd22c1b7c9e32d46b81cf1a64dd3089ae424d73be9"; Env = @("PORT=7000", "DISABLE_PROFILER=1") },
    @{ Name = "emailservice"; Image = "us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/emailservice:v0.10.6@sha256:77fd45d411b3550cbd39e30bda83ed6ea23d87fd6e58e69cf9fa2808e003984d"; Env = @("PORT=8080", "DISABLE_PROFILER=1") },
    @{ Name = "frontend"; Image = "us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/frontend:v0.10.6@sha256:c06df08eccd78568a37292cfbe889df42fac48691b7fb05f2deeba0ae8d669ef"; Env = @("PORT=8080", "ENV_PLATFORM=local", "PRODUCT_CATALOG_SERVICE_ADDR=productcatalogservice:3550", "CURRENCY_SERVICE_ADDR=currencyservice:7000", "CART_SERVICE_ADDR=cartservice:7070", "RECOMMENDATION_SERVICE_ADDR=recommendationservice:8080", "SHIPPING_SERVICE_ADDR=shippingservice:50051", "CHECKOUT_SERVICE_ADDR=checkoutservice:5050", "AD_SERVICE_ADDR=adservice:9555", "SHOPPING_ASSISTANT_SERVICE_ADDR=shoppingassistantservice:80", "ENABLE_PROFILER=0") },
    @{ Name = "paymentservice"; Image = "us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/paymentservice:v0.10.6@sha256:735b6d3255e2c74b0135a95cfc2337987e492f24e163c0bb9a853635876993c4"; Env = @("PORT=50051", "DISABLE_PROFILER=1") },
    @{ Name = "productcatalogservice"; Image = "us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/productcatalogservice:v0.10.6@sha256:fb8568ecfc948717eb07746a6ce360fb8e5f906ae8a874cbad666891f0d21790"; Env = @("PORT=3550", "DISABLE_PROFILER=1") },
    @{ Name = "recommendationservice"; Image = "us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/recommendationservice:v0.10.6@sha256:5d8321f2d24132889f654f75308e541b0626e6ae0cbacf81b170e5eb0921b415"; Env = @("PORT=8080", "PRODUCT_CATALOG_SERVICE_ADDR=productcatalogservice:3550", "DISABLE_PROFILER=1") },
    @{ Name = "shippingservice"; Image = "us-central1-docker.pkg.dev/online-boutique-ci/microservices-demo/shippingservice:v0.10.6@sha256:8527bafff8c8776e345f2dca0641f6e8595b053ce67f9a5af66f5a85d9eaca9d"; Env = @("PORT=50051", "DISABLE_PROFILER=1") }
)

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Action
    )
    Write-Host "[validate-aspire] $Name"
    & $Action
}

function Assert-Contains {
    param(
        [string]$Text,
        [string]$Expected,
        [string]$Message
    )
    if ($Text -notmatch [regex]::Escape($Expected)) {
        throw $Message
    }
}

function Invoke-ShopRequest {
    param(
        [string]$Uri,
        [string]$Method = "GET",
        [hashtable]$Body = $null,
        [Microsoft.PowerShell.Commands.WebRequestSession]$Session
    )
    $params = @{
        Uri = $Uri
        Method = $Method
        WebSession = $Session
        UseBasicParsing = $true
        TimeoutSec = 30
    }
    if ($Body) {
        $params.Body = $Body
        $params.ContentType = "application/x-www-form-urlencoded"
    }
    Invoke-WebRequest @params
}

function Convert-ImageReference {
    param([string]$Image)

    $digestIndex = $Image.IndexOf("@sha256:")
    if ($digestIndex -lt 0) {
        return $Image
    }

    $repositoryAndTag = $Image.Substring(0, $digestIndex)
    $digest = $Image.Substring($digestIndex)
    $lastSlash = $repositoryAndTag.LastIndexOf("/")
    $lastColon = $repositoryAndTag.LastIndexOf(":")
    if ($lastColon -gt $lastSlash) {
        $repositoryAndTag = $repositoryAndTag.Substring(0, $lastColon)
    }

    return "$repositoryAndTag$digest"
}

function Get-ContainerIdForService {
    param(
        [hashtable]$Service,
        [string]$AspireCreatorIdentity = $null
    )

    $expectedImage = Convert-ImageReference -Image $Service.Image
    $ids = docker ps -q
    $containerMatches = @()
    foreach ($id in $ids) {
        $dcpName = docker inspect --format '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.name" }}' $id
        $dcpGroupVersion = docker inspect --format '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.group-version" }}' $id
        $dcpCreatorProcessId = docker inspect --format '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.creatorProcessId" }}' $id
        $dcpCreatorProcessStartTime = docker inspect --format '{{ index .Config.Labels "com.microsoft.developer.usvc-dev.creatorProcessStartTime" }}' $id
        if ([string]::IsNullOrWhiteSpace($dcpName) -or $dcpName -notmatch "^$([regex]::Escape($Service.Name))-[a-z0-9]+$") {
            continue
        }
        if ($dcpGroupVersion -ne "usvc-dev.developer.microsoft.com/v1") {
            continue
        }
        if ([string]::IsNullOrWhiteSpace($dcpCreatorProcessId) -or [string]::IsNullOrWhiteSpace($dcpCreatorProcessStartTime)) {
            continue
        }

        $creatorIdentity = "$dcpCreatorProcessId|$dcpCreatorProcessStartTime"
        if ($AspireCreatorIdentity -and $creatorIdentity -ne $AspireCreatorIdentity) {
            continue
        }

        $image = docker inspect --format '{{.Config.Image}}' $id
        if ((Convert-ImageReference -Image $image) -eq $expectedImage) {
            $containerMatches += [pscustomobject]@{
                Id = $id
                CreatorIdentity = $creatorIdentity
                ResourceLabel = $dcpName
            }
        }
    }

    if ($containerMatches.Count -gt 1) {
        $matchList = ($containerMatches | ForEach-Object { "$($_.Id):$($_.ResourceLabel)" }) -join ", "
        throw "multiple Aspire containers matched $($Service.Name): $matchList"
    }

    if ($containerMatches.Count -eq 0) {
        return $null
    }

    return $containerMatches[0]
}

function Assert-ServiceContainer {
    param(
        [hashtable]$Service,
        [string]$AspireCreatorIdentity = $null
    )

    $container = Get-ContainerIdForService -Service $Service -AspireCreatorIdentity $AspireCreatorIdentity
    if (-not $container) {
        throw "missing running Aspire-managed container for $($Service.Name)"
    }

    $id = $container.Id
    $state = docker inspect --format '{{.State.Running}} {{.State.Restarting}} {{.RestartCount}} {{.State.ExitCode}}' $id
    $parts = $state -split ' '
    if ($parts[0] -ne "true" -or $parts[1] -ne "false" -or $parts[3] -ne "0") {
        throw "container $($Service.Name) is not stable: $state"
    }

    $env = docker inspect --format '{{range .Config.Env}}{{println .}}{{end}}' $id
    foreach ($expected in $Service.Env) {
        Assert-Contains -Text $env -Expected $expected -Message "container $($Service.Name) is missing expected environment value $expected"
    }

    return $container
}

function Get-AspireCreatorIdentity {
    $frontendService = $requiredServices | Where-Object { $_.Name -eq "frontend" } | Select-Object -First 1
    $frontend = Assert-ServiceContainer -Service $frontendService
    return $frontend.CreatorIdentity
}

function Assert-AspireContainerSet {
    $aspireCreatorIdentity = Get-AspireCreatorIdentity
    foreach ($service in $requiredServices) {
        [void](Assert-ServiceContainer -Service $service -AspireCreatorIdentity $aspireCreatorIdentity)
    }

    return $aspireCreatorIdentity
}

$appHostProcess = $null
$appHostLog = Join-Path ([System.IO.Path]::GetTempPath()) "online-boutique-aspire-apphost.log"
$appHostErrorLog = Join-Path ([System.IO.Path]::GetTempPath()) "online-boutique-aspire-apphost.err.log"

try {
    Invoke-Step "build AppHost" {
        dotnet build $AppHostProject
        if ($LASTEXITCODE -ne 0) {
            throw "dotnet build failed for $AppHostProject"
        }
    }

    if ($StartAppHost) {
        Invoke-Step "start AppHost" {
            if (Test-Path $appHostLog) {
                Remove-Item $appHostLog -Force
            }
            if (Test-Path $appHostErrorLog) {
                Remove-Item $appHostErrorLog -Force
            }
            $appHostProcess = Start-Process -FilePath "dotnet" -ArgumentList @("run", "--project", $AppHostProject, "--no-build") -NoNewWindow -RedirectStandardOutput $appHostLog -RedirectStandardError $appHostErrorLog -PassThru
            Start-Sleep -Seconds 5
            if ($appHostProcess.HasExited) {
                $log = if (Test-Path $appHostLog) { Get-Content $appHostLog -Raw } else { "" }
                $errorLog = if (Test-Path $appHostErrorLog) { Get-Content $appHostErrorLog -Raw } else { "" }
                throw "AppHost exited during startup. Log: $log $errorLog"
            }
        }
    }
    else {
        Write-Host "[validate-aspire] validating an already running AppHost. Pass -StartAppHost to start it from this script."
    }

    Invoke-Step "wait for frontend" {
        $deadline = (Get-Date).AddSeconds($StartupTimeoutSeconds)
        do {
            try {
                $health = Invoke-WebRequest -Uri "$BaseUrl/_healthz" -UseBasicParsing -TimeoutSec 5
                if ($health.StatusCode -eq 200 -and $health.Content -match "ok") {
                    return
                }
            }
            catch {
                Start-Sleep -Seconds 3
            }
        } while ((Get-Date) -lt $deadline)
        throw "frontend did not become available at $BaseUrl within $StartupTimeoutSeconds seconds"
    }

    Invoke-Step "browse, cart, and checkout path" {
        $session = New-Object Microsoft.PowerShell.Commands.WebRequestSession
        $homeResponse = Invoke-ShopRequest -Uri "$BaseUrl/" -Session $session
        Assert-Contains -Text $homeResponse.Content -Expected "Sunglasses" -Message "home page did not include expected product data"

        $productId = "OLJCESPC7Z"
        $product = Invoke-ShopRequest -Uri "$BaseUrl/product/$productId" -Session $session
        Assert-Contains -Text $product.Content -Expected "Add To Cart" -Message "product page did not render add-to-cart form"

        $cart = Invoke-ShopRequest -Uri "$BaseUrl/cart" -Method "POST" -Body @{ product_id = $productId; quantity = "1" } -Session $session
        Assert-Contains -Text $cart.Content -Expected "Sunglasses" -Message "cart page did not contain the added product"

        $checkout = Invoke-ShopRequest -Uri "$BaseUrl/cart/checkout" -Method "POST" -Body @{
            email = "validation@example.com"
            street_address = "1600 Amphitheatre Parkway"
            zip_code = "94043"
            city = "Mountain View"
            state = "CA"
            country = "United States"
            credit_card_number = "4111111111111111"
            credit_card_expiration_month = "12"
            credit_card_expiration_year = "2030"
            credit_card_cvv = "123"
        } -Session $session
        Assert-Contains -Text $checkout.Content -Expected "Your order is complete" -Message "checkout did not complete successfully"
    }

    Invoke-Step "container stability window" {
        Start-Sleep -Seconds $StableSeconds
        [void](Assert-AspireContainerSet)
    }

    Invoke-Step "resolved image inventory" {
        $aspireCreatorIdentity = Assert-AspireContainerSet
        foreach ($service in $requiredServices) {
            $container = Assert-ServiceContainer -Service $service -AspireCreatorIdentity $aspireCreatorIdentity
            $id = $container.Id
            $image = docker inspect --format '{{.Config.Image}}' $id
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
        if (-not $appHostProcess.HasExited) {
            Stop-Process -Id $appHostProcess.Id -Force
        }
    }
}