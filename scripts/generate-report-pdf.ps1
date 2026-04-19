$ErrorActionPreference = 'Stop'

$root = Split-Path -Parent $PSScriptRoot
$scriptPath = Join-Path $PSScriptRoot 'generate-report-pdf.py'

if (-not (Test-Path -LiteralPath $scriptPath)) {
    throw "PDF generator script not found: $scriptPath"
}

python $scriptPath
