param(
  [Parameter(Mandatory=$true)]
  [string]$InputPath,

  [Parameter(Mandatory=$true)]
  [string]$OutputPath
)

$ErrorActionPreference = "Stop"

function Read-DelimitedRows {
  param(
    [string]$Path,
    [string]$Delimiter
  )

  $lines = Get-Content -LiteralPath $Path -Encoding UTF8
  $rows = @()
  foreach ($line in $lines) {
    if ($Delimiter -eq "`t") {
      $cells = $line -split "`t", -1
    } else {
      $cells = $line -split [regex]::Escape($Delimiter), -1
    }
    $rows += ,@($cells)
  }
  return $rows
}

function Read-ExcelRows {
  param([string]$Path)

  $excel = $null
  $workbook = $null
  try {
    $excel = New-Object -ComObject Excel.Application
    $excel.Visible = $false
    $excel.DisplayAlerts = $false
    $workbook = $excel.Workbooks.Open($Path)
    $sheets = @()

    foreach ($sheet in $workbook.Worksheets) {
      $range = $sheet.UsedRange
      $rowCount = [int]$range.Rows.Count
      $colCount = [int]$range.Columns.Count
      $values = $range.Value2
      $rows = @()

      for ($r = 1; $r -le $rowCount; $r++) {
        $row = @()
        for ($c = 1; $c -le $colCount; $c++) {
          if ($rowCount -eq 1 -and $colCount -eq 1) {
            $cell = $values
          } else {
            $cell = $values[$r, $c]
          }
          if ($null -eq $cell) {
            $row += ""
          } else {
            $row += [string]$cell
          }
        }
        $rows += ,@($row)
      }

      $sheets += [ordered]@{
        name = $sheet.Name
        rows = @($rows)
      }
    }

    return $sheets
  } finally {
    if ($workbook) { $workbook.Close($false) | Out-Null }
    if ($excel) { $excel.Quit() | Out-Null }
  }
}

function Get-InputFiles {
  param([string]$Path)

  if (Test-Path -LiteralPath $Path -PathType Leaf) {
    return @(Get-Item -LiteralPath $Path)
  }

  $patterns = @("*.xlsx", "*.xls", "*.csv", "*.tsv", "*.txt", "*.md")
  $files = New-Object System.Collections.Generic.List[object]
  foreach ($pattern in $patterns) {
    Get-ChildItem -LiteralPath $Path -Filter $pattern -File -Recurse | ForEach-Object {
      $files.Add($_)
    }
  }
  return @($files | Sort-Object LastWriteTime -Descending)
}

$resolvedInput = Resolve-Path -LiteralPath $InputPath
$files = Get-InputFiles -Path $resolvedInput.Path
$resultFiles = @()

foreach ($file in $files) {
  $extension = $file.Extension.ToLowerInvariant()
  $fileEntry = [ordered]@{
    path = $file.FullName
    name = $file.Name
    last_write_time = $file.LastWriteTime.ToString("o")
    sheets = @()
    errors = @()
  }

  try {
    if ($extension -eq ".xlsx" -or $extension -eq ".xls") {
      $fileEntry.sheets = @(Read-ExcelRows -Path $file.FullName)
    } elseif ($extension -eq ".tsv") {
      $fileEntry.sheets = @([ordered]@{
        name = $file.BaseName
        rows = @(Read-DelimitedRows -Path $file.FullName -Delimiter "`t")
      })
    } elseif ($extension -eq ".csv") {
      $fileEntry.sheets = @([ordered]@{
        name = $file.BaseName
        rows = @(Read-DelimitedRows -Path $file.FullName -Delimiter ",")
      })
    } else {
      $fileEntry.sheets = @([ordered]@{
        name = $file.BaseName
        rows = @(Read-DelimitedRows -Path $file.FullName -Delimiter "`t")
      })
    }
  } catch {
    $fileEntry.errors = @($_.Exception.Message)
  }

  $resultFiles += $fileEntry
}

$result = [ordered]@{
  generated_at = (Get-Date).ToString("o")
  input_path = $resolvedInput.Path
  files = $resultFiles
}

$json = $result | ConvertTo-Json -Depth 100
Set-Content -LiteralPath $OutputPath -Value $json -Encoding UTF8
Write-Output "Wrote $OutputPath"
