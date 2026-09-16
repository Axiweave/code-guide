# Customization Contract: Protected Display Buffers

## Name-pattern preference

The package exposes `code-guide-protected-buffer-name-patterns`, a runtime list of buffer-name regexps.

- Each value uses Emacs regexp syntax and `string-match-p` semantics.
- Each regexp matches the candidate buffer's current name.
- Any matching regexp protects the buffer.
- An invalid regexp error propagates before source display changes a window.
- Nil means no name-based protection.
- Changes apply to the next source action.
- The default list is empty.

## Predicate preference

The package exposes `code-guide-protected-buffer-predicate`, an optional runtime predicate.

- The package calls it with one argument: the candidate buffer object.
- A non-nil return value protects that buffer.
- A predicate error propagates before source display changes a window.
- Nil means no predicate-based protection.
- Changes apply to the next source action.
- The default is nil.

## Combination contract

Name patterns and the predicate use OR semantics. A buffer is protected when either mechanism protects it. Readers can configure either mechanism alone or both together.

## Source command contract

The policy applies to:

- `code-guide-preview`
- `code-guide-visit`
- `code-guide-visit-other-window`

For each command:

- A window that showed a protected buffer when the action started must not become the source destination.
- The guide window must remain separate from the source destination.
- A safe destination still follows `code-guide-display-buffer-action` when possible.
- Preview keeps the guide window selected.
- Visit and visit-in-other-window select the accepted source destination.

## Fallback and failure contract

- The configured source action result is accepted only when it is a live, safe destination.
- If a user display rule replaces a protected window, the package restores its protected buffer and rejects that window.
- A fresh split can serve as the first fallback.
- A new-frame display can serve as the final fallback.
- A protected window is never selected as the destination, even when it already shows the requested source elsewhere.
- Standard actions exclude protected windows before they can replace a buffer.
- Restoration is last-resort recovery only when a custom action ignores the exclusion and mutates a protected window.
- Every fallback result must pass the same destination validation before explicit buffer assignment or acceptance.
- If no safe destination exists, the command signals a clear user error.
- Failure must leave every protected buffer visible.
- The implementation must not silently use the selected window as an unchecked fallback.

## Compatibility contract

- Empty name patterns and a nil predicate preserve established behavior.
- Guide placement remains controlled by `code-guide-guide-display-buffer-action`.
- Source placement remains controlled by `code-guide-display-buffer-action`, subject only to protected-window rejection.
- Local, standard remote, and optional remote source buffers use the same policy.
- Guide files contain no protection configuration.
