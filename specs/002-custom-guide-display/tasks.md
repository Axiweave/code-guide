---

description: "Implementation tasks for custom guide display"
---

# Tasks: Custom Guide Display

**Input**: Design documents from `specs/002-custom-guide-display/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/commands.md`, `quickstart.md`

**Tests**: The plan requires focused ERT behavior checks at the public command seam.

**Organization**: Tasks are grouped by user story so each story remains independently testable.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel because it changes a different file and has no incomplete dependency.
- **[Story]**: Maps the task to a user story from `spec.md`.
- Every task names the file or validation artifact it changes or exercises.

## Phase 1: Setup

**Purpose**: Confirm that the existing package layout already provides the required implementation and test files.

No setup changes are required. The feature uses the existing `code-guide.el`, `code-guide-test.el`, `README.org`, and `Makefile` layout.

---

## Phase 2: Foundational

**Purpose**: Confirm that no shared infrastructure blocks story work.

No foundational changes are required. The native editor display interface and existing guide-opening seam provide the shared capability.

**Checkpoint**: User story work can start without a new dependency, module, adapter, or data migration.

---

## Phase 3: User Story 1 - Choose Guide Placement (Priority: P1) 🎯 MVP

**Goal**: Let a reader supply a complete guide display action, including bottom placement.

**Independent Test**: Configure a bottom display action, open a guide directly, and confirm that the selected bottom window shows the guide.

### Tests for User Story 1

- [x] T001 [US1] Add a failing ERT behavior check that `code-guide-open` selects a bottom window showing the guide when `code-guide-guide-display-buffer-action` uses `display-buffer-at-bottom` in `code-guide-test.el`

### Implementation for User Story 1

- [x] T002 [US1] Add the nil-default `code-guide-guide-display-buffer-action` preference and pass it to the existing `pop-to-buffer` call in `code-guide-open` without changing `code-guide-open-file` in `code-guide.el`
- [x] T003 [P] [US1] Document the complete display-action preference, nil default, and bottom-window example in `README.org`

**Checkpoint**: Direct guide opening honors a complete display action while programmatic buffer loading remains display-free.

---

## Phase 4: User Story 2 - Keep Guide and Source Placement Independent (Priority: P2)

**Goal**: Keep guide placement separate from source visits and previews.

**Independent Test**: Configure different guide and source actions, open a guide, preview and visit a node, and confirm that each buffer follows its own action while preview keeps the guide selected.

### Tests for User Story 2

- [x] T004 [US2] Add an ERT behavior check that separate guide and source display actions preserve the bottom guide window, source placement, and preview focus in `code-guide-test.el`

**Checkpoint**: Guide placement never replaces or overrides source placement behavior.

---

## Phase 5: User Story 3 - Preserve Existing Default Behavior (Priority: P3)

**Goal**: Preserve the current layout for readers who leave the guide action nil and apply preference changes on reopen.

**Independent Test**: Open a guide with the nil default, change to a bottom action, reopen it, and confirm that the same guide buffer moves through the active display policy without a restart.

### Tests for User Story 3

- [x] T005 [US3] Add an ERT behavior check for nil-default compatibility, same-buffer reuse, and immediate action changes when reopening a guide in `code-guide-test.el`

**Checkpoint**: Existing users keep the current behavior, and runtime preference changes reuse guide identity.

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Verify the complete feature across local, project, source, and remote workflows.

- [x] T006 Run `make test` through `Makefile` and fix only regressions caused by custom guide display changes in `code-guide.el` and `code-guide-test.el`
  - Result: All 27 ERT tests passed.
- [x] T007 Run `make compile` through `Makefile` and fix all new byte-compiler warnings in `code-guide.el`
  - Result: Byte compilation completed without warnings.
- [x] T008 Run the default, bottom, project, source-independence, and runtime-change scenarios in `specs/002-custom-guide-display/quickstart.md` and record observed results under this task
  - Result: Default, bottom, project, source-independence, and runtime-change scenarios passed in batch Emacs.
- [x] T009 Run the remote identity scenario in `specs/002-custom-guide-display/quickstart.md` on an available standard TRAMP or TRAMP-RPC guide and record either the observed result or the unavailable environment prerequisite under this task
  - Result: Standard TRAMP open, bottom display, source preview, reload, and remote identity checks passed on Ramhorn.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No work is required.
- **Foundational (Phase 2)**: No work is required.
- **User Story 1 (Phase 3)**: Starts immediately and provides the MVP preference and display seam.
- **User Story 2 (Phase 4)**: Its test uses the preference from User Story 1.
- **User Story 3 (Phase 5)**: Its test uses the preference from User Story 1.
- **Polish (Phase 6)**: Starts after all selected user stories are complete.

### User Story Dependencies

- **User Story 1 (P1)**: No story dependency.
- **User Story 2 (P2)**: Depends on the User Story 1 preference but remains independently testable through guide and source behavior.
- **User Story 3 (P3)**: Depends on the User Story 1 preference but remains independently testable through default and reopen behavior.

### Within Each User Story

- Write the story's behavior check before its implementation or verification work.
- Make T001 fail before T002 implements the display preference.
- Keep `code-guide-open-file` free of display side effects.
- Use real window behavior rather than a forwarding mock.
- Complete the story checkpoint before starting the next priority when working sequentially.

### Parallel Opportunities

- T003 can run in parallel with T001 and T002 because it changes `README.org` while implementation changes package and test files.
- After T002, User Story 2 and User Story 3 validation can proceed independently, but T004 and T005 both edit `code-guide-test.el` and should not run concurrently.
- T008 and T009 can run in parallel when separate local and remote environments are available.

---

## Parallel Example: User Story 1

```text
Task: "T001 [US1] Add the bottom-window behavior check in code-guide-test.el"
Task: "T003 [P] [US1] Document the display preference and bottom example in README.org"
```

## Parallel Example: Final Validation

```text
Task: "T008 Run local custom-display scenarios from quickstart.md"
Task: "T009 Run the remote identity scenario from quickstart.md"
```

---

## Implementation Strategy

### MVP First: User Story 1

1. Confirm that Setup and Foundational require no changes.
2. Complete T001 and observe the missing behavior.
3. Complete T002 and T003.
4. Run the User Story 1 independent test.
5. Stop after the checkpoint if bottom guide placement is the only required delivery.

### Incremental Delivery

1. Deliver User Story 1 for complete guide placement control.
2. Add User Story 2 coverage for guide and source independence.
3. Add User Story 3 coverage for default compatibility and runtime changes.
4. Complete repository and quickstart verification.

### Task Completion Rules

- Keep guide display configuration separate from `code-guide-display-buffer-action`.
- Do not add a placement enum, adapter, dependency, or guide-file field.
- Do not add display side effects to `code-guide-open-file`.
- Do not claim remote validation passed without an available remote environment and observed result.
- Keep each behavior check focused on a reader-visible contract.
