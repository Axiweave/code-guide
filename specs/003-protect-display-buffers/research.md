# Research: Protect Display Buffers

## Decision: Support patterns and a predicate with OR semantics

**Decision**: Add `code-guide-protected-buffer-name-patterns`, a list of Emacs regexps tested with `string-match-p` against each buffer's current name, and `code-guide-protected-buffer-predicate`, an optional function called with the candidate buffer. Protect the buffer when any regexp matches or the predicate returns non-nil. Let invalid regexps and predicate errors propagate before source display starts.

**Rationale**: Emacs regexp semantics provide short configuration for exact names and families without a new matching language. The predicate covers mode-based or state-based rules. OR semantics keeps composition predictable. Visible buffers are evaluated before display, so a configuration error does not mutate a window.

**Alternatives considered**:

- Patterns only. Rejected because the clarification explicitly requires a predicate too.
- Predicate only. Rejected because common name-family configuration would need unnecessary functions.
- Hard-coded Ghostel or Claude Code rules. Rejected because package defaults must remain neutral.

## Decision: Use one checked source-display seam

**Decision**: Route destination selection and fallback from `code-guide-visit-node` through one internal source-display helper. Preview and visit already share this path. Visit-in-other-window dynamically changes the source action before it reaches the same path.

**Rationale**: One seam enforces the invariant for every source command and avoids three partial fixes.

**Alternatives considered**:

- Add checks to each command. Rejected because it duplicates policy and can drift.
- Put protection in source path resolution. Rejected because paths do not choose windows.
- Modify guide opening. Rejected because guide placement and source placement are separate concerns.

## Decision: Do not rely only on action-alist filtering

**Decision**: Temporarily make protected windows unavailable to standard reuse during the display call, then validate the returned destination against the pre-display protected-window snapshot. Use restoration only if a custom action ignores the exclusion and mutates a protected window.

**Rationale**: Emacs 29.1 action alists have no general `window-predicate` entry honored by all display action functions. Standard actions respect dedicated windows, but custom actions may interpret the action alist freely. Post-call validation is therefore required for the package guarantee.

**Alternatives considered**:

- Add a `window-predicate` action entry. Rejected because Emacs 29.1 does not define that general action entry.
- Override only `some-window`. Rejected because it affects `display-buffer-use-some-window` but not reuse or custom actions.
- Replace the reader's source action. Rejected because configured placement must remain effective for safe destinations.

## Decision: Snapshot and restore protected windows

**Decision**: Before display, record each visible protected window and its buffer. Temporarily preserve standard display behavior by dedicating those windows while the native action chain runs, then restore their prior dedication. Reject every protected snapshot window as a destination, including one that already shows the source. If a custom action ignores dedication and replaces a protected buffer, restore that buffer as a last-resort recovery and reject the destination.

**Rationale**: Pre-display exclusion avoids buffer hooks and state loss on standard paths. The snapshot preserves the original buffer identity for postcondition checks against custom actions. A protected window remains untouched even when the requested source is already visible elsewhere.

**Alternatives considered**:

- Check only the returned window's current buffer. Rejected because replacement erases the evidence that the window was protected.
- Trust every custom display action. Rejected because the specification requires protection even when a source preference would choose a protected window.
- Permanently dedicate protected windows. Rejected because protection applies only to code-guide source display and must not change editor state globally.

## Decision: Validate all fallback destinations

**Decision**: Reject the guide window and protected snapshot windows after the configured display call. On rejection or nil, try a fresh split of the guide window and then the established new-frame fallback. Accept a destination only when it is live and not protected. Signal `user-error` when none exists.

**Rationale**: The current fallback can unconditionally call `set-window-buffer`, and its selected-window default can overwrite an unsafe destination. Checking only the initial `display-buffer` result leaves those paths unprotected.

**Alternatives considered**:

- Keep `(or (display-buffer ...) (selected-window))`. Rejected because the selected window can show the guide or a protected buffer.
- Always create a frame. Rejected because a normal split is smaller and preserves established behavior.
- Silently skip the visit. Rejected because the reader needs a clear failure when the request cannot complete safely.

## Decision: Prove the visible-window invariant

**Decision**: Use ERT with real windows to assert that a protected `*claude-code[code-guide]*` buffer remains in its original window across preview, visit, and visit-in-other-window. Also cover predicate protection, runtime changes, an unsafe user action, and failure without a destination.

**Rationale**: The contract concerns observable window state. Mocking only action arguments would not prove that protected buffers remain visible.

**Alternatives considered**:

- Assert helper return values only. Rejected because that misses destructive display side effects.
- Duplicate the matching implementation in tests. Rejected because it would not prove the window invariant.
- Add separate local and remote matching implementations. Rejected because both paths converge after source loading.

All technical questions are resolved. The feature needs no new dependency, storage, protocol, or remote adapter.
