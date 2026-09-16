---

description: "Implementation tasks for protected code-guide display buffers"
---

# Tasks: Protect Display Buffers

**Input**: Design documents from `specs/003-protect-display-buffers/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/customization.md`, `quickstart.md`

**Tests**: The specification requires observable protection checks. Add ERT tests before each implementation change.

**Organization**: Tasks are grouped by user story. Each story has an independent visible-window acceptance check.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it changes a different file and has no incomplete dependency.
- **[Story]**: Maps the task to a user story from `spec.md`.
- All implementation and test work uses the repository-root `code-guide.el` and `code-guide-test.el` files.

## Phase 1: Setup (Shared Test Infrastructure)

**Purpose**: Reuse the repository's real-window ERT conventions without adding a test directory or dependency.

- [X] T001 Add cleanup-safe guide, source, protected-buffer, and multi-window test helpers with the existing fixed seed in code-guide-test.el

---

## Phase 2: Foundational (Blocking Public Configuration)

**Purpose**: Define the shared public settings required by every story.

**Critical**: Complete this phase before user-story work.

- [X] T002 Add nil-default `code-guide-protected-buffer-name-patterns` and `code-guide-protected-buffer-predicate` defcustoms with Emacs-regexp and one-buffer predicate contracts in code-guide.el

**Checkpoint**: The public configuration exists, but it does not change display behavior yet.

---

## Phase 3: User Story 1 - Keep Protected Buffers Visible (Priority: P1) MVP

**Goal**: A visible buffer protected by name remains unchanged during preview, visit, and visit-in-other-window.

**Independent Test**: Display `*claude-code[code-guide]*` beside a guide, protect its exact name, exercise `SPC`, `RET`, and `o`, and confirm the original window still shows that buffer while another window shows the source.

### Tests for User Story 1

- [X] T003 [US1] Add failing real-window ERT checks for exact-name protection, guide-window preservation, preview focus, normal visit selection, and the separate `code-guide-visit-other-window` dynamic action in code-guide-test.el

### Implementation for User Story 1

- [X] T004 [US1] Implement current-name regexp matching plus one shared source-display helper that snapshots protected windows, excludes them before native reuse, and rejects protected or guide destinations in code-guide.el
- [X] T005 [US1] Route `code-guide-visit-node`, preview, normal visit, and visit-in-other-window through the checked helper without changing guide display preferences in code-guide.el

**Checkpoint**: User Story 1 passes independently for one exact protected name across all three source commands.

---

## Phase 4: User Story 2 - Protect Multiple Assistant Buffers (Priority: P2)

**Goal**: Multiple regexp families and the optional predicate compose with OR semantics and apply at the next action.

**Independent Test**: Protect one buffer by a family regexp and another through the predicate, change both settings at runtime, and confirm each next action protects exactly the current matches.

### Tests for User Story 2

- [X] T006 [US2] Add failing fixed-seed generated ERT properties for exact and family regexps, punctuation, multiple matches, OR semantics, runtime changes, invalid regexps, and predicate argument, return, and error behavior in code-guide-test.el

### Implementation for User Story 2

- [X] T007 [US2] Complete multiple-pattern and optional-predicate evaluation with `string-match-p`, OR semantics, current buffer names, and pre-display error propagation in code-guide.el
- [X] T008 [P] [US2] Document both defcustom symbols, exact and family regexp examples, predicate signature, OR semantics, runtime updates, and neutral defaults in README.org

**Checkpoint**: User Story 2 passes independently for several protected buffers and both matching mechanisms.

---

## Phase 5: User Story 3 - Preserve Existing Defaults and Fallbacks (Priority: P3)

**Goal**: Empty configuration agrees with prior behavior, while unsafe user rules and constrained layouts never replace protected buffers.

**Independent Test**: Compare empty-configuration display with the established path, then protect every existing non-guide window and confirm a safe split or frame is used, or a clear error leaves all protected buffers visible.

### Tests for User Story 3

- [X] T009 [US3] Add failing ERT invariants for empty-configuration agreement, source already visible in a protected window, all existing windows protected, checked split and frame fallbacks, and no-safe-destination errors in code-guide-test.el
- [X] T010 [US3] Add failing real-window checks for custom `display-buffer-alist` rules that choose protected windows and for the existing remote-handler source path in code-guide-test.el

### Implementation for User Story 3

- [X] T011 [US3] Validate every configured, split, and frame destination, remove the unchecked selected-window fallback, restore only custom-action violations, preserve prior dedication with unwind protection, and signal a clear `user-error` when no safe window exists in code-guide.el
- [X] T012 [P] [US3] Document empty defaults, fallback order, custom display-rule rejection, propagated configuration errors, and no-destination failure in README.org

**Checkpoint**: User Story 3 preserves default behavior and protects every unsafe or failure path.

---

## Phase 6: Polish and Cross-Cutting Validation

**Purpose**: Validate the complete contract without adding another abstraction or test location.

- [X] T013 Run every local scenario in specs/003-protect-display-buffers/quickstart.md and correct only observed documentation or behavior drift in quickstart.md, README.org, or code-guide.el
- [X] T014 Run `make test` and `make compile` from Makefile, then resolve any feature regressions in code-guide.el or code-guide-test.el

---

## Dependencies and Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: Starts immediately.
- **Foundational (Phase 2)**: Depends on T001 and blocks every user story.
- **User Story 1 (Phase 3)**: Depends on T002 and establishes the shared safe-display seam.
- **User Story 2 (Phase 4)**: Depends on User Story 1 because it extends the shared matcher.
- **User Story 3 (Phase 5)**: Depends on User Story 1. It may follow User Story 2 to avoid concurrent edits to `code-guide.el` and `code-guide-test.el`.
- **Polish (Phase 6)**: Depends on all selected user stories.

### User Story Dependencies

```text
Setup → Foundation → US1 (MVP) → US2
                         └──────→ US3
US2 + US3 → Polish
```

- **US1**: Delivers the requested protected-window behavior by exact name.
- **US2**: Extends US1 with families, predicates, multiple buffers, and runtime changes.
- **US3**: Hardens US1 for defaults, custom rules, fallbacks, failures, and remote paths.

### Within Each User Story

1. Write the story's ERT checks first.
2. Confirm the new checks fail for the missing behavior.
3. Implement the minimum source change.
4. Run the story's focused ERT checks.
5. Confirm the story's independent test before the next story.

### Parallel Opportunities

- T008 can run with T006 because it updates README.org while the test task updates code-guide-test.el.
- T012 can run with T009 or T010 because it updates README.org while tests update code-guide-test.el.
- US2 and US3 are logically independent after US1, but serialize their edits to `code-guide.el` and `code-guide-test.el`.
- T013 documentation corrections can start only after story behavior stabilizes. T014 remains the final repository check.

## Parallel Example: User Story 1

User Story 1 changes the shared test and source files in test-first order, so it has no safe same-story parallel mutation.

```text
Task: T003 Add the failing real-window ERT checks in code-guide-test.el
Then: T004 and T005 implement and route the checked display path in code-guide.el
```

## Parallel Example: User Story 2

```text
Task: T006 Add generated matching properties in code-guide-test.el
Task: T008 Document the public configuration in README.org
Then: T007 implement the proven semantics in code-guide.el
```

## Parallel Example: User Story 3

```text
Task: T009 Add fallback and compatibility checks in code-guide-test.el
Task: T012 Document fallback and failure behavior in README.org
Then: T010 add custom-rule and remote-path checks in code-guide-test.el
Then: T011 implement checked fallback and failure behavior in code-guide.el
```

## Implementation Strategy

### MVP First: User Story 1

1. Complete T001 and T002.
2. Complete T003 through T005.
3. Run the focused User Story 1 checks.
4. Confirm `*claude-code[code-guide]*` remains visible for `SPC`, `RET`, and `o`.
5. Stop here for the smallest useful release.

### Incremental Delivery

1. Deliver US1 for exact protected names.
2. Add US2 for regexp families, predicates, and runtime changes.
3. Add US3 for compatibility, fallback, custom rules, failures, and remote parity.
4. Complete T013 and T014 once all selected stories pass independently.

### Task Summary

- **Setup**: 1 task
- **Foundation**: 1 task
- **User Story 1**: 3 tasks
- **User Story 2**: 3 tasks
- **User Story 3**: 4 tasks
- **Polish**: 2 tasks
- **Total**: 14 tasks

## Phase 7: Convergence

- [X] T015 Add constrained-layout ERT checks for every existing candidate protected, safe split/frame fallback, source already visible in a protected window, and no-safe-destination failure without protected-window mutation in code-guide-test.el per FR-009, FR-010, US3/AC2-3, and T009 (partial)
- [X] T016 Add a real-window ERT invariant that keeps multiple simultaneously matching protected buffers visible during preview and visit in code-guide-test.el per FR-005, US2/AC1, and T006 (partial)
- [X] T017 Add a real-window ERT check where a matching `display-buffer-alist` rule chooses a protected window and the source uses a safe destination in code-guide-test.el per plan: focused behavioral checks and T010 (partial)
