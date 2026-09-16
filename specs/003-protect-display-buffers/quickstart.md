# Quickstart: Validate Protected Display Buffers

## Prerequisites

- Emacs 29.1 or later.
- This repository available locally.
- The package loaded from the repository root.
- A valid `.codeguide.json` file with at least one source location.

See [the customization contract](contracts/customization.md) for matching and fallback rules.

## Repository checks

Run:

```sh
make test
make compile
```

Expected outcomes:

- Every ERT check passes.
- Byte compilation completes without warnings.

## Default compatibility

1. Evaluate `(setq code-guide-protected-buffer-name-patterns nil code-guide-protected-buffer-predicate nil)`.
2. Open a valid guide.
3. Preview a node with `SPC`.
4. Visit nodes with `RET` and `o`.

Expected outcomes:

- Source placement follows the established source display action.
- Preview keeps the guide selected.
- Normal visits select the source.
- The guide remains visible.

## Protect an assistant buffer by name

1. Create or display a buffer named `*claude-code[code-guide]*`.
2. Evaluate `(setq code-guide-protected-buffer-name-patterns '("\\`\\*claude-code"))`.
3. Keep the assistant buffer visible beside the guide.
4. Preview and visit nodes with `SPC`, `RET`, and `o`.

Expected outcomes:

- The assistant buffer remains in its original window after every action.
- The source appears in another safe window.
- Preview keeps the guide selected.
- Visits select the source window.

## Protect a buffer with the predicate

1. Evaluate `(setq code-guide-protected-buffer-predicate (lambda (buffer) (string= (buffer-name buffer) "*protected-by-predicate*")))`.
2. Use a name that does not match any configured regexp.
3. Keep that buffer visible.
4. Preview or visit a source node.

Expected outcomes:

- The package passes the candidate buffer to the predicate.
- A non-nil result protects the buffer.
- The source uses another destination.

## Confirm OR behavior

1. Protect one visible buffer by name.
2. Protect a different visible buffer through the predicate.
3. Preview a source node.

Expected outcome: Both buffers remain visible because either mechanism is sufficient.

## Override an unsafe source preference

1. Configure a source display action that would otherwise choose the protected buffer's window.
2. Preview or visit a source node.

Expected outcomes:

- The protected buffer remains in its original window.
- The unsafe result is rejected.
- The source appears in a fresh split or new frame.

## Confirm constrained-layout failure

1. Arrange the frame so every reusable non-guide window shows a protected buffer.
2. Prevent the frame from creating another split.
3. Use an environment where a new frame cannot be created.
4. Preview or visit a source node.

Expected outcomes:

- The command reports a clear user error.
- No protected buffer is replaced.
- The command does not use the selected window as an unchecked fallback.

## Confirm runtime changes

1. Open a guide and keep another buffer visible.
2. Add a matching pattern or change the predicate without restarting Emacs.
3. Preview a node.
4. Remove the matching rule and preview again.

Expected outcomes:

- The first action after the addition protects the buffer.
- The first action after removal lets normal source placement consider it again.

## Confirm guide placement independence

1. Configure the guide display action for a bottom or side window.
2. Configure protected source buffers.
3. Open a guide and preview a node.

Expected outcomes:

- Guide placement follows the guide display preference.
- Source placement follows the source display preference after protected windows are excluded.
- Protection does not merge the two display preferences.

## Remote parity

When a standard TRAMP or optional remote guide is available:

1. Open the remote guide.
2. Keep a protected local or remote assistant buffer visible.
3. Preview and visit a remote source node.

Expected outcomes:

- Protected-window behavior matches the local workflow.
- The guide document and source buffer keep their complete remote filenames.
- Protection does not substitute a local path or connection method.
