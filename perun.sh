#!/bin/bash
set -eo pipefail

usage() {
  echo "$(basename "${0}")"
}

log() {
  local mssg="${@}"
  local perun_log_prefix=${PERUN_LOG_PREFIX:-''}

  echo "${perun_log_prefix} ${mssg}"
}

readonly PERUN_LOG_PREFIX=${PERUN_LOG_PREFIX:-'[PERUN]'}
export PERUN_LOG_PREFIX

readonly GITHUB_REPO="${GITHUB_REPO:-'git@github.com:jbossas/jboss-eap7.git'}"
readonly GITHUB_BRANCH="${GITHUB_BRANCH:-'7.2.x-proposed'}"
readonly BISECT_WORKSPACE="${BISECT_WORKSPACE:-$(mktemp -d)}"

deleteBisectWorkspac() {

  rm -rf "${BISECT_WORKSPACE}"
  rm -rf "${REPRODUCER_PATCH}"
  rm -rf "${INTEGRATION_SH_PATCH}"
}
trap deleteBisectWorkspac EXIT


#good revision, we consider current one as bad?
readonly GOOD_REVISION="${GOOD_REVISION}"
if [ -z "${GOOD_REVISION}" ]; then
  log "No good revision provided, aborting."
  exit 1
fi
readonly BAD_REVISION="${BAD_REVISION}"
if [ -z "${BAD_REVISION}" ]; then
  log "No bad revision provided, aborting."
  exit 2
fi

git clone "${GITHUB_REPO}"  --branch "${GITHUB_BRANCH}" "${BISECT_WORKSPACE}"
cd "${BISECT_WORKSPACE}"

#revisions that are known to not compile due to split of changes, separated by ','
readonly CORRUPT_REVISIONS="${CORRUPT_REVISIONS}"
#url of a patch file (a diff) containing the changes required to insert
# the reproducer into EAP existing testsuite.
readonly REPRODUCER_PATCH_URL="${REPRODUCER_PATCH_URL}"
if [ -z "${REPRODUCER_PATCH_URL}" ]; then
  log "No URL for the reproducer patch provided, aborting."
  exit 3
fi
#test to run from suite, either existing one or one that comes from $TEST_DIFF
readonly TEST_NAME="${TEST_NAME}"
if [ -z "${TEST_NAME}" ]; then
  log "No test name provided, aborting."
  exit 4
fi

set -u

readonly REPRODUCER_PATCH=${PATCH_HOME:-$(mktemp)}
curl "${REPRODUCER_PATCH_URL}" -o "${REPRODUCER_PATCH}"
if [ -e "${REPRODUCER_PATCH}" ]; then
  export REPRODUCER_PATCH
else
  log 'No reproducer patch'
fi

readonly INTEGRATION_SH_PATCH=${INTEGRATION_SH_HOME:-$(mktemp)}
curl "${INTEGRATION_SH_PATCH_URL}" -o "${INTEGRATION_SH_PATCH}"
if [ -e "${INTEGRATION_SH_PATCH}" ]; then
  export INTEGRATION_SH_PATCH
else
  log "No integration sh patch"
  return 1
fi

git bisect 'start'
git bisect 'bad' "${BAD_REVISION}"
git bisect 'good' "${GOOD_REVISION}"

git bisect run "${WORKSPACE}/run-test.sh"
