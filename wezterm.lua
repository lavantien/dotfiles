local wezterm = require 'wezterm';
return {
  font = wezterm.font_with_fallback({
    "JetBrainsMono Nerd Font",
    "Victor Mono",
  }),
  font_size = 12,
  color_scheme = "nord",
  --color_scheme = "Nord Deep",
  --color_scheme = "wezterm_github_dark_brighten",
  --color_scheme = "Tinacious Design (Dark)",
  --color_scheme = "wezterm_tokyonight_night",
  --color_scheme = "wezterm_tokyonight_day",
  --color_scheme = "Alabaster",
  color_schemes = {
    ["Nord Deep"] = {
      foreground = "#d8dee9",
      background = "#232731",
      cursor_bg = "#eceff4",
      cursor_border = "#eceff4",
      cursor_fg = "#282828",
      selection_bg = "#eceff4",
      selection_fg = "#4c566a",
      ansi = {"#3b4252","#bf616a","#a3be8c","#ebcb8b","#81a1c1","#b48ead","#88c0d0","#e5e9f0"},
      brights = {"#4c566a","#bf616a","#a3be8c","#ebcb8b","#81a1c1","#b48ead","#8fbcbb","#eceff4"},
    },
  },
  enable_scroll_bar = true,
  keys = {
    {key="=", mods="ALT", action=wezterm.action{SplitHorizontal={domain="CurrentPaneDomain"}}},
    {key="+", mods="ALT", action=wezterm.action{SplitVertical={domain="CurrentPaneDomain"}}},
    {key="w", mods="CTRL", action=wezterm.action{CloseCurrentPane={confirm=true}}},
  },
}
