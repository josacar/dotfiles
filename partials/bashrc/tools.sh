command -v starship &>/dev/null
[ $? -eq 0 ] && eval "$(starship init bash)"

command -v ack-grep >/dev/null
[ $? -eq 0 ] && alias ack='ack-grep'

command -v nvim >/dev/null
[ $? -eq 0 ] && alias vim='nvim'

command -v eza >/dev/null
[ $? -eq 0 ] && alias ls='eza'

command -v fzf >/dev/null
if [ $? -eq 0 ]; then
  eval "$(fzf --bash)"
  export FZF_DEFAULT_OPTS='--height 40% --layout reverse --border top'
fi
