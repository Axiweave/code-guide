# Data Model: Remote Guide Support

## Guide Document

Represents one parsed code guide.

### Fields

- `version`: Guide format version.
- `title`: Display title.
- `description`: Optional guide summary.
- `root`: Path used as the base for node locations.
- `nodes`: Ordered guide-node tree.
- `source-file`: Complete local or remote identity of the selected guide file.

### Validation rules

- `source-file` remains unchanged after parsing and reload.
- A relative `root` resolves against the directory of `source-file`.
- Reload reads from the same `source-file` identity.
- Two documents with different expanded source filenames must not share one guide buffer.

### State transitions

1. **Selected**: The user supplies a guide filename.
2. **Parsed**: The file content becomes a guide document with its source identity.
3. **Loaded**: The document is installed in its guide buffer.
4. **Reloaded**: A new document replaces the prior document from the same source identity.

## Remote Identity

Represents the identity encoded by an Emacs remote filename.

### Fields

- Connection method.
- User, when present.
- Host.
- Hop chain, when present.
- Remote localname.

### Validation rules

- The package treats the complete filename as opaque.
- Relative path resolution preserves all remote identity fields.
- The package does not convert one remote method to another.
- The package does not remove the remote prefix or substitute a local path.

## Guide Node

Represents one item in the guide tree.

### Fields

- `id`: Unique identifier within the document.
- `title`: Display label.
- `comment`: Optional reading guidance.
- `location`: Optional source location.
- `children`: Ordered child nodes.
- `parent`: Parent node reference.
- `depth`: Render depth.

### Relationships

- A guide document owns zero or more top-level guide nodes.
- A guide node can own child nodes.
- A guide node can reference one source location.

## Source Location

Represents a source target relative to the guide root.

### Fields

- `file`: Source filename.
- `line`: One-based recorded line.
- `column`: Optional one-based column.
- `symbol`: Optional semantic label.
- `anchor`: Optional nearby text anchor.

### Validation rules

- The resolved file must remain inside the guide root unless outside-root access is enabled.
- The resolved file must be readable.
- The line and optional column must be positive.
- The line must exist in the source file.
- A missing nearby anchor produces a warning rather than changing remote identity.

## Remote Project

Represents the project used for guide discovery.

### Fields

- Project root filename, which can be local or remote.
- Configured guide-location globs.
- Matching guide filenames.

### Validation rules

- Each match retains the project root's remote identity.
- Selection uses complete guide filenames when more than one match exists.
- No match reports the configured search locations.
