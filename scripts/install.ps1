$ErrorActionPreference = "Stop"

$Repo = "ErwannCharlier/FaxMeTui"
$Bin = "fax-erwann.exe"

$arch = if ($env:PROCESSOR_ARCHITECTURE -eq "ARM64") { "arm64" } else { "amd64" }
$asset = "fax-erwann_windows_$arch.zip"
$url = "https://github.com/$Repo/releases/latest/download/$asset"

$root = Join-Path $env:LOCALAPPDATA "fax-erwann"
$bindir = Join-Path $root "bin"
New-Item -Force -ItemType Directory $bindir | Out-Null

$tmp = New-TemporaryFile
Invoke-WebRequest $url -OutFile $tmp
Expand-Archive -Force $tmp $bindir

$path = [Environment]::GetEnvironmentVariable("Path", "User")
if ($path -notlike "*$bindir*") {
  [Environment]::SetEnvironmentVariable("Path", "$path;$bindir", "User")
}

Write-Host "installed: $bindir\$Bin"
Write-Host "open a new terminal, then run: fax-erwann"
