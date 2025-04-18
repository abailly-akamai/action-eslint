#!/bin/sh

cd "${GITHUB_WORKSPACE}/${INPUT_WORKDIR}" || exit 1

TEMP_PATH="$(mktemp -d)"
PATH="${TEMP_PATH}:$PATH"
export REVIEWDOG_GITHUB_API_TOKEN="${INPUT_GITHUB_TOKEN}"
ESLINT_FORMATTER="${GITHUB_ACTION_PATH}/eslint-formatter-rdjson/index.js"

echo '::group::🐶 Installing reviewdog ... https://github.com/reviewdog/reviewdog'
curl -sfL https://raw.githubusercontent.com/reviewdog/reviewdog/fd59714416d6d9a1c0692d872e38e7f8448df4fc/install.sh | sh -s -- -b "${TEMP_PATH}" "${REVIEWDOG_VERSION}" 2>&1
echo '::endgroup::'

npx --no-install -c 'eslint --version'
if [ $? -ne 0 ]; then
  echo '::group:: Running `npm install` to install eslint ...'
  set -e
  npm install
  set +e
  echo '::endgroup::'
fi

echo "eslint version:$(npx --no-install -c 'eslint --version')"

echo '::group:: Running eslint with reviewdog 🐶 ...'
output=$(npx --no-install -c "eslint -f="${ESLINT_FORMATTER}" ${INPUT_ESLINT_FLAGS:-'.'}" \
  | reviewdog -f=rdjson \
      -name="${INPUT_TOOL_NAME}" \
      -reporter="${INPUT_REPORTER:-github-pr-review}" \
      -filter-mode="${INPUT_FILTER_MODE}" \
      -fail-level="${INPUT_FAIL_LEVEL}" \
      -fail-on-error="${INPUT_FAIL_ON_ERROR}" \
      -level="${INPUT_LEVEL}" \
      ${INPUT_REVIEWDOG_FLAGS} 2>&1)

reviewdog_rc=$?

case "$output" in
  *"Too many results (annotations) in diff"*)
    echo "Detected GitHub annotation limits, treating as success"
    reviewdog_rc=0
    ;;
esac

echo "$output"
echo '::endgroup::'
exit $reviewdog_rc