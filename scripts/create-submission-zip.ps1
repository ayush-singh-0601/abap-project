$ErrorActionPreference = 'Stop'

$root = (Get-Location).Path
$distDir = Join-Path $root 'dist'

if (-not (Test-Path -LiteralPath $distDir)) {
    New-Item -ItemType Directory -Path $distDir | Out-Null
}

$baseZip = Join-Path $distDir 'Purchase_Order_Analytics_Capstone_Package.zip'
$zipPath = $baseZip

if (Test-Path -LiteralPath $zipPath) {
    $timestamp = Get-Date -Format 'yyyyMMdd_HHmmss'
    $zipPath = Join-Path $distDir "Purchase_Order_Analytics_Capstone_Package_$timestamp.zip"
}

$pathsToCompress = @(
    (Join-Path $root 'README.md'),
    (Join-Path $root 'src'),
    (Join-Path $root 'docs'),
    (Join-Path $root 'screenshots'),
    (Join-Path $root 'scripts')
)

Compress-Archive -Path $pathsToCompress -DestinationPath $zipPath -CompressionLevel Optimal

Write-Output "ZIP generated at: $zipPath"
