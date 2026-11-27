#!/usr/bin/env bash
#----------------------------------------------------------------------------------
# EngineScript CI Test: debug_pause
#----------------------------------------------------------------------------------
# debug_pause must ask on the terminal even when its script's stderr goes to the error log and
# its stdout is hidden, as the install scripts run their steps. Enter continues, 'exit' stops the
# whole run and not only the script that paused, and a pause in a loop reading a file must not
# read that file. With no terminal it must not wait. The function is taken from
# enginescript-common.sh and run in a pseudo-terminal from script(1).
#
# The yes/no prompt (enginescript-prompts.sh) answered in such a step must leave nothing in the
# error log: read -p wrote its "> " there, which printed an empty "[ERRORS DETECTED]" block.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
WORK="$(mktemp -d)"
trap 'rm -rf "${WORK}"' EXIT
export WORK
FAILED=0

pass() { echo "PASS  $1"; }
fail() {
  echo "FAIL  $1"
  FAILED=1
}

sed -n '/^function debug_pause() {$/,/^}$/p' "${REPO_ROOT}/scripts/functions/shared/enginescript-common.sh" > "${WORK}/debug-pause.sh"
[[ -s "${WORK}/debug-pause.sh" ]] || {
  echo "FAIL  debug_pause was not found in enginescript-common.sh"
  exit 1
}

# The step pauses inside a script that another script started, with that script's stderr going to
# the error log and its stdout hidden. MODE=loop pauses once per line of a file the loop reads.
cat > "${WORK}/inner.sh" << 'EOF'
source "${WORK}/debug-pause.sh"
DEBUG_INSTALL="${DEBUG:-1}"
echo "inner-before" >> "${WORK}/marks"
if [[ "${MODE:-}" == "loop" ]]; then
  while IFS= read -r line; do
    debug_pause "Line ${line}"
    echo "line-${line}" >> "${WORK}/marks"
  done < "${WORK}/lines"
else
  debug_pause "Inner step"
fi
echo "inner-after" >> "${WORK}/marks"
EOF
cat > "${WORK}/outer.sh" << 'EOF'
bash "${WORK}/inner.sh" 2>> "${WORK}/errors.log" > /dev/null
echo "outer-after" >> "${WORK}/marks"
EOF
printf '%s\n' 1 2 3 > "${WORK}/lines"

# Runs outer.sh in a pseudo-terminal with the given keystrokes. The input stays open a moment so
# script(1) does not stop the run when its input ends.
run_tty() {
  local keys="$1" script="${2:-${WORK}/outer.sh}"
  : > "${WORK}/marks"
  : > "${WORK}/errors.log"
  { printf '%b' "${keys}"; sleep 2; } | timeout 30 script -qefc "bash ${script}" "${WORK}/screen" > /dev/null 2>&1 || true
}

marks() { tr '\n' ' ' < "${WORK}/marks" | sed 's/ $//'; }

check_marks() {
  local want="$1" label="$2" got
  got="$(marks)"
  if [[ "${got}" == "${want}" ]]; then
    pass "${label}"
  else
    fail "${label} (ran: ${got}; expected: ${want})"
  fi
}

# Enter continues, and the prompt shows on the terminal, not in the error log
run_tty '\n'
check_marks "inner-before inner-after outer-after" "Enter continues the paused script and its caller"
if grep -q 'Continue or exit? (Enter/exit):' "${WORK}/screen" && grep -q 'Completed step: Inner step' "${WORK}/screen"; then
  pass "the step and the prompt show on the terminal"
else
  fail "the step or the prompt is missing from the terminal"
fi
if [[ ! -s "${WORK}/errors.log" ]]; then
  pass "nothing from the pause reaches the error log"
else
  fail "the error log has: $(head -c 200 "${WORK}/errors.log")"
fi

# exit stops the paused script and the script that started it
run_tty 'exit\n'
check_marks "inner-before" "exit stops the paused script and its caller"
if grep -q 'Stopping as requested.' "${WORK}/screen"; then
  pass "exit says that it stops"
else
  fail "exit printed no message"
fi

# Other input asks again
run_tty 'maybe\n\n'
check_marks "inner-before inner-after outer-after" "other input asks again, then Enter continues"
if grep -q "Please press Enter to continue or type 'exit' to stop." "${WORK}/screen"; then
  pass "other input gets the reminder"
else
  fail "other input got no reminder"
fi

# Ctrl+D continues instead of asking forever
run_tty '\004'
check_marks "inner-before inner-after outer-after" "Ctrl+D continues"

# A pause in a loop reads the keyboard, not the file the loop reads
MODE=loop run_tty '\n\n\n'
check_marks "inner-before line-1 line-2 line-3 inner-after outer-after" "a pause in a loop leaves the loop's file alone"

# With no terminal, the step goes on without waiting
: > "${WORK}/marks"
if timeout 10 setsid -w bash "${WORK}/outer.sh" < /dev/null; then
  check_marks "inner-before inner-after outer-after" "with no terminal, it does not wait"
else
  fail "with no terminal, the run failed or waited"
fi

# With debug mode off, it does nothing
: > "${WORK}/marks"
# shellcheck disable=SC2016  # ${WORK} is for the inner shell
out="$(DEBUG=0 timeout 10 bash -c 'source "${WORK}/debug-pause.sh"; DEBUG_INSTALL=0; debug_pause "Off"' < /dev/null 2>&1)"
if [[ -z "${out}" ]]; then
  pass "with debug mode off, it prints nothing and does not wait"
else
  fail "with debug mode off, it printed: ${out}"
fi

# The yes/no prompt in a step whose stderr goes to the error log. As amazon-s3-install.sh asks it,
# in a subshell, so "exit" skips the question instead of ending the script.
export PROMPTS="${REPO_ROOT}/scripts/functions/shared/enginescript-prompts.sh"
cat > "${WORK}/prompt-inner.sh" << 'EOF'
source "${PROMPTS}"
if ( prompt_yes_no "Ready to configure?" "y" 20 ); then
  echo "answer-yes" >> "${WORK}/marks"
else
  echo "answer-skipped" >> "${WORK}/marks"
fi
echo "inner-after" >> "${WORK}/marks"
EOF
echo "bash \"\${WORK}/prompt-inner.sh\" 2>> \"\${WORK}/errors.log\"" > "${WORK}/prompt-outer.sh"

run_tty 'y\n' "${WORK}/prompt-outer.sh"
check_marks "answer-yes inner-after" "the yes/no prompt takes the answer"
if grep -q 'Ready to configure? \[Y/n/exit\]' "${WORK}/screen" && grep -q '^> ' "${WORK}/screen"; then
  pass "the question and its \"> \" show on the terminal"
else
  fail "the question or its \"> \" is missing from the terminal"
fi
if [[ ! -s "${WORK}/errors.log" ]]; then
  pass "an answered yes/no prompt leaves nothing in the error log"
else
  fail "the error log has: $(head -c 200 "${WORK}/errors.log")"
fi

run_tty 'exit\n' "${WORK}/prompt-outer.sh"
check_marks "answer-skipped inner-after" "exit in the subshell skips the question and the script carries on"
if [[ ! -s "${WORK}/errors.log" ]]; then
  pass "exit leaves nothing in the error log"
else
  fail "after exit, the error log has: $(head -c 200 "${WORK}/errors.log")"
fi

# Without a terminal (answers from a pipe), no "> " is printed, as with read -p
# shellcheck disable=SC2016  # ${PROMPTS} is for the inner shell
out="$(echo y | timeout 10 bash -c 'source "${PROMPTS}"; prompt_yes_no "Piped?" "n" 5 && echo yes' 2>&1)"
if [[ "${out}" == *yes* && "${out}" != *"> "* ]]; then
  pass "with answers from a pipe, it reads them and prints no \"> \""
else
  fail "with answers from a pipe, it printed: ${out}"
fi

exit "${FAILED}"
