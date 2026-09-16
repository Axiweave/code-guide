---

description: "Implementation tasks for remote guide support"
---

# Tasks: Remote Guide Support

**Input**: Design documents from `specs/001-remote-guide-support/`

**Prerequisites**: `plan.md`, `spec.md`, `research.md`, `data-model.md`, `contracts/commands.md`, `quickstart.md`

**Tests**: The implementation plan requires focused ERT checks for remote filename identity, containment, and buffer separation. Real transport checks remain in `quickstart.md`.

**Organization**: Tasks are grouped by user story. Each story leaves a separately verifiable increment.

## Phase 1: Setup

**Purpose**: Record the supported environments before implementation changes.

- [x] T001 Add standard TRAMP and optional TRAMP-RPC prerequisites and limitations to `README.org`

---

## Phase 2: Foundational

**Purpose**: Confirm the existing file-function seam that every story uses.

- [x] T002 Add connection-free ERT coverage for complete `/ssh:` filename preservation during guide root and source-path resolution in `code-guide-test.el`

**Checkpoint**: The suite proves that the existing document model preserves a remote identity without opening a connection.

---

## Phase 3: User Story 1 - Open a Remote Guide (Priority: P1) 🎯 MVP

**Goal**: Select a guide by remote filename or from a remote project without a local copy.

**Independent Test**: Open a known guide through standard TRAMP and through a capable TRAMP-RPC environment. From a remote project buffer, confirm that supported guide locations appear for selection.

### Tests for User Story 1

- [x] T003 [P] [US1] Add ERT coverage that `code-guide-open` accepts a complete remote filename and preserves it as the guide document source in `code-guide-test.el`

### Implementation for User Story 1

- [x] T004 [P] [US1] Document direct remote selection and remote project guide selection commands in `README.org`
- [x] T005 [US1] Run the standard TRAMP selection and project-discovery scenarios from `specs/001-remote-guide-support/quickstart.md` and record any environment blocker below this task
  - Result: Ramhorn direct selection and project discovery passed through `/ssh:ramhorn:`.
- [x] T006 [US1] Run the TRAMP-RPC selection and project-discovery scenarios from `specs/001-remote-guide-support/quickstart.md` in a capable environment and record any missing prerequisite below this task
  - Result: Live Emacs selected and discovered the Ramhorn guide through `/rpc:ramhorn:`.

**Checkpoint**: A remote guide can be selected directly and through remote project discovery. Standard TRAMP does not depend on TRAMP-RPC.

---

## Phase 4: User Story 2 - Follow Remote Source Locations (Priority: P2)

**Goal**: Visit and preview remote source locations while keeping the existing guide navigation behavior.

**Independent Test**: Open a remote guide with nested nodes, visit and preview its source locations, and confirm that every source buffer keeps the guide's remote identity.

### Tests for User Story 2

- [x] T007 [US2] Add ERT coverage that relative roots, parent segments, and node files preserve the full remote identity in `code-guide-test.el`

### Implementation for User Story 2

- [x] T008 [US2] Run the visit, preview, traversal, and anchor scenarios for standard TRAMP from `specs/001-remote-guide-support/quickstart.md` and record any environment blocker below this task
  - Result: Ramhorn navigation, preview, source identity, and anchor validation passed.
- [x] T009 [US2] Run the same navigation scenarios for TRAMP-RPC from `specs/001-remote-guide-support/quickstart.md` in a capable environment and record any missing prerequisite below this task
  - Result: Live Emacs navigation, preview, source identity, validation, and reload passed through TRAMP-RPC.

**Checkpoint**: Existing controls navigate remote sources without protocol-specific package code.

---

## Phase 5: User Story 3 - Validate and Reload a Remote Guide (Priority: P3)

**Goal**: Validate remote locations, reject outside-root paths, preserve identity on reload, and report remote failures without local fallback.

**Independent Test**: Validate a remote guide containing valid, missing, outside-root, out-of-range, and missing-anchor locations. Change the guide remotely, reload it, and interrupt the connection to inspect the resulting errors.

### Tests for User Story 3

- [x] T010 [US3] Add a generated containment property covering the root, descendants, parent escapes, and sibling-prefix paths in `code-guide-test.el`
- [x] T011 [US3] Add ERT coverage that reload retains the complete source filename and selected surviving node in `code-guide-test.el`

### Implementation for User Story 3

- [x] T012 [US3] Replace canonical string-prefix containment with `file-in-directory-p` in `code-guide--inside-root-p` in `code-guide.el`
- [x] T013 [US3] Preserve native remote error details while adding missing guide or source path context to open, visit, reload, and validation errors in `code-guide.el`
- [x] T014 [US3] Run the validation, reload, disconnect, and no-local-fallback scenarios from `specs/001-remote-guide-support/quickstart.md` and record transport-specific blockers below this task
  - Result: Ramhorn validation and reload passed. A failed local-host connection returned a native TRAMP error without local fallback.

**Checkpoint**: Validation and reload preserve remote identity, containment is filesystem-aware, and failures remain actionable.

---

## Phase 6: User Story 4 - Keep Remote Guides Distinct (Priority: P4)

**Goal**: Keep same-basename guides from different local or remote identities open at the same time.

**Independent Test**: Open two guides with the same basename but different complete filenames. Reload and navigate each guide independently.

### Tests for User Story 4

- [x] T015 [US4] Add generated ERT coverage that equal complete filenames produce stable names and distinct complete filenames produce distinct names in `code-guide-test.el`

### Implementation for User Story 4

- [x] T016 [US4] Derive the stable guide buffer name from the complete expanded guide filename in `code-guide--buffer-name` in `code-guide.el`
- [x] T017 [US4] Run the same-basename standard TRAMP and TRAMP-RPC scenarios from `specs/001-remote-guide-support/quickstart.md` and confirm that reload and navigation stay isolated
  - Result: Same-basename Ramhorn guides stayed isolated through standard TRAMP and live TRAMP-RPC.

**Checkpoint**: Different guide identities never replace each other's document state.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Align user documentation and run repository-wide checks after all story increments.

- [x] T018 [P] Reconcile remote usage, controls, prerequisites, and failure guidance between `README.org` and `specs/001-remote-guide-support/contracts/commands.md`
- [x] T019 Run `make test` and fix only regressions caused by remote guide changes in `code-guide.el` and `code-guide-test.el`
- [x] T020 Run `make compile` and fix all new byte-compiler warnings in `code-guide.el`
- [x] T021 Review `specs/001-remote-guide-support/quickstart.md` results and record any unverified real-host scenario under the corresponding task without claiming it passed

---

## Dependencies & Execution Order

### Phase dependencies

- **Setup (Phase 1)**: Starts immediately.
- **Foundational (Phase 2)**: Starts immediately and must finish before story implementation.
- **User Story 1 (Phase 3)**: Depends on T002. This is the MVP.
- **User Story 2 (Phase 4)**: Depends on T002. It does not depend on User Story 1 implementation.
- **User Story 3 (Phase 5)**: Depends on T002. T012 follows T010, and T013 follows T011.
- **User Story 4 (Phase 6)**: Depends on T002. T016 follows T015.
- **Polish (Phase 7)**: Depends on the completed story phases selected for release.

### User story dependency graph

```text
T002 foundational identity check
├── US1 remote selection
├── US2 remote navigation
├── US3 validation and reload
└── US4 buffer isolation

US1 + US2 + US3 + US4 → Polish
```

The four stories share the filename-preservation invariant. Their source edits can proceed independently by symbol, but changes to `code-guide.el` and `code-guide-test.el` must be serialized to avoid overlapping file edits.

### Parallel opportunities

- T001 and T002 touch different files and can run in parallel.
- Within US1, T003 and T004 touch different files and can run in parallel.
- US2 has no safe within-story parallel pair because all permanent checks use `code-guide-test.el` and real transport checks share one environment.
- Within US3, document review can occur while T010 and T011 are prepared, but T010 through T013 should remain serialized because they share two files.
- US4 is intentionally sequential: T015 defines the contract that T016 implements.
- T018 can run in parallel with final code review before T019 and T020.

### Parallel example: User Story 1

```text
Task T003: Add remote selection source-identity coverage in code-guide-test.el
Task T004: Document direct and project-based remote selection in README.org
```

### Parallel example: User Story 2

```text
No safe within-story parallel pair. Complete T007, then run T008 and T009 against the available transport environments.
```

### Parallel example: User Story 3

```text
No safe source-edit parallel pair. Complete T010 → T012 and T011 → T013, then run T014.
```

### Parallel example: User Story 4

```text
Complete T015 before T016. Run T017 only after the buffer-name contract passes locally.
```

---

## Implementation Strategy

### MVP first: User Story 1

1. Complete T001 and T002.
2. Complete T003 through T006.
3. Verify direct selection and remote project discovery.
4. Stop and report any unavailable real-host or TRAMP-RPC prerequisite instead of claiming transport success.

### Incremental delivery

1. Add User Story 2 to prove remote source navigation.
2. Add User Story 3 to harden containment, reload, and failures.
3. Add User Story 4 to support simultaneous same-basename guides.
4. Complete the polish phase and repository checks.

### Task completion rules

- Keep one native Emacs file-function path for local, TRAMP, and TRAMP-RPC filenames.
- Do not add a TRAMP-RPC package dependency.
- Do not switch `/rpc:` paths to `/ssh:` automatically.
- Do not mark real-host tasks complete without the required environment and observed result.
- Keep every user story independently demonstrable through its stated test.
