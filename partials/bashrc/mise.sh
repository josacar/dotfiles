type mise &>/dev/null

if [ $? -eq 0 ]; then
  eval "$(mise activate bash)"

  install_ruby_version(){
    if [ "$(uname)" = "Darwin" ]; then
      RUBY_CONFIGURE_OPTS="--with-jemalloc-dir=$(brew --prefix jemalloc) --enable-yjit" mise use ruby@$1
    else
      RUBY_CONFIGURE_OPTS="--with-jemalloc --enable-yjit" mise use ruby@$1
    fi
  }
fi
