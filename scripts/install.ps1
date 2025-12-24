$ErrorActionPreference = "Stop"

$Repo = "ErwannCharlier/FaxMeTui"
$Bin = "fax-erwann.exe"

$arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
$asset = "fax-erwann_windows_$arch.zip"
$url = "https://github.com/$Repo/releases/latest/download/$asset"

$root = Join-Path $env:LOCALAPPDATA "fax-erwann"
$bindir = Join-Path $root "bin"
New-Item -Force -ItemType Directory $bindir | Out-Null

$tmpZip = Join-Path $env:TEMP ("fax-erwann_" + [guid]::NewGuid().ToString() + ".zip")

try {
  Invoke-WebRequest -Uri $url -OutFile $tmpZip -MaximumRedirection 5
} catch {
  throw "download failed: $url"
}

try {
  Expand-Archive -Force $tmpZip $bindir
} catch {
  $head = (Get-Content -Raw -Encoding Byte -TotalCount 200 $tmpZip 2>$null)
  throw "bad archive. is the asset name correct? expected $asset"
} finally {
  Remove-Item -Force $tmpZip -ErrorAction SilentlyContinue
}

$path = [Environment]::GetEnvironmentVariable("Path", "User")
if ($path -notlike "*$bindir*") {
  [Environment]::SetEnvironmentVariable("Path", "$path;$bindir", "User")
}
$env:Path = "$env:Path;$bindir"

Write-Host "installed: $bindir\$Bin"
Write-Host "run: fax-erwann"
