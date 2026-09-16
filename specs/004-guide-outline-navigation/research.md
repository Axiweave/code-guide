# Research: Guide Outline Navigation

## Decision 1: Use built-in Imenu

**Decision**: Set a buffer-local Imenu index function for guide buffers.

**Rationale**: Imenu is built into the supported Emacs baseline. Standard `imenu`, menu-bar consumers, and optional clients such as Consult share this interface. Code Guide needs no command, completion UI, key binding, or dependency.

**Alternatives considered**:

- Add a code-guide completion command. Rejected because it duplicates native completion behavior and creates another user interface.
- Depend on Consult. Rejected because the built-in Imenu interface already lets Consult integrate when present.

## Decision 2: Return a flat index with hierarchy paths

**Decision**: Emit one depth-first list whose names use `Ancestor / Child` paths.

**Rationale**: Standard Imenu can search every node in one completion set. Full paths make nesting visible and distinguish equal titles in different branches. The order matches the guide's established reading order.

**Alternatives considered**:

- Return nested Imenu submenus. Rejected because standard Imenu requires staged submenu selection rather than one search across all nodes.
- Use bare titles. Rejected because equal titles in different branches become ambiguous.

## Decision 3: Number identical siblings

**Decision**: For siblings with the same title, append ` [1]`, ` [2]`, and subsequent one-based occurrence numbers to every duplicate.

**Rationale**: The clarified specification requires both hierarchy context and an occurrence number. Numbering every duplicate makes the group consistent and deterministic.

**Alternatives considered**:

- Number only the second and later occurrence. Rejected because the first entry would not show its occurrence number.
- Show source locations. Rejected because narrative nodes have no source location and paths would expose unrelated source details.
- Show node identifiers. Rejected because identifiers are authoring data rather than reader-facing context.

## Decision 4: Use Imenu special items backed by nodes

**Decision**: Put the node object in each Imenu special item and select it through a small callback.

**Rationale**: Folded descendants are absent from rendered text and therefore have no buffer position. Imenu explicitly supports non-position payloads through special items. The callback can pass the node to the existing `code-guide--goto-node` function, which unfolds ancestors and selects the heading.

**Alternatives considered**:

- Store buffer positions or markers. Rejected because folded nodes have no rendered position and rerendering invalidates positions.
- Unfold every node while building the index. Rejected because opening outline navigation must not change guide state.
- Add a second node-navigation implementation. Rejected because it would duplicate the current selection seam.

## Decision 5: Rescan on each outline request

**Decision**: Enable buffer-local Imenu automatic rescanning in guide buffers.

**Rationale**: A guide can reload with added, removed, or renamed nodes. Rebuilding an in-memory index for the specified 100-node scale is cheap and avoids coupling reload to Imenu's internal cache.

**Alternatives considered**:

- Clear Imenu's internal cache during `code-guide--load`. Rejected because it couples guide loading to an internal cache variable and adds another invalidation path.
- Maintain a persistent package index. Rejected because the parsed guide tree already holds all required data.

## Decision 6: Test the interface through observable invariants

**Decision**: Exercise the installed Imenu interface and selected guide node with fixed-seed generated trees plus focused edge cases.

**Rationale**: The important properties are complete membership, depth-first order, unambiguous labels, and correct selection. These properties fail for missing nodes, stale reloads, duplicate labels, or folded-position implementations.

**Alternatives considered**:

- Assert private helper return values only. Rejected because that would test implementation wiring instead of reader-visible behavior.
- Add Consult tests. Rejected because Consult remains optional and consumes the native interface without package-specific code.
