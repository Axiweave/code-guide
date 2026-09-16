# Command Contract: Custom Guide Display

## Guide display preference

The package exposes `code-guide-guide-display-buffer-action` in the editor's complete buffer-display action format.

- Nil preserves established guide-opening behavior.
- A configured action controls placement, window reuse, sizing, and related display policy.
- The preference applies when a guide is shown, not when its document is parsed or loaded.
- The preference is independent from the existing source display preference.

A bottom-window configuration can use the editor's native bottom display action or side-window action with a bottom side.

## `code-guide-open-file`

**Input**: A local or remote guide filename.

**Output**: A loaded guide buffer.

**Display contract**:

- It does not select or display the guide buffer.
- It does not consume the guide display preference.
- Reopening the same complete filename returns the same guide buffer.
- Different complete filenames retain distinct guide buffers.

## `code-guide-open`

**Input**: A local or remote guide filename.

**Output**: The loaded guide is shown and selected.

**Display contract**:

- It delegates parsing and buffer creation to `code-guide-open-file`.
- It applies the current guide display preference when showing the buffer.
- Nil preserves the current default behavior.
- A valid bottom action selects a bottom window that shows the guide.
- Native fallback and errors remain visible when an action cannot display the guide.

## `code-guide-open-project-guide`

**Input**: The current project and an optional guide selection when several guides match.

**Output**: The selected guide is shown and selected.

**Display contract**:

- It delegates display to `code-guide-open`.
- It applies the same guide display preference as direct opening.
- It adds no separate project-specific placement rule.

## Source visits and previews

`code-guide-visit`, `code-guide-preview`, and `code-guide-visit-other-window` keep using the source display preference.

- Guide placement does not change source placement.
- Preview keeps the guide selected and visible.
- Remote source identity remains attached to the originating guide.
