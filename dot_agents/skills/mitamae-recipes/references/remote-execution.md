# mitamae Remote Execution

mitamae has **no built-in SSH transport**. It runs recipes on the local machine only — `mitamae local` is the only execution subcommand. For remote hosts, you orchestrate mitamae externally. This reference covers the three production-grade patterns.

## Pattern 1: hocho (sorah/hocho) — Recommended

[hocho](https://github.com/sorah/hocho) is a Ruby gem (runs on your workstation) that orchestrates mitamae (or Itamae) against many hosts via SSH. It's used in production by [ruby/ruby-infra-recipe](https://github.com/ruby/ruby-infra-recipe) to provision ~27 heterogeneous CI hosts.

### Why hocho

- **One SSH connection per host per apply** — not one per resource, because mitamae is the single process running on the target.
- **Bootstrap aware** — ships a `mitamae_prepare_script` hook that auto-detects OS+arch and installs the mitamae binary before recipe execution.
- **Host inventory** — `hosts.yml` lists hosts, properties, run_lists. Out-of-band inventory is YAML.
- **Idempotent re-runs** — converges state across the fleet.

### Install hocho

On your workstation (not the targets):
```sh
gem install hocho
# or via Gemfile:
# gem 'hocho', '>= 0.3.7'
```

### Minimal host inventory (`hosts.yml`)

```yaml
host1.example.com:
  properties:
    nopasswd_sudo: true
    compress: false
    run_list:
      - recipes/default.rb

another.example.com:
  properties:
    nopasswd_sudo: true
    run_list:
      - recipes/default.rb
```

### Minimal hocho config (`hocho.yml`)

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
  os=$(uname -s | tr 'A-Z' 'a-z')
  arch_raw=$(uname -m)
  case "$arch_raw" in
    x86_64|amd64) arch=x86_64 ;;
    arm64|aarch64) arch=aarch64 ;;
    ppc64le) arch=ppc64le ;;
    s390x) arch=s390x ;;
  esac

  case "$os" in
    linux)  mitamae_bin="mitamae-${arch}-linux" ;;
    darwin) mitamae_bin="mitamae-${arch}-darwin" ;;
    *) echo "unsupported os: $os"; exit 1 ;;
  esac

  # Find latest release tag
  tag=$(git ls-remote --refs --tags --sort='version:refname' \
        https://github.com/itamae-kitchen/mitamae 'v*' \
        | tail -n1 | sed -E 's#.*/v(.*)$#\1#')

  url="https://github.com/itamae-kitchen/mitamae/releases/download/v${tag}/${mitamae_bin}.tar.gz"
  curl -fsSLo /tmp/mitamae.tar.gz "$url"
  tar -xzf /tmp/mitamae.tar.gz -C /tmp
  install -m 0755 "/tmp/${mitamae_bin}" /usr/local/bin/mitamae
  /usr/local/bin/mitamae version
```

### Project layout

```
my-provisioning/
├── bin/hocho                        # auto-inits plugins, runs `bundle exec hocho`
├── bin/hosts                        # prints hostnames parsed from hosts.yml
├── plugins/
│   └── itamae-plugin-recipe-rbenv/  # git submodule
├── recipes/
│   ├── default.rb
│   ├── setup-users.rb
│   └── keys/
├── hocho.yml                        # driver + bootstrap
├── hosts.yml                        # host inventory
├── Gemfile                          # hocho + ssh gems
├── .ruby-version                    # Ruby version for the workstation
└── .gitmodules                      # declares plugin submodules
```

### Invoking hocho

```sh
# Apply all hosts in hosts.yml
bundle exec hocho apply all

# Dry-run
bundle exec hocho apply all -- mitamae_options='-n'

# Apply one host
bundle exec hocho apply host1.example.com

# Bootstrap only (run mitamae_prepare_script, don't run recipes)
bundle exec hocho prepare host1.example.com
```

### Bootstrap auto-init submodules

```sh
#!/bin/bash
# bin/hocho
set -e
if [[ ! -d plugins/itamae-plugin-recipe-rbenv/.git ]]; then
  git submodule init && git submodule update
fi
exec bundle exec hocho "$@"
```

### Per-host property overrides

`hosts.yml` properties are merged into `node` attributes when hocho generates the node JSON for each host's mitamae invocation:

```yaml
host1.example.com:
  properties:
    run_list:
      - recipes/default.rb
    nopasswd_sudo: true
    custom_attr: hello
```

Inside the recipe, `node['custom_attr']` is accessible.

## Pattern 2: rsync + ssh (DIY)

For one-off or small-fleet provisioning without hocho.

```sh
# Sync Recipes + binary to target
rsync -avz --exclude 'bin/mitamae-*' \
  ./ user@host:/tmp/recipes/

# Install mitamae binary on target
scp ./bin/mitamae-1.14.1 user@host:/tmp/recipes/bin/
ssh user@host 'ln -sf bin/mitamae-1.14.1 /tmp/recipes/bin/mitamae'

# Apply remotely
ssh user@host 'cd /tmp/recipes && sudo -E ./bin/mitamae local recipes/default.rb -j node.json'
```

Wrap this in a shell loop to multiply across a host list. This is essentially what hocho automates with inventory tracking.

## Pattern 3: Deployment Agent + Object Storage

For large fleets, install a small agent on each host that polls for new mitamae binaries + recipes from an object store (S3, GCS) and runs `mitamae local` locally. AWS [CodeDeploy](https://aws.amazon.com/codedeploy/) is the canonical implementation.

### Sketch

1. CI pipeline builds mitamae binary, bundle recipes + `node.json` into a tarball, upload to S3.
2. AWS CodeDeploy deploys a new revision to all EC2 hosts (or CodeDeploy agent polls S3).
3. The `install.sh` in the revision extracts and runs `./mitamae local recipes/default.rb -j node.json`.

This decouples the orchestrator from long-lived SSH connections — better for security groups and large fleets.

## Choosing a Pattern

| Pattern | When to use | Pros | Cons |
|---|---|---|---|
| **hocho** | Up to dozens of hosts, need fleet-visible inventory, heterogeneous OS/arch | Idempotent, fast (1 SSH/host), self-bootstrapping mitamae | Requires Ruby on your workstation |
| **rsync + ssh** | One-off host setup or small fleet, you want full control | No tools beyond openssh | Manual, no inventory tracking, no error aggregation |
| **CodeDeploy / agent** | Large fleet (>50 hosts), fleet in autoscaling groups, security posture forbids inbound SSH | Scalable, no SSH required; integrates with IAM/SG | Setup overhead; needs CI pipeline to ship new recipes |

## Hocho vs. Chef/Ansible Tower Bypass

If you're coming from Chef Server or Ansible Tower/Lintanis, hocho is the closest equivalent: it provides a fleet inventory, an apply runner, and a bootstrap script — without a permanent server process. The big difference is **there is no Chef Server state**: your recipes and `hosts.yml` are the source of truth and live in git.

## SSH Authentication

For EC2 hosts, hocho and the rsync+ssh pattern both speak standard SSH. To use EC2 SSH keys:
```sh
ssh -i ~/.ssh/my-key.pem user@host ...
```
For EDDSA keys you may need the `bcrypt_pbkdf` and `ed25519` gems (as ruby-infra-recipe does in its Gemfile):
```ruby
# Gemfile
gem 'bcrypt_pbkdf'
gem 'ed25519'
```
Net::SSH (used by hocho) supports these via the gem additions.

## Reference Implementation

[ruby/ruby-infra-recipe](https://github.com/ruby/ruby-infra-recipe) is the most complete open-source hocho+mitamae deployment. Sections worth re-reading:
- `hosts.yml` — heterogeneous fleet with uniform run_list
- `hocho.yml` `mitamae_prepare_script` — bespoke multi-arch `/usr/local/bin/mitamae` bootstrap
- `bin/hocho` — submodule auto-init wrapper
- `recipes/default.rb` — single entry point dispatching on `node[:platform]`