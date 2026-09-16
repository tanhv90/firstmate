#!/usr/bin/env bash
# Pre-register Factory Droid's folder trust for the isolated task worktree a
# ship/scout spawn is about to launch a droid crewmate into, so the worker
# reaches its brief in the worktree instead of parking on the folder-trust
# dialog.
#
# Usage: fm-droid-trust.sh <worktree> <project>
#   <worktree>  the isolated task worktree this spawn launches into
#   <project>   the primary checkout that worktree belongs to
# Prints one line naming what it registered; refuses loudly on anything else.
#
# WHY THIS EXISTS. droid 0.220.0 gates a folder it has never seen behind
# "Trust this folder?" (Enter confirms the preselected safe default
# "1. Trust this folder"; Esc exits without trusting), and no launch flag
# suppresses it (`droid --help` lists none). Answering writes a
# `trustedFolders` object entry into ${HOME}/.factory/settings.json, keyed by
# the folder path with a `trustedAt` timestamp (verified live: accepting the
# dialog for a fresh scratch directory produced exactly that entry). This
# script writes the same shape ahead of launch, so the worker never sees the
# dialog; the post-launch gate in bin/fm-spawn.sh answers it with a single
# Enter as the backstop if one renders anyway.
#
# THE SCOPE TEST IS THE SAFETY PROPERTY and mirrors bin/fm-claude-trust.sh and
# bin/fm-agy-trust.sh: <worktree> must be a LINKED git worktree - its own git
# dir, sharing <project>'s common dir - whose top level is exactly the
# resolved argument. A primary checkout, a worktree of an unrelated repo, a
# subdirectory of a worktree, a plain directory, and a home directory are each
# refused with a non-zero exit, never a warning and never a silent skip. Only
# the launching user's own store is written, it must be a regular file this
# uid owns, every unrelated key and entry is preserved, and the replacement is
# atomic. settings.json carries the operator's other droid settings, so a
# lost update would be a real clobber, not an inconvenience.
set -u
unset CDPATH \
  GIT_DIR GIT_WORK_TREE GIT_COMMON_DIR GIT_OBJECT_DIRECTORY GIT_INDEX_FILE \
  GIT_ALTERNATE_OBJECT_DIRECTORIES GIT_CEILING_DIRECTORIES GIT_NAMESPACE \
  GIT_DISCOVERY_ACROSS_FILESYSTEM GIT_CONFIG GIT_CONFIG_GLOBAL \
  GIT_CONFIG_SYSTEM GIT_CONFIG_NOSYSTEM GIT_CONFIG_COUNT

[ "$#" -eq 2 ] || { echo "usage: fm-droid-trust.sh <worktree> <project>" >&2; exit 2; }
WT_ARG=$1
PROJ_ARG=$2

refuse() { echo "error: refusing to pre-register droid trust: $1" >&2; exit 1; }

real_dir() { (cd -P -- "$1" 2>/dev/null && pwd -P); }
real_file() { node -e 'process.stdout.write(require("node:fs").realpathSync(process.argv[1]))' "$1" 2>/dev/null; }

common_dir_of() {
  local dir=$1 common
  common=$(git -C "$dir" rev-parse --git-common-dir 2>/dev/null) || return 1
  (cd -P -- "$dir" && real_dir "$common")
}

WT_REAL=$(real_dir "$WT_ARG") || true
[ -n "$WT_REAL" ] || refuse "worktree '$WT_ARG' is not an accessible directory"
PROJ_REAL=$(real_dir "$PROJ_ARG") || true
[ -n "$PROJ_REAL" ] || refuse "project '$PROJ_ARG' is not an accessible directory"

[ -n "${HOME:-}" ] || refuse "HOME is not set, so droid's settings store cannot be located"
HOME_REAL=$(real_dir "$HOME") || true
[ -n "$HOME_REAL" ] || refuse "HOME '$HOME' is not an accessible directory"
[ "$WT_REAL" != "$HOME_REAL" ] || refuse "'$WT_REAL' is the home directory, not a task worktree"

WT_TOP=$(git -C "$WT_REAL" rev-parse --show-toplevel 2>/dev/null) || true
[ -n "$WT_TOP" ] || refuse "'$WT_REAL' is not inside a git repository"
WT_TOP_REAL=$(real_dir "$WT_TOP") || true
[ "$WT_TOP_REAL" = "$WT_REAL" ] || refuse "'$WT_REAL' is not a worktree root (its root is '${WT_TOP_REAL:-unresolvable}')"

WT_GIT_DIR=$(git -C "$WT_REAL" rev-parse --absolute-git-dir 2>/dev/null) || true
[ -n "$WT_GIT_DIR" ] || refuse "'$WT_REAL' has no resolvable git directory"
WT_GIT_DIR=$(real_dir "$WT_GIT_DIR") || true
[ -n "$WT_GIT_DIR" ] || refuse "'$WT_REAL' has an unresolvable git directory"
WT_COMMON=$(common_dir_of "$WT_REAL") || true
[ -n "$WT_COMMON" ] || refuse "'$WT_REAL' has no resolvable git common directory"
[ "$WT_GIT_DIR" != "$WT_COMMON" ] || refuse "'$WT_REAL' is a primary checkout, not an isolated worktree"

PROJ_COMMON=$(common_dir_of "$PROJ_REAL") || true
[ -n "$PROJ_COMMON" ] || refuse "project '$PROJ_REAL' is not inside a git repository"
[ "$WT_COMMON" = "$PROJ_COMMON" ] || refuse "'$WT_REAL' is not a worktree of project '$PROJ_REAL'"

command -v node >/dev/null 2>&1 || refuse "node is required to record folder trust and was not found on PATH"

# The store lives in droid's own config directory; create it when absent, the
# same shape bin/fm-agy-trust.sh uses for its store directory, so a first-ever
# registration on a machine where droid has not written settings yet works.
mkdir -p "$HOME_REAL/.factory" 2>/dev/null || true
[ -d "$HOME_REAL/.factory" ] || refuse "droid settings directory '$HOME_REAL/.factory' does not exist and could not be created"

STORE="$HOME_REAL/.factory/settings.json"
if [ -L "$STORE" ]; then
  STORE_REAL=$(real_file "$STORE") || true
  [ -n "$STORE_REAL" ] || refuse "'$STORE' is a symlink whose target cannot be resolved"
  STORE=$STORE_REAL
fi
if [ -e "$STORE" ]; then
  [ -f "$STORE" ] || refuse "'$STORE' is not a regular file"
  [ -O "$STORE" ] || refuse "'$STORE' is not owned by this user"
  [ -w "$STORE" ] || refuse "'$STORE' is not writable"
fi

# Read-modify-write with a fingerprint check before the rename and a readback
# after it, the bin/fm-agy-trust.sh shape: droid itself rewrites this file
# (trust answers, settings changes, session bookkeeping), so a store that
# moved under us is retried once and then refused rather than clobbered.
if ! node - "$STORE" "$WT_REAL" <<'NODE'
const fs = require("node:fs");
const path = require("node:path");
const crypto = require("node:crypto");
const [store, ...wanted] = process.argv.slice(2);
const paths = [...new Set(wanted)];
const readStore = () => {
  try {
    return fs.readFileSync(store);
  } catch (err) {
    if (err.code === "ENOENT") return null;
    throw err;
  }
};
const fingerprint = (buf) =>
  buf === null ? "absent" : crypto.createHash("sha256").update(buf).digest("hex");
const listed = (root) =>
  root.trustedFolders !== undefined &&
  typeof root.trustedFolders === "object" &&
  !Array.isArray(root.trustedFolders) &&
  paths.every((p) => root.trustedFolders[p] !== undefined);
const attempt = () => {
  const original = readStore();
  const before = fingerprint(original);
  let root = {};
  if (original !== null) {
    const raw = original.toString("utf8");
    if (raw.trim() !== "") {
      root = JSON.parse(raw);
      if (root === null || typeof root !== "object" || Array.isArray(root)) {
        throw new Error(`${store} is not a JSON object`);
      }
    }
  }
  if (root.trustedFolders === undefined || root.trustedFolders === null) root.trustedFolders = {};
  if (typeof root.trustedFolders !== "object" || Array.isArray(root.trustedFolders)) {
    throw new Error(`${store} has a non-object "trustedFolders" value`);
  }
  if (listed(root)) return "recorded";
  for (const p of paths) {
    root.trustedFolders[p] = { trustedAt: new Date().toISOString() };
  }
  const unique = `${process.pid}.${crypto.randomBytes(8).toString("hex")}`;
  const tmp = path.join(path.dirname(store), `.settings.json.fm-trust.${unique}`);
  fs.writeFileSync(tmp, `${JSON.stringify(root, null, 2)}\n`, { mode: 0o600, flag: "wx" });
  let renamed = false;
  try {
    if (fingerprint(readStore()) !== before) return "moved";
    fs.renameSync(tmp, store);
    renamed = true;
  } finally {
    if (!renamed) fs.rmSync(tmp, { force: true });
  }
  return listed(JSON.parse(fs.readFileSync(store, "utf8"))) ? "recorded" : "dropped";
};
try {
  for (let i = 0; i < 3; i += 1) {
    const result = attempt();
    if (result === "recorded") process.exit(0);
    if (result === "moved" && i >= 1) {
      console.error(`error: ${store} was modified while trust was being recorded; refusing to overwrite it`);
      process.exit(1);
    }
  }
} catch (err) {
  console.error(`error: ${err.message}`);
  process.exit(1);
}
console.error(`error: ${store} did not retain trust for ${paths.join(", ")} after 3 attempts`);
process.exit(1);
NODE
then
  refuse "could not record trust for '$WT_REAL' in '$STORE'"
fi

echo "trusted: $WT_REAL"
