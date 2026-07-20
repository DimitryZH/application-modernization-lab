param(
    [string]$ProjectName = "online-boutique-exp06",
    [string]$BaseUrl = "http://localhost:8080",
    [int]$StartupTimeoutSeconds = 180,
    [int]$StableSeconds = 30,
    [switch]$SkipCleanup
)

$ErrorActionPreference = "Stop"

$script:ComposeExe = "docker-compose"
$script:ComposeBaseArgs = @()
& docker-compose --version *> $null
if ($LASTEXITCODE -ne 0) {
    $script:ComposeExe = "docker"
    $script:ComposeBaseArgs = @("compose")
    & docker compose version *> $null
    if ($LASTEXITCODE -ne 0) {
        throw "Docker Compose is not available as docker-compose or docker compose"
    }
}

function Invoke-Compose {
    & $script:ComposeExe @script:ComposeBaseArgs @args
    if ($LASTEXITCODE -ne 0) {
        throw "Compose command failed: $($script:ComposeExe) $($script:ComposeBaseArgs -join ' ') $($args -join ' ')"
    }
}

$requiredServices = @(
    "redis-cart",
    "adservice",
    "cartservice",
    "checkoutservice",
    "currencyservice",
    "emailservice",
    "frontend",
    "paymentservice",
    "productcatalogservice",
    "recommendationservice",
    "shippingservice"
)

function Invoke-Step {
    param(
        [string]$Name,
        [scriptblock]$Action
    )
    Write-Host "[validate-compose] $Name"
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

try {
    Invoke-Step "compose config" {
        Invoke-Compose -p $ProjectName config --quiet
    }

    Invoke-Step "pull required images" {
        Invoke-Compose -p $ProjectName pull --quiet
    }

    Invoke-Step "pull optional loadgenerator image" {
        Invoke-Compose -p $ProjectName --profile loadgenerator pull --quiet loadgenerator
    }

    Invoke-Step "start required stack" {
        Invoke-Compose -p $ProjectName up -d
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
        foreach ($service in $requiredServices) {
            $id = Invoke-Compose -p $ProjectName ps -q $service
            if (-not $id) {
                throw "missing container for $service"
            }
            $state = docker inspect --format '{{.State.Running}} {{.State.Restarting}} {{.RestartCount}} {{.State.ExitCode}}' $id
            $parts = $state -split ' '
            if ($parts[0] -ne "true" -or $parts[1] -ne "false" -or $parts[3] -ne "0") {
                throw "container $service is not stable: $state"
            }
        }
    }

    Invoke-Step "resolved image inventory" {
        foreach ($service in $requiredServices) {
            $id = Invoke-Compose -p $ProjectName ps -q $service
            $image = docker inspect --format '{{.Config.Image}}' $id
            Write-Host "[validate-compose] image $service=$image"
        }
    }

    Write-Host "[validate-compose] PASS"
}
finally {
    if (-not $SkipCleanup) {
        Write-Host "[validate-compose] cleanup"
        Invoke-Compose -p $ProjectName down -v --remove-orphans
    }
}
