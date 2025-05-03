WIP

# Installation

These dotfiles are managed with chezmoi, converted from `freshshell/fresh`.

Open a terminal and run:

```
sh -c "$(curl -fsLS https://chezmoi.io/get)" -- init --apply josacar
```

# Missing things to backport

- Add `rupa/z` to `.bashrc`. Maybe with [includes](https://www.chezmoi.io/user-guide/include-files-from-elsewhere/#extract-a-single-file-from-an-archive)
- Refactor `.bashrc` fragments using [include or template](https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/#use-completely-different-dotfiles-on-different-machines)
- Add secrets like gpg and ssh keys from `bitwarden`

- Add `work` setup and cloning of private repository, and make `.vpnc-script` executable
