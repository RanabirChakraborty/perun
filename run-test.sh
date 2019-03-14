#!/bin/bash
set -eo pipefail

cleanPatch() {
  if [ -e "${REPRODUCER_PATCH}" ]; then
    echo '[PERUN]: Cleaning up after patch ...'
    patch -p1 -i "${REPRODUCER_PATCH}" -R
    patch -p1 -i "${INTEGRATION_SH_PATCH}" -R
  fi
}

trap cleanPatch EXIT

log() {
  local mssg="${@}"
  local perun_log_prefix=${PERUN_LOG_PREFIX:-'[PERUN]'}

  echo "${perun_log_prefix} ${mssg}"
}

set +e
which patch > /dev/null
if [ "${?}" -ne 0 ]; then
  log "This script requires 'patch' command, but command is missing. Aborting."
fi
set -e


readonly PERUN_LOG_PREFIX=${PERUN_LOG_PREFIX:-'[PERUN]'}
readonly GIT_SKIP_BISECT_ERROR_CODE=${GIT_SKIP_BISECT_ERROR_CODE:-'125'}
readonly REPRODUCER_PATCH="${REPRODUCER_PATCH}"
readonly TEST="${TEST_NAME}"
readonly HARMONIA_SCRIPT="${HARMONIA_SCRIPT:-'/opt/jboss-set-ci-scripts/harmonia-eap-build'}"
readonly CURRENT_REVISION=$(git rev-parse HEAD)

if [ ! -e "${HARMONIA_SCRIPT}" ]; then
  log "Invalid path to Harmonia script provided: ${HARMONIA_SCRIPT}. Aborting."
  exit 1
fi

if [[ $CORRUPT_REVISIONS == *"${CURRENT_REVISION}"* ]]; then
  log "Current revision \"${CURRENT_REVISION}\" is in corrupt list, skipping."
  exit "${GIT_SKIP_BISECT_ERROR_CODE}"
fi

set -u

if [ -e "${INTEGRATION_SH_PATCH}" ]; then
  log "Patching integration script...."
  patch -p1 -i "${INTEGRATION_SH_PATCH}"
else
  log "No integration.sh patch file provided, skipping"
  exit 1
fi

if [ -e "${REPRODUCER_PATCH}" ]; then
  log "Patching tests...."
  patch -p1 -i "${REPRODUCER_PATCH}"
else
  log "No tests patch file provided, skipping"
fi

# TODO if patch fails, we need to skip test and print a message that the test is not compatible with the revision skipped

if [ -z "${TEST}" ]; then
  log "No TEST provided."
  exit 1
fi

log "Building ..."

export BUILD_OPTS=${BUILD_OPTS:"-DskipTests"}
bash -x ${HARMONIA_SCRIPT}

log "Done."

log "Running testsuite ..."
export TESTSUITE_OPTS="${TESTSUITE_OPTS} -Dtest=${TEST}"
log "Start testsuite"
bash -x ${HARMONIA_SCRIPT} 'testsuite'
log "Stop testsuite"
