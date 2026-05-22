command -v starship &>/dev/null && eval "$(starship init bash)"

command -v ack-grep >/dev/null && alias ack='ack-grep'

command -v nvim >/dev/null && alias vim='nvim'

command -v eza >/dev/null && alias ls='eza'

command -v fzf >/dev/null && {
  eval "$(fzf --bash)"
  export FZF_DEFAULT_OPTS='--height 40% --layout reverse --border top'
}
