## Windows Dotfiles

Configs here cannot be managed with GNU Stow (Linux tool). Place them manually using the paths below.

### WezTerm

| File in repo | Windows target |
|---|---|
| `wezterm/.wezterm.lua` | `C:\Users\<you>\.wezterm.lua` |

**With symlink (run PowerShell as Administrator, or enable Developer Mode):**
```powershell
New-Item -ItemType SymbolicLink `
  -Path "$env:USERPROFILE\.wezterm.lua" `
  -Target "<path-to-repo>\windows\wezterm\.wezterm.lua"
```
