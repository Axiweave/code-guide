# code-guide.el

Agent-authored, hierarchical code-reading guides for Emacs.

An AI agent inspects a repository and writes a `.codeguide.json` file: a tree
of nodes, each pointing at a source location and explaining why it matters.
Emacs renders that guide as a read-only tree. You read the narrative in the
guide buffer and jump or preview into the code.

This is not an xref or tag browser. It is a persistent reading itinerary
through a codebase.

## Install

Requires Emacs 29.1 or later. No other dependencies.

```elisp
(use-package code-guide
  :load-path "path/to/code-guide"
  :commands (code-guide-open code-guide-open-project-guide))
```

## Use

1. Let an agent write a guide. `skills/code-guide-author/SKILL.md` teaches an
   agent how. `examples/authentication.codeguide.json` shows the shape.
   `code-guide.schema.json` is the JSON schema.
2. `M-x code-guide-open` and pick the file, or `M-x code-guide-open-project-guide`
   to find one under `.code-guides/`, `.codeguide.json`, or `docs/code-guides/`.

Keys in the guide buffer:

| Key       | Command                          |
|-----------|----------------------------------|
| `RET`     | visit the node's location        |
| `o`       | visit in another window          |
| `SPC`     | preview, keep the guide selected |
| `n` / `p` | next / previous node             |
| `]` / `[` | next / previous sibling          |
| `u` / `d` | parent / first child             |
| `TAB`     | fold or unfold the subtree       |
| `S-TAB`   | fold all                         |
| `U`       | unfold all                       |
| `g`       | reload the guide from disk       |
| `v`       | validate every location          |
| `q`       | quit                             |

Reload keeps the node at point and the fold state when the ids survive.
Validation writes a navigable `*Code Guide Validation*` buffer.

A location is `file` plus `line`. When the node also carries an `anchor`
string, the package searches `code-guide-anchor-search-range` lines around the
recorded line and uses the nearest match, so a guide survives line drift.

## Guide format

```json
{
  "version": 1,
  "title": "How request authentication works",
  "description": "Follow one request from socket read to authorization.",
  "root": ".",
  "nodes": [
    {
      "id": "route-auth",
      "title": "Authentication gate",
      "comment": "Credentials are checked before dispatch.",
      "location": {
        "file": "src/auth.c",
        "line": 210,
        "column": 1,
        "symbol": "authenticate_request",
        "anchor": "int authenticate_request("
      },
      "children": []
    }
  ]
}
```

`root` is relative to the guide file. `file` is relative to `root`. A node
without `location` is narrative only.

## Develop

```sh
make compile
make test
```

`docs/HANDOFF.md` is the original design document.

## License

GPL-3.0-or-later. See `LICENSE`.
