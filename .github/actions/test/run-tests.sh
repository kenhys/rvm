#!/usr/bin/env bash

# Usage: run-tests.sh TEST_FILE...
#
# Run tf once per file instead of once for all files. tf only prints the
# total count at the end, so this is the easy way to know which files
# failed without changing tf itself.

set -o pipefail

source ~/.rvm/scripts/rvm

strip_colors() {
  # tf adds colors with tput, but the job summary can not show them.
  sed -E $'s/(\x1b|\\^\\[)(\\[[0-9;]*m|\\(B)//g'
}

failed=()
output="$(mktemp)"

for test_file in "$@"; do
  echo "::group::${test_file}"
  if tf --text "${test_file}" | tee "${output}"; then
    echo "::endgroup::"
  else
    echo "::endgroup::"
    echo "::error file=${test_file}::tf reported failures in ${test_file}"
    failed+=("${test_file}")
    if [[ -n "${GITHUB_STEP_SUMMARY:-}" ]]; then
      {
        echo "### ${test_file}"
        echo '```'
        strip_colors < "${output}" | grep -E '^(\$ |# failed:)' | grep -B1 '^# failed:' | head -n 50
        echo '```'
      } >> "${GITHUB_STEP_SUMMARY}"
    fi
  fi
done

rm -f "${output}"

if (( ${#failed[@]} > 0 )); then
  echo "Failed test files (${#failed[@]} of $#):"
  printf '  %s\n' "${failed[@]}"
  exit 1
fi
