#!/bin/sh
# cubos-kit installer
#
# Usage:
#   curl -fsSL https://raw.githubusercontent.com/cubos/cubos-kit-releases/main/install.sh | sh
#
# Environment variables:
#   CUBOS_KIT_VERSION  Specific version to install, e.g. v0.2.0 (default: latest)
#   INSTALL_DIR        Where to install the binary (default: $HOME/.local/bin)

set -eu

GITHUB_REPO="${CUBOS_KIT_REPO:-cubos/cubos-kit-releases}"
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

info()  { printf '\033[0;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[0;33m!!!\033[0m %s\n' "$*" >&2; }
error() { printf '\033[0;31mxxx\033[0m %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || error "required command not found: $1"
}

need_cmd curl
need_cmd tar
need_cmd uname

# Print the sha256 of a file using whatever tool the system provides.
# Linux distros ship sha256sum (coreutils); macOS/BSD ship shasum (Perl Digest::SHA).
sha256_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 "$1" | awk '{print $NF}'
  else
    error "no sha256 tool found (need one of: sha256sum, shasum, openssl)"
  fi
}

detect_platform() {
  os=$(uname -s | tr '[:upper:]' '[:lower:]')
  arch=$(uname -m)
  case "$os" in
    linux)  os=linux ;;
    darwin) os=darwin ;;
    *) error "unsupported OS: $os (supported: linux, darwin)" ;;
  esac
  case "$arch" in
    x86_64|amd64)   arch=x64 ;;
    aarch64|arm64)  arch=arm64 ;;
    *) error "unsupported architecture: $arch (supported: x86_64, aarch64)" ;;
  esac
  printf '%s-%s' "$os" "$arch"
}

release_url() {
  version="$1"
  asset="$2"
  if [ "$version" = "latest" ]; then
    printf 'https://github.com/%s/releases/latest/download/%s' "$GITHUB_REPO" "$asset"
  else
    printf 'https://github.com/%s/releases/download/%s/%s' "$GITHUB_REPO" "$version" "$asset"
  fi
}

main() {
  platform=$(detect_platform)
  version="${CUBOS_KIT_VERSION:-latest}"
  archive="cubos-kit-${platform}.tar.gz"

  info "Installing cubos-kit $version ($platform) to $INSTALL_DIR"

  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT INT HUP TERM

  archive_url=$(release_url "$version" "$archive")
  sha_url=$(release_url "$version" "$archive.sha256")

  info "Downloading $archive"
  curl --fail --silent --show-error --location --output "$tmp/$archive" "$archive_url"

  info "Verifying checksum"
  curl --fail --silent --show-error --location --output "$tmp/$archive.sha256" "$sha_url"
  expected=$(awk '{print $1}' "$tmp/$archive.sha256")
  [ -n "$expected" ] || error "could not read expected checksum from $archive.sha256"
  actual=$(sha256_of "$tmp/$archive")
  [ "$expected" = "$actual" ] \
    || error "checksum mismatch for $archive (expected $expected, got $actual)"

  info "Extracting"
  tar -xzf "$tmp/$archive" -C "$tmp"

  mkdir -p "$INSTALL_DIR"
  mv "$tmp/cubos-kit" "$INSTALL_DIR/cubos-kit"
  chmod +x "$INSTALL_DIR/cubos-kit"

  info "Installed: $INSTALL_DIR/cubos-kit"

  case ":$PATH:" in
    *":$INSTALL_DIR:"*) : ;;
    *)
      warn "$INSTALL_DIR is not in your PATH."
      warn "Add this line to your shell config (~/.bashrc, ~/.zshrc, etc.):"
      warn "  export PATH=\"$INSTALL_DIR:\$PATH\""
      ;;
  esac

  info "Run 'cubos-kit --version' to verify."
}

main "$@"
