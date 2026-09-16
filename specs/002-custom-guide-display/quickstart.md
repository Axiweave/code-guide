# Quickstart: Validate Custom Guide Display

## Prerequisites

- Emacs 29.1 or later.
- This repository available locally.
- The package loaded from the repository root.
- A valid `.codeguide.json` file for interactive checks.

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

1. Leave the guide display preference at nil.
2. Run `M-x code-guide-open` and select a valid guide.
3. Navigate, preview, validate, and reload the guide.

Expected outcomes:

- The guide uses the established default display behavior.
- Existing controls continue to work.
- Source preview keeps the guide selected and visible.

## Bottom guide placement

Set a complete bottom action:

```elisp
(setq code-guide-guide-display-buffer-action
      '((display-buffer-at-bottom)
        (window-height . 0.25)))
```

1. Run `M-x code-guide-open` and select a valid guide.
2. Observe the selected guide window.
3. Open the same guide again.

Expected outcomes:

- The guide appears in a bottom window.
- The guide window is selected.
- Reopening reuses the same guide buffer.
- The configured sizing behavior is honored when the frame permits it.

## Project guide placement

1. Keep the bottom guide action active.
2. Visit a file in a project with a supported guide location.
3. Run `M-x code-guide-open-project-guide`.

Expected outcome: The project guide uses the same bottom placement as direct opening.

## Source placement independence

1. Configure the guide action for the bottom.
2. Keep the source display preference at its default or set a different action.
3. Open a guide and preview a node with `SPC`.
4. Visit a node with `RET` and `o`.

Expected outcomes:

- The guide remains in its configured window.
- Preview keeps the guide selected.
- Source buffers follow the source preference, not the guide preference.

## Runtime preference change

1. Open a guide with the default preference.
2. Change the guide preference to the bottom action.
3. Open the same guide again without restarting Emacs.

Expected outcomes:

- The same guide buffer is reused.
- The new bottom placement applies immediately.

## Remote identity check

When a standard TRAMP or TRAMP-RPC guide is available:

1. Open the remote guide with the bottom action active.
2. Visit and preview a remote node.
3. Reload the guide.

Expected outcomes:

- Placement matches the local workflow.
- The guide document and source buffers retain their complete remote filenames.
- No local path or connection method replaces the selected remote identity.
