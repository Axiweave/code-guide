---

description: "Implementation tasks for guide outline navigation"
---

# Tasks: Guide Outline Navigation

**Input**: Design documents from `/specs/004-guide-outline-navigation/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/imenu.md`, `quickstart.md`

**Tests**: The specification defines observable acceptance scenarios. Write each story's ERT checks before its implementation.

**Organization**: Tasks are grouped by user story so each story has a clear independent result.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it changes a separate file and has no incomplete dependency.
- **[Story]**: Maps the task to its specification user story.
- Every task names its exact repository path.

## Phase 1: Setup

**Purpose**: Establish the current package baseline before changing the native navigation interface.

- [X] T001 Run the existing `make test` and `make compile` baseline through `Makefile`, then remove the generated `code-guide.elc`

---

## Phase 2: Foundational

**Purpose**: Confirm the existing parsed-model and navigation seams used by every story.

No new foundational code is required. `code-guide--nodes` already supplies depth-first nodes, and `code-guide--goto-node` already reveals and selects folded descendants in `code-guide.el`.

**Checkpoint**: The existing model and navigation seam are ready for story work.

---

## Phase 3: User Story 1 - Search All Guide Nodes (Priority: P1) 🎯 MVP

**Goal**: Expose every guide node through standard Imenu in reading order and select narrative or source-backed nodes without visiting source.

**Independent Test**: Open a nested guide, get its Imenu entries, select a deep narrative node, and confirm every node appears once in depth-first order and the selected guide node changes.

### Tests for User Story 1

- [X] T002 [US1] Add a failing ERT property test for complete depth-first Imenu membership and node selection across empty, single, nested, and narrative guides in `code-guide-test.el`

### Implementation for User Story 1

- [X] T003 [US1] Add the built-in Imenu dependency, buffer-local index setup, flat hierarchy labels, special node-backed entries, and selection callback in `code-guide.el`

**Checkpoint**: `M-x imenu` can search and select every guide node without changing source buffers.

---

## Phase 4: User Story 2 - Navigate Folded and Duplicate Nodes (Priority: P2)

**Goal**: Keep folded descendants selectable and make every duplicate title distinguishable by hierarchy path and occurrence number.

**Independent Test**: Fold a parent, select each duplicate entry, and confirm each label and resulting node match reading order while punctuation and non-ASCII titles remain unchanged.

### Tests for User Story 2

- [X] T004 [US2] Add failing ERT cases for folded descendants, duplicate titles across branches, identical siblings, punctuation, and non-ASCII labels in `code-guide-test.el`

### Implementation for User Story 2

- [X] T005 [US2] Add linear sibling-title counting and one-based duplicate suffixes while reusing `code-guide--goto-node` for folded selection in `code-guide.el`

**Checkpoint**: Hidden nodes remain reachable, and duplicate sibling labels show `[1]`, `[2]`, and later occurrence numbers.

---

## Phase 5: User Story 3 - Keep the Outline Current (Priority: P3)

**Goal**: Rebuild outline entries from the current guide after reload without changing existing local, remote, folding, or visit behavior.

**Independent Test**: Reload a guide with added, removed, and renamed nodes, then confirm the next Imenu index contains only current nodes and preserves guide identity.

### Tests for User Story 3

- [X] T006 [US3] Add failing ERT checks for empty results, successful reload freshness, failed-reload preservation, and unchanged local or available remote identity in `code-guide-test.el`

### Implementation for User Story 3

- [X] T007 [US3] Enable buffer-local Imenu automatic rescanning from current `code-guide--nodes` without adding reload cache invalidation in `code-guide.el`

**Checkpoint**: Each outline request reflects the latest successful guide tree and leaves established behavior unchanged.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Document the native interface and validate the complete feature.

- [X] T008 [P] Document `M-x imenu` and optional `consult-imenu` use without adding a Consult dependency in `README.org`
- [X] T009 Execute the standard, folded, duplicate, narrative, reload, empty, and optional Consult scenarios in `specs/004-guide-outline-navigation/quickstart.md`
- [X] T010 Run the complete ERT regression suite through the `test` target in `Makefile`
- [X] T011 Run warning-as-error byte compilation through the `compile` target in `Makefile`, then remove the generated `code-guide.elc`

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies.
- **Foundational (Phase 2)**: Depends on the baseline and adds no code.
- **User Story 1 (Phase 3)**: Depends on Setup and establishes the Imenu interface.
- **User Story 2 (Phase 4)**: Depends on User Story 1 because it extends entry labeling and selection.
- **User Story 3 (Phase 5)**: Depends on User Story 1 because it controls index freshness.
- **Polish (Phase 6)**: Depends on the selected stories. Full validation requires all stories.

### User Story Dependency Graph

```text
Setup
  └── US1: searchable outline
        ├── US2: folded and duplicate nodes
        └── US3: reload freshness

US2 + US3
  └── Polish and full validation
```

### Within Each User Story

1. Add the observable ERT check and confirm it fails for the missing behavior.
2. Implement only the behavior required by that story.
3. Run the focused ERT check.
4. Confirm the story's independent test before advancing.

### Parallel Opportunities

- After US1, separate developers can implement US2 and US3, but they must coordinate edits to `code-guide.el` and `code-guide-test.el`.
- T008 can run in parallel with final validation because it changes only `README.org`.
- T009, T010, and T011 remain sequential because they exercise the same completed working tree.

## Parallel Examples

### User Story 1

No safe within-story parallel tasks exist. T002 must define the failing behavior before T003 changes the same feature surface.

### User Story 2 and User Story 3

After US1 passes, these story slices can proceed concurrently in isolated worktrees:

```text
Task: "T004-T005: implement folded and duplicate-node behavior in code-guide-test.el and code-guide.el"
Task: "T006-T007: implement reload freshness behavior in code-guide-test.el and code-guide.el"
```

Merge one slice before the other because both touch the same two files.

### Polish

```text
Task: "T008: document Imenu use in README.org"
Task: "T009-T011: run quickstart, ERT, and compilation validation"
```

## Implementation Strategy

### MVP First: User Story 1

1. Complete T001.
2. Confirm the existing model and navigation seam in Phase 2.
3. Complete T002 and confirm the new check fails.
4. Complete T003 and confirm the focused check passes.
5. Stop and validate standard Imenu search and node selection.

### Incremental Delivery

1. Deliver US1 for searchable access to every node.
2. Add US2 for folded and duplicate-node correctness.
3. Add US3 for reload freshness and compatibility.
4. Complete documentation and full verification.

## Notes

- Keep the implementation in `code-guide.el`. Do not add a new module for one native interface.
- Use `code-guide-test.el` at the repository root. There is no `test/` directory.
- Test observable Imenu membership and selected guide nodes, not private helper wiring.
- Keep Consult optional and untested because Code Guide only exposes the native Imenu interface.
- Do not add a guide-only search command, key binding, persistent index, or schema field.

---

## Phase 7: Convergence

- [X] T012 Make Imenu labels globally distinguishable when literal titles collide with generated hierarchy paths or occurrence suffixes, and add adversarial selection coverage in `code-guide.el` and `code-guide-test.el` per FR-002, FR-006, SC-001, and title-punctuation edge cases (partial)
