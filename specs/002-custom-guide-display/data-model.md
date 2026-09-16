# Data Model: Custom Guide Display

## Guide Display Preference

Represents the reader's runtime policy for showing guide buffers.

### Attributes

- **Display action**: A complete editor buffer-display action. It can specify candidate display functions plus placement, reuse, sizing, frame, tab, or fallback parameters.
- **Default**: Nil, which delegates to the editor's established display behavior.
- **Scope**: One user preference applies to direct and project guide opens for local and remote guides.

### Validation rules

- The value must use the editor's accepted display-action format.
- Bottom placement must be expressible without a package-specific placement option.
- The value must not alter the source display preference.
- An unusable action follows the editor's normal fallback or error behavior.

### Relationships

- `code-guide-open` consumes `code-guide-guide-display-buffer-action` when it displays a guide buffer.
- `code-guide-open-project-guide` reaches the same behavior through `code-guide-open`.
- `code-guide-open-file` creates or refreshes a guide buffer without consuming the preference.
- Source visits and previews continue to consume the separate source display preference.
- Guide documents, nodes, and remote filenames remain unchanged.

### State transitions

1. **Default**: The preference is nil and guide opening uses established behavior.
2. **Configured**: The reader assigns a complete display action.
3. **Applied**: Each interactive guide open uses the current value.
4. **Changed**: A later open uses the new value without restarting or recreating the guide.

No state is stored in guide files. No migration or new document field exists.
