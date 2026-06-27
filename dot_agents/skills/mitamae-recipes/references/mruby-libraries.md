# mitamae & mruby Compatibility Library

mitamae is **mruby-powered** (currently mruby 3.4.0 as of v2.0.0). The recipe DSL is an mruby superset, **not** full Ruby. Always check this list before assuming a stdlib method works.

## What mruby Gives You for Free

Standard mruby built-ins work as you would expect: `Kernel#print`, `Object#respond_to?`, `Array`, `Hash`, `String`, `Integer`, `Proc`, `Range`, `Regexp`, `Enumerator`. See [mruby API docs](http://mruby.org/docs/api/).

## Loaded mrbgems (Always Available)

These are baked into the mitamae binary, so you can use them without `require`:

| Library | Source | Provides |
|---|---|---|
| mruby-at_exit | [ksss/mruby-at_exit](https://github.com/ksss/mruby-at_exit) | `at_exit { }` hook |
| mruby-dir-glob | [gromnitsky/mruby-dir-glob](https://github.com/gromnitsky/mruby-dir-glob) | `Dir.glob`, `Dir.[]` pattern syntax |
| mruby-dir | [iij/mruby-dir](https://github.com/iij/mruby-dir) | `Dir.chdir`, `Dir.pwd`, `Dir.mkdir`, `Dir.entries`, `Dir.foreach`, `Dir.glob` |
| mruby-env | [iij/mruby-env](https://github.com/iij/mruby-env) | `ENV[]`, `ENV[]=`, `ENV.delete`, `ENV.update` |
| mruby-erb | [k0kubun/mruby-erb](https://github.com/k0kubun/mruby-erb) | `ERB.new(str).result` (used by `template` resource) |
| mruby-etc | [eagletmt/mruby-etc](https://github.com/eagletmt/mruby-etc) | `Etc.getpwnam`, `Etc.getgrnam`, `Etc.passwd`, `Etc.group` (used internally by user/group resources) |
| mruby-file-stat | [ksss/mruby-file-stat](https://github.com/ksss/mruby-file-stat) | `File::Stat` (`File.stat(path).mode`, `.uid`, etc.) |
| mruby-hashie | [k0kubun/mruby-hashie](https://github.com/k0kubun/mruby-hashie) | `Hashie::Mash`-style accessors — powers `node[:platform]` dotted access; supports `reverse_merge!` |
| mruby-json | [mattn/mruby-json](https://github.com/mattn/mruby-json) | `JSON.parse`, `JSON.generate` |
| mruby-open3 | [k0kubun/mruby-open3](https://github.com/k0kubun/mruby-open3) | `Open3.capture3`, `Open3.popen3` — use this for capturing subprocess output outside `run_command` |
| mruby-shellwords | [k0kubun/mruby-shellwords](https://github.com/k0kubun/mruby-shellwords) | `Shellwords.shellescape`, `Shellwords.shellsplit` |
| mruby-tempfile | [iij/mruby-tempfile](https://github.com/iij/mruby-tempfile) | `Tempfile.new`, `Tempfile.open` |
| mruby-uri | [zzak/mruby-uri](https://github.com/zzak/mruby-uri) | `URI.parse`, `URI.escape` (URI module interfaces subset) |
| mruby-yaml | [mrbgems/mruby-yaml](https://github.com/mrbgems/mruby-yaml) | `YAML.load`, `YAML.dump`, `YAML.load_file` (used for `-y node.yml` parsing) |

You can verify availability inside a recipe:
```ruby
local_ruby_block 'list mrbgems' do
  block { puts MRUBY_VERSION }
end
```

## Critical Differences vs. MRI Ruby

### Method coverage

| Topic | MRI Ruby | mruby (in mitamae) |
|---|---|---|
| `Enumerable#tally`, `#filter_map` | Available (Ruby 2.7+) | **Not available** |
| `String#freeze` (literals), `Symbol#to_s` literal dedup | Done by VM | Done by VM |
| `Comparable#clamp` | Ruby 2.4+ | **Not available** |
| `Hash#transform_keys` / `#transform_values` | Ruby 2.5+ | **Not available** |
| `Array#zip(...).to_h` | Compositional | Often expected |
| `String#split(limit: 3)` second arg | available | available via mruby-string |

**When in doubt**: test the method via a `local_ruby_block` dry run:
```ruby
local_ruby_block 'probe' do
  block { raise NotImplementedError unless [].respond_to?(:tally) }
  action :run
end
```

### require / load

`require` works **only for node modules that are mrbgems compiled into the binary**. You cannot `require 'net/http'` — there is no Net::HTTP. For outbound HTTP, use the `http_request` resource instead.

### Gems

`gem install` then `require` **does not work**. mruby doesn't use RubyGems. To add a library, fork the mitamae source and rebuild — out of scope for almost all users.

## Removing a Gem Dependency

If porting an Itamae recipe that uses `require 'json'`, drop the require — it's already loaded via mruby-json. The same is true for `require 'erb'`, `require 'yaml'`, `require 'open3'`, `require 'shellwords'`, `require 'tempfile'`, `require 'uri'`, `require 'etc'`, `require 'fileutils'` (mruby-file-utils ships with mruby core).

## Things That Won't Work

| Want | Won't work | Alternative |
|---|---|---|
| `require 'net/http'` | No Net::HTTP | Use `http_request` resource |
| `require 'open-uri'` | Not present | `run_command('curl -sL URL', error: false).stdout` or `http_request` |
| `require 'csv'` | Not present | Manual split, or `run_command('awk -F, ...')` |
| `require 'digest'` | No Digest module | `run_command('sha256sum file').stdout.strip.split.first` |
| `require 'pathname'` | Not present | Use `File.join`, `File.expand_path` |
| `require 'time'` parsing | Limited — see mruby-yaml docs | Use `run_command('date -d ...')` |
| `require 'fileutils'` | **Available** (core) | `FileUtils.mkdir_p(dir)` works |
| `pp` (pretty_inspect) | Not present | `require 'pp'` will fail; use `JSON.pretty_generate(node.to_h)` (or just `puts result.inspect`) |
| `Net::SSH` | Not present | Use `hocho` (separate driver) — see `references/remote-execution.md` |
| `MItamae.logger.debug` formatting (Rails-style tagged logs) | Not present | Bare `.debug` / `.info` / `.warn` / `.error` calls |

## Common Conversions From Full Ruby

### Reading a file

MRI:
```ruby
require 'json'
config = JSON.parse(File.read('config.json'))
```

mitamae:
```ruby
config = JSON.parse(File.read('config.json'))   # no require needed
```

### Capture command output

MRI:
```ruby
output = `git log --oneline`
```

mitamae (backticks may not work depending on shell):
```ruby
output = run_command('git log --oneline').stdout
# or, for finer control:
o, e, s = Open3.capture3('git', 'log', '--oneline')
```

### Compute sha256

MRI:
```ruby
require 'digest'
Digest::SHA256.file('archive.tar.gz').hexdigest
```

mitamae:
```ruby
sha256 = run_command('sha256sum archive.tar.gz', error: false).stdout.split.first
```

### Parse time

MRI:
```ruby
require 'time'
Time.parse('2025-04-28').to_s
```

mitamae:
```ruby
iso = run_command('date -u -d "2025-04-28" -Iseconds', error: false).stdout.strip
```

### Hash with indifferent access

Use mruby-hashie — it powers `node`:
```ruby
node.reverse_merge!(rbenv: { global: '3.4.8' })
node[:rbenv][:global]          # Symbol access
node['rbenv']['global']        # String access — both supported via Hashie::Mash
```

## Reference

- [`mrbgem.rake` in mitamae source](https://github.com/itamae-kitchen/mitamae/blob/master/mrbgem.rake) — declares the locked-in gemset
- [`Rakefile` in mitamae source](https://github.com/itamae-kitchen/mitamae/blob/master/Rakefile) — pins the mruby version
- [mruby API documentation](http://mruby.org/docs/api/)
- [CHANGELOG](https://github.com/itamae-kitchen/mitamae/blob/master/CHANGELOG.md) — notes when libraries were added/removed