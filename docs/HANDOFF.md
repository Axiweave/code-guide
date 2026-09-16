# code-guide.el — Implementation Handoff

## 1. Product idea

`code-guide.el` is an Emacs package for **agent-authored, hierarchical code-reading guides**.

An AI coding/research agent inspects a repository and produces a guide whose nodes point to source locations and explain why each location matters. Emacs renders that guide as an interactive tree. The user reads the narrative in the guide buffer while jumping/previewing the corresponding code.

This is deliberately **not** another xref/tag browser.

The package's core abstraction is:

> A persistent, structured reading itinerary through a codebase, authored by a human or agent.

Typical guide shapes:

- request lifecycle
- subsystem architecture
- vulnerability root-cause trail
- data-flow explanation
- control-flow explanation
- "how feature X works"
- "how this PR changes the system"
- onboarding path through an unfamiliar project

## 2. Package name

Working package name: **`code-guide`**

Primary Lisp file:

```text
code-guide.el
```

Suggested feature:

```elisp
(provide 'code-guide)
```

Suggested guide extension:

```text
*.codeguide.json
```

Avoid naming it `codetour` / `code-tour`; Microsoft's VS Code CodeTour already owns that concept/name, and an agent skill using `code-tour` also exists.

Avoid `sourcetrail`; Sourcetrail is an established source explorer and had an Emacs integration.

## 3. Core user experience

A guide might logically look like:

```text
Request lifecycle
├─ Entry point                 src/server.c:120
│  Receives and normalizes the incoming request.
│
├─ Routing                     src/router.c:88
│  Resolves the route and selects a handler.
│
│  ├─ Authentication           src/auth.c:210
│  │  Authentication is checked after route selection.
│  │
│  └─ Handler                  src/handler.c:55
│     Main feature-specific operation.
│
└─ Persistence                 src/storage.c:310
   Final state mutation reaches storage here.
```

The left/guide buffer is persistent. The source buffer is a viewing surface.

Desired interaction:

```text
RET       visit node location
SPC/TAB   preview node without permanently selecting source window
n         next node in reading order
p         previous node in reading order
]         next sibling
[         previous sibling
u         parent
TAB       fold/unfold subtree (if not used for preview)
S-TAB     cycle subtree/global folding
g         reload guide from disk
v         validate locations
q         bury/quit guide
```

Exact default bindings may change, but the concepts should exist.

## 4. Design goals

### Must-have

1. Agent-friendly file format.
2. Tree hierarchy is preserved.
3. Every code node can contain:
   - title
   - file
   - line
   - optional column
   - explanation/comment
   - children
4. Fast keyboard navigation.
5. Preview and visit operations.
6. Relative paths resolved against a guide/repository root.
7. Read-only rendered view.
8. Reload after an agent rewrites the guide.
9. Validation with useful diagnostics.
10. No LSP/ctags requirement.

### Strongly desired

1. Keep guide window visible while source changes.
2. Highlight the current guide node.
3. Remember visit/read state for the Emacs session.
4. Support non-location narrative nodes.
5. Optional robust anchors to survive line drift.
6. Open a guide directly from project root.
7. Optional `consult` integration later.

### Non-goals for MVP

- generating guides inside Emacs
- replacing xref
- building a source-code graph
- semantic indexing
- chat UI
- LSP client functionality
- modifying source code

The agent is the generator. Emacs is the reader/navigation UI.

## 5. Guide file format

Use JSON for MVP because Emacs has built-in JSON parsing (`json-parse-buffer`) and agents reliably emit it.

Recommended extension:

```text
.codeguide.json
```

Top-level schema:

```json
{
  "version": 1,
  "title": "How request authentication works",
  "description": "Follow one request from socket read to authorization.",
  "root": ".",
  "nodes": []
}
```

A node:

```json
{
  "id": "route-auth",
  "title": "Authentication gate",
  "comment": "The route has already been selected. This function checks credentials before dispatch.",
  "location": {
    "file": "src/auth.c",
    "line": 210,
    "column": 1,
    "symbol": "authenticate_request",
    "anchor": "int authenticate_request("
  },
  "children": []
}
```

Narrative-only nodes omit `location`:

```json
{
  "id": "authorization-phase",
  "title": "Authorization phase",
  "comment": "These nodes explain the transition from identity to permission checks.",
  "children": [...]
}
```

### Why include `symbol` and `anchor`?

Line numbers drift.

For MVP, `file + line` is authoritative.

Later, when opening a node:

1. open file
2. if `anchor` exists, search near the recorded line (e.g. ±80 lines)
3. if an exact nearby anchor is found, use it
4. otherwise fall back to the recorded line
5. optionally use `symbol` through imenu/xref in a future version

This preserves the simple agent contract while making guides much less brittle.

## 6. JSON schema

See `code-guide.schema.json` in this handoff package.

Validation should check at least:

- supported `version`
- title is present
- node IDs are unique
- relative path stays within root unless explicitly allowed
- file exists
- line >= 1
- line <= file line count
- column, if present, >= 1
- children is a list
- anchor mismatch should be a warning, not a hard failure

## 7. Emacs architecture

Suggested files:

```text
code-guide.el
code-guide-parse.el       ; optional split after MVP
code-guide-render.el      ; optional split after MVP
code-guide-test.el
README.md
```

For the first implementation, keeping everything in `code-guide.el` is fine.

### Internal structs

Use `cl-defstruct`:

```elisp
(cl-defstruct code-guide-location
  file line column symbol anchor)

(cl-defstruct code-guide-node
  id title comment location children parent depth)

(cl-defstruct code-guide-document
  version title description root nodes source-file)
```

Populate `parent` and `depth` after parsing for navigation.

### Major mode

Create:

```elisp
(define-derived-mode code-guide-mode special-mode "Code-Guide"
  ...)
```

The rendered buffer should be read-only.

Each rendered heading/node should carry text properties such as:

```text
code-guide-node
code-guide-node-id
```

Do not parse the rendered textual indentation to recover structure. The parsed object model is the source of truth.

### Tree rendering

MVP should use built-in Emacs facilities and avoid a hard dependency on Magit.

Recommended approach:

- render one heading line per node
- use indentation and Unicode/ASCII markers for hierarchy
- use `outline-minor-mode` or explicit overlay/invisibility folding
- attach node objects through text properties

Possible display:

```text
▾ Request processing
  ● Entry point                     src/server.c:120
  ▾ Routing                         src/router.c:88
    ● Authentication                src/auth.c:210
    ● Main handler                  src/handler.c:55
  ● Persistence                     src/storage.c:310
```

The comment can appear below the heading:

```text
  ● Authentication                  src/auth.c:210
      Authentication happens after the route is selected.
```

Provide a customization controlling whether comments are always visible.

### Navigation model

Maintain a flattened depth-first list of visible/all nodes.

Commands:

```elisp
code-guide-next-node
code-guide-previous-node
code-guide-next-sibling
code-guide-previous-sibling
code-guide-parent
code-guide-first-child
```

`next` / `previous` should initially mean depth-first reading order, including children.

### Visiting locations

Core helper:

```elisp
(code-guide--visit-node NODE &optional preview)
```

Behavior:

1. resolve file against document root
2. `find-file-noselect`
3. display buffer using configurable display action
4. go to line/column
5. attempt nearby anchor repair
6. pulse/highlight target line temporarily
7. for preview, keep selection in guide buffer
8. for visit, select source window

Useful built-ins:

- `find-file-noselect`
- `display-buffer`
- `goto-char`
- `forward-line`
- `pulse-momentary-highlight-one-line`

### Window behavior

Default desired layout:

```text
+----------------------+---------------------------------------+
| code-guide tree      | source file                           |
|                      |                                       |
| > Authentication     | int authenticate_request(...)         |
|   Handler            | {                                     |
|   Persistence        |   ...                                 |
|                      |                                       |
+----------------------+---------------------------------------+
```

Do not aggressively delete the user's windows.

Use `display-buffer` with a customizable action/alist.

Suggested variable:

```elisp
(defcustom code-guide-display-buffer-action ...)
```

### Reload

`code-guide-reload` should:

- reread the source guide JSON
- reparse
- preserve current node by `id` if it still exists
- rerender
- preserve folding where reasonable
- report validation errors clearly

This matters because an agent may regenerate the file while the user is reading it.

## 8. Public API

Suggested initial public commands:

```text
M-x code-guide-open
M-x code-guide-open-project-guide
M-x code-guide-reload
M-x code-guide-next-node
M-x code-guide-previous-node
M-x code-guide-visit
M-x code-guide-preview
M-x code-guide-toggle-subtree
M-x code-guide-validate
```

Useful Lisp API:

```elisp
(code-guide-open-file FILE)
(code-guide-parse-file FILE)
(code-guide-validate-document DOCUMENT)
(code-guide-current-node)
(code-guide-visit-node NODE)
```

Avoid exposing implementation-specific render internals.

## 9. Suggested keymap

Initial proposal:

```elisp
(defvar-keymap code-guide-mode-map
  :parent special-mode-map
  "RET" #'code-guide-visit
  "o"   #'code-guide-visit-other-window
  "SPC" #'code-guide-preview
  "n"   #'code-guide-next-node
  "p"   #'code-guide-previous-node
  "]"   #'code-guide-next-sibling
  "["   #'code-guide-previous-sibling
  "u"   #'code-guide-parent
  "TAB" #'code-guide-toggle-subtree
  "g"   #'code-guide-reload
  "v"   #'code-guide-validate
  "q"   #'quit-window)
```

If `SPC` conflicts with normal scrolling expectations, make preview `.` or `P`; choose after testing.

## 10. Project-root resolution

Resolution order:

1. guide's explicit `root`
2. directory containing guide file
3. project root via `project-current`, only when explicitly configured

Recommended semantics:

- `root` is interpreted relative to guide file's directory
- source `file` is interpreted relative to resolved root
- never silently resolve against `default-directory` from an unrelated buffer

## 11. Guide discovery

Later convenience command:

```text
M-x code-guide-open-project-guide
```

Search in:

```text
.code-guides/*.codeguide.json
.codeguide.json
docs/code-guides/*.codeguide.json
```

Do not make discovery necessary for MVP. `code-guide-open` with a file picker is enough.

## 12. Validation UX

Validation should produce either:

- a dedicated `*Code Guide Validation*` buffer using `compilation-mode`, or
- `user-error` for one fatal parse problem plus a diagnostics buffer for multiple issues

Diagnostics should be navigable.

Example:

```text
guide.codeguide.json: node auth-check: src/auth.c:9999: line outside file
guide.codeguide.json: node storage: src/store.c:88: warning: anchor not found near line
```

## 13. Optional future integrations

### Consult

Expose all nodes as candidates:

```text
Authentication       src/auth.c:210
Handler              src/handler.c:55
Persistence          src/storage.c:310
```

Preview candidate location live.

Possible command:

```text
code-guide-consult-node
```

Keep this optional.

### Embark

Actions on a node candidate:

- visit
- preview
- copy `file:line`
- copy comment
- reveal in guide

### Xref

Possible export of a guide subtree into xref results, but not core architecture.

### Org export/import

Potential later support for authoring human-readable Org guides.

Do not make Org the canonical MVP storage format because the JSON tree is easier for agents to emit and validate.

## 14. Agent workflow

Expected end-to-end flow:

```text
User: "Explain how authentication works in this repository."

Agent:
1. inspects code
2. follows relevant control/data flow
3. writes `.code-guides/auth.codeguide.json`
4. validates every file and line
5. summarizes that the guide is ready

User:
M-x code-guide-open
select `.code-guides/auth.codeguide.json`

Emacs:
- displays hierarchy
- previews source as user moves through guide
```

The package should not care which agent created the file.

## 15. Guide quality principles

A guide is **not** a search-result dump.

Bad:

```text
auth.c:10
auth.c:42
auth.c:90
handler.c:22
```

Good:

```text
Authentication path
├─ Request enters authenticated routing
│  Why this matters...
├─ Credentials are parsed
│  What state is produced...
├─ Identity is validated
│  Important invariant...
└─ Permission decision
   This is the actual authorization boundary...
```

Tree edges should communicate conceptual containment or branching.

Comments should answer:

- Why am I looking here?
- What should I notice?
- How does this node relate to its parent?
- What should I understand before moving to the next node?

## 16. MVP acceptance criteria

A first release is successful if:

1. Emacs 29+ can open a valid `.codeguide.json`.
2. It renders a hierarchical read-only guide.
3. `n`/`p` navigate nodes.
4. `TAB` folds/unfolds subtrees.
5. `RET` jumps to exact source line.
6. preview shows source while retaining focus in guide.
7. comments display under nodes.
8. reload works after file changes.
9. malformed paths/lines produce clear validation errors.
10. tests cover parsing, navigation, root resolution, and anchor fallback.

## 17. Tests

Use ERT.

At minimum:

```text
code-guide-parse/basic
code-guide-parse/nested
code-guide-parse/narrative-node
code-guide-parse/duplicate-id
code-guide-resolve/relative-root
code-guide-resolve/missing-file
code-guide-location/line
code-guide-location/nearby-anchor
code-guide-navigation/depth-first
code-guide-navigation/siblings
code-guide-navigation/parent
code-guide-reload/preserve-node-id
```

Tests should create temporary repositories/files using `make-temp-file` / `make-temp-name`.

## 18. Implementation order

### Phase 1 — vertical slice

1. JSON parser
2. node structs
3. render buffer
4. `RET` visit
5. `n` / `p`

At that point the package is already usable.

### Phase 2 — reading UX

1. preview
2. tree folding
3. parent/sibling navigation
4. comments
5. target-line highlight
6. stable window behavior

### Phase 3 — robustness

1. validation
2. anchor fallback
3. reload preserving node
4. tests
5. customization

### Phase 4 — optional integrations

1. Consult
2. project guide discovery
3. progress/visited state
4. Org conversion
5. guide series / links between guides

## 19. Example

See:

```text
examples/authentication.codeguide.json
```

## 20. Agent-authoring skill

A reusable skill is included at:

```text
skills/code-guide-author/SKILL.md
```

Its job is to teach an implementation/coding agent how to investigate a repository and produce a **high-quality guide**, rather than merely emit syntactically valid JSON.

That skill should remain editor-independent: it creates the `.codeguide.json`; `code-guide.el` consumes it.
