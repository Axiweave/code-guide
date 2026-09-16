# Research: Custom Guide Display

## Decision: Pass a complete display action to guide opening

**Decision**: Add one guide-specific display preference that accepts the editor's complete buffer display action format. Pass it to the existing guide-opening display call.

**Rationale**: The existing display system already supports bottom windows, side windows, reuse, sizing, frames, tabs, and fallback behavior. Reusing this interface gives readers the requested control without a new placement vocabulary or dispatch layer.

**Alternatives considered**:

- Add a bottom-only switch. Rejected because it cannot express the clarified complete display rule.
- Add a fixed side enum. Rejected because it duplicates a smaller subset of existing display behavior.
- Require readers to modify global display rules. Rejected because guide placement must remain package-specific and independent from source placement.

## Decision: Keep guide and source display preferences separate

**Decision**: Retain `code-guide-display-buffer-action` for source visits and previews. Add `code-guide-guide-display-buffer-action` for guide buffers.

**Rationale**: A bottom guide and a source window serve different reading roles. Sharing one value would couple unrelated layouts and contradict the specification.

**Alternatives considered**:

- Reuse the source display preference. Rejected because changing guide placement would also change node visits and previews.
- Rename the existing source preference. Rejected because the feature does not require an interface-breaking migration.

## Decision: Put the seam in the interactive guide-opening command

**Decision**: Apply the guide display preference when `code-guide-open` shows the buffer. Keep `code-guide-open-file` responsible only for parsing, loading, and returning the buffer. Let project discovery continue to delegate to `code-guide-open`.

**Rationale**: This is the smallest existing seam. It covers direct and project opens while preserving the useful non-display interface for tests and programmatic callers.

**Alternatives considered**:

- Display from `code-guide-open-file`. Rejected because it would add a window side effect to a function whose current interface returns a prepared buffer.
- Apply separate display logic in project discovery. Rejected because it would duplicate the direct-open path.

## Decision: Preserve the current default with a nil action

**Decision**: Default the new guide display preference to nil and pass it as the optional action when selecting the guide buffer.

**Rationale**: The editor documents that a nil action retains normal selection and fallback behavior. This preserves current behavior for readers who do not configure the feature.

**Alternatives considered**:

- Copy the editor's fallback action into package configuration. Rejected because it would freeze global policy and drift from user settings.
- Supply a bottom-window default. Rejected because bottom placement is an example, not the new default.

## Decision: Validate real window behavior at the public command seam

**Decision**: Exercise the public guide-opening command with a bottom display action and assert the resulting guide window's placement and buffer. Keep the existing source-preview checks as the independence regression gate.

**Rationale**: A real window assertion proves observable behavior. A test that only records or forwards the action would duplicate the implementation without proving placement.

**Alternatives considered**:

- Mock the display call and assert its arguments. Rejected because that tests wiring rather than reader-visible behavior.
- Add broad window-layout fixtures. Rejected because one focused bottom-window scenario plus existing preview tests covers the contract.

All technical questions are resolved. The feature needs no new dependency, data store, adapter, or protocol-specific path.
