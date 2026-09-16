# Feature Specification: Remote Guide Support

**Feature Branch**: `main`

**Created**: 2026-09-16

**Status**: Draft

**Input**: User description: "Support selecting and following code guides through standard TRAMP and TRAMP-RPC connections."

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Open a Remote Guide (Priority: P1)

A developer selects a guide stored in a remote repository and reads its guide tree without copying the guide locally.

**Why this priority**: Remote guide selection is the entry point for every other remote guide action.

**Independent Test**: Connect to a remote repository, select one guide by its remote path, and confirm that the guide tree opens with its title and nodes.

**Acceptance Scenarios**:

1. **Given** a readable guide on a standard TRAMP connection, **When** the developer selects that remote guide, **Then** the guide opens and displays its complete navigation tree.
2. **Given** a readable guide on a working TRAMP-RPC connection, **When** the developer selects that remote guide, **Then** the guide opens with the same content and controls as a local guide.
3. **Given** a remote project with one or more guides in supported project locations, **When** the developer asks to select a project guide from a buffer in that project, **Then** all matching remote guides are offered for selection.

---

### User Story 2 - Follow Remote Source Locations (Priority: P2)

A developer follows, previews, and traverses guide nodes whose source files remain on the same remote repository.

**Why this priority**: A remote guide is useful only when its nodes lead to the corresponding remote source.

**Independent Test**: Open a remote guide containing several nested nodes, then visit and preview each referenced source location while traversing parent, child, and sibling nodes.

**Acceptance Scenarios**:

1. **Given** an open remote guide with a node that references a readable remote source file, **When** the developer visits the node, **Then** the referenced remote file opens at the recorded location.
2. **Given** an open remote guide, **When** the developer previews a node, **Then** the remote source appears while the guide remains selected.
3. **Given** an anchor near a recorded line in a remote source file, **When** the developer visits the node, **Then** the nearest matching anchor determines the displayed line.
4. **Given** a remote guide with nested nodes, **When** the developer uses the existing navigation and folding controls, **Then** those controls behave the same as they do for a local guide.

---

### User Story 3 - Validate and Reload a Remote Guide (Priority: P3)

A developer validates remote locations and reloads a guide after another process changes it remotely.

**Why this priority**: Validation and reload make remote guides reliable during active repository work.

**Independent Test**: Open a remote guide with valid and invalid locations, validate it, update the guide remotely, and reload it.

**Acceptance Scenarios**:

1. **Given** an open remote guide, **When** the developer validates it, **Then** each missing file, invalid line, outside-root path, and missing nearby anchor is reported against its remote path.
2. **Given** an open remote guide that changed remotely, **When** the developer reloads it, **Then** the new content appears and the current node remains selected when its identifier still exists.
3. **Given** a lost or unavailable remote connection, **When** the developer opens, visits, validates, or reloads a guide, **Then** the operation reports a clear error without substituting a local path.

---

### User Story 4 - Keep Remote Guides Distinct (Priority: P4)

A developer keeps guides from different remote repositories open at the same time, even when the guide files have the same basename.

**Why this priority**: Remote repositories commonly use the same conventional guide filename.

**Independent Test**: Open two remote guides with the same basename from different remote identities and confirm that both remain available with their own content.

**Acceptance Scenarios**:

1. **Given** two remote guides with the same basename but different remote identities, **When** the developer opens both, **Then** each guide has a distinct buffer and retains its own document.
2. **Given** two such open guides, **When** the developer reloads or follows a node in either guide, **Then** the action uses that guide's remote repository and does not affect the other guide.

### Edge Cases

- The selected remote guide does not exist, is unreadable, or contains invalid JSON.
- The remote connection requires authentication, disconnects, or times out during an operation.
- A guide root contains `..`, refers to a symbolic link, or resolves outside the permitted remote root.
- A node references an absolute path, a missing source file, or a line beyond the end of a remote file.
- Several nodes reference the same remote source file.
- Multiple matching guides exist in the remote project.
- Standard TRAMP is available but TRAMP-RPC is absent or unavailable.
- TRAMP-RPC is selected but one of its runtime prerequisites is unavailable.
- Two remote connections use different methods or hosts but expose the same path and guide basename.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: Developers MUST be able to select and open a guide through a standard TRAMP remote path.
- **FR-002**: Developers MUST be able to select and open a guide through a working TRAMP-RPC remote path.
- **FR-003**: The system MUST discover supported guide locations when the current project is remote.
- **FR-004**: The system MUST preserve the selected guide's full remote identity when it resolves the guide root and node source paths.
- **FR-005**: Developers MUST be able to visit, preview, and open remote node locations in another window with the existing guide controls.
- **FR-006**: Developers MUST be able to navigate and fold a remote guide with the same controls and behavior as a local guide.
- **FR-007**: Developers MUST be able to reload a remote guide while preserving the selected node when its identifier remains present.
- **FR-008**: Developers MUST be able to validate remote guide locations and receive diagnostics that identify the relevant remote paths and nodes.
- **FR-009**: The system MUST reject a node path that resolves outside the guide root unless outside-root access is explicitly allowed.
- **FR-010**: The system MUST report remote access, authentication, dependency, and connection failures without silently using a local file.
- **FR-011**: Standard TRAMP support MUST remain usable when TRAMP-RPC is not installed or is unavailable.
- **FR-012**: The system MUST keep simultaneously open guides distinct when their complete remote identities differ, even if their basenames match.
- **FR-013**: Reload, validation, and node actions MUST continue to use the remote identity of the guide from which the action started.
- **FR-014**: Existing local guide selection and navigation behavior MUST remain unchanged.

### Key Entities

- **Guide document**: A selected guide with a title, description, root, node tree, and complete source identity.
- **Remote identity**: The connection method, user, host, optional hop chain, and remote path that identify a guide or source file.
- **Guide node**: A navigation item with an identifier, text, optional children, and an optional source location.
- **Source location**: A file path, line, optional column, symbol, and anchor resolved relative to the guide root.
- **Remote project**: The project root used to discover conventional guide locations through a remote connection.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can select and display a known remote guide in no more than three user actions after opening a remote project buffer, excluding authentication steps.
- **SC-002**: In acceptance testing, 100% of valid remote node visits, previews, reloads, and validations retain the guide's remote identity.
- **SC-003**: In acceptance testing, 100% of paths outside the remote guide root are rejected when outside-root access is disabled.
- **SC-004**: Two remote guides with the same basename but different remote identities can remain open and usable at the same time without content replacement.
- **SC-005**: A developer can use the same documented navigation keys for local, standard TRAMP, and TRAMP-RPC guides without learning a separate remote workflow.
- **SC-006**: Every tested remote access failure produces an actionable error and zero tested failures silently open a local substitute.
- **SC-007**: All existing local guide checks continue to pass after remote support is added.

## Assumptions

- The developer already has a working remote connection and the required credentials.
- A TRAMP-RPC connection requires its own installed runtime dependencies and a supported remote environment.
- Remote connection provisioning, credential management, and TRAMP-RPC server deployment are outside this feature's scope.
- The existing guide file format and supported project guide locations remain unchanged.
- Relative guide roots and node paths refer to the same remote identity as the selected guide.
- Cross-host node references are outside this feature's scope.
- Remote operations may take longer than local operations because connection and network latency remain outside the package's control.
