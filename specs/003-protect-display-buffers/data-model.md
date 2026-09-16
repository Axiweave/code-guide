# Data Model: Protect Display Buffers

## Protected Buffer Policy

Represents the reader's runtime rules for buffers that code-guide source display must not replace.

### Attributes

- **Name patterns**: `code-guide-protected-buffer-name-patterns`, a list of Emacs regexps tested with `string-match-p` against each candidate buffer's current name. Default: nil.
- **Predicate**: `code-guide-protected-buffer-predicate`, an optional function called with one buffer argument. A non-nil result protects that buffer. Errors propagate and abort source display. Default: nil.
- **Combination rule**: OR. One matching pattern or a non-nil predicate result protects the buffer.
- **Scope**: Source preview, normal visit, and visit-in-other-window. Guide display remains separate.

### Validation rules

- Every name pattern must be a valid Emacs regexp.
- The predicate must be nil or callable with one buffer argument.
- An invalid regexp error propagates before a source display action changes a window.
- A predicate error propagates before a source display action changes a window.
- Empty patterns plus a nil predicate preserve established source display behavior.
- Current values apply at each guide action without a restart.
- No default pattern names Ghostel, Claude Code, or another external package.

## Protected Window Snapshot

Represents the visible windows that must remain unchanged during one source display operation.

### Attributes

- **Window**: A live window visible when the source action starts.
- **Buffer**: The protected buffer shown by that window before display.
- **Prior dedication**: The window's dedication state before temporary protection.

### Validation rules

- Membership depends on the buffer shown when the action starts.
- A renamed buffer uses its current name.
- Killed or non-visible buffers do not create snapshot entries.
- The guide window remains excluded independently from this policy.
- Temporary window state must return to its prior value after display succeeds or fails.

## Source Destination

Represents the window accepted for a source buffer.

### States

1. **Candidate**: Returned by the configured source display action or a fallback.
2. **Rejected**: Nil, dead, the guide window, or a protected snapshot window.
3. **Accepted**: Live, separate from the guide, and absent from the protected snapshot.
4. **Unavailable**: No configured or fallback candidate reaches Accepted.

### Transitions

1. The configured source action produces a Candidate.
2. Validation moves the Candidate to Accepted or Rejected.
3. A Rejected candidate triggers fresh split fallback, then new-frame fallback.
4. An Accepted destination shows the source and preserves protected snapshots.
5. Unavailable signals a clear user error and leaves every protected buffer visible.

## Relationships

- The Protected Buffer Policy evaluates buffers before source placement.
- Protected Window Snapshot records the visible result of that policy for one action.
- Source Destination validation uses the snapshot before any explicit buffer assignment.
- `code-guide-display-buffer-action` still supplies the reader's preferred source placement.
- `code-guide-guide-display-buffer-action` remains independent.
- Local and remote source buffers use the same policy after source resolution.

No state is stored in guide files. No migration or document schema change exists.
