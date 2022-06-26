# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"

export SHELL=zsh

autoload -Uz promptinit
promptinit

# Prompt
# Prompt credits go to https://github.com/N3k0Ch4n/dotRice

precmd() { print "" }
PS1='%B%(?.%K{135}.%K{167}) %k %F{183}%4~ / %k%b%f '
PS2='%K{167} %K{235} -> %k '

# oh-my-zsh plugins
plugins=(zsh-autosuggestions git zsh-syntax-highlighting history-substring-search)

source $ZSH/oh-my-zsh.sh

alias ls="logo-ls -A"
alias osu="sh ~/.wineosu/osu/start.sh"
