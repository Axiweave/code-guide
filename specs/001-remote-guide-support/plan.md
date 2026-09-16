# Implementation Plan: Remote Guide Support

**Branch**: `001-remote-guide-support` | **Date**: 2026-09-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/001-remote-guide-support/spec.md`

## Summary

Support local, standard TRAMP, and TRAMP-RPC guides through the existing Emacs file-function seam. Preserve complete remote filenames from selection through path resolution, navigation, validation, and reload. Change only filename containment and guide-buffer identity where current generic behavior is insufficient. Add deterministic filename and buffer-isolation checks, and keep real SSH and RPC validation in the quickstart guide.

## Technical Context

**Language/Version**: Emacs Lisp, Emacs 29.1 package baseline

**Primary Dependencies**: Built-in `cl-lib`, `json`, `pulse`, `project`, `compile`, and TRAMP file-name handling. TRAMP-RPC is optional and not a package dependency.

**Storage**: Read-only `.codeguide.json` files on local or remote filesystems

**Testing**: ERT batch suite through `make test`, byte compilation through `make compile`, and real-connection scenarios in `quickstart.md`

**Target Platform**: Emacs 29.1 or later on platforms supported by Emacs. TRAMP-RPC scenarios require the versions and remote platforms supported by TRAMP-RPC.

**Project Type**: Single Emacs package

**Performance Goals**: Remote guide operations add no protocol-specific round trips beyond the file operations required for equivalent local behavior. Opening two guides remains constant in package-owned state per guide.

**Constraints**: No new dependency, no connection-method branches, no automatic RPC-to-SSH fallback, no local path substitution, and no regression to local guide behavior

**Scale/Scope**: One package source file, one ERT test file, one README usage section, conventional project guide locations, and guide trees of the existing supported size

## Constitution Check

*GATE: Passed before Phase 0 research. Re-checked after Phase 1 design.*

The constitution file contains only unresolved template placeholders. It defines no ratified project principles or enforceable gates. This plan therefore applies the repository's existing package constraints and the feature specification:

- **No new dependency**: Passed. Standard Emacs file functions remain the sole remote seam.
- **Local compatibility**: Passed. Local paths follow the same commands and document model.
- **Remote identity preservation**: Passed. The complete guide source filename remains canonical.
- **No silent fallback**: Passed. Errors remain attached to the selected handler and path.
- **Testability**: Passed. Deterministic behavior uses ERT, while environment-dependent transport behavior uses the quickstart scenarios.
- **Simplicity**: Passed. The plan changes existing functions instead of adding a remote adapter or protocol abstraction.

Post-design re-check: The research, data model, command contract, and quickstart introduce no gate violation. No complexity exception is required.

## Project Structure

### Documentation (this feature)

```text
specs/001-remote-guide-support/
├── spec.md
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── commands.md
├── checklists/
│   └── requirements.md
└── tasks.md                 # Created later by /speckit.tasks
```

### Source Code (repository root)

```text
code-guide.el                # Package implementation and command interface
code-guide-test.el           # ERT behavior and property checks
README.org                   # User workflow and remote-path examples
Makefile                     # Batch test and byte-compile commands
```

**Structure Decision**: Keep the current single-package layout. Remote support deepens the existing file-function seam in `code-guide.el`. It does not justify a new module or adapter.

## Phase 0: Research Decisions

Research is complete in [research.md](research.md).

1. Use native Emacs file functions for both TRAMP methods.
2. Keep complete remote identity in `code-guide-document-source-file`.
3. Derive guide buffer identity from the complete expanded guide filename.
4. Use `file-in-directory-p` for root containment.
5. Retain native project discovery. Emacs implements wildcard expansion through remote-aware directory operations and marks it as `remote-wildcards`; real transport behavior remains a quickstart gate.
6. Preserve native remote errors and prohibit protocol fallback.
7. Split deterministic tests from real-host quickstart validation.

All technical unknowns are resolved. The environment limitation is explicit: this session has no SSH host and lacks `msgpack` for TRAMP-RPC batch loading.

## Phase 1: Design

### Data model

[data-model.md](data-model.md) defines the existing guide document, remote identity, guide node, source location, and remote project invariants. No new stored entity or format field is required.

### Command interface

[contracts/commands.md](contracts/commands.md) keeps one command interface for local and remote guides. It defines selection, project discovery, navigation, reload, validation, compatibility, and error behavior.

### Validation guide

[quickstart.md](quickstart.md) separates deterministic repository checks from real standard TRAMP and TRAMP-RPC scenarios. It includes prerequisites, commands, controls, and expected outcomes.

## Implementation Strategy

### 1. Preserve one native file seam

Keep `code-guide-parse-file`, `code-guide-document-root-directory`, `code-guide-resolve-file`, `code-guide-visit-node`, `code-guide--project-guides`, and `code-guide-reload` on standard Emacs file functions. Do not inspect TRAMP methods or require TRAMP-RPC.

### 2. Make containment filesystem-aware

Update `code-guide--inside-root-p` to use the native directory-containment predicate with the resolved file and guide root. Preserve `code-guide-allow-outside-root` behavior in validation.

### 3. Make guide buffers collision-safe

Update `code-guide--buffer-name` to derive a stable name from the complete expanded guide filename. Reopening the same guide must reuse its buffer. Different local or remote identities must not collide.

### 4. Preserve actionable failures

Exercise open, visit, validate, reload, and project discovery failures. Add context only where the current error omits the guide or source path. Do not catch and replace detailed handler errors with generic messages.

### 5. Add focused permanent checks

Add ERT checks that prove these observable properties:

- Relative roots and node paths preserve an `/ssh:` filename's method, user, host, and path without opening a connection.
- Complete guide filenames produce stable, distinct buffer identities.
- Containment accepts the root and descendants but rejects siblings and parent escapes.
- Existing local selection, navigation, reload, and validation checks continue to pass.

Do not add a mocked test that only echoes project discovery calls. Use the quickstart for real remote discovery and transport behavior.

### 6. Document the user workflow

Add concise standard TRAMP and TRAMP-RPC examples to `README.org`. State that TRAMP-RPC owns its optional prerequisites. Keep one set of guide controls for every file method.

## Verification

1. Run `make test`.
2. Run `make compile`.
3. Run the standard TRAMP scenarios in `quickstart.md` on an accessible SSH host.
4. Run the TRAMP-RPC scenarios only where its runtime prerequisites are installed.
5. Confirm two same-basename remote guides remain distinct.
6. Confirm failures never open a local substitute.

## Post-Design Constitution Check

Passed. The design uses the existing module and interface, adds no dependency or adapter, preserves local behavior, and records the real-host verification boundary. No unresolved clarification or unjustified violation remains.
