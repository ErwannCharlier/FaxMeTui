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
$tmpDir = Join-Path $env:TEMP ("fax-erwann_" + [guid]::NewGuid().ToString())

if ($PSVersionTable.PSVersion.Major -lt 6) {
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile $tmpZip -MaximumRedirection 5
} else {
  Invoke-WebRequest -Uri $url -OutFile $tmpZip -MaximumRedirection 5
}

New-Item -Force -ItemType Directory $tmpDir | Out-Null
Expand-Archive -Force -Path $tmpZip -DestinationPath $tmpDir

$exe = Get-ChildItem -Path $tmpDir -Recurse -File -Filter $Bin | Select-Object -First 1
if (-not $exe) { throw "binary not found in archive: $asset" }

Copy-Item -Force $exe.FullName (Join-Path $bindir $Bin)

Remove-Item -Force $tmpZip -ErrorAction SilentlyContinue
Remove-Item -Recurse -Force $tmpDir -ErrorAction SilentlyContinue

$path = [Environment]::GetEnvironmentVariable("Path", "User")
if ($path -notlike "*$bindir*") {
  [Environment]::SetEnvironmentVariable("Path", "$path;$bindir", "User")
}
$env:Path = "$env:Path;$bindir"

Write-Host "installed: $bindir\$Bin"
Write-Host "run: fax-erwann"
