# Contract: Guide Outline Navigation

## Consumer interface

Each `code-guide-mode` buffer exposes its current guide nodes through the editor's standard Imenu interface. The package adds no separate search command.

## Entry membership and order

1. The index contains one entry for every parsed guide node.
2. Narrative nodes without source locations are included.
3. Entries follow the guide's depth-first reading order.
4. An empty guide returns no entries and does not signal a package error.
5. Fold state does not remove descendants from the index.

## Entry labels

1. Each label contains the node's full title path from the top level.
2. Path segments use ` / ` as the separator.
3. Equal titles under different parents are distinguished by their paths.
4. When siblings have identical titles, every member receives a one-based occurrence suffix: ` [1]`, ` [2]`, and so on.
5. Occurrence order follows guide reading order.
6. Titles retain punctuation and non-ASCII characters.

## Selection

1. Selecting an entry moves the guide buffer to its node.
2. If folded ancestors hide the node, selection reveals those ancestors first.
3. Selection does not visit source code or mark the node visited.
4. Selection does not change guide or source file identity.

## Freshness

1. Each outline request reflects the current successfully loaded guide tree.
2. Added and renamed nodes appear after reload.
3. Removed nodes do not remain after reload.
4. A failed reload leaves the last successful guide and outline behavior intact.

## Compatibility

1. Built-in `M-x imenu` consumes the interface.
2. Optional Imenu clients, including Consult, can consume the same interface without code-guide-specific configuration.
3. Completion style, ranking, presentation, and key bindings remain user configuration.
4. Existing movement, folding, preview, visit, validation, reload, display, and protected-buffer behavior remain unchanged.
