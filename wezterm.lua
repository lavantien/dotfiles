local wezterm = require 'wezterm'
local config = wezterm.config_builder()

config.color_scheme = 'rose-pine'
config.enable_tab_bar = false
config.tab_bar_at_bottom = true
config.scrollback_lines = 1000000
config.font_size = 17
config.font = wezterm.font_with_fallback({
	"IosevkaTerm Nerd Font",
	"Noto Sans SC",
})
config.window_decorations = "TITLE | RESIZE"
config.window_padding = {
	left = 0,
	right = 0,
	top = 0,
	bottom = 0,
}
config.keys = {
	{
		key = 'Enter',
		mods = 'ALT',
		action = wezterm.action.DisableDefaultAssignment,
	},
}

local dimmer = { brightness = 0.01 }
local bg_path = wezterm.home_dir .. "/assets"
config.background = {
	{
		source = {
			-- File = bg_path .. "/fantasy-forest-wallpaper.jpg",
			-- File = bg_path .. "/tokyo-sunset.jpeg",
			File = bg_path .. "/Buddha-and-animals.png",
		},
		repeat_x = "NoRepeat",
		width = "100%",
		hsb = dimmer,
	},
}

return config
