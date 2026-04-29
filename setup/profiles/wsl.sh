#!/usr/bin/env bash

wsl_bootstrap_needed() {
  local default_user

  is_wsl || return 1
  is_root || return 1

  default_user="$(detect_wsl_default_user || true)"
  [[ -z "$default_user" ]] && return 0
  ! id "$default_user" >/dev/null 2>&1 && return 0
  ! pacman_pkg_installed sudo && return 0
  ! pacman_pkg_installed nano && return 0
  ! grep -Eq '^\s*systemd\s*=\s*true\s*$' /etc/wsl.conf 2>/dev/null && return 0

  return 1
}

run_wsl_bootstrap() {
  local username

  section "WSL bootstrap"
  ensure_bootstrap_locale
  install_pacman_packages sudo nano git curl fzf

  if [[ -n "${WSL_USERNAME_OVERRIDE:-}" ]]; then
    username="$WSL_USERNAME_OVERRIDE"
    log_info "Using WSL username override: ${username}"
  else
    username="$(prompt_with_default "New WSL username" "$(detect_wsl_default_user || true)")"
  fi

  [[ -n "$username" ]] ||
    die "A username is required. Re-run in a terminal or pass --wsl-user <name> (or set DOTFILES_WSL_USERNAME)."

  if id "$username" >/dev/null 2>&1; then
    log_info "User ${username} already exists; skipping user creation."
  else
    run_root useradd -m -s /bin/bash -G wheel "$username"
  fi

  section "Set password for ${username}"
  if [[ -t 0 ]]; then
    passwd "$username"
  elif [[ -r /dev/tty ]]; then
    passwd "$username" </dev/tty
  else
    die "Setting the password for ${username} requires a terminal."
  fi

  section "Configuring sudo and WSL"
  run_root sed -i 's/^# %wheel ALL=(ALL:ALL) NOPASSWD: ALL/%wheel ALL=(ALL:ALL) NOPASSWD: ALL/' /etc/sudoers
  upsert_ini_value /etc/wsl.conf user default "$username"
  upsert_ini_value /etc/wsl.conf boot systemd true

  cat <<EOF

Bootstrap complete.

From Windows PowerShell, run:
  wsl --terminate archlinux

Then relaunch WSL as ${username} and run the same bootstrap command again.
EOF
}

profile_prepare_docker() {
  local before

  before="$(detect_wsl_default_user || true)"
  upsert_ini_value /etc/wsl.conf boot systemd true
  if ! systemd_ready; then
    die "systemd is not active in this WSL session yet. Run 'wsl --terminate archlinux', relaunch WSL, then re-run setup."
  fi
  add_note "If Docker does not start inside WSL yet, run 'wsl --terminate archlinux' and relaunch."
  [[ -n "$before" ]] && add_note "WSL default user: ${before}"
}
