# mitamae Recipe Patterns — Production Reference

This file distills how production mitamae deployments are organized. It's the authoritative reference the SKILL.md points to when a user needs to bootstrap a new project, lay out a recipe tree, dispatch across platforms, or reuse recipe logic.

## 1. Recipe Tree Layout (k0kubun/dotfiles)

This is the canonical dotfiles-management layout. The repo doubles as both "the dotfile content" and "the recipe that installs them".

```
my-dotfiles/
├── install.sh              # bash entry point: ./bin/setup && mitamae local recipes/default.rb
├── bin/
│   ├── setup               # downloads + sha256-verifies mitamae binary
│   ├── mitamae             # symlink → bin/mitamae-<version> (gitignored)
│   ├── mitamae-1.14.1       # actual binary (gitignored)
│   └── update              # bumps pinned version + sha256 in bin/setup
├── config/                 # Source-of-truth dotfile content
│   ├── .gitconfig
│   ├── .gitconfig.darwin
│   ├── .gitconfig.linux
│   ├── .tmux.conf
│   ├── .tmux.conf.darwin
│   ├── .tmux.conf.linux
│   ├── .zshrc
│   ├── .zshrc.darwin
│   ├── .zshrc.Linux
│   ├── .gemrc
│   ├── .config/nvim/init.vim
│   └── ...
├── recipes/
│   ├── default.rb          # top-level dispatch
│   ├── base/
│   │   ├── default.rb      # cross-platform base setup
│   │   └── helpers.rb      # define :dotfile, define :github_binary
│   ├── darwin/
│   │   ├── default.rb
│   │   ├── gpg-agent.rb
│   │   └── files/           # files used by remote_file/remote_directory
│   ├── ubuntu/
│   │   ├── default.rb
│   │   ├── docker/
│   │   │   └── default.rb
│   │   ├── ruby/
│   │   │   └── default.rb
│   │   ├── skk/
│   │   │   ├── default.rb
│   │   │   └── files/
│   │   ├── files/
│   │   ├── ddns-update.rb
│   │   ├── gpg-agent.rb
│   │   ├── setup-perf.rb
│   │   ├── ssh-agent.rb
│   │   ├── systemd.rb
│   │   ├── xremap.rb
│   │   └── zsh.rb
│   ├── wsl/
│   │   ├── default.rb
│   │   ├── neovim.rb
│   │   ├── ssh-agent.rb
│   │   ├── systemd.rb
│   │   ├── zsh.rb
│   │   └── files/
│   └── spin/
│       ├── default.rb
│       └── files/home/spin/
├── plugins/                # git submodules for recipe/resource plugins
└── .gitignore              # excludes bin/mitamae* and config/.zsh/bundle/
```

### `install.sh` — entry-point pattern

```bash
#!/bin/bash
set -ex

bin/setup                 # bit-perfect binary bootstrap

if [[ -n "$SPIN" ]]; then
  sudo -E bin/mitamae local $@ recipes/spin/default.rb
  exit
fi

case "$(uname)" in
  "Darwin")  bin/mitamae local $@ recipes/default.rb ;;     # Homebrew needs no sudo
  *)         sudo -E bin/mitamae local $@ recipes/default.rb ;;
esac
```

Flags passed to `install.sh` are forwarded to mitamae: `./install.sh -n` is a dry-run, `./install.sh -j node.json` passes node config.

### `bin/setup` — pin-and-verify binary bootstrap

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

Always pin mitamae versions and sha256-verify — supply chain safety in a "single binary" world is paramount.

### `recipes/default.rb` — cross-platform routing

```ruby
include_recipe 'base'

if node[:kernel][:release] =~ /microsoft/i
  include_recipe 'wsl'
else
  include_recipe node[:platform]   # 'ubuntu' or 'darwin' etc.
end
```

### `recipes/base/default.rb` — cross-platform base

```ruby
node.reverse_merge!(
  os: run_command('uname').stdout.strip.downcase,
  user: ENV['SUDO_USER'] || ENV['USER'],
)

include_recipe 'helpers'   # pulls in define :dotfile, define :github_binary

directory "#{ENV['HOME']}/bin" do
  owner node[:user]
end

github_binary 'ghq' do
  repository 'motemen/ghq'
  version 'v0.10.0'
  archive "ghq_#{node[:os]}_amd64.zip"
  binary_path "ghq_#{node[:os]}_amd64/ghq"
end
```

### `recipes/base/helpers.rb` — reusable `define`s

```ruby
# define :dotfile — symlink $HOME/.foo → config/.foo
define :dotfile do
  if params[:name].is_a?(String)
    links = { params[:name] => params[:name] }
  else
    links = params[:name]
  end

  links.each do |link_from, link_to|
    directory File.dirname(link_from = File.join(ENV['HOME'], link_from)) do
      user node[:user]
    end

    link link_from do
      to File.expand_path("../../../config/#{link_to}", __FILE__)
      user node[:user]
      force true
    end
  end
end
```

Usage:
```ruby
dotfile '.gitconfig'
dotfile '.tmux.conf.local' => '.tmux.conf.darwin'        # target → source mapping
dotfile '.config/nvim/init.vim'
```

### `recipes/darwin/default.rb` — platform-specific

```ruby
dotfile '.config/nvim/coc-settings.json'
dotfile '.config/nvim/init.vim'
dotfile '.gitconfig'
dotfile '.gitignore'
dotfile '.karabiner'
dotfile '.peco'
dotfile '.pryrc'
dotfile '.tmux.conf'
dotfile '.tmux.conf.local' => '.tmux.conf.darwin'
dotfile '.zsh'
dotfile '.zshrc'
dotfile '.zshrc.darwin'

package 'git' do
  action :install
end

include_recipe 'gpg-agent'

# Render karabiner.json from YAML schema
file "#{ENV['HOME']}/.config/karabiner/karabiner.json" do
  yaml_path = File.expand_path('../../../config/karabiner.yml', __FILE__)
  yaml = ERB.new(File.read(yaml_path)).result
  content JSON.pretty_generate(YAML.load(yaml))
end
```

## 2. Hocho-Based Provisioning (ruby/ruby-infra-recipe)

When provisioning **multiple remote hosts** rather than the local machine, hocho is the canonical orchestrator. mitamae has no built-in SSH support — hocho provides SSH-to-target + binary bootstrap.

### Directory layout

```
my-infra/
├── bin/hocho              # auto-inits plugins submodules, runs `bundle exec hocho`
├── bin/hosts              # lists hostnames parsed from hosts.yml
├── plugins/
│   └── itamae-plugin-recipe-rbenv/   # git submodule
├── recipes/
│   ├── default.rb         # single entry point used by all hosts
│   ├── setup-users.rb     # data-driven user creation
│   └── keys/              # *.keys files — each filename becomes a username
│       ├── hsbt.keys
│       ├── eregon.keys
│       └── ...
├── hocho.yml              # host inventory + driver config + bootstrap
├── hosts.yml             # node properties per host
├── Gemfile               # hocho, bcrypt_pbkdf, ed25519 (for SSH)
├── .ruby-version         # Ruby version used on the workstation running hocho
└── .gitmodules           # declares rbenv plugin submodule
```

### `hosts.yml` — uniform per-host attribution

All 27 nodes in ruby-infra-recipe use the **same** run_list and properties:
```yaml
debian.rubyci.org:
  properties:
    nopasswd_sudo: true
    compress: false
    run_list:
      - recipes/default.rb
ubuntu2204.rubyci.org:
  properties:
    nopasswd_sudo: true
    compress: false
    run_list:
      - recipes/default.rb
```
Platform-specific logic lives **inside** recipes via `node[:platform]` — not via per-host recipes.

### `hocho.yml` — driver config + bootstrap

```yaml
property_providers:
  - add_default:
      properties:
        preferred_driver: mitamae

driver_options:
  mitamae:
    mitamae_path: /usr/local/bin/mitamae
    mitamae_options: ['--log-level', 'info']

mitamae_prepare_script: |
  #!/bin/bash
  set -e
  # detect OS via uname -s → linux, darwin, freebsd, openbsd, solaris
  # detect arch via uname -m → x86_64, aarch64, ppc64le, s390x, etc.
  # git ls-remote --tags itamae-kitchen/mitamae to find latest release
  # curl -L the corresponding binary to /usr/local/bin/mitamae
  # chmod +x && /usr/local/bin/mitamae version
```

Hocho copies the recipe tree (rsync over ssh), runs the bootstrap script on the target (which installs mitamae), then executes `mitamae local recipes/default.rb -j <generated.json>` on the remote host.

### `bin/hocho` — auto-init submodules

```bash
#!/bin/bash
set -e
if [[ ! -d plugins/itamae-plugin-recipe-rbenv/.git ]]; then
  git submodule init && git submodule update
fi
exec bundle exec hocho "$@"
```

### `recipes/default.rb` — single entry, branch inside

```ruby
include_recipe "setup-users"

user 'chkbuild' do
  case node[:platform]
  when 'debian', 'ubuntu'
    shell '/bin/bash'
  end
end

# openSUSE workaround: no wheel group
group = if node[:platform] == 'opensuse' then 'users' else 'chkbuild' end

node.reverse_merge!(
  rbenv: {
    user: 'chkbuild',
    group: group,
    global: '3.4.8',
    versions: %w[3.4.8],
    install_development_dependency: true,
  },
  'ruby-build': {
    build_envs: { 'RUBY_CONFIGURE_OPTS': '--disable-install-doc --disable-dtrace' },
  },
  'rbenv-default-gems': {
    'default-gems': ['aws-sdk-s3'],
  },
)

include_recipe 'rbenv::user'   # from the plugin submodule

# Clone chkbuild if missing
git "chkbuild" do
  repository "https://github.com/ruby/chkbuild"
  user "chkbuild"
  not_if "test -e /home/chkbuild/chkbuild"
end

# Per-platform cron/package installs
case node[:platform]
when 'debian'
  package 'cron'
when 'fedora', 'amazon'
  %w[cronie cronie-anacron patch].each { |p| package p }
  service 'crond' do
    action [:enable, :start]
  end
when 'rhel', 'openbsd', 'opensuse'
  package 'patch'
when 'arch'
  %w[cronie vi inetutils].each { |p| package p }
  service 'cronie' do
    action [:enable, :start]
  end
when 'gentoo'
  package 'fcron'
  service 'fcron' do
    action [:enable, :start]
  end
end
```

### `recipes/setup-users.rb` — data-driven resource creation

Pattern: glob for data files; filename becomes the username, file content becomes authorised_keys.

```ruby
Dir.glob(File.expand_path("../keys/*.keys", __FILE__)).sort.each do |key|
  u = File.basename(key).delete_suffix('.keys')   # filename = username

  user u do
    case node[:platform]
    when 'debian', 'ubuntu'
      gid 27      # sudo
      shell '/bin/bash'
    when 'freebsd', 'openbsd'
      gid 0       # wheel
    when 'opensuse'
      gid 100     # users (no wheel)
    when 'arch'
      gid 998     # wheel
    else
      gid 10
    end
  end

  directory "/home/#{u}/.ssh" do
    owner u
    mode '0700'
  end

  file "/home/#{u}/.ssh/authorized_keys" do
    content File.read(key)
    owner u
    mode '0600'
  end
end
```

**Onboarding a new developer becomes: drop their `.keys` file into `recipes/keys/`. No recipe edit needed.**

## 3. Multi-OS Host Across WSLLinux/macOS (k0kubun/dotfiles WSL recipe)

`recipes/wsl/default.rb` demonstrates a **minimal** WSL setup:
```ruby
dotfile '.config/nvim/coc-settings.json'
dotfile '.config/nvim/init.vim'
dotfile '.gitconfig'
dotfile '.peco'
dotfile '.tmux.conf'
dotfile '.tmux.conf.local' => '.tmux.conf.linux'
dotfile '.zsh'
dotfile '.zshrc'
dotfile '.zshrc.Linux'

package 'tmux'
package 'zsh'
package 'htop'

include_recipe 'zsh'
include_recipe 'neovim'
include_recipe 'systemd'
include_recipe 'ssh-agent'
```

### `recipes/spin/default.rb` — minimal override

For Shopify's Spin platform (which has its own home dir convention):
```ruby
include_recipe '../base'      # relative path

remote_file '/home/spin/.zshrc' do
  owner node[:user]
end
```

## 4. Common Dispatch Patterns

### Per-platform package list

Use `case node[:platform]` rather than per-platform recipes to keep the diff small:

```ruby
case node[:platform]
when 'debian', 'ubuntu'
  %w[cron ripgrep vim neovim fd-find fzf].each { |p| package p }
when 'fedora', 'amazon', 'rhel'
  %w[cronie ripgrep vim neovim fd-find fzf].each { |p| package p }
when 'arch'
  %w[cronie ripgrep vim neovim fd fzf].each { |p| package p }
when 'darwin'
  package 'ripgrep'    # handled by Homebrew
end
```

### `node.reverse_merge!` for layered defaults

```ruby
# defaults live in recipe
node.reverse_merge!(
  docker: { users: %w[deploy] },
  rbenv: { global: '3.4.8' },
)
# overriding node.yml/JSON passed via -y/-j wins
```

This is the idiomatic way to give a recipe a default shape while letting deployment override it.

### Multi-recipe `include_recipe`

```ruby
include_recipe 'base'                           # recipes/base/default.rb
include_recipe 'base/helpers'                    # recipes/base/helpers.rb
include_recipe 'setup-users'                     # recipes/setup-users.rb
include_recipe '../shared/ssh'                   # sibling recipe (relative)
include_recipe 'rbenv::user'                     # plugin recipe (plugins/.../rbenv/user.rb)
```

### Conditional include

```ruby
if node[:platform] == 'ubuntu'
  include_recipe 'ubuntu/docker'
end
```

`include_recipe` will raise if no file is found. Use the conditional guard above to skip on platforms.

## 5. `define` — Inspection Recipe Reuse

`define :name do ... end` creates a recipe-level DSL keyword. Inside, `params[:name]` is the resource name (or Hash if passed one), and additional params via `param_name:` arguments in the call:

```ruby
define :github_binary do
  repository = params[:repository]
  version    = params[:version]
  archive    = params[:archive]
  binary     = params[:binary_path] || params[:name]

  # download, extract, install to ~/bin
  ...
end

github_binary 'ghq' do
  repository 'motemen/ghq'
  version 'v0.10.0'
  archive "ghq_#{node[:os]}_amd64.zip"
  binary_path "ghq_#{node[:os]}_amd64/ghq"
end
```

## 6. Authoring Checklist for a New Project

1. Bootstrap with `bin/setup` (pin + verify binary).
2. Use `install.sh` (or your own entry script) to invoke `mitamae local` with appropriate `sudo` semantics.
3. Lay out `config/` (sources), `recipes/` (logic), `plugins/` (submodules).
4. Put cross-platform helpers in `recipes/base/helpers.rb` with `define`.
5. Route from `recipes/default.rb` to per-platform recipes via `node[:platform]`.
6. Use `node.reverse_merge!` for defaults (not bare assignments).
7. Guard one-shot commands with `not_if`/`only_if`.
8. Pin all plugin versions as git submodules.
9. Make `bin/hocho` (or equivalent) auto-init submodules so clones always work.
10. Use `./install.sh -n` for a dry-run preview.

## Source Repos

- [k0kubun/dotfiles](https://github.com/k0kubun/dotfiles) — cross-platform dotfiles with `define :dotfile` linker
- [ruby/ruby-infra-recipe](https://github.com/ruby/ruby-infra-recipe) — hocho + mitamae provisioning 27 CI hosts
- [sorah/hocho](https://github.com/sorah/hocho) — SSH orchestrator