-- Pull in the wezterm API
local wezterm = require 'wezterm'

-- This will hold the configuration.
local config = wezterm.config_builder()

local function get_appearance()
  if wezterm.gui then
    return wezterm.gui.get_appearance()
  end
  return 'Dark'
end

local function scheme_for_appearance(appearance)
  if appearance:find 'Dark' then
    return 'Catppuccin Mocha'
  else
    return 'Catppuccin Frappe'
  end
end

-- This is where you actually apply your config choices. May be machine specific
-- config.default_prog = { 'C:/Program Files/PowerShell/7/pwsh.exe', '-NoLogo' }
-- config.default_cwd = "C:/working"

-- For example, changing the initial geometry for new windows:
config.initial_cols = 140
config.initial_rows = 48

-- or, changing the font size and color scheme.
config.font_size = 10
config.font = wezterm.font 'CaskaydiaCove NF'
config.color_scheme = scheme_for_appearance(get_appearance())

config.enable_scroll_bar = true

-- Allow for new line within Copilot CLI
config.keys = {
  {
    key = 'Enter',
    mods = 'SHIFT',
    action = wezterm.action.SendString('\n'),
  },
}

-- Finally, return the configuration to wezterm:
return config