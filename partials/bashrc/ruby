alias rc='rails console'
alias rs='rails server'
alias ber=rspec
alias berd='RSPEC_FORMAT=doc ber'

function rspec-branch {
  rspec $(
    git diff $(git merge-base origin/HEAD HEAD).. --name-only |
    sed 's#^app/\(.*\)\.rb$#spec/\1_spec.rb#' |
    grep '_spec\.rb$' |
    sort -u |
    xargs find 2> /dev/null
  )
}

function rspec-work {
  rspec $(
    git status --porcelain -z --untracked-files=all | tr '\0' '\n' | cut -c 4- |
    sed 's#^app/\(.*\)\.rb$#spec/\1_spec.rb#' |
    grep '_spec\.rb$' |
    sort -u |
    xargs find 2> /dev/null
  )
}

# fresh: shell/aliases/ruby.sh

alias b='bundle'
alias bo='bundle open'
alias be='bundle exec'
alias ber='bundle exec rspec'
alias beh='BUNDLE_GEMFILE=$HOME/Gemfile bundle exec'

function rake
{
  if [ -f Gemfile ]; then
    bundle exec rake "$@"
  else
    command rake "$@"
  fi
}

function _bundle_spec_names() {
ruby <<-RUBY
  NAME_VERSION = '(?! )(.*?)(?: \(([^-]*)(?:-(.*))?\))?'
  File.open 'Gemfile.lock' do |io|
    in_specs = false
    io.lines.each do |line|
      line.chomp!
      case
      when in_specs && line == ''
        in_specs = false
      when line =~ /^ +specs:\$/
        in_specs = true
      when in_specs && line =~ %r{^ +#{NAME_VERSION}\$}
        puts \$1
      end
    end
  end
RUBY
}

function _bundle_open() {
  local curw
  COMPREPLY=()
  curw=${COMP_WORDS[COMP_CWORD]}
  COMPREPLY=($(compgen -W '$(_bundle_spec_names)' -- $curw));
  return 0
}
if type complete > /dev/null 2>&1; then
  complete -F _bundle_open bo
fi

