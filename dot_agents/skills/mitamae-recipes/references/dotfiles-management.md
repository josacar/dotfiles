# mitamae Dotfiles Management Patterns

This reference extends `references/recipe-patterns.md` to focus specifically on using mitamae for dotfiles — the most common mitamae use-case outside of server provisioning.

## Why mitamae for Dotfiles

Compared to GNU Stow, chezmoi, yadm, dotbot:
- **Idempotent execution** — re-running your dotfiles setup converges without errors.
- **Run-time templating** — `template` resource lets you render `.gitconfig`, `.tmux.conf`, etc. with platform-specific content.
- **Conditional installation** — `not_if`/`only_if` make "install if absent" one-liners.
- **Cross-platform** — `node[:platform]` switches between macOS/Linux/WSL with one recipe tree.
- **Package installation inline** — `package` resource interleaves with dotfile linking so you can install `fzf` and link `~/.config/fzf` in the same recipe.

## Anatomy of a Dotfiles Repo

```
your-dotfiles/
├── install.sh                          # entry script: bootstraps + invokes mitamae
├── bin/
│   ├── setup                           # binary downloader + sha256 verify
│   ├── mitamae                         # symlink → bin/mitamae-<version>
│   └── mitamae-<version>                # real binary (gitignored)
├── config/                             # dotfile source-of-truth
│   ├── .gitconfig
│   ├── .gitconfig.darwin               # platform variants via .<suffix>
│   ├── .gitconfig.linux
│   ├── .zshrc
│   ├── .zshrc.darwin
│   ├── .zshrc.Linux
│   ├── .tmux.conf
│   ├── .tmux.conf.darwin
│   ├── .tmux.conf.linux
│   ├── .gemrc
│   ├── .irbrc
│   ├── .pryrc
│   ├── .config/
│   │   ├── nvim/
│   │   │   ├── init.vim
│   │   │   └── coc-settings.json
│   │   └── solargraph/config.yml
│   ├── .zsh/lib/
│   ├── .peco/
│   ├── .claude/
│   ├── .docker/
│   ├── .githooks/
│   ├── .git-template/
│   └── ...
├── recipes/
│   ├── default.rb
│   ├── base/
│   │   ├── default.rb
│   │   └── helpers.rb                  # define :dotfile, define :github_binary
│   ├── darwin/
│   │   ├── default.rb
│   │   ├── gpg-agent.rb
│   │   └── files/
│   ├── ubuntu/
│   │   ├── default.rb
│   │   ├── docker/
│   │   ├── files/
│   │   └── ...
│   └── wsl/
│       ├── default.rb
│       └── ...
├── plugins/
│   └── <submodule>/...                 # recipe/resource plugins
└── .gitignore                          # bin/mitamae*, *.swp, symlink cache
```

## The `define :dotfile` Pattern

The reusable primitive — symlinks `$HOME/.foo` to `config/.foo`:

```ruby
# recipes/base/helpers.rb
define :dotfile do
  if params[:name].is_a?(String)
    links = { params[:name] => params[:name] }     # name and source match
  else
    links = params[:name]                          # Hash form: target => source
  end

  links.each do |link_from, link_to|
    full_target = File.join(ENV['HOME'], link_from)

    directory File.dirname(full_target) do
      owner node[:user]
    end

    link full_target do
      to File.expand_path("../../../config/#{link_to}", __FILE__)
      owner node[:user]
      force true
    end
  end
end
```

Three call shapes:

```ruby
dotfile '.gitconfig'
# → symlink $HOME/.gitconfig → <repo>/config/.gitconfig

dotfile '.tmux.conf.local' => '.tmux.conf.darwin'
# → symlink $HOME/.tmux.conf.local → <repo>/config/.tmux.conf.darwin

dotfile '.config/nvim/init.vim'
# → symlink $HOME/.config/nvim/init.vim → <repo>/config/.config/nvim/init.vim
# 'directory' auto-creates ~/.config/nvim/
```

## Cross-Platform Routing

`recipes/default.rb`:
```ruby
include_recipe 'base'

if node[:kernel][:release] =~ /microsoft/i
  include_recipe 'wsl'
else
  include_recipe node[:platform]      # 'ubuntu', 'darwin'...
end
```

Guarded routes via plain `if` also work:
```ruby
if node[:platform] == 'darwin'
  include_recipe 'darwin/karabiner'
end
```

## Platform Variants via Filename Suffix

Avoid `node[:platform]` conditionals *inside* a template — instead ship multiple variants of the dotfile and link the right one:

```
config/
├── .gitconfig           # base content (unused directly)
├── .gitconfig.darwin    # macOS-specific
├── .gitconfig.linux     # Linux-specific
```

```ruby
# recipes/darwin/default.rb
dotfile '.gitconfig' => '.gitconfig.darwin'

# recipes/ubuntu/default.rb
dotfile '.gitconfig' => '.gitconfig.linux'
```

## Run-time Templating Alternative

For dotfiles that need true ERB rendering (variables interpolated):

```
templates/
└── gitconfig.erb
```

```erb
[user]
name = <%= @name %>
email = <%= @email %>
signingkey = <%= @signingkey %>
[core]
  autocrlf = input
<% if @linux %>
[credential]
  helper = store
<% end %>
```

```ruby
# recipes/base/default.rb
template "#{ENV['HOME']}/.gitconfig" do
  source 'gitconfig.erb'
  variables(
    name: node[:name] || 'José',
    email: node[:email],
    signingkey: node[:signingkey],
    linux: node[:platform] != 'darwin',
  )
  owner node[:user]
end
```

Choose variant linking for "shape differs entirely" cases; use templating for "shape mostly same, values vary".

## Bootstrap Script (`bin/setup`)

Reproducibility hinges on the **mitamae binary itself being pinned**. Use this template:

```bash
#!/bin/sh
set -e

mitamae_version="1.14.1"
mitamae_linux_sha256="dc5fe86e5a6ea46f8d1deedb812670871b9cd06547c7be456ebace73f83cbf7b"
mitamae_darwin_sha256="eabb808469ee29e41c20de83966d8559604c7cec799475db0c98c379bd3e42aa"

mitamae_cache="mitamae-${mitamae_version}"
if ! [ -f "bin/${mitamae_cache}" ]; then
  case "$(uname)" in
    "Linux")  mitamae_bin="mitamae-x86_64-linux";   mitamae_sha256="$mitamae_linux_sha256" ;;
    "Darwin") mitamae_bin="mitamae-x86_64-darwin";  mitamae_sha256="$mitamae_darwin_sha256" ;;
    *) echo "unexpected uname: $(uname)"; exit 1 ;;
  esac

  curl -o "bin/${mitamae_bin}.tar.gz" -fL \
    "https://github.com/itamae-kitchen/mitamae/releases/download/v${mitamae_version}/${mitamae_bin}.tar.gz"

  sha256="$(/usr/bin/openssl dgst -sha256 "bin/${mitamae_bin}.tar.gz" | cut -d" " -f2)"
  if [ "$mitamae_sha256" != "$sha256" ]; then
    echo "checksum verification failed!"; exit 1
  fi
  tar xvzf "bin/${mitamae_bin}.tar.gz"
  rm "bin/${mitamae_bin}.tar.gz"
  mv "${mitamae_bin}" "bin/${mitamae_cache}"
  chmod +x "bin/${mitamae_cache}"
fi
ln -sf "${mitamae_cache}" bin/mitamae
```

Update versions with a small `bin/update` script that queries GitHub releases API and rewrites the version + sha256 constants.

## Entry Script (`install.sh`)

```bash
#!/bin/bash
set -ex
bin/setup    # ensure binary present

case "$(uname)" in
  "Darwin")  bin/mitamae local "$@" recipes/default.rb ;;   # Homebrew forbids sudo
  *)         sudo -E bin/mitamae local "$@" recipes/default.rb ;;
esac
```

`"$@"` passes args through:
- `./install.sh` — apply changes
- `./install.sh -n` — dry-run
- `./install.sh -j node.json` — pass node config
- `./install.sh --log-level debug` — verbose

## `.gitignore` essentials

```
bin/mitmae-*       # versioned binaries
bin/mitamae        # symlink
*.swp
config/.zsh/bundle/   # generated cache (varies by tool)
```

## Integrating Packages

The key advantage of mitamae over a simple symlinker: install packages and link dotfiles together.

```ruby
# recipes/ubuntu/default.rb
dotfile '.gitconfig'
dotfile '.tmux.conf'
dotfile '.zshrc'

package 'git'
package 'tmux'
package 'zsh'
package 'fzf'

include_recipe 'systemd'
include_recipe 'gpg-agent'
include_recipe 'ssh-agent'
```

## Sub-recipe organisation

Group related enhancements into their own sub-recipe:

```
recipes/ubuntu/
├── default.rb           # top-level: dotfile links + package installs
├── systemd.rb           # user-service management
├── ssh-agent.rb         # auto-start ssh-agent via systemd user
├── gpg-agent.rb         # GPG agent config + systemd user
├── xremap.rb            # xremap key remapper download + auto-start
├── ddns-update.rb       # cron job for DDNS
├── setup-perf.rb        # perf permissions (debug perf)
├── zsh.rb               # zsh specifics (e.g. install zsh, enable as default shell)
├── docker/
│   └── default.rb       # Docker install + user in docker group
├── ruby/
│   └── default.rb       # rbenv via plugin
└── skk/
    ├── default.rb       # libskk install + keymap deploy
    └── files/usr/share/libskk/rules/default/keymap/
```

In `recipes/ubuntu/default.rb`, `include_recipe 'systemd'` resolves to `recipes/ubuntu/systemd.rb`. To use a top-level recipe instead, `include_recipe '../base'` (relative) or `include_recipe 'base'` (relative to `recipes/`).

## User Detection Pattern

```ruby
node.reverse_merge!(
  user: ENV['SUDO_USER'] || ENV['USER'],
)
```

`SUDO_USER` is set when invoked via `sudo -E` (recommended). Fallback to `USER` for non-sudo invocations. Use `node[:user]` consistently inside `user:`/`owner:` attrs.

## Sudo Semantics Per Platform

| Platform | Sudo? | Reason |
|---|---|---|
| Linux (Debian/Ubuntu/etc.) | `sudo -E` | Installing system packages requires root. `-E` preserves `$HOME` and other env (so mitamae expands `ENV['HOME']` to the real user). |
| macOS (Darwin) | **no sudo** | Homebrew refuses to run as root. Use `bin/mitamae local recipes/default.rb` directly. |
| WSL | `sudo -E` | Linux rules apply. |
| Shopify Spin | `sudo -E` plus custom recipe path. | Defaults ship their own sub-recipe `recipes/spin/default.rb`. |

## Dry-Run Workflow

Always dry-run before applying:
```sh
./install.sh -n       # show what would change
./install.sh --log-level=debug     # verbose — includes every run_command output
./install.sh          # apply
```

## Idempotency Checks

**Self-contained examples**

### `not_if` for "install if missing"

```ruby
git "#{node[:user]}/code/dotfiles-content" do
  repository 'https://github.com/you/your-content'
  user node[:user]
  not_if "test -e #{node[:user]}/code/dotfiles-content"
end
```

### `only_if` for platform-conditional logic

```ruby
execute 'configure iptables' do
  command 'iptables-restore < /etc/iptables/rules.v4'
  only_if 'test -f /etc/iptables/rules.v4'
  only_if 'test $(id -u) -eq 0'
end
```

### Per-action `not_if`/`only_if`

Block form (mitamae-specific):
```ruby
file "#{ENV['HOME']}/.config/foo/bar.conf" do
  content 'managed = true'
  only_if { File.directory?("#{ENV['HOME']}/.config/foo") }
end
```

## Chezmoi Interop

This skill lives inside a chezmoi-managed dotfiles repo — but the two tools usually don't mix well because chezmoi already handles templating, encryption, `run_onchange_after_apply_*` scripts, etc. Pick the one that solves your problem:

- **chezmoi** when you want pure dotfile management with template logic and secret encryption.
- **mitamae** when you need a real config-management DSL: cross-platform package installation, plugin-based recipe reuse (e.g. rbenv across hosts), or system provisioning mixing packages + dotfiles + systemd services in one idempotent run.

If you must combine them, the closest useful pattern is:

1. Use chezmoi to ship `~/.local/bin/mitamae` (via `dot_local/bin/executable_mitamae`).
2. Add a chezmoi `run_onchange_after_apply_*` script that invokes `mitamae local` to handle non-dotfile provisioning (system packages, services).
3. Keep the recipe tree in `dot_mitamae/` (so chezmoi deploys it to `~/.mitamae/`).

Most users pick one tool.

## Reference Deployment

- [k0kubun/dotfiles](https://github.com/k0kubun/dotfiles) — the canonical reference. Notable features:
  - `bin/setup` with sha256 verification
  - `define :dotfile` linker
  - `define :github_binary` for downloading release binaries
  - Cross-platform detection via `node[:kernel][:release]` for WSL
  - Per-platform folders (darwin, ubuntu, wsl, spin)
  - Plugin submodule for itamae-plugin-recipe-rbenv