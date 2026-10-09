if [ -f "/opt/homebrew/bin/brew" ]; then
  eval "$(/opt/homebrew/bin/brew shellenv)"
fi

if [ -n "$HOMEBREW_PREFIX" ]; then
  eval 'test -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" && . "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"'
fi
