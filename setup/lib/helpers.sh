#!/usr/bin/env bash

die() {
  log_error "$*"
  exit 1
}

run_root() {
  if is_root; then
    "$@"
  else
    sudo "$@"
  fi
}

require_sudo() {
  if is_root; then
    return 0
  fi

  section "Validating sudo access"
  sudo -v
}

command_exists() {
  command -v "$1" >/dev/null 2>&1
}

all_commands_exist() {
  local command_name

  for command_name in "$@"; do
    command_exists "$command_name" || return 1
  done
}

pacman_pkg_installed() {
  pacman -Q "$1" >/dev/null 2>&1
}

all_pacman_packages_installed() {
  local package_name

  for package_name in "$@"; do
    pacman_pkg_installed "$package_name" || return 1
  done
}

repo_has_pacman_package() {
  pacman -Si "$1" >/dev/null 2>&1
}

install_pacman_packages() {
  local missing=()
  local pkg

  for pkg in "$@"; do
    pacman_pkg_installed "$pkg" || missing+=("$pkg")
  done

  if ((${#missing[@]} == 0)); then
    return 0
  fi

  log_info "Installing pacman packages: ${missing[*]}"
  run_root pacman -S --needed --noconfirm "${missing[@]}"
}

install_best_available_packages() {
  local pacman_pkgs=()
  local aur_pkgs=()
  local pkg

  for pkg in "$@"; do
    if pacman_pkg_installed "$pkg"; then
      continue
    elif repo_has_pacman_package "$pkg"; then
      pacman_pkgs+=("$pkg")
    else
      aur_pkgs+=("$pkg")
    fi
  done

  ((${#pacman_pkgs[@]})) && install_pacman_packages "${pacman_pkgs[@]}"
  ((${#aur_pkgs[@]})) && install_aur_packages "${aur_pkgs[@]}"
}

install_aur_packages() {
  local missing=()
  local pkg

  for pkg in "$@"; do
    pacman_pkg_installed "$pkg" || missing+=("$pkg")
  done

  if ((${#missing[@]} == 0)); then
    return 0
  fi

  command_exists yay || die "yay is required before installing AUR packages: ${missing[*]}"
  log_info "Installing AUR packages: ${missing[*]}"
  yay -S --needed --noconfirm "${missing[@]}"
}

repo_is_dirty() {
  local repo_dir="$1"
  [[ -d "${repo_dir}/.git" ]] || return 1
  [[ -n "$(git -C "$repo_dir" status --porcelain)" ]]
}

ensure_directory() {
  mkdir -p "$1"
}

add_note() {
  POST_RUN_NOTES+=("$1")
}

current_shell_path() {
  getent passwd "$USER" | awk -F: '{print $7}'
}

shell_registered() {
  local shell_path="$1"
  [[ -r /etc/shells ]] && grep -Fxq "$shell_path" /etc/shells
}

ensure_login_shell_registered() {
  local shell_path="$1"

  [[ -n "$shell_path" ]] || die "Login shell path cannot be empty."
  [[ "$shell_path" == /* ]] || die "Login shell path must be absolute: ${shell_path}"
  [[ -x "$shell_path" ]] || die "Login shell is not executable: ${shell_path}"

  if shell_registered "$shell_path"; then
    return 0
  fi

  log_info "Registering login shell in /etc/shells: ${shell_path}"
  if [[ -e /etc/shells ]]; then
    printf '%s\n' "$shell_path" | run_root tee -a /etc/shells >/dev/null
  else
    printf '%s\n' "$shell_path" | run_root tee /etc/shells >/dev/null
  fi
}

user_in_group() {
  id -nG "$USER" | tr ' ' '\n' | grep -qx "$1"
}

systemd_service_active() {
  command_exists systemctl && systemctl is-active --quiet "$1"
}

systemd_ready() {
  command_exists systemctl && systemctl show-environment >/dev/null 2>&1
}

normalize_locale_name() {
  printf '%s\n' "$1" | tr '[:upper:]' '[:lower:]' | sed 's/utf-8/utf8/g'
}

locale_is_generic() {
  local normalized_locale

  normalized_locale="$(normalize_locale_name "${1:-}")"
  case "$normalized_locale" in
    ""|c|c.utf8|posix)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

locale_is_generated() {
  local locale="$1"
  local normalized_locale
  local available_locales

  [[ -n "$locale" ]] || return 1

  normalized_locale="$(normalize_locale_name "$locale")"
  available_locales="$(locale -a 2>/dev/null | tr '[:upper:]' '[:lower:]' | sed 's/utf-8/utf8/g')"
  grep -qx "$normalized_locale" <<<"$available_locales"
}

ensure_locale_generated() {
  local locale="$1"
  local entry="${locale} UTF-8"
  local locale_pattern="${locale//./\\.}"

  if grep -Eq "^#?${locale_pattern} UTF-8$" /etc/locale.gen; then
    run_root sed -i -E "s/^#?${locale_pattern} UTF-8$/${entry}/" /etc/locale.gen
  else
    printf '%s\n' "$entry" | run_root tee -a /etc/locale.gen >/dev/null
  fi

  run_root locale-gen
}

set_system_locale() {
  local locale="$1"

  if command_exists localectl && systemd_ready; then
    run_root localectl set-locale "LANG=${locale}"
  else
    printf 'LANG=%s\n' "$locale" | run_root tee /etc/locale.conf >/dev/null
  fi
}

detect_current_locale() {
  if [[ -r /etc/locale.conf ]]; then
    awk -F= '/^LANG=/{print $2; exit}' /etc/locale.conf
    return 0
  fi
}

detect_current_timezone() {
  if command_exists timedatectl && systemd_ready; then
    timedatectl show --property=Timezone --value 2>/dev/null || true
    return 0
  fi

  if [[ -L /etc/localtime ]]; then
    readlink /etc/localtime | sed 's#^/usr/share/zoneinfo/##'
  fi
}

set_system_timezone() {
  local timezone="$1"

  if command_exists timedatectl && systemd_ready; then
    run_root timedatectl set-timezone "$timezone"
  else
    run_root ln -sf "/usr/share/zoneinfo/${timezone}" /etc/localtime
  fi
}

suggest_locale_default() {
  local locale

  locale="$(detect_current_locale || true)"
  if [[ -n "$locale" ]] && ! locale_is_generic "$locale"; then
    printf '%s\n' "$locale"
    return 0
  fi

  locale="${LANG:-}"
  if locale_is_generic "$locale"; then
    printf '%s\n' "en_US.UTF-8"
  else
    printf '%s\n' "$locale"
  fi
}

configured_locale_ready() {
  local locale

  locale="$(detect_current_locale || true)"
  [[ -n "$locale" ]] && ! locale_is_generic "$locale" && locale_is_generated "$locale"
}

ensure_bootstrap_locale() {
  local locale

  if configured_locale_ready; then
    export LANG="$(detect_current_locale)"
    unset LC_ALL
    return 0
  fi

  locale="${1:-$(suggest_locale_default)}"

  section "Configuring locale"
  ensure_locale_generated "$locale"
  set_system_locale "$locale"

  export LANG="$locale"
  unset LC_ALL
}

git_identity_configured() {
  [[ -n "$(git config --global user.name 2>/dev/null || true)" ]] &&
  [[ -n "$(git config --global user.email 2>/dev/null || true)" ]]
}

upsert_ini_value() {
  local file="$1"
  local section_name="$2"
  local key="$3"
  local value="$4"
  local tmp_file

  tmp_file="$(mktemp)"
  if [[ ! -f "$file" ]]; then
    printf '[%s]\n%s=%s\n' "$section_name" "$key" "$value" >"$tmp_file"
    run_root install -m 644 "$tmp_file" "$file"
    rm -f "$tmp_file"
    return 0
  fi

  awk -v section_name="$section_name" -v key="$key" -v value="$value" '
    function print_value() { print key "=" value }

    BEGIN {
      in_section = 0
      section_found = 0
      key_written = 0
    }

    /^\[.*\]$/ {
      if (in_section && !key_written) {
        print_value()
        key_written = 1
      }

      in_section = ($0 == "[" section_name "]")
      if (in_section) {
        section_found = 1
      }

      print
      next
    }

    {
      if (in_section && $0 ~ "^" key "=") {
        if (!key_written) {
          print_value()
          key_written = 1
        }
        next
      }

      print
    }

    END {
      if (!section_found) {
        print ""
        print "[" section_name "]"
        print_value()
      } else if (in_section && !key_written) {
        print_value()
      }
    }
  ' "$file" >"$tmp_file"

  run_root install -m 644 "$tmp_file" "$file"
  rm -f "$tmp_file"
}
