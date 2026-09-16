# Droid adapter verification

Live verification of the `droid` (Factory Droid CLI) harness adapter, performed 2026-09-16 on Linux x86_64 (NixOS) through the Herdr backend (herdr 0.9.0), droid 0.220.0.
Scope: crewmate and scout adapter only.
The fact owners are `.agents/skills/harness-adapters/references/harness/droid.md` and the executable owners it names; this record holds the evidence.

## Detection (ancestry-only)

`ps -o comm=` on the ancestor chain of a tool subprocess inside a live droid 0.220.0 session reported, in order: `bash`, `.droid-wrapped`, `.droid-wrapped`, `zsh`, `herdr`, `herdr`, `zsh`, `wezterm-gui`.
The stock binary name `droid` is expected on non-Nix installs from the same vendor distribution mechanism (a single native binary), so both names are matched, anchored.
After adding the `droid|.droid-wrapped` comm arm, `bin/fm-harness.sh` printed `droid` in that live session, where it had printed `unknown` before the change.
No environment marker was promoted: `FACTORY_ENV`, `FACTORY_API_BASE_URL`, `FACTORY_UPSTREAM_CLIENT_TYPE`, and `FACTORY_DROID_AUTO_UPDATE_ENABLED` were observed in the live session's environment, but a Herdr or tmux worker pane inherits the server's stored environment rather than the droid session's, so none is proven to reach a worker and none may be trusted as an identity claim.
A `*droid*` glob was deliberately rejected: `android`, `droidify`, and similar unrelated names carry the fragment.

## Launch (positional brief auto-submit), trust dialog, and pre-registration

A scratch probe directory `/tmp/droid-probe` (not a worktree) exercised the TUI directly through Herdr panes:

- Launching `droid --auto high` in a fresh unregistered directory parked the TUI on a folder-trust dialog titled `Trust this folder?` offering `1. Trust this folder` / `2. Exit without trusting` with the footer `Enter to confirm · Esc to exit`, the safe choice preselected.
- Answering with a single Enter started the TUI and produced a `trustedFolders` entry in `~/.factory/settings.json`: key `/tmp/droid-probe`, value `{"trustedAt": "2026-09-16T08:02:33.077Z"}` (read back from the store after acceptance).
- The store path and shape are what `bin/fm-droid-trust.sh` writes ahead of launch.
  Its own effectiveness as a dialog suppressor was verified in the same probe sequence: after the trust entry existed, relaunching `droid --auto high "reply with exactly: probe-ok"` in the same directory reached the TUI with no dialog, the positional brief auto-submitted, and the reply `probe-ok` rendered unattended.
  The pre-registration-equals-no-dialog step was exercised through the same store shape the helper writes, one acceptance observation on one version.
- `--auto high` renders `Auto (High) · allow all commands` in the status row, and the probe's tool call (`run the command: sleep 25`) executed with no approval gate.

## Busy state, interrupt, and exit

- Mid-turn, the TUI pins a status row carrying `Press ESC to stop` above the composer, with a braille spinner and a phase word (`Executing...`, `Invoking tools...`).
  The composer ghost (`Enter to steer · Ctrl+Enter to queue`) renders even while the turn runs, so only the pinned row is a busy signal.
- A single Escape mid-turn printed `Request cancelled by user` and left the composer empty with no repollution; no clear key is needed.
- `/exit` quit the TUI back to the shell prompt, printing `To resume this session, run: droid --resume <id>` and a session-duration line.
- The idle composer renders as a bordered box with a bare `>` glyph prefix and rotating ghost text (`Try "Implement a REST endpoint for user data"` observed in a fresh session); both ghost shapes were added to the shared idle-placeholder set in `bin/fm-composer-lib.sh`.

## Busy fallback wiring

`fm_busy_droid_tail_busy` matches `Press ESC to stop` (case-insensitive, `FM_BUSY_DROID_REGEX` overrides), and `fm_busy_classify` reports `unknown droid-regex` when the marker is absent from the captured tail, never idle.
`fm_busy_sources_for_harness` arms nothing for droid: a Stop-hook surface was observed (a Stop hook fired in the probe under the orca agent-hook integration) but no firstmate turn-end hook is verified, so no semantic writer may seed a record it could never clear.

## Portable regression

`tests/fm-droid-harness.test.sh` pins, without any real harness process: the comm arms (`droid`, `.droid-wrapped`, and non-matches `android`, `droidify`), the launch template shape (`--auto high`, no model or effort flag), the model/effort record-and-omit behavior, the control tables (supported, crew/scout-only kind gate, Escape interrupt, single repeat, no clear key, `/exit`), the busy tail fallback (busy marker, ghost-only tail reporting unknown), and the trust-helper refusal paths (non-worktree, primary checkout, unrelated project).

## Still unproven

- tmux placement (all live probes ran under Herdr; no tmux-specific fact was claimed).
- Secondmate and primary-harness operation (refused by the kind gate; no wake protocol exists).
- Whether droid honors `trustedFolders` entries for the LOGICAL vs resolved path distinction (both are identical in the verified shape, and the helper records the resolved path only).
- The Stop-hook surface as a firstmate turn-end writer.
