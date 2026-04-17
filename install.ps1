# cubos-kit installer (Windows / PowerShell)
#
# Usage:
#   irm https://git.cubos.io/cubos-kit/releases/-/raw/main/install.ps1 | iex
#
# Environment variables:
#   CUBOS_KIT_VERSION  Specific version to install (default: latest)
#   INSTALL_DIR        Where to install the binary (default: $env:LOCALAPPDATA\cubos-kit\bin)

$ErrorActionPreference = 'Stop'

$GitLabHost    = if ($env:CUBOS_KIT_GITLAB_HOST) { $env:CUBOS_KIT_GITLAB_HOST } else { 'git.cubos.io' }
$ProjectPath   = if ($env:CUBOS_KIT_PROJECT_PATH) { $env:CUBOS_KIT_PROJECT_PATH } else { 'cubos-kit/releases' }
$ProjectIdEnc  = $ProjectPath -replace '/', '%2F'
$InstallDir    = if ($env:INSTALL_DIR) { $env:INSTALL_DIR } else { Join-Path $env:LOCALAPPDATA 'cubos-kit\bin' }
$PackageName   = 'cubos-kit'

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

function Resolve-Version {
  if ($env:CUBOS_KIT_VERSION) { return $env:CUBOS_KIT_VERSION }
  $url = "https://$GitLabHost/api/v4/projects/$ProjectIdEnc/releases/permalink/latest"
  try {
    $r = Invoke-RestMethod -Uri $url -Method Get
  } catch {
    Die "could not resolve latest version from $url ($_)"
  }
  if (-not $r.tag_name) { Die "no tag_name in release response" }
  return $r.tag_name
}

$platform = Get-Platform
$version  = Resolve-Version
$archive  = "cubos-kit-$platform.zip"
$base     = "https://$GitLabHost/api/v4/projects/$ProjectIdEnc/packages/generic/$PackageName/$version"

Info "Installing cubos-kit $version ($platform) to $InstallDir"

$tmp = New-Item -ItemType Directory -Path (Join-Path $env:TEMP "cubos-kit-$([guid]::NewGuid())")
try {
  Info "Downloading $archive"
  Invoke-WebRequest -Uri "$base/$archive" -OutFile (Join-Path $tmp $archive)

  Info "Verifying checksum"
  Invoke-WebRequest -Uri "$base/$archive.sha256" -OutFile (Join-Path $tmp "$archive.sha256")
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
