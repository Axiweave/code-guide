# Data Model: Guide Outline Navigation

## Existing source entities

### Guide document

The current parsed guide held by a guide buffer.

- **Nodes**: The document's depth-first node sequence.
- **Lifecycle**: Replaced after each successful reload.
- **Authority**: Supplies outline membership and order.

### Guide node

An existing node in the parsed guide tree.

- **Identity**: Unique node id within one guide.
- **Title**: Reader-facing text preserved in the outline.
- **Parent**: Optional containing node.
- **Children**: Ordered child nodes.
- **Location**: Optional. Narrative nodes remain valid without it.
- **Depth**: Existing nesting depth.

## Derived transient entities

### Sibling title group

A group of nodes that share one parent and an equal title.

- **Group key**: Parent identity plus exact title.
- **Total**: Number of siblings in the group.
- **Occurrence**: One-based position among equal-title siblings in reading order.
- **Validation**: When total exceeds one, every group member receives an occurrence number.

Top-level nodes use the guide root as their shared parent for grouping.

### Hierarchy label

The reader-facing name of one outline entry.

- **Segments**: Ancestor titles followed by the node title.
- **Separator**: ` / `.
- **Duplicate suffix**: ` [N]` on each segment whose sibling title group contains more than one node.
- **Text preservation**: Punctuation and non-ASCII text remain unchanged.
- **Uniqueness**: Unique node ids remain the selection identity even if display labels still collide through unusual title text.

Example:

```text
Request Flow / Authorization [1] / Policy Check
Request Flow / Authorization [2] / Policy Check
```

### Outline entry

A transient selection item derived from one guide node.

- **Display name**: The hierarchy label.
- **Target**: The guide node object.
- **Order**: The node's position in the guide's depth-first sequence.
- **Selection action**: Reveal folded ancestors and select the target node.
- **Persistence**: None. Entries are rebuilt from current guide state.

## State transitions

```text
Guide loaded or reloaded
        ↓
Current parsed node tree
        ↓ outline requested
Sibling groups counted
        ↓
Hierarchy labels and entries built in depth-first order
        ↓ entry selected
Folded ancestors revealed → target node selected
```

An empty guide produces no outline entries. Building or viewing the outline does not change folding, visited state, source locations, or files.
