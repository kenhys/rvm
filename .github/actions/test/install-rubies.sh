#!/usr/bin/env bash

# Usage: install-rubies.sh [--default] RUBY...
#
# Install rubies before tf runs. When a build fails, show the tail of
# make.log and stop here, so the real error is not buried under many
# failed checks in the tests.

source ~/.rvm/scripts/rvm

use_flags=(--install)
if [[ "$1" == "--default" ]]; then
  use_flags+=(--default)
  shift
fi

show_make_logs() {
  local old_dirs="$1" dir log
  # rvm makes a new log directory for each install. We compare with the
  # list taken before the install, because file times are not exact
  # enough to tell old logs from new ones.
  while IFS= read -r dir; do
    log="${rvm_path}/log/${dir}/make.log"
    [[ -f "${log}" ]] || continue
    echo "::error title=make failed::see ${log} below"
    # With make -j the first error is often far from the end of the log.
    echo "::group::grep error ${log}"
    grep -n -m 30 -E '(error|Error)[: ]' "${log}"
    echo "::endgroup::"
    echo "::group::tail -n 200 ${log}"
    tail -n 200 "${log}"
    echo "::endgroup::"
  done < <(comm -13 <(printf '%s\n' "${old_dirs}") <(list_log_dirs))
}

list_log_dirs() {
  ls -1 "${rvm_path}/log" 2>/dev/null | sort
}

for ruby in "$@"; do
  old_dirs="$(list_log_dirs)"
  echo "::group::rvm use ${ruby} ${use_flags[*]}"
  if rvm use "${ruby}" "${use_flags[@]}"; then
    echo "::endgroup::"
  else
    echo "::endgroup::"
    echo "::error::failed to install ${ruby}"
    show_make_logs "${old_dirs}"
    exit 1
  fi
done
