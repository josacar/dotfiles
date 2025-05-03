These dotfiles are managed with chezmoi, converted from `freshshell/fresh`.

Original repository is [here](https://github.com/josacar/dotfiles-fresh)

# Installation

Open a terminal and run:

```
sh -c "$(curl -fsLS https://chezmoi.io/get)" -- init --apply josacar
```

# Missing things to backport

- Refactor `.bashrc` fragments using [include or template](https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/#use-completely-different-dotfiles-on-different-machines)

- Add secrets like gpg and ssh keys from `bitwarden`

- Add `work` setup and cloning of private repository, and make `.vpnc-script` executable
