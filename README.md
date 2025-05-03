WIP

Dotfiles managed with chezmoi, converted from `freshshell/fresh`

Missing things:
- Add `rupa/z` to `.bashrc`. Maybe with [includes](https://www.chezmoi.io/user-guide/include-files-from-elsewhere/#extract-a-single-file-from-an-archive)
- Refactor `.bashrc` fragments using [include or template](https://www.chezmoi.io/user-guide/manage-machine-to-machine-differences/#use-completely-different-dotfiles-on-different-machines)
- Check the `private` and `private_readonly` as maybe only `.ssh` makes sense to be `private`

- Add secrets like gpg and ssh keys from `bitwarden`

- Add commands to initialize the system from `freshrc` with [scripts](https://www.chezmoi.io/user-guide/use-scripts-to-perform-actions/)

- Add `work` setup and cloning of private repository
