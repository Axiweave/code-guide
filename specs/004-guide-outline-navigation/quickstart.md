# Quickstart: Validate Guide Outline Navigation

## Prerequisites

- Emacs 29.1 or later
- This repository checkout
- No optional completion package is required

## Automated checks

From the repository root:

```sh
make test
make compile
```

Expected outcomes:

- The ERT suite passes.
- Byte compilation completes without warnings.

## Standard Imenu scenario

1. Open `examples/authentication.codeguide.json` with `M-x code-guide-open`.
2. Run `M-x imenu`.
3. Search for a nested node title.
4. Select its hierarchy-path entry.
5. Confirm the guide selects that node without visiting its source.

Expected outcome: Every guide node is available in depth-first reading order through standard Imenu.

## Folded-node scenario

1. Fold a parent with `TAB`.
2. Run `M-x imenu`.
3. Select one of the hidden descendants.

Expected outcome: The guide reveals the folded path and selects the descendant.

## Duplicate-title scenario

Use a guide with two sibling nodes named `Check` under a parent named `Request`.

Expected entries:

```text
Request / Check [1]
Request / Check [2]
```

Select each entry and confirm it reaches a different node in reading order.

## Narrative and text scenario

Use a guide that contains:

- A narrative node without a source location.
- A title with punctuation.
- A title with non-ASCII text.

Run `M-x imenu` and select each entry.

Expected outcome: All entries appear with their title text preserved and each selection reaches its node.

## Reload scenario

1. Open a guide and inspect `M-x imenu` entries.
2. Add, remove, and rename nodes in the guide file.
3. Reload with `g`.
4. Run `M-x imenu` again.

Expected outcome: The second outline contains all current nodes and no removed nodes.

## Empty-guide scenario

1. Open a valid guide whose node list is empty.
2. Run `M-x imenu`.

Expected outcome: Imenu reports that no entries are available. Code Guide does not signal a package-specific error.

## Optional Consult scenario

If Consult is already installed:

1. Open a guide.
2. Run `M-x consult-imenu`.
3. Search for and select a nested node.

Expected outcome: Consult shows and selects the same Code Guide entries. Code Guide does not require Consult configuration.
