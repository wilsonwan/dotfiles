# dotfiles

Personal dotfiles managed with [GNU Stow](https://www.gnu.org/software/stow/).  
Targets: **Arch Linux** (native + WSL) and **Windows** (WezTerm).

---

## Structure

```text
dotfiles/
├── setup/              # bootstrap entrypoint + internal profiles/helpers
├── stow.sh             # Linux: stow active packages
├── linux/              # stow packages — each symlinked to ~
│   ├── fish/           # Fish shell
│   ├── fastfetch/      # Fastfetch system info
│   ├── lazygit/        # Lazygit TUI
│   ├── htop/           # Htop
│   ├── tmux/           # tmux (XDG: ~/.config/tmux/)
│   ├── starship/       # Starship prompt
│   ├── kitty/          # Kitty terminal (native Arch only)
│   ├── nvim/           # Neovim — placeholder for LazyVim
│   └── git/            # .gitconfig (credential helper only)
└── windows/            # manually placed — see windows/README.md
    └── wezterm/        # WezTerm config
```

---

## Linux setup

The supported entrypoint is:

```bash
setup/bootstrap.sh
```

It is designed for **already-installed and booted** Arch Linux, CachyOS, and Arch Linux on WSL.

### Native Arch / CachyOS

Paste this on a fresh machine:

```bash
sudo pacman -S --noconfirm curl && curl -fsSL https://raw.githubusercontent.com/wilsonwan/dotfiles/main/setup/bootstrap.sh | bash
```

The script will:

- install the minimum needed to drive setup
- open an interactive `fzf`-based checklist
- auto-skip sections that already look installed/configured
- stop on first failure so you can fix the issue and re-run it

### WSL Arch Linux

Fresh WSL Arch boots as `root` with no regular user, so the same entrypoint has a bootstrap phase first.

Run this inside WSL on first boot:

```bash
pacman -S --noconfirm curl && curl -fsSL https://raw.githubusercontent.com/wilsonwan/dotfiles/main/setup/bootstrap.sh | bash
```

That first run will:

- install `sudo`, `nano`, `git`, `curl`, and `fzf`
- create your regular user in the `wheel` group
- enable passwordless wheel sudo
- write `/etc/wsl.conf` with your default user and `systemd=true`

If you want to automate that first run instead of answering the username prompt interactively, pass an explicit override:

```bash
curl -fsSL https://raw.githubusercontent.com/wilsonwan/dotfiles/main/setup/bootstrap.sh | \
  bash -s -- --wsl-user <your-linux-username>
```

Then, from **Windows PowerShell**, restart the distro:

```powershell
wsl --terminate distroName
```

After relaunching WSL as your regular user, run the **same** bootstrap command again with **sudo**, to continue with the normal setup flow.

### What the bootstrap can install

The interactive checklist is environment-aware and currently covers:

- system update
- base tools (`base-devel`, `git`, `stow`, `curl`, `fzf`)
- `yay`
- essential CLI/dev tools
- Docker
- Fish
- Node.js 24 via `fnm`
- .NET SDK + `dotnet-ef`
- GitHub CLI
- AUR extras (`lazygit`, `starship`, `fastfetch`)
- cloning / validating the dotfiles repo
- stowing dotfiles
- git identity
- locale / timezone

### Manual steps that remain manual

| Step | Why |
|------|-----|
| `passwd` | Interactive by design |
| `wsl --terminate distroName` | Must be run from Windows PowerShell |
| `gh auth login` | Left to the machine owner intentionally |
| Re-login after shell/group changes | Needed for `chsh` and Docker group membership |

### Re-running

- The setup writes logs to `~/.local/state/dotfiles-setup/`
- The setup is intended to be re-runnable
- Already-installed/configured sections are auto-skipped by default
- `stow.sh` uses `--restow`, so repeated stow runs are safe

### Running from a local clone

If you already have the repo locally:

```bash
cd ~/repos/dotfiles
./setup/bootstrap.sh
```

Preview stow changes only:

```bash
./stow.sh --dry-run
```

---

## Windows setup

See [`windows/README.md`](windows/README.md) for manual placement instructions.

| Config | Target |
|--------|--------|
| `windows/wezterm/.wezterm.lua` | `C:\Users\<you>\.wezterm.lua` |

---

## Notes

- `fish_variables` is gitignored — fish manages it and it contains machine-specific data
- `git/.gitconfig` only tracks shared settings and includes `~/.gitconfig.local` for machine-local `user.name` / `user.email`
- `nvim/` and `kitty/` are placeholders — edit `stow.sh` to enable them when ready
