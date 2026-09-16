# Implementation Plan: Custom Guide Display

**Branch**: `002-custom-guide-display` | **Date**: 2026-09-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/002-custom-guide-display/spec.md`

## Summary

Let readers supply a complete editor display action for guide buffers, including bottom placement, reuse, and sizing. Add one guide-specific preference and pass it through the existing interactive open seam. Keep source display configuration, programmatic buffer loading, remote identity, and the default layout unchanged.

## Technical Context

**Language/Version**: Emacs Lisp, Emacs 29.1 package baseline

**Primary Dependencies**: Built-in buffer and window display functions. No new package dependency.

**Storage**: N/A. The feature adds one runtime user preference and no persisted application data.

**Testing**: ERT batch suite through `make test`, byte compilation through `make compile`, and interactive bottom-window scenarios in `quickstart.md`

**Target Platform**: Emacs 29.1 or later on supported desktop platforms

**Project Type**: Single Emacs package

**Performance Goals**: Opening a guide performs one native display selection and no extra file or network operation.

**Constraints**: Preserve the current default, keep guide and source display actions independent, retain `code-guide-open-file` as a non-display buffer loader, add no placement abstraction, and apply identical behavior to local and remote guides.

**Scale/Scope**: One package source file, one ERT test file, one README usage section, and one global guide display preference shared by any number of open guides

## Constitution Check

*GATE: Passed before Phase 0 research. Re-checked after Phase 1 design.*

The constitution contains unresolved template placeholders. It defines no ratified principles or enforceable gates. This plan therefore applies the specification and existing package constraints:

- **No new dependency**: Passed. The native display interface provides the complete required behavior.
- **Default compatibility**: Passed. A nil guide action preserves current opening behavior.
- **Independent placement**: Passed. Guide display does not modify source display configuration.
- **Remote compatibility**: Passed. Display occurs after file loading and does not inspect or change remote filenames.
- **Small interface**: Passed. One preference deepens the existing open command rather than adding placement commands or adapters.
- **Testability**: Passed. The public command produces observable window placement without a mock-only seam.

No complexity exception is required.

## Project Structure

### Documentation (this feature)

```text
specs/002-custom-guide-display/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── commands.md
└── tasks.md
```

### Source Code (repository root)

```text
code-guide.el                # Guide preference and interactive display path
code-guide-test.el           # Observable guide-window behavior checks
README.org                   # Configuration example and user workflow
Makefile                     # Batch test and byte-compile commands
```

**Structure Decision**: Keep the current single-package layout. The native display action is already the correct seam, so no new module or adapter is justified.

## Phase 0: Research Decisions

Research is complete in [research.md](research.md).

1. Pass a complete native display action to guide opening.
2. Keep guide and source display preferences separate.
3. Apply guide display at `code-guide-open`; keep `code-guide-open-file` free of display side effects.
4. Use nil as the compatibility-preserving default.
5. Prove placement with a real bottom-window behavior check rather than a forwarding mock.

All technical unknowns are resolved.

## Phase 1: Design

### Data model

[data-model.md](data-model.md) defines the runtime guide display preference and its relationship to guide and source buffers. No stored entity or migration is required.

### Command interface

[contracts/commands.md](contracts/commands.md) defines direct open, project open, programmatic load, default behavior, and source-placement independence.

### Validation guide

[quickstart.md](quickstart.md) covers default behavior, bottom placement, project opening, source independence, preference changes, and local or remote identity preservation.

## Implementation Strategy

### 1. Add one guide-specific preference

Add `code-guide-guide-display-buffer-action` beside the existing source display preference. Accept the editor's complete display action format and default it to nil.

### 2. Deepen the existing open seam

Pass the guide preference when `code-guide-open` selects the buffer returned by `code-guide-open-file`. Do not add display behavior to `code-guide-open-file`. Keep project opening delegated to `code-guide-open`.

### 3. Preserve source behavior

Leave node visits, previews, and visit-in-other-window behavior on `code-guide-display-buffer-action`. Do not merge guide and source layout policy.

### 4. Add one focused behavior check

Open a guide with a bottom display action and assert that the selected window shows the guide at the frame bottom. Keep existing preview and distinct-buffer properties as regression coverage.

### 5. Document configuration

Add one bottom-window example and state that nil preserves the current layout. Keep detailed display-action options in the editor documentation rather than duplicating them.

## Verification

1. Run `make test`.
2. Run `make compile`.
3. Open a guide with the default preference and confirm established behavior.
4. Configure a bottom display action and open a guide directly.
5. Open a project guide and confirm the same placement.
6. Preview and visit source nodes and confirm source placement remains independent.
7. Change the guide preference and reopen the same guide without restarting.
8. Repeat with an available remote guide and confirm its complete remote identity remains unchanged.

## Post-Design Constitution Check

Passed. The design adds one preference at the existing display seam, relies on native behavior, preserves default and remote paths, and adds no dependency, adapter, storage, or duplicated placement model. No unresolved clarification or unjustified violation remains.
