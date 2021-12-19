local wezterm = require 'wezterm';
return {
  font = wezterm.font_with_fallback({
    "JetBrainsMono Nerd Font",
    "Victor Mono",
    "unifont",
  }),
  font_size = 12,
  color_scheme = "nord",
  enable_scroll_bar = true,
  keys = {
    {key="=", mods="ALT", action=wezterm.action{SplitHorizontal={domain="CurrentPaneDomain"}}},
    {key="+", mods="ALT", action=wezterm.action{SplitVertical={domain="CurrentPaneDomain"}}},
	{key="w", mods="CTRL", action=wezterm.action{CloseCurrentPane={confirm=true}}},
  },
}
