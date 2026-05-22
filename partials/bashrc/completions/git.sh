# Source git-prompt.sh from system install (ships with git)
# Provides __git_ps1 for shell prompt
if [ -f /usr/lib/git-core/git-sh-prompt ]; then
  . /usr/lib/git-core/git-sh-prompt
elif [ "$(command -v brew)" ] && [ -f "$(brew --prefix)/etc/bash_completion.d/git-prompt.sh" ]; then
  . "$(brew --prefix)/etc/bash_completion.d/git-prompt.sh"
fi
