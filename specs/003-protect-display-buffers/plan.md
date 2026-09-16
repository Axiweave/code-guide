# Implementation Plan: Protect Display Buffers

**Branch**: `003-protect-display-buffers` | **Date**: 2026-09-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/003-protect-display-buffers/spec.md`

## Summary

Keep configured assistant and conversation buffers visible when a code guide previews or visits source. Add buffer-name patterns and an optional buffer predicate, combine them with OR semantics, and centralize source display behind one checked helper. The helper preserves the existing source action, prevents native reuse of protected windows, validates every returned or created destination, restores any protected window changed by a user display rule, and reports a user error when no safe destination exists.

## Technical Context

**Language/Version**: Emacs Lisp, Emacs 29.1 package baseline

**Primary Dependencies**: Built-in buffer and window display functions. No new package dependency.

**Storage**: N/A. The feature adds runtime user preferences and no persisted guide data.

**Testing**: ERT batch suite through `make test`, byte compilation through `make compile`, and interactive window-layout scenarios in `quickstart.md`

**Target Platform**: Emacs 29.1 or later on supported desktop platforms

**Project Type**: Single Emacs package

**Performance Goals**: Each source display checks the small set of visible windows and configured patterns once, with no added file or network operation.

**Constraints**: Patterns use Emacs regexp and `string-match-p` semantics. Predicate and regexp errors propagate before display. Preserve empty-configuration behavior, protect the guide independently, honor safe source preferences, validate every fallback, and keep local and remote source resolution unchanged.

**Scale/Scope**: One package source file, one ERT test file, one README section, two runtime preferences, and the windows visible on current Emacs frames

## Constitution Check

*GATE: Passed before Phase 0 research. Re-checked after Phase 1 design.*

The constitution contains unresolved template placeholders. It defines no ratified principles or enforceable gates. This plan therefore applies the specification and existing package constraints:

- **No new dependency**: Passed. Built-in regexp, predicate, window, and display APIs cover the feature.
- **Default compatibility**: Passed. Empty patterns and a nil predicate retain the current source action.
- **Protected-window invariant**: Passed. One source-display helper checks user-selected and fallback destinations before assignment.
- **Independent placement**: Passed. The guide display preference remains separate from source protection.
- **Remote compatibility**: Passed. Protection inspects windows after source resolution and does not alter filenames.
- **Small interface**: Passed. Two direct preferences and one internal decision helper cover the clarified contract.
- **Testability**: Passed. Real window layouts can prove that protected buffers stay visible.

No complexity exception is required.

## Project Structure

### Documentation (this feature)

```text
specs/003-protect-display-buffers/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── customization.md
└── tasks.md                 # Created later by /speckit.tasks
```

### Source Code (repository root)

```text
code-guide.el                # Preferences, protection decision, and safe source display
code-guide-test.el           # Observable protected-window behavior checks
README.org                   # User configuration examples
Makefile                     # Batch test and byte-compile commands
```

**Structure Decision**: Keep the current single-package layout. All source display actions already pass through `code-guide-visit-node`, so a small internal helper provides one enforcement point without a new module.

## Phase 0: Research Decisions

Research is complete in [research.md](research.md).

1. Expose a regexp list and an optional buffer predicate with OR semantics.
2. Call the predicate with the candidate buffer. A non-nil result protects it.
3. Centralize all source destination selection and assignment behind one checked helper.
4. Exclude protected windows before native reuse, then validate the result.
5. Treat returned windows, manual splits, and frame fallbacks as untrusted destinations until checked.
6. Use restoration only as last-resort recovery when a custom display action ignores exclusion.
7. Report a user error instead of falling back to the selected window when no safe destination exists.

All technical unknowns are resolved.

## Phase 1: Design

### Data model

[data-model.md](data-model.md) defines the two runtime preferences, the derived protection decision, the protected-window snapshot, and source destination states. No stored entity or migration exists.

### Customization contract

[contracts/customization.md](contracts/customization.md) defines pattern matching, predicate invocation, OR precedence, runtime updates, command coverage, destination validation, fallback, and failure behavior.

### Validation guide

[quickstart.md](quickstart.md) covers default compatibility, name patterns, predicate behavior, all three source commands, user display rules, constrained layouts, and local or remote parity.

## Implementation Strategy

### 1. Add two direct preferences

Add `code-guide-protected-buffer-name-patterns`, a list of regexps, and `code-guide-protected-buffer-predicate`, a function or nil. Default both values to nil. Document that the predicate receives a buffer and protects it when it returns non-nil.

### 2. Add one protection decision

Add one internal function that returns non-nil when any regexp matches the buffer's current name or the predicate returns non-nil. Read both preferences at each guide action so runtime changes apply immediately.

### 3. Centralize source display

Move source window selection from `code-guide-visit-node` into one internal helper used by preview, visit, and visit-in-other-window. Keep the dynamic source action used by `code-guide-visit-other-window` compatible with this helper.

### 4. Protect before and after native display

Snapshot visible protected windows and their buffers before calling `display-buffer`. Temporarily make those windows unavailable to standard reuse while preserving and restoring their prior dedication. After the call, reject the guide window and every protected snapshot window, including one that already shows the source. Restore a protected buffer only as last-resort recovery when a custom action ignored exclusion and changed it.

Do not rely on a new action-alist key. Emacs 29.1 has no general window predicate honored by every display action, and custom action functions can ignore action entries or window dedication.

### 5. Validate every fallback

If the configured action yields no safe window, try a fresh split of the guide window and then the established new-frame fallback. Validate each returned window before setting or accepting its buffer. Remove the current selected-window fallback. If no safe live destination exists, signal a clear `user-error` without changing a protected window.

### 6. Add focused behavioral checks

Use real windows plus the repository's fixed-seed generated-property convention. Prove that every accepted destination is non-protected across generated buffer-name and regexp cases, and that empty configuration agrees with the prior display path. Cover exact and family regexps, predicate results and errors, the guide window, every existing window protected, custom `display-buffer-alist` rules, `code-guide-visit-other-window` and its dynamic action, and the existing remote-handler path in `code-guide-test.el`.

### 7. Document configuration

Add one configuration example for assistant buffer families and one predicate example. State the buffer argument, non-nil meaning, OR semantics, empty defaults, and failure behavior. Do not hard-code Ghostel or Claude Code defaults.

## Verification

1. Run `make test`.
2. Run `make compile`.
3. Open a guide with empty protection settings and confirm established preview and visit behavior.
4. Protect `*claude-code[code-guide]*` by name and exercise `SPC`, `RET`, and `o`.
5. Protect a different buffer through the predicate and repeat a source action.
6. Configure a source display action that prefers the protected window and confirm another destination is used.
7. Constrain the layout so no safe destination can be created and confirm a clear error preserves protected buffers.
8. Change patterns and the predicate at runtime and confirm the next action uses the new values.
9. Repeat a source action from an available remote guide and confirm identical protection behavior.

## Post-Design Constitution Check

Passed. The design uses one shared enforcement seam, validates every destination path, preserves existing defaults and source preferences, adds no dependency or storage, and keeps local and remote path handling unchanged. The predicate call contract and OR semantics are explicit. No unresolved clarification or unjustified violation remains.
