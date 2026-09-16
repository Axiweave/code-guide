# Feature Specification: Guide Outline Navigation

**Feature Branch**: `main`

**Created**: 2026-09-16

**Status**: Draft

**Input**: User description: "Add searchable guide-outline navigation through the editor's standard outline-navigation experience."

## Clarifications

### Session 2026-09-16

- Q: How should the outline distinguish nodes with identical titles under the same parent? → A: Show the hierarchy path and occurrence number.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Search All Guide Nodes (Priority: P1)

A reader can open the editor's standard outline-navigation experience, search guide node titles, and jump directly to a selected node. The reader does not need to traverse the guide sequentially.

**Why this priority**: Large guides become slow to navigate one node at a time. Searchable outline navigation gives immediate access to every part of a guide.

**Independent Test**: Open a guide with top-level and nested nodes, invoke standard outline navigation, select a nested node, and confirm the guide moves to that node.

**Acceptance Scenarios**:

1. **Given** an open guide with top-level and nested nodes, **When** the reader opens standard outline navigation, **Then** every guide node appears in reading order.
2. **Given** the reader searches for part of a node title, **When** a matching entry is selected, **Then** the corresponding guide node becomes selected.
3. **Given** a narrative node without a source location, **When** the reader selects it from the outline, **Then** the guide moves to that node without requiring a source file.

---

### User Story 2 - Navigate Folded and Duplicate Nodes (Priority: P2)

A reader can distinguish repeated titles by their guide context and can select nodes hidden inside folded sections.

**Why this priority**: Real guides can repeat common titles and collapse long sections. Every node must remain reachable and identifiable.

**Independent Test**: Fold a parent, open a guide containing duplicate titles, select each duplicate from the outline, and confirm each selection reveals the correct node.

**Acceptance Scenarios**:

1. **Given** a folded parent with hidden descendants, **When** the reader selects a hidden descendant, **Then** the guide reveals and selects that node.
2. **Given** duplicate node titles at different nesting levels, **When** the reader views the outline, **Then** each entry shows its hierarchy path.
3. **Given** duplicate titles under the same parent, **When** the reader views the outline, **Then** each entry shows its hierarchy path and occurrence number.

---

### User Story 3 - Keep the Outline Current (Priority: P3)

A reader sees the current guide structure after the guide reloads, while existing guide navigation continues unchanged.

**Why this priority**: Agents can rewrite guides during a reading session. Search results must not retain removed nodes or omit new nodes.

**Independent Test**: Open outline navigation, rewrite and reload the guide with a changed tree, reopen outline navigation, and confirm it reflects only the new tree.

**Acceptance Scenarios**:

1. **Given** an open guide that reloads with added, removed, or renamed nodes, **When** the reader reopens outline navigation, **Then** the entries match the reloaded tree.
2. **Given** the reader never invokes outline navigation, **When** normal movement, folding, preview, visit, validation, or reload commands run, **Then** their behavior remains unchanged.
3. **Given** a local or remote guide, **When** the reader uses outline navigation, **Then** guide identity and source paths remain unchanged.

### Edge Cases

- A guide has no nodes.
- A guide has one node.
- Several nodes share the same title and parent.
- A title contains punctuation, markup-like text, or non-ASCII characters.
- A selected node is hidden beneath several folded ancestors.
- The guide reloads while the reader remains in the same guide buffer.
- A node has no source location.
- A guide uses a standard or optional remote filename handler.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Readers MUST be able to access guide nodes through the editor's standard outline-navigation experience.
- **FR-002**: Every guide node MUST appear in the outline, including nested and narrative nodes without source locations.
- **FR-003**: Outline entries MUST preserve guide reading order and represent nesting.
- **FR-004**: Selecting an outline entry MUST move the guide to the corresponding node.
- **FR-005**: Selecting a node hidden by folded ancestors MUST reveal and select that node.
- **FR-006**: Duplicate titles MUST remain independently selectable.
- **FR-007**: Duplicate titles MUST show their hierarchy path, and identical sibling titles MUST also show an occurrence number.
- **FR-008**: The outline hierarchy MUST agree with the hierarchy shown in the guide.
- **FR-009**: Outline entries MUST reflect the latest successful guide reload without reopening the guide buffer.
- **FR-010**: An empty guide MUST produce an empty outline without an error.
- **FR-011**: Local, standard remote, and optional remote guides MUST expose the same outline behavior without changing guide or source identity.
- **FR-012**: Existing movement, folding, preview, visit, validation, reload, guide display, source display, and protected-buffer behavior MUST remain unchanged.
- **FR-013**: The feature MUST use the editor's shared outline-navigation experience rather than introduce a separate guide-only search interface.
- **FR-014**: Completion presentation, matching style, and user key bindings MUST remain controlled by the reader's editor configuration.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In acceptance testing, 100% of guide nodes, including folded and narrative nodes, are reachable through outline navigation.
- **SC-002**: A reader can locate and select any node in a 100-node guide without sequential guide traversal.
- **SC-003**: Every duplicate-title fixture keeps 100% of its nodes independently selectable.
- **SC-004**: After each successful reload fixture, outline navigation contains all current nodes and zero removed nodes.
- **SC-005**: Empty, single-node, nested, local, and available remote guide checks complete without outline-navigation errors.
- **SC-006**: All existing guide navigation, display protection, reload, and available remote checks continue to pass without changed outcomes.

## Assumptions

- Outline entries represent guide nodes, not source symbols or files.
- The editor's existing outline-navigation command supplies search, completion, and presentation.
- Guide node identity remains the source of truth when titles repeat.
- Selecting an outline entry changes only the guide position. It does not visit the node's source.
- Search ranking, completion presentation, and key bindings remain controlled by the reader's editor configuration.
- The feature does not persist search history in guide files.
- The feature does not generate, rewrite, or repair guide content.
- Return-to-guide history is a separate feature and is outside this specification.
