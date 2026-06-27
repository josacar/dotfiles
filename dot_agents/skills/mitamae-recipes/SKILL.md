---
name: mitamae-recipes
description: Authoritative reference for mitamae, the mruby-powered single-binary configuration management tool with a Chef-like DSL. Use when the user asks to write mitamae recipes, manage dotfiles, provision servers, create resource or recipe plugins, migrate from Chef/Itamae, set up hocho integration, debug recipe execution, exercise the not_if/only_if guards, or structure node attributes. Covers all 15 built-in resources, the `define` custom-resource system, mruby library compatibility, and real-world recipe organization patterns.
---

# mitamae Recipes

mitamae is a fast, simple, single-binary configuration management tool with a Chef-like DSL, powered by **mruby** (not standard Ruby). It is an alternative implementation of [Itamae](https://github.com/itamae-kitchen/itamae), drop-in compatible — so Itamae wiki docs and plugins apply. This skill is distilled from the upstream repo, the Itamae wiki, the plugin ecosystem, and production deployments (k0kubun/dotfiles, ruby/ruby-infra-recipe).

## When to Use This Skill

Reach for this skill when the user:
- Wants to **provision a server** with repeatable, idempotent steps
- Needs to **manage dotfiles** declaratively (cross-platform, symlinked)
- Asks about **mitamae vs. Chef/Ansible/Puppet/Itamae** distinctions
- Wants to **write a recipe** (any resource: package, file, git, link, etc.)
- Wants to **define a custom resource** (`define :name do ... end`) for reuse
- Wants to **build a mitamae plugin** (resource or recipe)
- Needs to **migrate recipes from Chef or Itamae**
- Asks how to **run mitamae remotely** (hocho, rsync+ssh, CodeDeploy)
- Needs to debug `not_if`/`only_if`, notifications (`notifies`/`subscribes`), or dry-run (`-n`)

## Key Facts

- **Single binary** (statically linked against musl since v1.14.0 on Linux) — deploy a single file per host architecture.
- **mruby powered** — the DSL is mruby-compatible, not full-Ruby-compatible. Full class list: see `references/mruby-libraries.md`.
- **Idempotent.** Re-running a recipe always converges to the declared state.
- **No Chef Server, Berkshelf, or Data Bags.** Recipes and node config live in plain `.rb` + `.json`/`.yaml` files.
- **Itamae compatibility.** Plugins named `itamae-plugin-*` and `mitamae-plugin-*` are both loaded — Itamae plugins work unmodified.
- **v2.0.0** is the latest release (mruby 3.4.0, Zig cross-compile).
- **Linux binaries are musl-static** (no glibc dependency) since v1.14.0.
- [itamae-kitchen/mitamae](https://github.com/itamae-kitchen/mitamae): 391 stars, MIT licensed, official home.

## Quick Reference

### Installation

```bash
curl -O -L https://github.com/itamae-kitchen/mitamae/releases/latest/download/mitamae-x86_64-linux
chmod +x ./mitamae-x86_64-linux
./mitamae-x86_64-linux help
```

Available binary targets: `mitamae-x86_64-linux`, `mitamae-i386-linux`, `mitamae-aarch64-linux`, `mitamae-armhf-linux`, `mitamae-x86_64-darwin`, `mitamae-aarch64-darwin`.

Since v1.14.0 binaries are shipped as `.tar.gz` containing the binary; extract before use. Older releases ship raw binaries.

### First Recipe (`recipe.rb`)

```ruby
package 'nginx' do
  action :install
end

service 'nginx' do
  action [:enable, :start]
end
```

### Invoking mitamae

```bash
# Apply to local machine
mitamae local recipe.rb

# Dry-run — show what would change (since v1.12.0; alternatively -n works in some versions)
mitamae local -n recipe.rb
mitamae local --dry-run recipe.rb

# Pass node config
mitamae local -j node.json recipe.rb           # JSON; may be repeated, last wins
mitamae local -y node.yml recipe.rb             # YAML; may be repeated, last wins

# Debug verbosity
mitamae local --log-level=debug recipe.rb

# Use bash as the recipe's shell (defaults to /bin/sh)
mitamae local --shell=/bin/bash recipe.rb

# Specify plugins directory (v1.10.1+)
mitamae local --plugins=./plugins recipe.rb

# Disable colour (v1.12.3+)
mitamae local --no-color recipe.rb

# Multi-recipe: last recipe listed in an include_recipe chain runs first
mitamae local recipes/default.rb -j node.json
```

### All Available subcommands

- `mitamae local [recipe] [options]` — run against the local machine (**primary use**)
- `mitamae help [local]` — print comprehensive help
- `mitamae version` — show version (v1.8.0+)

There is no `mitamae ssh` subcommand — for remote execution, see `references/remote-execution.md`.

## Built-in Resources (All 15)

See `references/resources.md` for complete attribute tables, actions, and examples. Summary:

| Resource | Default action | All actions | Required attr (beyond common) |
|---|---------------|-------------|------------------------------|
| `directory` | `:create` | delete, create, nothing | — |
| `execute` | `:run` | run, nothing | — |
| `file` | `:create` | delete, edit, create, nothing | — |
| `gem_package` | `:install` | install, uninstall, upgrade, nothing | — |
| `git` | `:sync` | sync, nothing | `repository` |
| `group` | `:create` | create, nothing | — |
| `http_request` | `:get` | delete, post, options, get, put, nothing | `url` |
| `link` | `:create` | create, nothing | `to` |
| `local_ruby_block` | `:run` | run, nothing | — |
| `package` | `:install` | install, remove, nothing | — |
| `remote_directory` | `:create` | delete, create, nothing | `source` |
| `remote_file` | `:create` | delete, edit, create, nothing | — |
| `service` | `:nothing` | start, stop, reload, restart, disable, enable, nothing | — |
| `template` | `:create` | delete, edit, create, nothing | — |
| `user` | `:create` | create, nothing | — |

### Common attributes (every resource)

| Attribute | Use |
|---|---|
| `action` | Symbol or Array of Symbols — run multiple actions |
| `only_if` | String command — resource is skipped if the command exits non-zero |
| `not_if` | String command (or block — mitamae extension) — resource is skipped if the command exits zero |
| `notifies` | `:action, "type[name]", :delayed` (or `:immediately`) — fire another resource when this one changes |
| `subscribes` | Inverse of `notifies` — react to another resource's changes |
| `user` | Run all commands related to this resource as the given user |

### mitamae extensions beyond Itamae

- **`not_if` / `only_if` accept a block** (not just a command string)
- **`file`/`remote_file`/`template` have `atomic_update`** — replace file atomically (link + unlink)
- **`run_command` streams output** when given `log_output: true` or with `--log-level debug`
- **`local_ruby_block`'s `code` runs under `cwd`** if specified (v1.13.0+)
- **`http_request` raises on 4XX/5XX** responses (v1.8.0+)
- **`template` supports a `content` attribute** (v1.7.6+) — pass a string directly instead of an ERB file
- **`execute` supports an Array argument** (v1.3.3+) — no manual shell escaping
- **`git` resource has a `depth` attribute** (v1.4.3+) — shallow clones
- **`file` resource supports an `:edit` action** (v0.6.2+)
- **`gem_package` supports `:uninstall`** (v0.4.1+)

## Node Attributes

mitamae ships with pre-populated node attributes — use them for platform detection:
```ruby
node[:platform]            # 'ubuntu', 'debian', 'rhel', 'fedora', 'amazon', 'arch',
                           #  'freebsd', 'openbsd', 'opensuse', 'darwin', ...
node[:platform_version]
node[:kernel][:release]    # e.g. '6.5.0-21-generic', 'Darwin Kernel Version 23.0.0'
node[:hostname]
node[:ec2][:xxx]           # EC2 metadata query if running on AWS (Symbol keys supported v1.5.5+)
node[:ec2][:instance_id]
```

Seed your own defaults with `reverse_merge!` so explicit `-j`/`-y` node files override:
```ruby
node.reverse_merge!(
  user: ENV['SUDO_USER'] || ENV['USER'],
  rbenv: { global: '3.4.8', versions: %w[3.4.8] },
)
```

`node.json` example:
```json
{
  "platform": "ubuntu",
  "rbenv": { "global": "3.4.8" }
}
```

`node.yml` example (loaded via `-y node.yml`):
```yaml
platform: ubuntu
rbenv:
  global: "3.4.8"
  versions:
    - "3.4.8"
```

Multi-file merging: every `-j`/`-y` is loaded in order; later keys merge over (shallow merge by default), (currently no deep merge primitive — plan accordingly).

## Recipe Organization Patterns

See `references/recipe-patterns.md` for detailed walkthroughs of three real-world deployments. The most common shape:

```
my-project/
├── install.sh              # entry script: bootstraps binary and runs `mitamae local recipes/default.rb`
├── bin/
│   ├── setup               # downloads + sha256-verifies mitamae binary
│   ├── mitamae             # symlink to bin/mitamae-<version> (gitignored)
│   └── mitamae-1.14.1       # actual binary (gitignored)
├── config/                 # actual dotfile source files (template/cookbook sources)
│   ├── .gitconfig
│   ├── .tmux.conf
│   └── ...
├── node.json               # optional node attributes passed via -j
├── plugins                 # git submodules providing resource/recipe plugins
│   └── itamae-plugin-recipe-rbenv
├── recipes/
│   ├── default.rb          # root recipe
│   ├── base/
│   │   ├── default.rb
│   │   └── helpers.rb      # custom `define` blocks (dotfile, github_binary...)
│   ├── darwin/
│   │   ├── default.rb
│   │   └── files/
│   ├── ubuntu/
│   │   ├── default.rb
│   │   ├── docker/
│   │   ├── files/
│   │   └── ...
│   └── wsl/
│       └── default.rb
└── templates/              # ERB templates referenced by `template` resource
```

Cross-platform routing (idiomatic):
```ruby
# recipes/default.rb
include_recipe 'base'

if node[:kernel][:release] =~ /microsoft/i
  include_recipe 'wsl'
else
  include_recipe node[:platform]      # resolves to 'ubuntu', 'darwin', etc.
end
```

`include_recipe` paths (relative to the current recipe):
```ruby
include_recipe 'base'                                  # recipes/base/default.rb
include_recipe 'base/helpers'                          # recipes/base/helpers.rb
include_recipe '../shared/setup'                       # sibling recipe (relative)
include_recipe 'rbenv::user'                           # looks in plugins/<rbenv_recipe>/mrblib/...
```

## Custom Resources via `define`

```ruby
# recipes/helpers.rb — a reusable dotfile linker
define :dotfile do
  if params[:name].is_a?(String)
    links = { params[:name] => params[:name] }
  else
    links = params[:name]    # Hash: { "target_path" => "source_name" }
  end

  links.each do |link_from, link_to|
    directory File.dirname(link_from = File.join(ENV['HOME'], link_from)) do
      owner node[:user]
    end

    link link_from do
      to File.expand_path("../../../config/#{link_to}", __FILE__)
      owner node[:user]
      force true
    end
  end
end

# usage
dotfile '.gitconfig'
dotfile '.tmux.conf.local' => '.tmux.conf.linux'
dotfile '.config/nvim/init.vim'
```

## Plugins: Resource & Recipe

See `references/plugin-development.md` for the full reference. Quick facts:

- Plugins are **dynamically loaded** from a `plugins/` directory, not via gem/mrbgem.
- Auto-searched in `./plugins` relative to the mitamae working directory.
- Specify explicitly with `mitamae local --plugins=/path/to/plugins` (v1.10.1+).
- Repo name prefix: `mitamae-plugin-{resource,recipe}-<name>` or `itamae-plugin-{resource,recipe}-<name>` (both work).
- Add as git submodule under `./plugins/`.

## Debugging Recipes

1. **Dry-run**: `mitamae local -n recipe.rb` — show output without changes (use `--no-color` for clean log piping).
2. **Increase verbosity**: `mitamae local --log-level=debug recipe.rb` — streams every `run_command`'s output to stdout.
3. **Use `run_command`** (available outside resource blocks):
   ```ruby
   result = run_command('uname -a')
   result.stdout  # captured stdout
   result.stderr  # captured stderr
   result.exit_status
   ```
4. **`local_ruby_block`** for inline print debugging:
   ```ruby
   local_ruby_block 'debug node' do
     block { puts node[:platform] }
   end
   ```
5. `puts`/`print` work anywhere in a recipe (mruby Kernel#print).

## Migration From

- See `references/plugin-development.md` -> "Migrating from Chef" for the crosswalk.
- For Itamae: recipes are **pure-compatible**. Notable differences:
  - mitamae plugins live in `./plugins/`, Itamae installs via Bundler/RubyGems.
  - mitamae's `not_if`/`only_if` accept blocks; Itamae's only accept command strings.
  - mitamae supports `atomic_update` on file-like resources; Itamae does not.
  - Full Ruby gems usable in Itamae recipes are NOT available in mitamae (mruby subset).

## Reference Files

- `references/resources.md` — complete attribute tables and examples for all 15 built-in resources
- `references/recipe-patterns.md` — three production-grade recipe organizations (k0kubun/dotfiles, ruby/ruby-infra-recipe, k0kubun/dotfiles WSL)
- `references/plugin-development.md` — writing, structuring, and loading resource and recipe plugins; ResourceExecutor internals
- `references/dotfiles-management.md` — patterns for symlinked dotfiles: cross-platform dispatch, plugin use, bin/setup bootstrap
- `references/mruby-libraries.md` — full list of available mruby libraries, and per-feature Ruby→mruby caveats
- `references/remote-execution.md` — hocho integration, rsync+ssh pattern, deployment tools

## External References

- [itamae-kitchen/mitamae](https://github.com/itamae-kitchen/mitamae) — source repo, includes CHANGELOG and PLUGINS.md
- [itamae-kitchen/itamae wiki](https://github.com/itamae-kitchen/itamae/wiki) — canonical resource documentation (mitamae is compatible)
- [Releases](https://github.com/itamae-kitchen/mitamae/releases) — download binaries; v2.0.0 is latest as of creation
- [sorah/hocho](https://github.com/sorah/hocho) — recommended SSH orchestrator
- [itamae-plugins org](https://github.com/itamae-plugins) — plugin hub
- [k0kubun/dotfiles](https://github.com/k0kubun/dotfiles) — dotfiles reference deployment
- [ruby/ruby-infra-recipe](https://github.com/ruby/ruby-infra-recipe) — production server provisioning reference