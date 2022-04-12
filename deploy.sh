cp .zshrc .zshenv .zprofile vscode-exts.txt ~/

mkdir -p ~/.config/wezterm/colors

mkdir -p ~/.config/nvim

mkdir -p ~/.config/Code/User

cp wezterm.lua ~/.config/wezterm/

cp wezterm_tokyonight_night.toml wezterm_tokyonight_day.toml wezterm_github_dark_brighten.toml ~/.config/wezterm/colors/

cp init.vim ~/.config/nvim/

cp settings.json keybindings.json ~/.config/Code/User/

echo "deploy done!"

