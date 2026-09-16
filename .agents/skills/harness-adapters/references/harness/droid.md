# Droid (Factory Droid CLI)

Droid's interactive TUI, verified end to end on 2026-09-16 with droid 0.220.0 on Linux through the Herdr backend.
Verified as a CREWMATE and SCOUT adapter only; `../../../../../bin/fm-spawn.sh` refuses a secondmate launch on it because `../../../../../docs/supervision-protocols/` carries no droid wake protocol.
`../../../../../docs/verification/droid.md` owns how every fact below was established and what is still unproven.

## Operating facts

| Fact | Value |
|---|---|
| Binary | Absolute `droid` from `PATH`, refused if absent; a native single binary, so the live process name is exactly `droid` on stock installs. NixOS wraps the binary and the wrapper's truncated 15-char comm is `.droid-wrapped`; both names are matched, anchored. |
| Launch | `droid --auto high "<brief>"`, with the resolved absolute binary; the positional brief auto-submits with no extra Enter (verified: a positional prompt started and finished its turn unattended). The spawn pre-registers the worktree in droid's trust store first, then waits for a busy turn (answering the folder-trust dialog if it renders anyway) before reporting success. |
| Autonomy | `--auto high` sets the autonomy level whose status row reads `Auto (High) · allow all commands`, the targeted equivalent of grok's `--always-approve`; tool calls run with no approval gate. |
| Busy state | No verified firstmate turn-end hook, so nothing is armed and no record is seeded; on Herdr the native `working` status classifies busy, and everywhere else the `droid-regex` rendered-tail fallback in `../../../../../bin/fm-busy-lib.sh` does. |
| Rendered tail | The busy status row pins `Press ESC to stop` above the composer; the idle pane renders no such row. The braille spinner and the `Executing...`/`Invoking tools...` word beside it are free-floating output and are not signals. |
| Turn end | No verified turn-end hook wiring; completion arrives through the worker status protocol and, on Herdr, the native return to `idle`. A Stop-hook surface exists (one was observed firing under the orca agent-hook integration) and is the lead for future turn-end wiring, but nothing about it is verified here. |
| Exit | `/exit`, one Enter; the process exits and prints a `droid --resume <id>` hint. (`/quit` is advertised in the TUI help as `Exit from the Droid CLI`; `/exit` is the verified one.) |
| Interrupt | Single `Escape`, which prints `Request cancelled by user` and leaves an empty composer with no repollution, so no clear key follows. |
| Skill | No verified slash-skill form; use natural language. |
| Marker | None promoted: `FACTORY_*` variables are set inside a droid session but are not proven to reach daemon-spawned worker panes (a Herdr or tmux pane inherits the server's stored environment, not the droid session's), so detection is ancestry-only. |
| Resume | `-r/--resume [sessionId]`, `--fork <id>`, and `--last` exist, but no pane-resume contract is verified; use deterministic relaunch. |
| Model | None passed: the interactive TUI takes no `--model` flag (exec mode only, `-m/--model`, checked against 0.220.0 `--help`), so a requested model stays in task metadata under the record-and-omit contract. |
| Effort | None passed: the interactive TUI takes no `--reasoning-effort` flag (exec mode only, `-r`), so effort also stays in task metadata. |
| Composer | Bordered box with a bare `>` glyph prefix and rotating ghost text: `Try "..."` in a fresh session, `Enter to steer · Ctrl+Enter to queue` beside it, rendered even while a turn runs. Both ghost shapes are in the shared idle-placeholder set in `../../../../../bin/fm-composer-lib.sh`, so an idle composer classifies `empty`. |

## Trust, and where the decision persists

Every task worktree is a path droid has never seen, so an unregistered launch stops on `Trust this folder?` with the safe choice `1. Trust this folder` preselected (`Enter to confirm · Esc to exit`), and an unanswered dialog leaves the brief unsubmitted.
There is no launch flag that suppresses the dialog, but droid honours a `trustedFolders` entry in the captain's own `~/.factory/settings.json` written ahead of launch: accepting the dialog for a fresh scratch directory produced a `trustedFolders.<path>.trustedAt` entry there (verified live), and `../../../../../bin/fm-droid-trust.sh` writes the same shape before launch, the agy shape: the helper refuses anything but a linked worktree of the spawning project, records the resolved path (droid compares the resolved worktree path, the form `git rev-parse --show-toplevel` reports), and preserves every other key in the store, which also carries the operator's own droid settings.
The post-launch readiness gate is the backstop: it answers a dialog that renders anyway with a single Enter, then requires a busy verdict (Herdr's native `working` status or the pinned `Press ESC to stop` row) before the spawn reports success, and on a path that was not pre-registered it never counts a busy verdict as ready until the dialog has been answered.
A pane whose brief cannot be confirmed to run in the worktree fails the spawn, records the failure in the task status, and closes the endpoint.
Never steer into a pane still showing the dialog; a spawn that reported success has already cleared it.

## Credential precondition

A verified droid worker ran under the operator's existing Factory account with no key export and no dialog (the TUI banner shows the signed-in state through its model row).
The unauthenticated failure mode was not observed, so treat any login prompt, `Login expired`, or `/login` banner as a credential blocker under `../../../../../AGENTS.md` section 9, fix the environment, and retire the endpoint rather than typing into it.

## Detection

Detected by ancestry alone: `../../../../../bin/fm-harness.sh` matches the anchored process names `droid` and `.droid-wrapped` (the Nix wrapper's truncated comm), never `*droid*`.
No environment marker is promoted, and droid is deliberately absent from the session-lock name vocabulary in `../../../../../bin/fm-session-lock-lib.sh`, where muse, gemini, and rovo are also absent: a crewmate-only adapter must never own a home session lock.

## Worker busy state and turn end

`../../../../../bin/fm-spawn.sh` arms no busy generation for droid and writes no sidecar, exactly because no writer could ever clear a seeded record.
`fm_busy_droid_tail_busy` matches the pinned `Press ESC to stop` status row alone (`FM_BUSY_DROID_REGEX` overrides it), and `fm_busy_classify` reports `unknown droid-regex` rather than idle when it is absent, because a long turn can scroll the marker out of the captured tail.
Teardown removes nothing droid-specific because the spawn leaves nothing behind.

## Primary integration

Unsupported and unverified.
`../../../../../docs/supervision-protocols/` carries no droid protocol, no turn-end guard adapter exists for it, and this adapter verified only the crewmate-side launch, busy state, interrupt, and exit.
`references/common/primary-hooks.md`'s unsupported-boundary rule applies: never invent a wake protocol from a similar TUI.
