#!/usr/bin/env bash

LOG_DIR="${HOME}/.local/state/dotfiles-setup"
LOG_FILE=""

init_logging() {
  mkdir -p "$LOG_DIR"
  LOG_FILE="${LOG_DIR}/$(date +%Y%m%d-%H%M%S).log"
  touch "$LOG_FILE"
  exec > >(tee -a "$LOG_FILE") 2>&1
  log_info "Logging to ${LOG_FILE}"
}

log_info() {
  printf '[INFO] %s\n' "$*"
}

log_warn() {
  printf '[WARN] %s\n' "$*"
}

log_error() {
  printf '[ERROR] %s\n' "$*" >&2
}

section() {
  printf '\n==> %s\n' "$*"
}
