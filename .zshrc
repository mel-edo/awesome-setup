# If you come from bash you might have to change your $PATH.
# export PATH=$HOME/bin:/usr/local/bin:$PATH

# Path to your oh-my-zsh installation.
export ZSH="$HOME/.oh-my-zsh"
export SHELL=zsh
export LANG=en_US.UTF-8
export GTK_THEME=catppuccin-mocha-lavender-standard-dark
export QML_XHR_ALLOW_FILE_READ=1
export EDITOR=nvim
export VISUAL=nvim

autoload -Uz promptinit vcs_info
promptinit

setopt prompt_subst

zstyle ':vcs_info:git:*' formats '(%b%u%c)'
zstyle ':vcs_info:git:*' actionformats '(%b|%a)'
zstyle ':vcs_info:*' unstagedstr='*'
zstyle ':vcs_info:*' stagedstr='+'

# Prompt
# Prompt credits go to https://github.com/N3k0Ch4n/dotRice

precmd() {
  vcs_info
  print ""
}
PS1='%B%(?.%K{135}.%K{167}) %k %F{183}%4~ %F{181}${vcs_info_msg_0_}%f/ %k%b%f'
PS2='%K{167} %K{235} -> %k '
# oh-my-zsh plugins
plugins=(zsh-autosuggestions git zsh-syntax-highlighting history-substring-search timer)
zstyle ':omz:update' mode disabled
source $ZSH/oh-my-zsh.sh

TIMER_FORMAT='/%d'
TIMER_PRECISION=3

pokemon-colorscripts -r --no-title

alias ls="eza --icons=always -a"
alias fetch="fastfetch"
export PATH="$HOME/.local/bin/:$PATH"
export PATH="$HOME/.cargo/bin:$PATH"
