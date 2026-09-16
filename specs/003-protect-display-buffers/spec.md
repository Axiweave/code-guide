# Feature Specification: Protect Display Buffers

**Feature Branch**: `main`

**Created**: 2026-09-16

**Status**: Draft

**Input**: User description: "support excluding some buffer from been overtaking to show preview/target/ like right now I dont want it take over my ghostel and claude-code and ghostel buffer *claude-code[code-guide]*"

## Clarifications

### Session 2026-09-16

- Q: How should readers identify buffers that source previews and visits must never replace? → A: Support both buffer-name patterns and an optional user predicate.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Keep Protected Buffers Visible (Priority: P1)

A reader identifies buffers that must remain visible while browsing a code guide. When the reader previews or visits a source location, the package uses another eligible window instead of replacing a window that shows a protected buffer such as Ghostel or Claude Code.

**Why this priority**: Protecting active conversation and assistant buffers is the requested value. Replacing those windows interrupts the reader's workflow and can hide important context.

**Independent Test**: Mark a visible buffer as protected by name, preview a guide node, and confirm that the protected buffer remains visible while the source appears elsewhere.

**Acceptance Scenarios**:

1. **Given** a visible protected buffer and an open guide, **When** the reader previews a node, **Then** the protected buffer remains in its window and the source appears in another eligible window.
2. **Given** a visible protected buffer and an open guide, **When** the reader visits a node, **Then** the protected buffer remains visible and the source becomes selected elsewhere.
3. **Given** `*claude-code[code-guide]*` matches a protected-buffer rule, **When** a source is displayed, **Then** the window showing that buffer is not reused for the source.

---

### User Story 2 - Protect Multiple Assistant Buffers (Priority: P2)

A reader can protect several buffers through reusable name patterns or an optional user predicate, so Ghostel, Claude Code, and similar assistant buffers remain visible across repeated guide actions.

**Why this priority**: Readers often use several assistant sessions. Requiring one hard-coded name or one manual window adjustment would not solve the repeated interruption.

**Independent Test**: Configure rules that match multiple assistant buffer names, run preview and visit actions repeatedly, and confirm that none of their windows are replaced.

**Acceptance Scenarios**:

1. **Given** several visible buffers that match protected-buffer rules, **When** the reader previews or visits different nodes, **Then** every protected buffer remains visible.
2. **Given** a name pattern or predicate that matches several buffers, **When** a new matching buffer becomes visible, **Then** later guide actions protect it without restarting the editor.
3. **Given** a buffer that does not match any protected rule, **When** the display system selects its window for a source, **Then** the package may reuse that window normally.

---

### User Story 3 - Preserve Existing Defaults and Fallbacks (Priority: P3)

A reader who configures no protected-buffer rules keeps the current preview and visit behavior. When all existing candidate windows show protected buffers, the package follows established display fallback behavior without replacing a protected buffer.

**Why this priority**: Existing users must not need new configuration, and protection must remain reliable in constrained window layouts.

**Independent Test**: Compare source display with an empty rule set, then protect every existing non-guide window and confirm that source display finds another destination or reports a clear failure while protected buffers remain visible.

**Acceptance Scenarios**:

1. **Given** no protected-buffer rules, **When** the reader previews or visits a node, **Then** the existing source display behavior remains unchanged.
2. **Given** every existing candidate window shows a protected buffer, **When** the reader previews or visits a node, **Then** no protected window is reused.
3. **Given** no eligible destination can be created or selected, **When** the reader requests a source display, **Then** the operation reports a clear failure and every protected buffer remains visible.

### Edge Cases

- A protected buffer is renamed before the next guide action.
- A protected buffer is buried, killed, or no longer visible.
- One name rule matches several buffers.
- A buffer name contains punctuation such as brackets or asterisks.
- The guide window itself also matches a protected-buffer rule.
- All visible non-guide windows show protected buffers.
- A user-supplied source display preference would otherwise choose a protected window.
- Preview must keep the guide selected while also preserving protected buffers.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Readers MUST be able to configure zero or more protected-buffer name patterns and an optional protected-buffer predicate.
- **FR-002**: A window showing a buffer that matches a protected rule MUST NOT be reused to display a guide node's source.
- **FR-003**: Protection MUST apply to preview, normal visit, and visit-in-other-window actions.
- **FR-004**: Protected-buffer name patterns MUST support exact names and families of related names, including names such as `*claude-code[code-guide]*`.
- **FR-005**: Multiple protected rules and multiple matching visible buffers MUST be supported at the same time.
- **FR-006**: Rule changes and newly visible matching buffers MUST take effect on the next guide action without restarting the editor.
- **FR-007**: Buffers that do not match a protected rule MUST remain eligible for normal source display.
- **FR-008**: When no protected rules are configured, existing preview and visit behavior MUST remain unchanged.
- **FR-009**: If all existing candidate windows are protected, the system MUST use established fallback behavior without replacing a protected buffer.
- **FR-010**: If no eligible destination is available, the system MUST preserve every protected buffer and report a clear failure.
- **FR-011**: Protected-buffer handling MUST remain compatible with separate guide and source display preferences.
- **FR-012**: Local, standard remote, and optional remote source paths MUST use the same protected-buffer behavior.
- **FR-013**: A buffer MUST be protected when any configured name pattern matches it or the configured predicate identifies it as protected.
- **FR-014**: The optional predicate MUST receive the candidate buffer and return non-nil to protect it.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: In acceptance testing, 100% of preview, visit, and visit-in-other-window actions leave all matching protected buffers visible.
- **SC-002**: A reader can protect Ghostel and Claude Code buffer families with one-time configuration and no per-visit window rearrangement.
- **SC-003**: In acceptance testing, rule changes and newly visible matching buffers affect the next guide action without a restart.
- **SC-004**: All existing source display checks pass when the protected rule set is empty.
- **SC-005**: In constrained-window testing, zero protected windows are reused when every existing candidate window is protected.
- **SC-006**: Local and available remote source checks produce identical protection behavior with no path substitution.

## Assumptions

- Protection applies to windows currently showing matching buffers. It does not change or lock the buffers themselves.
- Readers can identify protected buffers through buffer-name patterns, an optional predicate that receives the candidate buffer, or both.
- Matching uses the buffer's current name at the time of each guide action.
- The default protected rule set is empty.
- Source placement still follows the reader's source display preference after protected windows are excluded.
- Guide-buffer placement remains controlled by the separate guide display preference.
- The feature does not persist protected rules in guide files or add hard-coded rules for Ghostel or Claude Code.
