#!/bin/sh
# cubos-kit installer
#
# Usage:
#   curl -fsSL https://git.cubos.io/cubos-kit/releases/-/raw/main/install.sh | sh
#
# Environment variables:
#   CUBOS_KIT_VERSION  Specific version to install (default: latest)
#   INSTALL_DIR        Where to install the binary (default: $HOME/.local/bin)

set -eu

GITLAB_HOST="${CUBOS_KIT_GITLAB_HOST:-git.cubos.io}"
PROJECT_PATH="${CUBOS_KIT_PROJECT_PATH:-cubos-kit/releases}"
PROJECT_ID_ENCODED=$(printf '%s' "$PROJECT_PATH" | sed 's|/|%2F|g')
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"
PACKAGE_NAME="cubos-kit"

info()  { printf '\033[0;34m==>\033[0m %s\n' "$*"; }
warn()  { printf '\033[0;33m!!!\033[0m %s\n' "$*" >&2; }
error() { printf '\033[0;31mxxx\033[0m %s\n' "$*" >&2; exit 1; }

need_cmd() {
  command -v "$1" >/dev/null 2>&1 || error "required command not found: $1"
}

need_cmd curl
need_cmd tar
need_cmd uname

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

resolve_version() {
  if [ -n "${CUBOS_KIT_VERSION:-}" ]; then
    printf '%s' "$CUBOS_KIT_VERSION"
    return
  fi
  url="https://$GITLAB_HOST/api/v4/projects/$PROJECT_ID_ENCODED/releases/permalink/latest"
  version=$(curl --fail --silent --show-error --location "$url" \
    | sed -n 's/.*"tag_name":"\([^"]*\)".*/\1/p' \
    | head -n1)
  [ -n "$version" ] || error "could not resolve latest version from $url"
  printf '%s' "$version"
}

main() {
  platform=$(detect_platform)
  version=$(resolve_version)
  archive="cubos-kit-${platform}.tar.gz"
  base="https://$GITLAB_HOST/api/v4/projects/$PROJECT_ID_ENCODED/packages/generic/$PACKAGE_NAME/$version"

  info "Installing cubos-kit $version ($platform) to $INSTALL_DIR"

  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT INT HUP TERM

  info "Downloading $archive"
  curl --fail --silent --show-error --location --output "$tmp/$archive" "$base/$archive"

  info "Verifying checksum"
  curl --fail --silent --show-error --location --output "$tmp/$archive.sha256" "$base/$archive.sha256"
  (cd "$tmp" && shasum -a 256 -c "$archive.sha256" >/dev/null 2>&1) \
    || error "checksum verification failed"

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
