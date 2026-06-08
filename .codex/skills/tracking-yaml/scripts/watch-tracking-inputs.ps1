param(
  [string[]]$InputPaths = @(),

  [string]$OutputPath = "",

  [int]$IntervalSeconds = 5,

  [switch]$Once
)

$ErrorActionPreference = "Stop"
$extractScript = Join-Path $PSScriptRoot "extract-tracking-tables.ps1"
$extensions = @(".xlsx", ".xls", ".csv", ".tsv", ".txt", ".md")
$lastSignature = ""

if ($InputPaths.Count -eq 0) {
  $InputPaths = @((Join-Path $env:USERPROFILE "Downloads"), (Get-Location).Path)
}

if (-not $OutputPath) {
  $OutputPath = Join-Path (Get-Location).Path "tracking_tables_extract.json"
}

function Get-CandidateSignature {
  param([string[]]$Paths)

  $items = @()
  foreach ($path in $Paths) {
    if (-not (Test-Path -LiteralPath $path)) { continue }
    $items += Get-ChildItem -LiteralPath $path -File -Recurse |
      Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 20 FullName, Length, LastWriteTime
  }

  return ($items | ConvertTo-Json -Depth 5 -Compress)
}

function Run-Extraction {
  param([string[]]$Paths)

  $tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("tracking-yaml-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Force -Path $tempDir | Out-Null

  foreach ($path in $Paths) {
    if (-not (Test-Path -LiteralPath $path)) { continue }
    Get-ChildItem -LiteralPath $path -File -Recurse |
      Where-Object { $extensions -contains $_.Extension.ToLowerInvariant() } |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 20 |
      ForEach-Object {
        $target = Join-Path $tempDir $_.Name
        Copy-Item -LiteralPath $_.FullName -Destination $target -Force
      }
  }

  & $extractScript -InputPath $tempDir -OutputPath $OutputPath
  Remove-Item -LiteralPath $tempDir -Recurse -Force
}

do {
  $signature = Get-CandidateSignature -Paths $InputPaths
  if ($signature -and $signature -ne $lastSignature) {
    $lastSignature = $signature
    Run-Extraction -Paths $InputPaths
  }

  if ($Once) { break }
  Start-Sleep -Seconds $IntervalSeconds
} while ($true)
