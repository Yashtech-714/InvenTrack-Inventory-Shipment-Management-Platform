param(
    [int]$ProductsRequests = 300,
    [int]$ReportsRequests = 200,
    [int]$WarmupRequests = 20
)

$ErrorActionPreference = "Stop"

function Get-ComposeCommand {
    if (Get-Command docker-compose -ErrorAction SilentlyContinue) {
        return "docker-compose"
    }
    return "docker compose"
}

function Invoke-Compose {
    param([string]$ComposeCmd, [string[]]$ComposeArgs)
    Write-Host "> $ComposeCmd $($ComposeArgs -join ' ')" -ForegroundColor DarkGray
    if ($ComposeCmd -eq "docker-compose") {
        & docker-compose @ComposeArgs
    } else {
        & docker compose @ComposeArgs
    }
}

function Get-BackendCacheType {
    try {
        $json = docker inspect wms-backend --format "{{json .Config.Env}}"
        $envList = $json | ConvertFrom-Json
        $entry = $envList | Where-Object { $_ -like "SPRING_CACHE_TYPE=*" } | Select-Object -First 1
        if ($null -ne $entry -and $entry.Contains("=")) {
            return $entry.Split("=", 2)[1]
        }
        return ""
    } catch {
        return ""
    }
}

function Wait-BackendReady {
    param([int]$TimeoutSec = 120)

    $deadline = (Get-Date).AddSeconds($TimeoutSec)
    while ((Get-Date) -lt $deadline) {
        try {
            $state = docker inspect wms-backend --format "{{.State.Health.Status}}" 2>$null
            if ($state -eq "healthy") {
                try {
                    $null = Invoke-RestMethod -Uri "http://localhost:8080/products" -TimeoutSec 10
                    return
                } catch {
                    Start-Sleep -Seconds 2
                }
            } else {
                Start-Sleep -Seconds 2
            }
        } catch {
            Start-Sleep -Seconds 2
        }
    }
    throw "Backend did not become ready within $TimeoutSec seconds."
}

function Warmup-Endpoint {
    param([string]$Url, [int]$Count)
    for ($i = 0; $i -lt $Count; $i++) {
        try { $null = Invoke-RestMethod -Uri $Url -TimeoutSec 15 } catch {}
    }
}

function Measure-Endpoint {
    param(
        [string]$Url,
        [int]$Requests
    )

    $times = New-Object System.Collections.Generic.List[double]
    $errors = 0
    $total = [System.Diagnostics.Stopwatch]::StartNew()

    for ($i = 0; $i -lt $Requests; $i++) {
        $sw = [System.Diagnostics.Stopwatch]::StartNew()
        try {
            $null = Invoke-RestMethod -Uri $Url -TimeoutSec 30
        } catch {
            $errors++
        }
        $sw.Stop()
        $times.Add($sw.Elapsed.TotalMilliseconds)
    }

    $total.Stop()

    $sorted = $times | Sort-Object
    $avg = ($times | Measure-Object -Average).Average
    $p95Index = [Math]::Max([int][Math]::Ceiling(0.95 * $sorted.Count) - 1, 0)
    $p95 = $sorted[$p95Index]
    $throughput = $Requests / [Math]::Max($total.Elapsed.TotalSeconds, 0.001)
    $errorRate = ($errors / [Math]::Max($Requests, 1)) * 100

    return [PSCustomObject]@{
        Url            = $Url
        Requests       = $Requests
        AvgMs          = [Math]::Round($avg, 2)
        P95Ms          = [Math]::Round($p95, 2)
        ThroughputRps  = [Math]::Round($throughput, 2)
        ErrorRatePct   = [Math]::Round($errorRate, 2)
    }
}

function Get-RedisStats {
    $stats = @{}
    try {
        $lines = docker exec wms-redis redis-cli INFO stats
        foreach ($line in $lines) {
            if ($line -match "^keyspace_hits:(\d+)") {
                $stats.hits = [int64]$Matches[1]
            }
            if ($line -match "^keyspace_misses:(\d+)") {
                $stats.misses = [int64]$Matches[1]
            }
        }
        if (-not $stats.ContainsKey('hits')) { $stats.hits = 0 }
        if (-not $stats.ContainsKey('misses')) { $stats.misses = 0 }
    } catch {
        $stats.hits = 0
        $stats.misses = 0
    }

    $total = $stats.hits + $stats.misses
    $ratio = if ($total -gt 0) { [Math]::Round(($stats.hits / $total) * 100, 2) } else { 0 }

    return [PSCustomObject]@{
        Hits = $stats.hits
        Misses = $stats.misses
        HitRatioPct = $ratio
    }
}

function Reset-RedisStats {
    for ($i = 0; $i -lt 5; $i++) {
        try {
            docker exec wms-redis redis-cli FLUSHALL | Out-Null
            docker exec wms-redis redis-cli CONFIG RESETSTAT | Out-Null

            $stats = Get-RedisStats
            if ($stats.Hits -eq 0 -and $stats.Misses -eq 0) {
                return
            }
        } catch {
            Start-Sleep -Seconds 1
        }
    }
    throw "Failed to reset Redis stats to zero."
}

function Run-Mode {
    param(
        [string]$ComposeCmd,
        [string]$ModeName,
        [bool]$DisableCache
    )

    Write-Host "\n=== Running mode: $ModeName ===" -ForegroundColor Cyan

    $overrideFile = Join-Path (Get-Location) "docker-compose.benchmark.override.yml"
    if (Test-Path $overrideFile) { Remove-Item $overrideFile -Force }

    if ($DisableCache) {
        @"
services:
  backend:
    environment:
      - SPRING_CACHE_TYPE=none
"@ | Set-Content -Path $overrideFile -Encoding UTF8

        Invoke-Compose -ComposeCmd $ComposeCmd -ComposeArgs @("-f", "docker-compose.yml", "-f", "docker-compose.benchmark.override.yml", "down", "-v", "--remove-orphans")
        Invoke-Compose -ComposeCmd $ComposeCmd -ComposeArgs @("-f", "docker-compose.yml", "-f", "docker-compose.benchmark.override.yml", "up", "-d", "--build", "--force-recreate", "redis", "backend")
    } else {
        Invoke-Compose -ComposeCmd $ComposeCmd -ComposeArgs @("down", "-v", "--remove-orphans")
        Invoke-Compose -ComposeCmd $ComposeCmd -ComposeArgs @("up", "-d", "--build", "--force-recreate", "redis", "backend")
    }

    Wait-BackendReady
    $cacheType = Get-BackendCacheType
    if ($DisableCache -and $cacheType -ne "none") {
        throw "NO_CACHE mode validation failed: SPRING_CACHE_TYPE is '$cacheType' (expected 'none')."
    }
    if (-not $DisableCache -and $cacheType -eq "none") {
        throw "REDIS_CACHE mode validation failed: SPRING_CACHE_TYPE is 'none'."
    }
    Reset-RedisStats

    if (-not $DisableCache) {
        Warmup-Endpoint -Url "http://localhost:8080/products" -Count $WarmupRequests
        Warmup-Endpoint -Url "http://localhost:8080/reports/inventory" -Count $WarmupRequests
    }

    $products = Measure-Endpoint -Url "http://localhost:8080/products" -Requests $ProductsRequests
    $reports  = Measure-Endpoint -Url "http://localhost:8080/reports/inventory" -Requests $ReportsRequests
    $redis    = Get-RedisStats

    if (Test-Path $overrideFile) { Remove-Item $overrideFile -Force }

    return [PSCustomObject]@{
        Mode = $ModeName
        Products = $products
        Reports = $reports
        Redis = $redis
    }
}

function Compare-Metrics {
    param($Before, $After, [string]$Section)

    $rows = @()
    foreach ($metric in @("AvgMs", "P95Ms", "ThroughputRps", "ErrorRatePct")) {
        $b = [double]$Before.$metric
        $a = [double]$After.$metric
        $delta = if ($b -ne 0) { (($a - $b) / $b) * 100 } else { 0 }

        $rows += [PSCustomObject]@{
            Endpoint = $Section
            Metric = $metric
            Before = [Math]::Round($b, 2)
            After = [Math]::Round($a, 2)
            ChangePct = [Math]::Round($delta, 2)
        }
    }
    return $rows
}

$composeCmd = Get-ComposeCommand
Write-Host "Using compose command: $composeCmd" -ForegroundColor Green

$before = Run-Mode -ComposeCmd $composeCmd -ModeName "NO_CACHE" -DisableCache $true
$after  = Run-Mode -ComposeCmd $composeCmd -ModeName "REDIS_CACHE" -DisableCache $false

Write-Host "\n=== Raw Results ===" -ForegroundColor Green
[PSCustomObject]@{
    Mode = $before.Mode
    ProductsAvgMs = $before.Products.AvgMs
    ProductsP95Ms = $before.Products.P95Ms
    ProductsRps = $before.Products.ThroughputRps
    ReportsAvgMs = $before.Reports.AvgMs
    ReportsP95Ms = $before.Reports.P95Ms
    ReportsRps = $before.Reports.ThroughputRps
    RedisHitRatioPct = $before.Redis.HitRatioPct
} | Format-Table -AutoSize

[PSCustomObject]@{
    Mode = $after.Mode
    ProductsAvgMs = $after.Products.AvgMs
    ProductsP95Ms = $after.Products.P95Ms
    ProductsRps = $after.Products.ThroughputRps
    ReportsAvgMs = $after.Reports.AvgMs
    ReportsP95Ms = $after.Reports.P95Ms
    ReportsRps = $after.Reports.ThroughputRps
    RedisHitRatioPct = $after.Redis.HitRatioPct
} | Format-Table -AutoSize

Write-Host "\n=== Side-by-Side Comparison (%) ===" -ForegroundColor Green
$cmp = @()
$cmp += Compare-Metrics -Before $before.Products -After $after.Products -Section "/products"
$cmp += Compare-Metrics -Before $before.Reports -After $after.Reports -Section "/reports/inventory"
$cmp | Format-Table -AutoSize

Write-Host "\n=== Redis Cache Stats (CACHE MODE) ===" -ForegroundColor Green
$after.Redis | Format-Table -AutoSize

Write-Host "\nDone. Tip: negative % on AvgMs/P95Ms is good (lower latency), positive % on ThroughputRps is good." -ForegroundColor Cyan
