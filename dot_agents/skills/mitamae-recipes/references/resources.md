# mitamae Resources — Complete Reference

All 15 built-in resources. mitamae's DSL is Itamae-compatible; this reference is derived from the [Itamae wiki](https://github.com/itamae-kitchen/itamae/wiki) plus mitamae-specific extensions noted inline.

## Common Attributes (Every Resource)

| Attribute | Type | Notes |
|---|---|---|
| `action` | Symbol or Array | Multiple actions via `[:enable, :start]`. Default differs per resource (see below). |
| `user` | String | Execute commands as this user. Propagates to shell commands mitamae runs for this resource. |
| `cwd` | String | Working directory for commands invoked by this resource. |
| `only_if` | String **or** Block | Skip resource if command exits non-zero. mitamae extension: also accepts a `do ... end` block. |
| `not_if` | String **or** Block | Skip resource if command exits zero. mitamae extension: also accepts a `do ... end` block. |
| `notifies` | Triple | `notifies :action, "resource_type[resource_name]", :delayed` (or `:immediately`) — fire this action on another resource when this one changes. |
| `subscribes` | Triple | Inverse of `notifies` — react to another resource's changes. |

Block form for guards (mitamae-only):
```ruby
execute 'migrate db' do
  command 'bundle exec rails db:migrate'
  not_if { Dir.empty?('db/migrate') }    # block returns truthy/falsy; not_if skips on truthy
  only_if { File.exist?('/opt/app/config/database.yml') }
end
```
The block's **return value** (truthy/falsy) is the test; for `not_if` truthy means *skip*.

---

## 1. `directory`

Creates (or deletes) a directory tree with optional owner/group/mode.

**Actions**: `:create` (default), `:delete`, `:nothing`

| Attribute | Default | Notes |
|---|---|---|
| `path` | resource name | Target path |
| `mode` | unset | e.g. `'0755'` |
| `owner` | unset | Username |
| `group` | unset | Group name |
| `user` (common) | unset | Run mkdir/chmod as this user |

**Recursive by default.** Unlike Chef, mitamae creates parent directories automatically — `recursive: true` is implicit.

```ruby
directory "#{ENV['HOME']}/.config/nvim" do
  owner node[:user]
  mode '0755'
end
```

---

## 2. `execute`

Runs an arbitrary shell command. Idempotency must be provided by you via `not_if`/`only_if` — `execute` is never idempotent on its own.

**Actions**: `:run` (default), `:nothing`

| Attribute | Default | Notes |
|---|---|---|
| `command` | resource name | String, or Array (v1.3.3+) — Array skips shell escaping |

```ruby
execute 'create empty file' do
  command 'touch /tmp/marker'
  not_if 'test -e /tmp/marker'
end

execute 'apt-get update' do
  command ['apt-get', 'update']     # Array form — no shell interpolation
  not_if 'test -f /var/cache/apt/updated.marker'
end
```

Pass `cwd:` / `user:` (common attributes) to run in a specific context.

---

## 3. `file`

Manages a file's content, mode, owner. `:edit` action (mitamae v0.6.2+) takes a block to transform existing content.

**Actions**: `:create` (default), `:delete`, `:edit`, `:nothing`

| Attribute | Default | Notes |
|---|---|---|
| `path` | resource name | Target path |
| `content` | unset | The full new content (for `:create`) |
| `mode` | unset | e.g. `'0644'` |
| `owner` | unset | |
| `group` | unset | |
| `block` | unset (Proc) | For `:edit` — receives current content, return mutated content |
| `sensitive` | unset | Hide content from logs |
| `atomic_update` | unset (mitamae) | Write to temp file + rename for safe atomic writes |

`:edit` example:
```ruby
file '/etc/default/locale' do
  action :edit
  block do |content|
    content.gsub!(/^LANG=.*$/, 'LANG=en_US.UTF-8')
  end
end
```

---

## 4. `gem_package`

Install/uninstall/upgrade Ruby gems. Use only when you actually need `gem install` (e.g. installing into a non-bundler environment).

**Actions**: `:install` (default), `:uninstall` (v0.4.1+), `:upgrade`, `:nothing`

| Attribute | Default | Notes |
|---|---|---|
| `package_name` | resource name | |
| `gem_binary` | `'gem'` | String or Array — path to gem executable |
| `version` | unset | Pinned version |
| `options` | `[]` | String or Array of extra args |
| `source` | unset | Local `.gem` path or URL |

---

## 5. `git`

Clones/syncs a git repository into a destination dir. Implements `git fetch` + `git reset --hard` on subsequent runs.

**Actions**: `:sync` (default), `:nothing`

| Attribute | Default | Notes |
|---|---|---|
| `destination` | resource name | Clone directory |
| `repository` | **required** | URL |
| `revision` | unset | Branch, tag, or commit SHA |
| `recursive` | unset | Init and update submodules |
| `depth` | unset (mitamae v1.4.3+) | Shallow clone depth |

```ruby
git "#{node[:user]}/chkbuild" do
  repository 'https://github.com/ruby/chkbuild'
  user node[:user]
  not_if "test -e #{node[:user]}/chkbuild"
end
```

---

## 6. `group`

**Actions**: `:create` (default), `:nothing`

| Attribute | Default | Notes |
|---|---|---|
| `groupname` | resource name | |
| `gid` | unset | Integer |

```ruby
group 'app' do
  gid 5000
end
```

---

## 7. `http_request`

Issues an HTTP request. **Always raises on 4XX/5XX** responses (mitamae v1.8.0+).

**Actions**: `:get` (default), `:post`, `:put`, `:delete`, `:options`, `:nothing`

| Attribute | Default | Notes |
|---|---|---|
| `url` | **required** | Full URL |
| `message` | `''` | Request body (POST/PUT) |
| `headers` | `{}` | Hash of headers |
| `redirect_limit` | `10` | Max redirects |
| `content` | unset | Alternate way to set body (v1.7.6+) |

---

## 8. `link`

Creates a symlink. `force: true` overwrites an existing file/symlink at the link path.

**Actions**: `:create` (default), `:nothing`

| Attribute | Default | Notes |
|---|---|---|
| `link` | resource name | Destination symlink path |
| `to` | **required** | Source (target of the symlink) |
| `force` | unset | Replace existing file/dir at link path |

```ruby
link "#{ENV['HOME']}/.gitconfig" do
  to File.expand_path('../../config/.gitconfig', __FILE__)
  user node[:user]
  force true
end
```

---

## 9. `local_ruby_block`

Runs a block of Ruby code inside the recipe. Unlike `execute`, the block **is not idempotent** — it runs every time unless guarded.

**Actions**: `:run` (default), `:nothing`

| Attribute | Default | Notes |
|---|---|---|
| `block` | **required (Proc)** | Code to run |

Since v1.13.0, the block runs under `cwd` if the resource's `cwd` attribute is set.

```ruby
local_ruby_block 'configure user' do
  block do
    run_command('usermod -aG docker chkbuild')
  end
  only_if 'id chkbuild'
end
```

---

## 10. `package`

Installs or removes a system package via the native package manager (dpkg, rpm, homebrew, pkg, ...). Detection is automatic via Specinfra.

**Actions**: `:install` (default), `:remove`, `:nothing`

| Attribute | Default | Notes |
|---|---|---|
| `name` | resource name | |
| `version` | unset | Pinned version |
| `options` | unset | Extra args (e.g. `'--no-recommends'`) |

```ruby
package 'nginx' do
  version '1.18.0'
end
```

---

## 11. `remote_directory`

Recursively copies a directory tree from the recipe's `files/` directory into the target path. `files/` discovery is relative to the recipe file.

**Actions**: `:create` (default), `:delete`, `:nothing`

| Attribute | Default | Notes |
|---|---|---|
| `path` | resource name | Destination directory |
| `source` | **required** | Subdirectory under the recipe's `files/` |
| `mode` | unset | Applied recursively by default |
| `owner` | unset | |
| `group` | unset | |

---

## 12. `remote_file`

Copies a single file from the recipe's `files/` directory into a target path. Default `source :auto` looks for a file named after the recipe + resource.

**Actions**: `:create` (default), `:delete`, `:edit`, `:nothing`

| Attribute | Default | Notes |
|---|---|---|
| `path` | resource name | Target path |
| `source` | `:auto` | String filename (looked up in recipe's `files/`) or `:auto` |
| `content` | unset | Inline content (overrides `source`) |
| `mode` | unset | |
| `owner` | unset | |
| `group` | unset | |
| `block` | unset (Proc) | Transform content before write |
| `atomic_update` | unset (mitamae) | Atomic write via rename |
| `sensitive` | unset | Hide content from logs |

```ruby
remote_file '/etc/motd' do
  source 'motd'
  mode '0644'
end
```

---

## 13. `service`

Manages a system service. Unlike most resources, the default action is `:nothing` — you must specify actions explicitly.

**Actions**: `:nothing` (default), `:start`, `:stop`, `:reload`, `:restart`, `:enable`, `:disable`

| Attribute | Default | Notes |
|---|---|---|
| `name` | resource name | Service name |
| `provider` | unset | Override service subsystem (auto-detected by Specinfra normally) |

```ruby
service 'nginx' do
  action [:enable, :start]
end

service 'cron' do
  action [:enable, :start]
  subscribes :restart, 'package[cron]'
end
```

---

## 14. `template`

Renders an ERB template. Available ERB is [k0kubun/mruby-erb](https://github.com/k0kubun/mruby-erb). Template files live in `templates/` alongside the recipe (mirror of `remote_file`).

**Actions**: `:create` (default), `:delete`, `:edit`, `:nothing`

| Attribute | Default | Notes |
|---|---|---|
| `path` | resource name | Destination path |
| `source` | `:auto` | ERB file basename under `templates/` |
| `content` | unset (mitamae v1.7.6+) | Inline ERB content string |
| `variables` | `{}` | Hash accessible inside template via `@varname` |
| `mode` | unset | |
| `owner` | unset | |
| `group` | unset | |
| `block` | unset (Proc) | Transform rendered content |
| `atomic_update` | unset (mitamae) | Atomic write via rename |
| `sensitive` | unset | Hide content from logs |

`templates/app.conf.erb`:
```erb
server {
  listen <%= @port %>;
  server_name <%= @hostname %>;
}
```

`recipes/web.rb`:
```ruby
template '/etc/nginx/conf.d/app.conf' do
  variables(port: 8080, hostname: node[:hostname])
  mode '0644'
end
```

---

## 15. `user`

Creates a system user.

**Actions**: `:create` (default), `:nothing`

| Attribute | Default | Notes |
|---|---|---|
| `username` | resource name | |
| `uid` | unset | Integer |
| `gid` | unset | Integer or String group name |
| `home` | unset | Home directory path |
| `shell` | unset | Shell path |
| `password` | unset | Encrypted password string |
| `system_user` | unset | Boolean — create as system user |
| `create_home` | unset | Boolean — create home directory |

Platform-aware shell selection:
```ruby
user 'chkbuild' do
  case node[:platform]
  when 'debian', 'ubuntu'
    shell '/bin/bash'
  end
end
```

---

## Actions in array (multiple actions in one block)

```ruby
service 'nginx' do
  action [:enable, :start]   # enable then start
end
```

Actions always execute **in array order**; Chef's array-run order (reversed before v11.10.4) does not apply to mitamae.

## Notifications: why `not_if` BEFORE `notifies`

`notifies` is skipped if the guarded resource was itself skipped (i.e. `not_if`/`only_if` shielded it). So this works safely:
```ruby
execute 'reload systemd' do
  command 'systemctl daemon-reload'
  action :nothing
  subscribes :run, 'template[/etc/systemd/system/app.service]'
end
```