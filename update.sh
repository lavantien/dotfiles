cp ~/.aider.model.settings.yml .
cp ~/.bash_aliases .
cp ~/.bashrc .
cp ~/.gitconfig .
cp ~/.aider.conf.yml .aider.conf.yml.example && sed -i 's/\(  #\?- [a-z]*=\).*/\1/' .aider.conf.yml.example
