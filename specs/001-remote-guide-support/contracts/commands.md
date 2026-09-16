# Command Contract: Remote Guides

The package keeps one command interface for local and remote guides. Remote support does not add protocol-specific commands.

## `code-guide-open`

### Input

An existing guide filename accepted by Emacs. The filename may be local or remote.

### Observable behavior

- Reads and parses the selected guide through its file-name handler.
- Opens a guide buffer identified by the complete expanded guide filename.
- Preserves the selected filename as the document source.
- Reports parse and remote access failures without opening a local substitute.

## `code-guide-open-project-guide`

### Input

The current buffer's project context.

### Observable behavior

- Searches configured guide locations below the project root.
- Preserves a remote project root in every result.
- Opens the only match directly.
- Prompts with complete filenames when several guides match.
- Reports a user error when no guide matches.

## Guide navigation commands

The existing `RET`, `SPC`, `o`, `n`, `p`, `[`, `]`, `u`, `d`, `TAB`, `S-TAB`, and `U` controls retain their current meanings.

### Observable behavior

- Source visits resolve from the active guide document.
- Visits and previews open the resolved local or remote source file.
- Preview keeps the guide selected.
- Navigation and folding do not depend on connection method.

## `code-guide-reload`

### Observable behavior

- Reads the same complete guide source filename.
- Keeps the current node when its identifier survives.
- Never changes the connection method, host, or path.

## `code-guide-validate`

### Observable behavior

- Validates containment, readability, line bounds, columns, and anchors through the selected filename handler.
- Diagnostics include the complete resolved source filename.
- Remote failures remain actionable and do not trigger protocol or local fallback.

## Compatibility

- Local guide behavior remains supported.
- Standard TRAMP works without TRAMP-RPC.
- TRAMP-RPC works when its own prerequisites and remote environment are available.
- The package declares no TRAMP-RPC dependency and contains no `/ssh:` or `/rpc:` method branch.
