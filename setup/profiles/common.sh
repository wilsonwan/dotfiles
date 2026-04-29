#!/usr/bin/env bash

POST_RUN_NOTES=()
SECTION_IDS=()
SECTION_LABELS=()
SECTION_DEFAULTS=()
SECTION_REASONS=()
SECTION_FUNCS=()

ensure_yay_available() {
  local tmp_dir

  if command_exists yay; then
    return 0
  fi

  section "Installing yay"
  install_pacman_packages base-devel git
  tmp_dir="$(mktemp -d)"
  git clone https://aur.archlinux.org/yay.git "${tmp_dir}/yay"
  (
    cd "${tmp_dir}/yay"
    makepkg -si --noconfirm
  )
  rm -rf "$tmp_dir"
}

ensure_dotfiles_repo() {
  local current_repo_root="${REPO_ROOT:-}"

  if [[ -d "${CANONICAL_DOTFILES_DIR}/.git" ]]; then
    repo_is_dirty "$CANONICAL_DOTFILES_DIR" && die "Existing repo at ${CANONICAL_DOTFILES_DIR} has local changes. Resolve them manually before running setup."
    ACTIVE_DOTFILES_DIR="$CANONICAL_DOTFILES_DIR"
    return 0
  fi

  if [[ -d "${current_repo_root}/.git" ]]; then
    repo_is_dirty "$current_repo_root" && die "Current repo at ${current_repo_root} has local changes. Resolve them manually before running setup."
    ACTIVE_DOTFILES_DIR="$current_repo_root"
    return 0
  fi

  section "Cloning dotfiles repo"
  ensure_directory "$(dirname "$CANONICAL_DOTFILES_DIR")"
  git clone "${DOTFILES_REPO_URL}.git" "$CANONICAL_DOTFILES_DIR"
  ACTIVE_DOTFILES_DIR="$CANONICAL_DOTFILES_DIR"
}

section_system_update() {
  section "System update"
  run_root pacman -Syu --noconfirm
}

section_base_tools() {
  section "Base tools"
  install_pacman_packages base-devel git stow curl fzf
}

section_yay() {
  ensure_yay_available
}

section_dev_tools() {
  section "Essential development tools"
  install_pacman_packages git-lfs tmux htop ripgrep fd bat fzf eza zoxide curl wget jq httpie neovim
}

section_docker() {
  section "Docker"
  install_pacman_packages docker docker-compose docker-buildx
  profile_prepare_docker
  run_root systemctl enable --now docker
  run_root usermod -aG docker "$USER"
  add_note "Re-login for the docker group change to take effect."
}

section_fish() {
  local fish_path

  section "Fish shell"
  install_pacman_packages fish
  fish_path="$(command -v fish || true)"
  [[ -n "$fish_path" ]] || die "fish was installed but is not available on PATH."
  ensure_login_shell_registered "$fish_path"

  if [[ "$(current_shell_path)" != "$fish_path" ]]; then
    chsh -s "$fish_path" || die "Failed to change the default shell to ${fish_path}."
    add_note "Fish becomes your default shell on next login."
  else
    log_info "Fish is already the default shell."
  fi
}

section_node() {
  section "Node.js and fnm"
  install_pacman_packages unzip

  if ! command_exists fnm; then
    curl -fsSL https://fnm.vercel.app/install | bash
  fi

  export PATH="${HOME}/.local/share/fnm:${PATH}"
  # shellcheck disable=SC1090
  eval "$(fnm env --shell bash)"

  fnm install 24
  fnm default 24
  corepack enable yarn
  npm install -g pnpm typescript
}

section_dotnet() {
  section ".NET SDK"
  install_pacman_packages dotnet-sdk

  if ! dotnet tool list --global | grep -q '^dotnet-ef '; then
    dotnet tool install --global dotnet-ef
  else
    log_info "dotnet-ef is already installed."
  fi
}

section_gh() {
  section "GitHub CLI"
  ensure_yay_available
  install_aur_packages github-cli
  add_note "Run 'gh auth login' when you are ready."
}

section_aur_extras() {
  section "AUR extras"
  ensure_yay_available
  install_aur_packages lazygit starship fastfetch
}

section_clone_repo() {
  ensure_dotfiles_repo
  log_info "Using dotfiles repo at ${ACTIVE_DOTFILES_DIR}"
}

section_stow() {
  ensure_dotfiles_repo
  section "Stowing dotfiles"
  (
    cd "$ACTIVE_DOTFILES_DIR"
    chmod +x stow.sh
    ./stow.sh
  )
}

section_git_config() {
  local current_name current_email git_name git_email local_gitconfig

  section "Git identity"
  local_gitconfig="${HOME}/.gitconfig.local"

  current_name="$(git config --file "$local_gitconfig" user.name 2>/dev/null || git config --global --includes user.name 2>/dev/null || true)"
  current_email="$(git config --file "$local_gitconfig" user.email 2>/dev/null || git config --global --includes user.email 2>/dev/null || true)"

  git_name="$(prompt_with_default "Git user.name" "$current_name")"
  git_email="$(prompt_with_default "Git user.email" "$current_email")"

  [[ -n "$git_name" ]] || die "Git user.name cannot be empty."
  [[ -n "$git_email" ]] || die "Git user.email cannot be empty."

  git config --file "$local_gitconfig" user.name "$git_name"
  git config --file "$local_gitconfig" user.email "$git_email"
  chmod 600 "$local_gitconfig"
}

section_locale_timezone() {
  local locale timezone

  section "Locale and timezone"
  locale="$(prompt_with_default "Locale" "$(suggest_locale_default)")"
  timezone="$(prompt_with_default "Timezone" "$(detect_current_timezone || true)")"

  [[ -n "$locale" ]] || die "Locale cannot be empty."
  [[ -n "$timezone" ]] || die "Timezone cannot be empty."

  ensure_locale_generated "$locale"
  set_system_locale "$locale"
  set_system_timezone "$timezone"
}

is_section_complete() {
  local section_id="$1"

  case "$section_id" in
    system-update)
      return 1
      ;;
    base-tools)
      all_commands_exist make git stow curl fzf
      ;;
    yay)
      command_exists yay
      ;;
    dev-tools)
      all_commands_exist git-lfs tmux htop rg fd bat fzf eza zoxide curl wget jq http nvim
      ;;
    docker)
      command_exists docker && user_in_group docker && systemd_service_active docker
      ;;
    fish)
      command_exists fish && [[ "$(current_shell_path)" == "$(command -v fish)" ]]
      ;;
    node)
      all_commands_exist fnm node pnpm tsc
      ;;
    dotnet)
      command_exists dotnet && dotnet tool list --global | grep -q '^dotnet-ef '
      ;;
    gh)
      command_exists gh
      ;;
    aur-extras)
      command_exists lazygit && command_exists starship && command_exists fastfetch
      ;;
    clone-repo)
      [[ -d "${CANONICAL_DOTFILES_DIR}/.git" || -d "${REPO_ROOT}/.git" ]]
      ;;
    stow)
      return 1
      ;;
    git-config)
      git_identity_configured
      ;;
    locale-timezone)
      configured_locale_ready && [[ -n "$(detect_current_timezone || true)" ]]
      ;;
    *)
      return 1
      ;;
  esac
}

build_sections() {
  local default_enabled reason
  local ids=(
    system-update
    base-tools
    yay
    dev-tools
    docker
    fish
    node
    dotnet
    gh
    aur-extras
    clone-repo
    stow
    git-config
    locale-timezone
  )
  local labels=(
    "System update"
    "Base tools (base-devel, git, stow, curl, fzf)"
    "yay (AUR helper)"
    "Essential development tools"
    "Docker"
    "Fish shell"
    "Node.js 24 / fnm / JS globals"
    ".NET SDK / dotnet-ef"
    "GitHub CLI"
    "AUR extras (lazygit, starship, fastfetch)"
    "Clone or validate dotfiles repo"
    "Stow dotfiles"
    "Git identity"
    "Locale and timezone"
  )
  local funcs=(
    section_system_update
    section_base_tools
    section_yay
    section_dev_tools
    section_docker
    section_fish
    section_node
    section_dotnet
    section_gh
    section_aur_extras
    section_clone_repo
    section_stow
    section_git_config
    section_locale_timezone
  )
  local idx

  SECTION_IDS=()
  SECTION_LABELS=()
  SECTION_DEFAULTS=()
  SECTION_REASONS=()
  SECTION_FUNCS=()

  for idx in "${!ids[@]}"; do
    default_enabled=1
    reason="available to enable"

    if is_section_complete "${ids[$idx]}"; then
      default_enabled=0
      reason="already installed or configured"
    fi

    SECTION_IDS+=("${ids[$idx]}")
    SECTION_LABELS+=("${labels[$idx]}")
    SECTION_DEFAULTS+=("$default_enabled")
    SECTION_REASONS+=("$reason")
    SECTION_FUNCS+=("${funcs[$idx]}")
  done
}

run_selected_sections() {
  local -a selected_ids=("$@")
  local idx selected_id found

  for selected_id in "${selected_ids[@]}"; do
    [[ -n "$selected_id" ]] || continue
    found=0
    for idx in "${!SECTION_IDS[@]}"; do
      if [[ "${SECTION_IDS[$idx]}" == "$selected_id" ]]; then
        "${SECTION_FUNCS[$idx]}"
        found=1
        break
      fi
    done

    [[ "$found" -eq 1 ]] || die "Unknown section id: ${selected_id}"
  done
}

run_user_setup() {
  local -a selected_ids=()
  local profile_name

  if is_root; then
    die "Run the user setup flow as your regular user, not as root."
  fi

  require_sudo
  ensure_bootstrap_locale
  install_pacman_packages git curl base-devel fzf

  if [[ -n "$PROFILE_OVERRIDE" ]]; then
    profile_name="$PROFILE_OVERRIDE"
  elif is_wsl; then
    profile_name="wsl"
  else
    profile_name="native"
  fi

  section "Setup profile"
  log_info "Using profile: ${profile_name}"

  build_sections
  mapfile -t selected_ids < <(choose_sections SECTION_IDS SECTION_LABELS SECTION_DEFAULTS SECTION_REASONS)
  run_selected_sections "${selected_ids[@]}"

  section "Setup complete"
  if ((${#POST_RUN_NOTES[@]})); then
    printf 'Notes:\n'
    printf '  - %s\n' "${POST_RUN_NOTES[@]}"
  fi
}
