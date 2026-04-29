# Copilot Instructions

## Build, test, and validation commands

There is no formal build, test, or lint pipeline in this repo. The practical validation commands are:

```bash
./stow.sh --dry-run
```

Preview Linux symlink changes without touching `$HOME`.

```bash
bash -n setup/bootstrap.sh setup/lib/*.sh setup/profiles/*.sh
```

Syntax-check the setup/bootstrap shell scripts.

```bash
bash setup/bootstrap.sh --help
```

Quickly verify the bootstrap entrypoint still parses and exposes its CLI.

## High-level architecture

- **Linux dotfiles are GNU Stow packages** under `linux/<package>/`. Each package mirrors the final path under `$HOME`, and `stow.sh` is the single place that decides which packages are active through its explicit `PACKAGES` array.
- **Windows config is separate and manual** under `windows/`. It is not managed by Stow; `windows/README.md` is the source for placement/symlink instructions.
- **Machine bootstrap now lives in `setup/`**. `setup/bootstrap.sh` is the only public entrypoint; when run via `curl ... | bash`, it first downloads a temporary archive of the repo, then re-runs itself locally so it can source sibling files.
- **Bootstrap logic is split by responsibility**:
  - `setup/lib/` holds shared logging, environment detection, UI, and install helpers
  - `setup/profiles/common.sh` defines installable sections and the shared user setup flow
  - `setup/profiles/wsl.sh` handles WSL-specific bootstrap and Docker/systemd checks
  - `setup/profiles/native.sh` is the native Arch hook point
- **WSL has a two-phase flow hidden behind one command**: root on first boot runs the WSL bootstrap path (user creation, sudo, `/etc/wsl.conf`, systemd), then after `wsl --terminate distroName` the same entrypoint runs the normal user setup flow.

## Key conventions

- **All Linux configs use XDG-style paths**. New Linux packages should follow `linux/<package>/.config/<tool>/...` instead of writing directly to legacy dotfiles in `$HOME`.
- **`stow.sh` is the source of truth for active Linux packages**. A directory existing under `linux/` does not make it active by itself; it must also be added to the `PACKAGES` array.
- **`nvim` and `kitty` are intentionally present but inactive**. They stay commented out in `stow.sh` until the user explicitly wants them enabled.
- **Fish startup is split between `config.fish` and `conf.d/`**. Tool-specific startup snippets belong in `linux/fish/.config/fish/conf.d/*.fish`; keep `config.fish` for the small shared interactive shell setup.
- **Starship is maintained in two places on purpose**. `linux/starship/.config/starship.toml` is the source of truth, and equivalent Windows Starship config must be copied manually when it changes.
- **Git identity and other machine-local secrets stay out of the repo**. `linux/git/.gitconfig` only carries the `gh` credential helper; `user.name`, `user.email`, `gh auth`, and Fish-generated `fish_variables` are intentionally per-machine.
- **Setup scripts are meant to be re-runnable and fail fast**. They rely on idempotent checks (`command -v`, `pacman -Q`, repo dirtiness checks, `stow.sh --restow`) and stop on first failure instead of trying to continue through partial setup.
