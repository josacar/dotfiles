# mitamae Plugin Development — Complete Reference

mitamae's plugin system is fundamentally different from Itamae's. This document covers everything you need to write, package, and load both **resource plugins** (add new DSL keywords like `cron`) and **recipe plugins** (reusable `include_recipe` bundles).

## How Plugins Are Loaded

**Not via gem, not via mrbgem.** mitamae dynamically loads plugin sources from a filesystem directory searched relative to the mitamae process working directory.

### Default location: `./plugins`

```sh
cd /path/to     # dir containing the plugins/ directory
mitamae local ...
```

mitamae walks `./plugins/*` and auto-loads any directory matching `mitamae-plugin-*` or `itamae-plugin-*`.

### Explicit path: `--plugins` (v1.10.1+)

```sh
mitamae local --plugins=/path/to/plugins ...
```

The flag overrides the default `./plugins` search.

> Plugins are **experimental**. Loading order and path conventions may change in future versions. Pin plugin versions as git submodule commits in your parent repo for stability.

## Resource Plugins

A resource plugin adds a new DSL keyword. Example: `mitamae-plugin-resource-cron` adds `cron 'foo' do ... end`.

### Repository Naming

- **Required prefix**: `mitamae-plugin-resource-<name>` or `itamae-plugin-resource-<name>` (both work — Itamae-compatible prefix is supported for plugin reuse).
- The DSL keyword is inferred from the repository name suffix. `mitamae-plugin-resource-cron` exposes the `cron` resource; `mitamae-plugin-resource-deploy_revision` exposes `deploy_revision`.

### Directory Structure

```
mitamae-plugin-resource-<name>/
├── mrblib/
│   ├── resource/
│   │   └── <name>.rb               # Resource class — attribute definitions
│   └── resource_executor/
│       └── <name>.rb               # Executor class — implementation
├── LICENSE
├── NOTICE
└── README.md
```

**Filename must match the class name suffix** — `cron.rb` defines `::MItamae::Plugin::Resource::Cron`, the DSL keyword is derived from the class name (`Cron` → `cron`).

### The Resource Class

Subclass `MItamae::Resource::Base`. Declare attributes via `define_attribute`. Each attribute takes a name, plus any of: `type:` (single class or Array of classes), `default:` (literal default value), `default_name:` (use the resource's name as the default for this attribute).

```ruby
# mrblib/resource/cron.rb
module ::MItamae
  module Plugin
    module Resource
      class Cron < ::MItamae::Resource::Base
        define_attribute :action, default: :create
        define_attribute :command, type: String, default_name: true   # use resource name

        define_attribute :minute, type: String, default: '*'
        define_attribute :hour,   type: String, default: '*'
        define_attribute :day,    type: String, default: '*'
        define_attribute :month,  type: String, default: '*'
        define_attribute :weekday, type: String, default: '*'
        define_attribute :user,    type: String, default: 'root'

        define_attribute :mailto,      type: String
        define_attribute :path,        type: String
        define_attribute :shell,       type: String
        define_attribute :home,        type: String
        define_attribute :environment, type: Hash, default: {}

        self.available_actions = [:create, :delete]
      end
    end
  end
end
```

**Per-key conventions**:
- `default: :create` — default action
- `default_name: true` — if user does not pass `command:`, use the resource *name* (e.g. `cron 'echo hi'` sets `command = 'echo hi'`)
- `type: Hash` / `type: Integer` / `type: [TrueClass, FalseClass]` — runtime type check
- `self.available_actions = [:create, :delete]` — declare which symbols are valid as `action:`

### The Resource Class can compute Derived Attributes

The `deploy_revision` resource overrides `process_attributes` to lazily compute derived attributes from others:

```ruby
class DeployRevision < ::MItamae::Resource::Base
  # ... define_attribute calls ...

  private

  def process_attributes
    unless @attributes.key?(:current_path)
      @attributes[:current_path] = File.join(@attributes.fetch(:deploy_to), 'current')
    end
    unless @attributes.key?(:shared_path)
      @attributes[:shared_path] = File.join(@attributes.fetch(:deploy_to), 'shared')
    end
    unless @attributes.key?(:destination)
      @attributes[:destination] = File.join(@attributes.fetch(:shared_path), 'cached-copy')
    end
    unless @attributes.key?(:depth)
      @attributes[:depth] = @attributes.fetch(:shallow_clone) ? 5 : nil
    end
    super
  end
end
```

### The Executor Class

Subclass `MItamae::ResourceExecutor::Base`. The base class provides the orchestration loop (see below). You must implement **three** methods:

```ruby
module ::MItamae
  module Plugin
    module ResourceExecutor
      class Cron < ::MItamae::ResourceExecutor::Base
        def apply                                        # REQUIRED: makes the actual change
          if desired.cron_exists
            action_create
          else
            action_delete
          end
        end

        private

        def set_desired_attributes(desired, action)      # REQUIRED
          case action
          when :create
            desired.cron_exists = true
          when :delete
            desired.cron_exists = false
          else
            raise NotImplementedError, "unhandled action: '#{action}'"
          end
        end

        def set_current_attributes(current, action)       # REQUIRED
          case action
          when :create, :delete
            @cron_empty = false
            load_current_resource(current)               # reads `crontab -l`
          else
            raise NotImplementedError, "unhandled action: '#{action}'"
          end
        end

        # Helper methods called by your three required methods:
        def load_current_resource(current)
          raw = run_command('crontab -l -u root', error: false).stdout
          # ... parse raw crontab into current.* synonyms ...
        end
      end
    end
  end
end
```

### Executor Base Class Loop (from `mitamae/mrblib/mitamae/resource_executor/base.rb`)

```ruby
def execute(specific_action = nil)
  return if skip_condition?           # not_if / only_if
  [specific_action || @resource.attributes[:action]].flatten.each do |action|
    run_action(action)
  end
  verify
  notify if updated?
end

def run_action(action)
  @desired = desired_attributes(action).freeze         # -> set_desired_attributes
  @current = current_attributes(action).freeze          # -> set_current_attributes
  pre_action                                           # hook (overridable, optional)
  show_differences                                     # logs what would change
  return if action == :nothing
  apply unless @runner.dry_run?                         # your apply ...
  updated! if different?
end
```

| Method | Override? | Purpose |
|---|---|---|
| `set_desired_attributes(desired, action)` | **Required** | Set `desired.<bool>` flags by action — describe what the world should look like |
| `set_current_attributes(current, action)` | **Required** | Inspect the system (e.g. `crontab -l`) and set `current.<bool>` flags |
| `apply` | **Required** | Compare `desired` vs `current` and act — call helper methods like `action_create`, `action_delete` |
| `pre_action` | Optional | Hook for destructive work that must happen BEFORE diff is computed/logged |
| `verify` | Optional | Run post-action assertions; raise on failure |

`desired` and `current` are dynamic OpenStruct-like objects: assigning `desired.cron_exists = true` in `set_desired_attributes` creates an accessor that `apply` can read.

### Running commands

Inside the executor, call `run_command`:
```ruby
output = run_command('crontab -l -u root', error: false)   # error: false allows non-zero exit
output.stdout
output.stderr
output.exit_status
```

Prefer pre/mitamae-core execution via `run_command`.  Use `run_command(cmd, user: 'app')` to run as another user.

### Real-world plugin example layout

`mitamae-plugin-resource-cron/mrblib/resource/cron.rb` — given above.

`mitamae-plugin-resource-cron/mrblib/resource_executor/cron.rb` — reads `crontab -l`, parses lines against three regex patterns, compares against desired state, and rewrites the crontab by piping a temp file into `crontab -u root -`. Excerpts:

```ruby
SPECIAL_TIME_VALUES = [:reboot, :yearly, :annually, :monthly, :weekly, :daily, :midnight, :hourly]
CRON_ATTRIBUTES = [:minute, :hour, :day, :month, :weekday, :time, :command,
                   :mailto, :path, :shell, :home, :environment]
CRON_PATTERN = /\A([-0-9*,\/]+)\s([-0-9*,\/]+)\s([-0-9*,\/]+)\s([-0-9*,\/]+|[a-zA-Z]{3})\s([-0-9*,\/]+|[a-zA-Z]{3})\s(.*)/
SPECIAL_PATTERN = /\A(@(reboot|yearly|annually|monthly|weekly|daily|midnight|hourly))\s(.*)/

def write_crontab(crontab)
  # write to temp file, pipe into `crontab -u root -`
end

def get_crontab_entry
  # build entry line from desired.* attrs
end
```

## Recipe Plugins

A recipe plugin exposes reusable recipes via `include_recipe`. Example: `itamae-plugin-recipe-rbenv` exposes `include_recipe 'rbenv::user'`.

### Repository Naming

- **Required prefix**: `mitamae-plugin-recipe-<name>` or `itamae-plugin-recipe-<name>` (both prefixes work — Itamae plugin reuse).

### Directory Structure

```
mitamae-plugin-recipe-<name>/
└── mrblib/
    └── mitamae/
        └── plugin/
            └── recipe/
                └── <name>/
                    ├── default.rb      # loaded for `include_recipe '<name>'`
                    └── example.rb      # loaded for `include_recipe '<name>::example'`
```

Or, for a flat single-recipe plugin:
```
mitamae-plugin-recipe-<name>/mrblib/mitamae/plugin/recipe/<name>.rb
```

### Path Convention to `include_recipe` Argument

| `include_recipe` argument | Recipe file path |
|---|---|
| `'sample'` | `mrblib/mitamae/plugin/recipe/sample/default.rb` (preferred) **or** `mrblib/mitamae/plugin/recipe/sample.rb` |
| `'sample::example'` | `mrblib/mitamae/plugin/recipe/sample/example.rb` |
| `'sample::nested::deep'` | `mrblib/mitamae/plugin/recipe/sample/nested/deep.rb` |

### Example: `itamae-plugin-recipe-rbenv`

```
mitamae-plugin-recipe-rbenv (or itamae-plugin-recipe-rbenv)/
└── mrblib/
    └── mitamae/
        └── plugin/
            └── recipe/
                └── rbenv/
                    ├── system.rb       # `include_recipe 'rbenv::system'`
                    ├── user.rb         # `include_recipe 'rbenv::user'`
                    └── default.rb      # `include_recipe 'rbenv'`
```

Use in your project's recipe:
```ruby
node.reverse_merge!(
  rbenv: {
    user: 'deploy',
    global: '3.4.8',
    versions: %w[3.4.8],
  },
)
include_recipe 'rbenv::user'
```

### Adding a Recipe Plugin as a Git Submodule

Inside the parent repo (where mitamae runs):
```sh
git submodule add https://github.com/k0kubun/itamae-plugin-recipe-rbenv plugins/itamae-plugin-recipe-rbenv
git commit -m "vendor rbenv plugin"
```

`.gitmodules` will then contain:
```ini
[submodule "plugins/itamae-plugin-recipe-rbenv"]
    path = plugins/itamae-plugin-recipe-rbenv
    url = https://github.com/k0kubun/itamae-plugin-recipe-rbenv
```

Recipients must run `git submodule update --init` after clone. A typical `bin/hocho` wrapper does this lazily:
```bash
if [[ ! -d plugins/itamae-plugin-recipe-rbenv/.git ]]; then
  git submodule init && git submodule update
fi
```

## Known Plugin Repositories

### Resource plugins

| Plugin | Adds |
|---|---|
| [mitamae-plugin-resource-cron](https://github.com/itamae-plugins/mitamae-plugin-resource-cron) | `cron` (ported from Chef) |
| [mitamae-plugin-resource-deploy_revision](https://github.com/itamae-plugins/mitamae-plugin-resource-deploy_revision) | `deploy_revision` (Chef-style deploy with cookbook rollback) |
| [mitamae-plugin-resource-deploy_directory](https://github.com/itamae-plugins/mitamae-plugin-resource-deploy_directory) | `deploy_directory` (similar) |
| [mitamae-plugin-resource-runit_service](https://github.com/itamae-plugins/mitamae-plugin-resource-runit_service) | `runit_service` |
| [itamae-plugin-resource-cask](https://github.com/k0kubun/itamae-plugin-resource-cask) | `cask` (Homebrew cask, Itamae original but mitamae-compatible) |

### Recipe plugins

| Plugin | Adds |
|---|---|
| [itamae-plugin-recipe-rbenv](https://github.com/k0kubun/itamae-plugin-recipe-rbenv) | `rbenv`, `rbenv::system`, `rbenv::user` — Ruby version management |

### Finding more

- [GitHub search: `mitamae-plugin`](https://github.com/search?q=mitamae-plugin)
- [GitHub search: `itamae-plugin mitamae`](https://github.com/search?q=itamae-plugin+mitamae)
- [itamae-plugins org](https://github.com/itamae-plugins)

## Migrating from Chef

When porting Chef cookbooks to mitamae, the key substitutions are:

| Chef | mitamae |
|---|---|
| `cookbook_file 'name' do source ... end` | Use `remote_file` (source from `files/`) or `template` (source from `templates/`) with the `source` attribute |
| `directory 'name' do recursive: true end` | `directory` is **recursive by default** — drop the `recursive: true` |
| `ruby_block 'name' do block { ... } end` | Use `local_ruby_block` (same API) |
| `shell_out!('cmd')` | Use `run_command('cmd')` (raises on non-zero unless `error: false`) |
| `Chef::Log.info '...'` | `MItamae.logger.info '...'` |
| `` Digest::SHA256.hexdigest `` | Spawn `sha256sum` via `run_command('sha256sum file').stdout.strip` |
| `bash 'name' do code '...' end` | `execute` with `command`, OR `execute 'name' do command "bash -c '...'" end`. Stock shell is `/bin/sh` — pass `--shell=/bin/bash` to mitamae to use bash for the entire recipe |
| `cron` resource | [mitamae-plugin-resource-cron](https://github.com/itamae-plugins/mitamae-plugin-resource-cron) |
| `deploy_revision` | [mitamae-plugin-resource-deploy_revision](https://github.com/itamae-plugins/mitamae-plugin-resource-deploy_revision) |
| `deploy_directory` | [mitamae-plugin-resource-deploy_directory](https://github.com/itamae-plugins/mitamae-plugin-resource-deploy_directory) |
| `runit_service` | [mitamae-plugin-resource-runit_service](https://github.com/itamae-plugins/mitamae-plugin-resource-runit_service) |

Additional notes:
- No Chef Server, no Data Bags, no Berkshelf — pass per-node config via `-j` or `-y`.
- LWRPs (lightweight resources/providers) — re-implement via `define` (mitamae recipe-level) or write a `mitamae-plugin-resource-*` for full resource/executor separation.
- Libraries that need full Ruby (PG, Net-HTTP, etc.) — **not available** in mitamae (mruby subset). If needed, shell out via `run_command` to a Ruby script invoked separately.
- `Chef::Config[:file_cache_path]` — use `Dir.tmpdir` or your own temp dir constant.

## Migrating from Itamae

Recipes are essentially drop-in compatible. The differences:

| Topic | Itamae | mitamae |
|---|---|---|
| Installer | Bundler + gem | git submodule, single binary |
| Plugin delivery | RubyGems | `./plugins/` directory (no gems) |
| `not_if`/`only_if` | String only | String OR block |
| File atomic_update | Not available | Available on file-like resources |
| `run_command` output streaming | At end | Streaming at debug log level (or `log_output: true`) |
| `http_request` 4XX/5XX | configurable | **Always raises** (v1.8.0+) |
| Full Ruby gems | Available | **No** — mruby subset only |

## Writing a Minimal Plugin from Scratch

This is a complete walkthrough for a custom `swap` resource that creates a swap file.

### Project layout

```
mitamae-plugin-resource-swap/
├── README.md
└── mrblib/
    ├── resource/
    │   └── swap.rb
    └── resource_executor/
        └── swap.rb
```

### `mrblib/resource/swap.rb`

```ruby
module ::MItamae
  module Plugin
    module Resource
      class Swap < ::MItamae::Resource::Base
        define_attribute :action, default: :create
        define_attribute :path, type: String, default_name: true
        define_attribute :size_mb, type: Integer, required: true
        define_attribute :owner, type: String, default: 'root'

        self.available_actions = [:create, :remove]
      end
    end
  end
end
```

### `mrblib/resource_executor/swap.rb`

```ruby
module ::MItamae
  module Plugin
    module ResourceExecutor
      class Swap < ::MItamae::ResourceExecutor::Base
        def apply
          if action == :create
            action_create
          else
            action_remove
          end
        end

        private

        def action_create
          run_command("dd if=/dev/zero of=#{desired.path} bs=1M count=#{desired.size_mb}")
          run_command("chmod 0600 #{desired.path}")
          run_command("mkswap #{desired.path}")
          run_command("swapon #{desired.path}")
        end

        def action_remove
          run_command("swapoff #{desired.path}")
          run_command("rm -f #{desired.path}")
        end
      end
    end
  end
end
```

### Using it

In the parent repo:
```sh
git submodule add https://github.com/you/mitamae-plugin-resource-swap plugins/mitamae-plugin-resource-swap
```

```ruby
# recipes/system.rb
swap '/swapfile' do
  size_mb 2048
end
```

## References

- [PLUGINS.md (upstream)](https://github.com/itamae-kitchen/mitamae/blob/master/PLUGINS.md)
- [ResourceExecutor::Base implementation](https://github.com/itamae-kitchen/mitamae/blob/master/mrblib/mitamae/resource_executor/base.rb)
- [mitamae-plugin-resource-cron source](https://github.com/itamae-plugins/mitamae-plugin-resource-cron) — full module by module walkthrough
- [mitamae-plugin-resource-deploy_revision source](https://github.com/itamae-plugins/mitamae-plugin-resource-deploy_revision) — advanced example with Derived attributes and embedded GitProvider
- [itamae-plugin-recipe-rbenv source](https://github.com/k0kubun/itamae-plugin-recipe-rbenv) — recipe plugin exemplar