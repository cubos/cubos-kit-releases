# cubos-kit installer (Windows / PowerShell)
#
# Usage:
#   irm https://raw.githubusercontent.com/cubos/cubos-kit-releases/main/install.ps1 | iex
#
# Environment variables:
#   CUBOS_KIT_VERSION  Specific version to install, e.g. v0.2.0 (default: latest)
#   INSTALL_DIR        Where to install the binary (default: $env:LOCALAPPDATA\cubos-kit\bin)

$ErrorActionPreference = 'Stop'

$GitHubRepo = if ($env:CUBOS_KIT_REPO) { $env:CUBOS_KIT_REPO } else { 'cubos/cubos-kit-releases' }
$InstallDir = if ($env:INSTALL_DIR)    { $env:INSTALL_DIR }    else { Join-Path $env:LOCALAPPDATA 'cubos-kit\bin' }

function Info($msg)  { Write-Host "==> $msg" -ForegroundColor Blue }
function Warn($msg)  { Write-Host "!!! $msg" -ForegroundColor Yellow }
function Die($msg)   { Write-Host "xxx $msg" -ForegroundColor Red; exit 1 }

function Get-Platform {
  $arch = switch ($env:PROCESSOR_ARCHITECTURE) {
    'AMD64' { 'x64' }
    'ARM64' { 'arm64' }
    default { Die "unsupported architecture: $($env:PROCESSOR_ARCHITECTURE)" }
  }
  return "win32-$arch"
}

function Get-ReleaseUrl($version, $asset) {
  if ($version -eq 'latest') {
    return "https://github.com/$GitHubRepo/releases/latest/download/$asset"
  }
  return "https://github.com/$GitHubRepo/releases/download/$version/$asset"
}

$platform = Get-Platform
$version  = if ($env:CUBOS_KIT_VERSION) { $env:CUBOS_KIT_VERSION } else { 'latest' }
$archive  = "cubos-kit-$platform.zip"

Info "Installing cubos-kit $version ($platform) to $InstallDir"

$tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "cubos-kit-$([guid]::NewGuid())")
try {
  $archiveUrl = Get-ReleaseUrl $version $archive
  $shaUrl     = Get-ReleaseUrl $version "$archive.sha256"

  Info "Downloading $archive"
  Invoke-WebRequest -Uri $archiveUrl -OutFile (Join-Path $tmp $archive)

  Info "Verifying checksum"
  Invoke-WebRequest -Uri $shaUrl -OutFile (Join-Path $tmp "$archive.sha256")
  $expected = (Get-Content (Join-Path $tmp "$archive.sha256") -Raw).Split()[0].ToLower()
  $actual   = (Get-FileHash (Join-Path $tmp $archive) -Algorithm SHA256).Hash.ToLower()
  if ($expected -ne $actual) { Die "checksum verification failed" }

  Info "Extracting"
  Expand-Archive -Path (Join-Path $tmp $archive) -DestinationPath $tmp -Force

  if (-not (Test-Path $InstallDir)) {
    New-Item -ItemType Directory -Path $InstallDir -Force | Out-Null
  }
  Move-Item -Path (Join-Path $tmp 'cubos-kit.exe') -Destination (Join-Path $InstallDir 'cubos-kit.exe') -Force

  Info "Installed: $(Join-Path $InstallDir 'cubos-kit.exe')"

  $userPath = [Environment]::GetEnvironmentVariable('PATH', 'User')
  if (-not $userPath -or ($userPath -split ';') -notcontains $InstallDir) {
    Warn "$InstallDir is not in your PATH."
    Warn "Add it with:"
    Warn "  [Environment]::SetEnvironmentVariable('PATH', `"$InstallDir;`$env:PATH`", 'User')"
  }

  Info "Run 'cubos-kit --version' to verify."
}
finally {
  Remove-Item -Recurse -Force $tmp -ErrorAction SilentlyContinue
}
