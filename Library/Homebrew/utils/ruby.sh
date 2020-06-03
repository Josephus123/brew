test_ruby () {
  if [[ ! -x $1 ]]
  then
    return 1
  fi

  local ruby_status
  ruby_status=$("$1" --enable-frozen-string-literal --disable=gems,did_you_mean,rubyopt -rrubygems -e \
    "puts Gem::Version.new(RUBY_VERSION.to_s.dup).to_s.split('.').first(2) == \
          Gem::Version.new('$required_ruby_version').to_s.split('.').first(2)" 2>/dev/null)

  test "$ruby_status" = true
}

setup-ruby-path() {
  local vendor_dir
  local vendor_ruby_path
  local vendor_ruby_latest_version
  local vendor_ruby_current_version
  local usable_ruby_version
  # When bumping check if HOMEBREW_MACOS_SYSTEM_RUBY_NEW_ENOUGH (in brew.sh)
  # also needs to be changed.
  local required_ruby_version="2.6"
  local ruby_exec
  local advice="
If there's no Homebrew Portable Ruby available for your processor:
- install Ruby $required_ruby_version with your system package manager (or rbenv/ruby-build)
- make it first in your PATH
- try again
"

  vendor_dir="$HOMEBREW_LIBRARY/Homebrew/vendor"
  vendor_ruby_path="$vendor_dir/portable-ruby/current/bin/ruby"
  vendor_ruby_latest_version=$(<"$vendor_dir/portable-ruby-version")
  vendor_ruby_current_version=$(readlink "$vendor_dir/portable-ruby/current")

  unset HOMEBREW_RUBY_PATH

  if [[ "$HOMEBREW_COMMAND" == "vendor-install" ]]
  then
    return 0
  fi

  if [[ -x "$vendor_ruby_path" ]]
  then
    HOMEBREW_RUBY_PATH="$vendor_ruby_path"
    if [[ $vendor_ruby_current_version != $vendor_ruby_latest_version ]]
    then
      if ! brew vendor-install ruby
      then
        if [[ -n "$HOMEBREW_MACOS" ]]
        then
          odie "Failed to upgrade Homebrew Portable Ruby!"
        else
          odie "Failed to upgrade Homebrew Portable Ruby!$advice"
        fi
      fi
    fi
  else
    if [[ -n "$HOMEBREW_MACOS" ]]
    then
      HOMEBREW_RUBY_PATH="/System/Library/Frameworks/Ruby.framework/Versions/Current/usr/bin/ruby"
    else
      IFS=$'\n' # Do word splitting on new lines only
      for ruby_exec in $(which -a ruby) $(PATH=$HOMEBREW_PATH which -a ruby)
      do
        if [[ $(test_ruby "$ruby_exec") == "true" ]]; then
          HOMEBREW_RUBY_PATH=$ruby_exec
          break
        fi
      done
      IFS=$' \t\n' # Restore IFS to its default value
      [[ -z $HOMEBREW_RUBY_PATH ]] && onoe "Failed to find usable Ruby $required_ruby_version!"
    fi

    if [[ -n "$HOMEBREW_MACOS_SYSTEM_RUBY_NEW_ENOUGH" ]]
    then
      usable_ruby_version="true"
    elif [[ -n "$HOMEBREW_RUBY_PATH" && -z "$HOMEBREW_FORCE_VENDOR_RUBY" ]]
    then
      usable_ruby_version=$(test_ruby "$HOMEBREW_RUBY_PATH")
    fi

    if [[ -z "$HOMEBREW_RUBY_PATH" || -n "$HOMEBREW_FORCE_VENDOR_RUBY" || "$usable_ruby_version" != "true" ]]
    then
      brew vendor-install ruby
      if [[ ! -x "$vendor_ruby_path" ]]
      then
        if [[ -n "$HOMEBREW_MACOS" ]]
        then
          odie "Failed to install Homebrew Portable Ruby (and your system version is too old)!"
        else
          odie "Failed to install Homebrew Portable Ruby and cannot find another Ruby $required_ruby_version!$advice"
        fi
      fi
      HOMEBREW_RUBY_PATH="$vendor_ruby_path"
    fi
  fi

  export HOMEBREW_RUBY_PATH
}
