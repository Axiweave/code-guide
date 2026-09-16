# Implementation Plan: Guide Outline Navigation

**Branch**: `004-guide-outline-navigation` | **Date**: 2026-09-16 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `specs/004-guide-outline-navigation/spec.md`

## Summary

Expose every guide node through Emacs Imenu so built-in `imenu` and optional clients such as Consult can search the same outline. Build a flat depth-first index from the parsed node tree, label each entry with its hierarchy path, number identical siblings, and use an Imenu special-item callback to reuse `code-guide--goto-node`, which already unfolds hidden ancestors. Add no command, key binding, dependency, or stored state.

## Technical Context

**Language/Version**: Emacs Lisp, Emacs 29.1 package baseline

**Primary Dependencies**: Built-in `imenu` and existing code-guide node and navigation functions. No new package dependency.

**Storage**: N/A. The outline is derived from the current in-memory guide document.

**Testing**: ERT batch suite through `make test`, byte compilation through `make compile`, and an interactive `M-x imenu` scenario in `quickstart.md`

**Target Platform**: Emacs 29.1 or later on supported desktop platforms

**Project Type**: Single Emacs package

**Performance Goals**: A 100-node guide exposes its searchable outline in under one second without file or network access.

**Constraints**: Preserve depth-first reading order, support folded and narrative nodes, distinguish duplicate sibling titles, reflect every successful reload, retain local and remote identities, and avoid a Consult dependency or guide-only search command.

**Scale/Scope**: One package source file, one ERT test file, one README section, and guide trees of at least 100 nodes

## Constitution Check

*GATE: Passed before Phase 0 research. Re-checked after Phase 1 design.*

The constitution contains unresolved template placeholders. It defines no ratified principles or enforceable gates. This plan therefore applies the specification and existing package constraints:

- **Native interface**: Passed. Built-in Imenu supplies search and lets existing completion clients integrate without an adapter.
- **Small interface**: Passed. The feature adds no public command, preference, key binding, or schema field.
- **Parsed model authority**: Passed. The index uses `code-guide--nodes` and parent links, not rendered indentation.
- **Navigation locality**: Passed. Imenu selection reuses `code-guide--goto-node`, the existing seam for unfolding and selecting a node.
- **Reload correctness**: Passed. Buffer-local automatic rescanning derives entries from the current document on each request.
- **Compatibility**: Passed. Existing movement, folding, visits, protected-window behavior, and remote paths remain unchanged.
- **Testability**: Passed. The Imenu interface exposes ordered entries whose selections can be checked against observable guide nodes.

No complexity exception is required.

## Project Structure

### Documentation (this feature)

```text
specs/004-guide-outline-navigation/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   └── imenu.md
└── tasks.md                 # Created later by /speckit.tasks
```

### Source Code (repository root)

```text
code-guide.el                # Imenu index construction and selection callback
code-guide-test.el           # Outline ordering, labels, selection, folding, and reload checks
README.org                   # M-x imenu and optional Consult usage
Makefile                     # Existing batch test and byte-compile commands
```

**Structure Decision**: Keep the current single-package layout. The parsed depth-first node list and `code-guide--goto-node` already provide the data and navigation behavior that Imenu needs.

## Phase 0: Research Decisions

Research is complete in [research.md](research.md).

1. Use the built-in Imenu interface instead of adding a code-guide search command.
2. Return one flat depth-first index so standard Imenu searches all nodes in one completion set.
3. Use full hierarchy paths as display names and append one-based occurrence numbers to identical siblings.
4. Use Imenu special items that carry node objects to a callback, because folded nodes have no rendered buffer position.
5. Reuse `code-guide--goto-node` so selecting a folded descendant reveals its ancestors.
6. Enable buffer-local Imenu rescanning so each outline request reflects the latest successful guide reload.
7. Keep Consult optional. It consumes the same Imenu interface when installed.

All technical unknowns are resolved.

## Phase 1: Design

### Data model

[data-model.md](data-model.md) defines the transient outline entry, hierarchy label, sibling occurrence, and selection behavior. No stored entity or migration exists.

### Imenu contract

[contracts/imenu.md](contracts/imenu.md) defines index membership, order, labels, duplicate numbering, folded-node selection, empty guides, reload behavior, and optional client compatibility.

### Validation guide

[quickstart.md](quickstart.md) covers standard Imenu search, duplicate labels, folded and narrative nodes, reload, empty guides, and optional Consult behavior.

## Implementation Strategy

### 1. Enable the native outline interface

Require the built-in Imenu library. In `code-guide-mode`, set `imenu-create-index-function` to one package-local index builder and enable buffer-local automatic rescanning. Do not add a command or key binding.

### 2. Build deterministic labels from the parsed tree

Walk `code-guide--nodes` in its existing depth-first order. Build each label from ancestor titles plus the node title, separated by ` / `. Count titles per parent and add ` [N]` to every member of an identical sibling-title group. Keep punctuation and non-ASCII text unchanged.

Use two small passes over the node list: one to count each `(parent, title)` group and one to emit entries while tracking occurrences. Cache parent labels only during that index build. This keeps work linear in the node count and avoids reading rendered indentation.

### 3. Use node-backed Imenu entries

Return Imenu special entries whose display name is the hierarchy label and whose position payload is the node object. Their callback calls `code-guide--goto-node`. This supports folded nodes that have no current buffer position and reuses existing reveal behavior.

### 4. Keep reload behavior automatic

Build the index from current buffer-local node state on every Imenu request. Do not add a second reload hook, cache invalidation path, or persistent outline state.

### 5. Add one property-focused test cluster

Extend `code-guide-test.el` with generated and focused fixtures. Prove that the Imenu interface contains every node exactly once in depth-first order, labels preserve hierarchy, identical siblings receive contiguous one-based occurrences, selecting each entry reaches its node, and folded selection reveals the target. Cover empty, single-node, narrative, punctuation, non-ASCII, reload, and local or available remote guides.

Use the existing fixed seed and independent tree oracle. Do not test helper implementation details or Consult itself.

### 6. Document standard and optional use

Add `M-x imenu` to the guide workflow. State that `consult-imenu` works when the user already has Consult. Do not add Consult installation or configuration.

## Verification

1. Run `make test`.
2. Run `make compile`.
3. Open a nested guide and use `M-x imenu` to search for a deep node.
4. Fold its parent, select the node again, and confirm the guide reveals it.
5. Confirm duplicate sibling titles show the hierarchy path plus `[1]`, `[2]`, and subsequent occurrence numbers.
6. Reload a changed guide and confirm the next Imenu invocation lists only current nodes.
7. Open an empty guide and confirm Imenu reports no entries without a package error.
8. If Consult is already installed, run `M-x consult-imenu` and confirm it uses the same entries.

## Post-Design Constitution Check

Passed. The design uses one native seam, reuses the parsed model and existing node-selection function, adds no dependency or stored state, and keeps all established navigation and remote behavior unchanged. The transient index has one deterministic contract and no unresolved clarification. No unjustified violation remains.
