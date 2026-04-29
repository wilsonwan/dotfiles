#!/usr/bin/env bash
set -euo pipefail

DOTFILES_REPO_URL="https://github.com/wilsonwan/dotfiles"
CANONICAL_DOTFILES_DIR="${HOME}/repos/personal/dotfiles"
BOOTSTRAP_ARCHIVE_TMP_DIR=""
WSL_USERNAME_OVERRIDE="${DOTFILES_WSL_USERNAME:-}"

cleanup_bootstrap_archive() {
  [[ -n "${BOOTSTRAP_ARCHIVE_TMP_DIR:-}" ]] && rm -rf "$BOOTSTRAP_ARCHIVE_TMP_DIR"
}

bootstrap_from_archive() {
  local tmp_dir archive_dir status

  command -v curl >/dev/null 2>&1 || {
    echo "error: curl is required to bootstrap from GitHub" >&2
    exit 1
  }
  command -v tar >/dev/null 2>&1 || {
    echo "error: tar is required to bootstrap from GitHub" >&2
    exit 1
  }

  tmp_dir="$(mktemp -d)"
  BOOTSTRAP_ARCHIVE_TMP_DIR="$tmp_dir"
  trap cleanup_bootstrap_archive EXIT

  curl -fsSL "${DOTFILES_REPO_URL}/archive/refs/heads/main.tar.gz" | tar -xzf - -C "$tmp_dir"
  archive_dir="${tmp_dir}/dotfiles-main"

  if [[ ! -t 0 && -r /dev/tty ]]; then
    if bash "${archive_dir}/setup/bootstrap.sh" "$@" </dev/tty; then
      status=0
    else
      status=$?
    fi
  elif bash "${archive_dir}/setup/bootstrap.sh" "$@"; then
    status=0
  else
    status=$?
  fi

  cleanup_bootstrap_archive
  BOOTSTRAP_ARCHIVE_TMP_DIR=""
  trap - EXIT
  exit "$status"
}

SCRIPT_SOURCE="${BASH_SOURCE[0]:-}"
if [[ -z "$SCRIPT_SOURCE" || "$SCRIPT_SOURCE" == "bash" || "$SCRIPT_SOURCE" == "/dev/stdin" ]]; then
  bootstrap_from_archive "$@"
fi

SCRIPT_DIR="$(cd "$(dirname "$SCRIPT_SOURCE")" && pwd)"
if [[ ! -f "${SCRIPT_DIR}/lib/helpers.sh" || ! -f "${SCRIPT_DIR}/profiles/common.sh" ]]; then
  bootstrap_from_archive "$@"
fi

REPO_ROOT="$(cd "${SCRIPT_DIR}/.." && pwd)"

source "${SCRIPT_DIR}/lib/logging.sh"
source "${SCRIPT_DIR}/lib/detection.sh"
source "${SCRIPT_DIR}/lib/helpers.sh"
source "${SCRIPT_DIR}/lib/ui.sh"
source "${SCRIPT_DIR}/profiles/wsl.sh"
source "${SCRIPT_DIR}/profiles/native.sh"
source "${SCRIPT_DIR}/profiles/common.sh"

AUTO_YES=0
PROFILE_OVERRIDE=""
SECTIONS_OVERRIDE=()

usage() {
  cat <<'EOF'
Usage: setup/bootstrap.sh [--yes] [--profile native|wsl] [--sections id1,id2,...] [--wsl-user <name>]

Options:
  --yes                 Accept default selections and prompt defaults.
  --profile <name>      Force profile selection for user-mode setup.
  --sections <ids>      Comma-separated section ids to run.
  --wsl-user <name>     Override the first-run WSL username.
  -h, --help            Show this help.

Environment:
  DOTFILES_WSL_USERNAME Set the first-run WSL username override.
EOF
}

parse_args() {
  while (($# > 0)); do
    case "$1" in
      --yes)
        AUTO_YES=1
        ;;
      --profile)
        shift
        [[ $# -gt 0 ]] || die "--profile requires a value"
        PROFILE_OVERRIDE="$1"
        ;;
      --sections)
        shift
        [[ $# -gt 0 ]] || die "--sections requires a value"
        IFS=',' read -r -a SECTIONS_OVERRIDE <<<"$1"
        ;;
      --wsl-user)
        shift
        [[ $# -gt 0 ]] || die "--wsl-user requires a value"
        WSL_USERNAME_OVERRIDE="$1"
        ;;
      -h|--help)
        usage
        exit 0
        ;;
      *)
        die "unknown option: $1"
        ;;
    esac
    shift
  done
}

main() {
  parse_args "$@"
  init_logging

  section "Environment"
  is_supported_arch_like || die "This bootstrap is only intended for Arch Linux, CachyOS, or Arch-based WSL images."
  log_info "Detected environment: $(detect_environment_label)"

  if is_wsl && is_root; then
    if wsl_bootstrap_needed; then
      run_wsl_bootstrap
      exit 0
    fi

    die "WSL bootstrap looks complete. Relaunch WSL as your regular user and run the same command again."
  fi

  run_user_setup
}

main "$@"
