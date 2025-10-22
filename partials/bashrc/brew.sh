if [ -f "/opt/homebrew/bin/brew" ]; then # Apple Silicon
  eval "$(/opt/homebrew/bin/brew shellenv)"
elif [ -f "/usr/local/bin/brew" ]; then # Intel
  eval "$(/usr/local/bin/brew shellenv)"
fi

if [ -n "$HOMEBREW_PREFIX" ]; then
  eval 'test -r "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh" && . "${HOMEBREW_PREFIX}/etc/profile.d/bash_completion.sh"'
fi
