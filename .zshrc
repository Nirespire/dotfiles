export SSH_AUTH_SOCK=/Users/sanjaynair/Library/Containers/com.bitwarden.desktop/Data/.bitwarden-ssh-agent.sock
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/sanjaynair/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions

fpath+=($HOME/.zsh/pure)
autoload -U promptinit; promptinit
prompt pure

# Aliases
[ -f ~/.aliases ] && source ~/.aliases
