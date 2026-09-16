# Feature Specification: Custom Guide Display

**Feature Branch**: `main`

**Created**: 2026-09-16

**Status**: Draft

**Input**: User description: "next is to allow custom display buffer for code guide buffer; like at bottom?"

## Clarifications

### Session 2026-09-16

- Q: How much control should readers have over guide-buffer placement? → A: Accept a complete editor display rule.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Choose Guide Placement (Priority: P1)

A reader supplies a complete editor display rule so guide buffers fit their preferred reading layout. For example, the reader can place the guide at the bottom of the current frame while source files remain elsewhere.

**Why this priority**: Placement control is the requested value. It lets the reader keep the guide visible without manually rearranging windows after every open.

**Independent Test**: Set the guide placement preference to the bottom, open a guide, and confirm that the guide appears in a bottom window.

**Acceptance Scenarios**:

1. **Given** a valid guide and a bottom placement preference, **When** the reader opens the guide directly, **Then** the guide appears in a bottom window.
2. **Given** any valid editor display rule, **When** the reader opens the guide, **Then** the guide appears according to that rule.
3. **Given** a guide in a remote repository, **When** the reader opens it with a placement preference, **Then** the guide uses that placement without changing its remote identity.

---

### User Story 2 - Keep Guide and Source Placement Independent (Priority: P2)

A reader configures guide placement without changing how visited or previewed source files appear.

**Why this priority**: The guide and its source serve different purposes. A useful layout must let the reader position each independently.

**Independent Test**: Configure different guide and source placements, open a guide, then visit and preview nodes. Confirm that each buffer follows its own preference.

**Acceptance Scenarios**:

1. **Given** different guide and source placement preferences, **When** the reader opens a guide and visits a node, **Then** each buffer uses its respective placement.
2. **Given** a guide displayed at the bottom, **When** the reader previews a node, **Then** the guide remains visible and selected while the source uses the source placement preference.

---

### User Story 3 - Preserve Existing Default Behavior (Priority: P3)

A reader who does not configure guide placement continues to open and use guides as before.

**Why this priority**: Existing users must not need configuration changes for the package to keep working.

**Independent Test**: Open a guide without a custom placement preference and confirm that opening, navigation, preview, validation, and reload remain available.

**Acceptance Scenarios**:

1. **Given** no custom guide placement, **When** the reader opens a guide, **Then** the established default display behavior is unchanged.
2. **Given** an already open guide, **When** the reader opens it again, **Then** the existing guide buffer is reused and shown according to the active guide placement preference.

### Edge Cases

- The requested placement cannot fit in the current frame.
- A display preference selects an existing window instead of creating a new one.
- The guide is already visible when the reader opens it again.
- Multiple distinct guides are open at the same time.
- The reader changes the guide placement preference between opens.
- A source preview must not replace the visible guide window.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Readers MUST be able to configure guide-buffer placement with a complete editor display rule, including placement, reuse, and sizing behavior.
- **FR-002**: The guide placement preference MUST support displaying a guide at the bottom of the current frame.
- **FR-003**: Direct guide opening and project guide opening MUST honor the same guide placement preference.
- **FR-004**: Guide placement MUST remain independent from the existing source-buffer placement preference.
- **FR-005**: A source preview MUST keep the guide visible and selected, regardless of the configured guide placement.
- **FR-006**: When no custom guide placement is configured, the established guide-opening behavior MUST remain unchanged.
- **FR-007**: Reopening an existing guide MUST reuse its guide buffer and apply the active guide placement preference.
- **FR-008**: Distinct guides MUST remain distinct when a custom guide placement is active.
- **FR-009**: Local, standard remote, and optional remote guide paths MUST use the same placement behavior.
- **FR-010**: If the requested placement cannot be used, the system MUST retain the guide buffer and follow the editor's established fallback display behavior.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A reader can configure bottom guide placement once and every subsequent guide open uses it without manual window rearrangement.
- **SC-002**: In acceptance testing, 100% of direct and project guide opens honor the active guide placement preference.
- **SC-003**: In acceptance testing, 100% of source visits and previews continue to follow the separate source placement preference.
- **SC-004**: All existing guide-opening, navigation, preview, validation, reload, and remote-path checks pass with no custom guide placement.
- **SC-005**: Two distinct guides can remain open and usable at the same time while sharing one custom placement preference.
- **SC-006**: A reader can switch between the default placement and bottom placement without restarting the editor or recreating a guide.

## Assumptions

- Bottom placement is an example configuration, not a new mandatory default.
- The existing guide-opening behavior remains the default for compatibility.
- Guide placement and source placement are separate user preferences.
- The editor's complete display-rule format determines placement, window reuse, sizing, and fallback behavior.
- This feature changes guide-buffer placement only. It does not add persistent per-guide layouts or window-size management.
