test -f /opt/homebrew/etc/bash_completion.d/asdf && . /opt/homebrew/etc/bash_completion.d/asdf

type asdf &>/dev/null

if [ $? -eq 0 ]; then
  export ASDF_DATA_DIR=$HOME/.asdf
  export PATH=$ASDF_DATA_DIR/shims:$PATH

  install_ruby_version(){
    jemalloc-config --version || brew install jemalloc
    RUBY_CONFIGURE_OPTS="--with-jemalloc-dir=$(brew --prefix jemalloc) --enable-yjit" asdf install ruby $1
  }
fi

