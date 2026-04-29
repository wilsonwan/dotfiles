#!/usr/bin/env bash

load_os_release() {
  if [[ -r /etc/os-release ]]; then
    # shellcheck disable=SC1091
    source /etc/os-release
  fi
}

is_wsl() {
  grep -qi microsoft /proc/version 2>/dev/null
}

is_root() {
  [[ "${EUID:-$(id -u)}" -eq 0 ]]
}

is_supported_arch_like() {
  load_os_release
  case "${ID:-}" in
    arch|cachyos)
      return 0
      ;;
  esac

  [[ "${ID_LIKE:-}" == *arch* ]]
}

detect_environment_label() {
  if is_wsl; then
    echo "WSL Arch Linux"
  else
    echo "Native Arch Linux"
  fi
}

detect_wsl_default_user() {
  [[ -r /etc/wsl.conf ]] || return 1
  awk '
    /^\[user\]$/ { in_user = 1; next }
    /^\[/ { in_user = 0 }
    in_user && $1 ~ /^default=/ {
      sub(/^default=/, "", $1)
      print $1
      exit
    }
  ' /etc/wsl.conf
}
