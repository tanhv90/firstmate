#!/usr/bin/env bash
# Behavior tests for the verified droid (Factory Droid CLI) crewmate/scout adapter.
#
# The facts pinned here are the ones a droid release could silently change and
# the ones a wrong guess would make dangerous:
#   1. droid publishes no harness-identity marker of its own (FACTORY_*
#      variables are not proven to reach daemon-spawned worker panes), so
#      detection is ancestry alone on the anchored process names `droid` and
#      `.droid-wrapped` (the NixOS wrapper's truncated 15-char comm).
#   2. The anchored match must never claim unrelated commands carrying the
#      fragment (android, droidify), and a structural droid ancestor outranks a
#      retained or inherited CLAUDECODE - tests/fm-harness-precedence.test.sh
#      owns the general boundary.
#   3. The busy signature is the pinned `Press ESC to stop` status row alone;
#      the braille spinner and the free-floating `Executing...`/`Invoking
#      tools...` words must never read busy on their own, and a ghost-only tail
#      is unknown, never idle, because a long turn can scroll the marker out.
#   4. droid is a crewmate/scout adapter only: a secondmate launch is refused,
#      and nothing is armed as busy wiring because no writer could clear it.
#   5. The interactive TUI takes no --model or --reasoning-effort flag (both
#      are exec mode only), so both shared axes are record-and-omit.
#   6. The folder-trust pre-registration (bin/fm-droid-trust.sh) refuses
#      anything but a linked worktree of the spawning project, records the
#      resolved path under the trustedFolders object key, preserves every
#      unrelated store key and entry, and never duplicates an entry.
set -u

# shellcheck source=tests/lib.sh
. "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

# bin/fm-harness.sh checks verified ENV markers before ancestry. A suite run
# from inside another harness inherits those markers, which outrank the fake
# ancestry the detection cases set up. Drop the ambient markers so the asserted
# verdict does not depend on which harness launched the suite.
unset CLAUDECODE PI_CODING_AGENT FM_PI_HARNESS GROK_AGENT CURSOR_AGENT CURSOR_INVOKED_AS \
  ATLASSIAN_AGENT_TYPE ROVODEV_CLI GEMINI_CLI AGENT FM_OMP_HARNESS

# shellcheck source=/dev/null
. "$ROOT/bin/fm-control-lib.sh"
# shellcheck source=/dev/null
. "$ROOT/bin/fm-busy-lib.sh"
# shellcheck source=/dev/null
. "$ROOT/bin/fm-composer-lib.sh"

HARNESS="$ROOT/bin/fm-harness.sh"
TRUST="$ROOT/bin/fm-droid-trust.sh"
TMP_ROOT=$(fm_test_tmproot fm-droid-harness)

test_droid_ancestry_detects_the_native_command_name() {
  local fakebin out
  fakebin=$(fm_fakebin "$TMP_ROOT/anc-native")
  cat > "$fakebin/ps" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"comm="*) printf '%s\n' "${FAKE_PS_COMM:-droid}"; exit 0 ;;
  *"args="*) printf '%s\n' "${FAKE_PS_ARGS:-droid --auto high hello}"; exit 0 ;;
esac
exit 1
SH
  chmod +x "$fakebin/ps"
  out=$(PATH="$fakebin:$PATH" "$HARNESS")
  [ "$out" = droid ] \
    || fail "a natively-named droid command must be detected by ancestry, got '$out'"
  out=$(FAKE_PS_COMM=.droid-wrapped FAKE_PS_ARGS='/nix/store/x-droid-0.220.0/bin/.droid-wrapped --auto high' \
    PATH="$fakebin:$PATH" "$HARNESS")
  [ "$out" = droid ] \
    || fail "the NixOS .droid-wrapped wrapper comm must be detected by ancestry, got '$out'"
  pass "fm-harness.sh: ancestry detects the native and Nix-wrapped droid names"
}

test_droid_ancestry_rejects_unrelated_fragment_names() {
  local fakebin out
  fakebin=$(fm_fakebin "$TMP_ROOT/anc-negatives")
  cat > "$fakebin/ps" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"comm="*) printf '%s\n' "${FAKE_PS_COMM:?}"; exit 0 ;;
  *"args="*) printf '%s\n' "${FAKE_PS_ARGS:?}"; exit 0 ;;
esac
exit 1
SH
  chmod +x "$fakebin/ps"

  out=$(FAKE_PS_COMM=android FAKE_PS_ARGS='android-sdk --list' PATH="$fakebin:$PATH" "$HARNESS")
  [ "$out" != droid ] \
    || fail "an unrelated android command must not detect droid, got '$out'"

  out=$(FAKE_PS_COMM=droidify FAKE_PS_ARGS='droidify --serve' PATH="$fakebin:$PATH" "$HARNESS")
  [ "$out" != droid ] \
    || fail "an unrelated droidify command must not detect droid, got '$out'"

  out=$(FAKE_PS_COMM=bash FAKE_PS_ARGS='bash -c "echo droid --help"' PATH="$fakebin:$PATH" "$HARNESS")
  [ "$out" != droid ] \
    || fail "a later shell argument naming droid must not detect droid, got '$out'"
  pass "fm-harness.sh: ancestry rejects unrelated droid fragment names"
}

test_droid_ancestry_outranks_a_retained_claude_marker() {
  local fakebin out
  # droid does not clear an inherited CLAUDECODE (verified in the launch
  # template's env -u list being launch-side only), so a structural droid
  # ancestor must outrank the retained marker rather than being renamed away
  # from it.
  fakebin=$(fm_fakebin "$TMP_ROOT/anc-claude")
  cat > "$fakebin/ps" <<'SH'
#!/usr/bin/env bash
case "$*" in
  *"comm="*) printf '%s\n' droid; exit 0 ;;
  *"args="*) printf '%s\n' 'droid --auto high hi'; exit 0 ;;
esac
exit 1
SH
  chmod +x "$fakebin/ps"
  out=$(CLAUDECODE=1 PATH="$fakebin:$PATH" "$HARNESS")
  [ "$out" = droid ] \
    || fail "a structural droid ancestor must outrank an inherited CLAUDECODE, got '$out'"
  pass "fm-harness.sh: a structural droid ancestor outranks a retained CLAUDECODE"
}

test_droid_control_mechanics_are_the_verified_ones() {
  fm_control_harness_supported droid || fail "droid must be a supported control harness"
  [ "$(fm_control_harness_family droid)" = droid ] || fail "droid must map to its own family"
  fm_control_harness_supports_kind droid scout || fail "droid must run scouts"
  fm_control_harness_supports_kind droid ship || fail "droid must run ships"
  fm_control_harness_supports_kind droid secondmate \
    && fail "droid must refuse secondmates" || true
  [ "$(fm_control_interrupt_key droid)" = Escape ] || fail "droid must interrupt on Escape"
  [ "$(fm_control_interrupt_repeat droid)" = 1 ] || fail "droid must interrupt on a single press"
  [ -z "$(fm_control_interrupt_clear_key droid)" ] || fail "droid must need no clear key"
  [ "$(fm_control_interrupt_ack_source droid)" = none ] || fail "droid must have no ack source"
  [ "$(fm_control_exit_command droid)" = /exit ] || fail "droid must exit on /exit"
  pass "fm-control-lib: droid mechanics are Escape once, no clear key, and /exit"
}

test_droid_busy_tail_needs_the_pinned_status_row() {
  printf 'working\nPress ESC to stop\n' | fm_busy_droid_tail_busy \
    || fail "the press-esc-to-stop status row must read busy"
  printf ' ⢰ Executing...  (Press ESC to stop)\n' | fm_busy_droid_tail_busy \
    || fail "the spinner row carrying the pinned token must read busy"
  printf 'working\n  Invoking tools...\n' | fm_busy_droid_tail_busy \
    && fail "the free-floating Invoking-tools word alone must not read busy" || true
  printf 'Executing report...\ndone\n' | fm_busy_droid_tail_busy \
    && fail "echoed worker output naming Executing must not read busy" || true
  pass "fm-busy-lib: the droid busy signature is the pinned press-esc-to-stop row alone"
}

test_droid_classify_reports_unknown_when_the_marker_scrolls_out() {
  local out
  # A ghost-only tail is never idle: a long turn can scroll the busy marker
  # out of the captured tail, so its absence means "can't tell".
  out=$(printf 'reply\nTry "Implement a REST endpoint"\n' \
    | fm_busy_classify herdr 'default:w9:p1' droid droidcls1 /nonexistent-state -)
  [ "$out" = "unknown droid-regex" ] \
    || fail "a ghost-only tail must read unknown, got '$out'"
  pass "fm-busy-lib: a ghost-only droid tail is unknown, never idle"
}

test_droid_idle_placeholders_are_the_verified_ghosts() {
  local re=${FM_COMPOSER_IDLE_RE_DEFAULT:?}
  printf 'Try "Implement a REST endpoint for user data"' | grep -qiE "$re" \
    || fail "the rotating Try-quote ghost must classify empty"
  printf 'Enter to steer · Ctrl+Enter to queue' | grep -qiE "$re" \
    || fail "the enter-to-steer ghost must classify empty"
  printf 'some typed worker text' | grep -qiE "$re" \
    && fail "typed worker text must never match the idle ghost set" || true
  pass "fm-composer-lib: the droid idle ghosts are the Try-quote and enter-to-steer rows"
}

make_droid_trust_case() {  # <name> -> "<case>|<proj>|<wt>|<home>"
  local name=$1 case_dir proj wt home
  case_dir="$TMP_ROOT/trust-$name"
  proj="$case_dir/project"
  wt="$case_dir/wt"
  home="$case_dir/home"
  mkdir -p "$home"
  fm_git_worktree "$proj" "$wt" "wt-trust-$name"
  printf '%s|%s|%s|%s\n' "$case_dir" "$proj" "$wt" "$home"
}

read_droid_trust_case() {
  IFS='|' read -r CASE_DIR PROJ_DIR WT_DIR HOME_DIR <<EOF
$1
EOF
}

run_droid_trust() {  # <home> <worktree> <project>
  HOME="$1" "$TRUST" "$2" "$3" 2>&1
}

droid_trusted_paths() {  # <store>
  node -e 'const fs=require("node:fs");const j=fs.existsSync(process.argv[1])?JSON.parse(fs.readFileSync(process.argv[1],"utf8")):{};for(const p of Object.keys(j.trustedFolders||{}))console.log(p);' "$1"
}

droid_store_value() {  # <store> <key>
  node -e 'const j=JSON.parse(require("node:fs").readFileSync(process.argv[1],"utf8"));console.log(JSON.stringify(j[process.argv[2]]));' "$1" "$2"
}

assert_droid_trusted() {  # <store> <path> <msg>
  droid_trusted_paths "$1" | grep -Fqx "$2" || fail "$3"
}

test_droid_trust_registers_the_resolved_worktree_path() {
  local rec store out
  rec=$(make_droid_trust_case fresh)
  read_droid_trust_case "$rec"
  store="$HOME_DIR/.factory/settings.json"
  mkdir -p "$(dirname "$store")"
  printf '%s\n' '{"customModels":[],"trustedFolders":{"/home/someone/elsewhere":{"trustedAt":"2026-09-01T00:00:00Z"}}}' > "$store"
  out=$(run_droid_trust "$HOME_DIR" "$WT_DIR" "$PROJ_DIR") || fail "a fresh linked worktree must be trusted: $out"
  assert_droid_trusted "$store" "$WT_DIR" "the resolved worktree path was not registered"
  assert_droid_trusted "$store" "/home/someone/elsewhere" "registration dropped an existing trustedFolders entry"
  [ "$(droid_store_value "$store" customModels)" = '[]' ] \
    || fail "registration did not preserve an unrelated store key"
  out=$(run_droid_trust "$HOME_DIR" "$WT_DIR" "$PROJ_DIR") || fail "repeat registration must succeed: $out"
  [ "$(droid_trusted_paths "$store" | grep -Fcx "$WT_DIR")" -eq 1 ] \
    || fail "repeat registration duplicated the worktree entry"
  pass "fm-droid-trust.sh: registers the resolved worktree path and preserves the store"
}

test_droid_trust_creates_a_missing_store() {
  local rec store
  rec=$(make_droid_trust_case nostore)
  read_droid_trust_case "$rec"
  store="$HOME_DIR/.factory/settings.json"
  run_droid_trust "$HOME_DIR" "$WT_DIR" "$PROJ_DIR" >/dev/null \
    || fail "a missing store must be created"
  [ -f "$store" ] || fail "no settings store was created at $store"
  assert_droid_trusted "$store" "$WT_DIR" "the worktree was not registered in the created store"
  pass "fm-droid-trust.sh: creates a missing settings store"
}

test_droid_trust_refuses_out_of_scope_paths() {
  local rec out
  rec=$(make_droid_trust_case refusals)
  read_droid_trust_case "$rec"

  out=$(run_droid_trust "$HOME_DIR" "$PROJ_DIR" "$PROJ_DIR")
  [ "$?" -ne 0 ] || fail "a primary checkout must be refused"
  case "$out" in *primary\ checkout*) ;; *) fail "a primary-checkout refusal must name the reason: $out" ;; esac

  out=$(run_droid_trust "$HOME_DIR" "$CASE_DIR" "$CASE_DIR")
  [ "$?" -ne 0 ] || fail "a plain directory must be refused"

  local other
  other="$TMP_ROOT/trust-refusals/other-project"
  fm_git_worktree "$other" "$other-wt" "wt-other" 2>/dev/null || mkdir -p "$other-wt"
  out=$(run_droid_trust "$HOME_DIR" "$other-wt" "$PROJ_DIR")
  [ "$?" -ne 0 ] || fail "a worktree of an unrelated project must be refused"
  pass "fm-droid-trust.sh: refuses primary checkouts, plain dirs, and unrelated projects"
}

test_droid_nothing_is_armed_as_busy_wiring() {
  # fm_busy_sources_for_harness trusts nothing for droid: with no verified
  # turn-end hook writer, a seeded record could never be cleared.
  [ -z "$(fm_busy_sources_for_harness droid)" ] \
    || fail "droid must arm no semantic busy source"
  pass "fm-busy-lib: droid arms no semantic busy wiring"
}

test_droid_ancestry_detects_the_native_command_name
test_droid_ancestry_rejects_unrelated_fragment_names
test_droid_ancestry_outranks_a_retained_claude_marker
test_droid_control_mechanics_are_the_verified_ones
test_droid_busy_tail_needs_the_pinned_status_row
test_droid_classify_reports_unknown_when_the_marker_scrolls_out
test_droid_idle_placeholders_are_the_verified_ghosts
test_droid_trust_registers_the_resolved_worktree_path
test_droid_trust_creates_a_missing_store
test_droid_trust_refuses_out_of_scope_paths
test_droid_nothing_is_armed_as_busy_wiring
