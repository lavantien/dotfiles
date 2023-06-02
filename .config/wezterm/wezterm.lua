local wezterm = require("wezterm")
local mux = wezterm.mux
local config = {}

wezterm.on("gui-startup", function(cmd)
	local tab, pane, window = mux.spawn_window(cmd or {})
	window:gui_window():maximize()
	window:gui_window():toggle_fullscreen()
end)

if wezterm.config_builder then
	config = wezterm.config_builder()
end

config.font = wezterm.font_with_fallback {
	'Iosevka Nerd Font',
	'Noto Sans SC',
	'DengXian',
	'Source Han Sans SC',
}
config.font_size = 24.0
config.color_scheme = "tokyonight_night"
config.window_decorations = "NONE"
config.hide_tab_bar_if_only_one_tab = true

local dimmer = { brightness = 0.020 }
local bg_path = "~/Pictures/wallpaper"
config.background = {
	{
		source = {
			File = bg_path .. "/fantasy-forest-wallpaper.jpg",
		},
		repeat_x = "NoRepeat",
		width = "100%",
		hsb = dimmer,
	},
}

return config
