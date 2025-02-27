cp ~/.bash_aliases .
cp ~/.zshrc .
cp ~/.gitconfig .
cp ~/.config/wezterm/wezterm.lua .
cp ~/.aider.model.settings.yml .
cp ~/.aider.conf.yml .aider.conf.yml.example && sed -i 's/\(  #\?- [a-z]*=\).*/\1/' .aider.conf.yml.example
