---
name: code-guide-author
description: Create a hierarchical .codeguide.json code-reading guide grounded in real repository files and line numbers. Use when asked to explain how code works, create a code comprehension guide, trace a feature or bug, explain architecture/control flow/data flow, prepare onboarding, or produce an Emacs code-guide.
---

# Code Guide Author

Create a **structured reading guide through a real codebase**.

The output is not documentation in the abstract and not a flat list of search hits. It is a curated navigation tree that tells a developer **where to read, in what order, and what to notice**.

Canonical output format:

```text
*.codeguide.json
```

## Goal

A good guide lets someone unfamiliar with the codebase open the guide in `code-guide.el` and understand the requested concept by walking through a small, intentionally selected set of source locations.

Each node should answer:

1. **Where should I look?**
2. **Why does this location matter?**
3. **What should I notice here?**
4. **How does it connect to the parent/next node?**

## Required workflow

### 1. Understand the user's question

Turn the request into a concrete comprehension target.

Examples:

- "How does authentication work?"
- "Where does untrusted input become trusted?"
- "Explain this bug's root cause."
- "How does a request reach the database?"
- "What changed in this PR?"
- "How does this scheduler choose a task?"

Do not begin by dumping every textual match.

### 2. Identify the conceptual spine

Before writing the guide, determine the shortest useful narrative.

Common spines:

```text
entry → parsing → transformation → decision → effect
```

```text
public API → abstraction → implementation → backend
```

```text
source → propagation → validation → sink
```

```text
trigger → state transition → callback → cleanup
```

```text
configuration → registration → dispatch → handler
```

The top-level tree should reflect this narrative.

### 3. Inspect the actual code

For every proposed location:

- confirm the file exists
- confirm the line number against the current checkout
- read enough surrounding code to explain it accurately
- follow relevant callees/callers when needed
- distinguish direct evidence from inference

Never invent a path, symbol, or line number.

### 4. Prefer semantic landmarks

A guide should usually point to:

- function/method definition
- important call site
- type/struct/class definition
- branch implementing a decision
- registration table
- state transition
- validation boundary
- mutation/sink
- key test demonstrating intended behavior

Avoid pointing to arbitrary lines in the middle of boilerplate when a better landmark exists.

### 5. Create hierarchy intentionally

Use children when they elaborate or branch from a parent.

Good:

```text
Routing
├─ route lookup
├─ authentication branch
│  ├─ token parsing
│  └─ identity validation
└─ handler dispatch
```

Bad:

```text
Routing
├─ file A
├─ file B
├─ file C
├─ file D
```

Hierarchy expresses reasoning, not directory structure.

### 6. Keep the guide selective

Default target:

- 5–15 location nodes for a focused mechanism
- 10–30 for a subsystem/architecture guide

Use more only when the user asks for exhaustive coverage.

Prefer one excellent landmark over five redundant references.

### 7. Write comments for reading

A node comment should be short but explanatory.

Good:

> The router has already normalized the path here. Notice that authentication is selected from route metadata before the handler is invoked.

Bad:

> This function authenticates the request.

Avoid merely restating identifiers.

### 8. Record robust anchors

For each source location, include when possible:

```json
"symbol": "authenticate_request",
"anchor": "int authenticate_request("
```

`anchor` should be a short exact source substring likely to remain recognizable after nearby edits.

Avoid anchors containing:

- generated values
- line numbers
- huge expressions
- unstable whitespace-heavy text

### 9. Validate before finishing

Re-open or inspect every referenced file.

Check:

- file exists
- line is correct
- line is inside the file
- anchor is present at or near the recorded line
- comment still matches the code
- node IDs are unique
- tree tells a coherent story

If the repository changes while you are generating the guide, re-check affected locations.

## Output schema

Top level:

```json
{
  "version": 1,
  "title": "Human-readable title",
  "description": "One or two sentences describing what the reader will understand.",
  "root": ".",
  "nodes": []
}
```

Location node:

```json
{
  "id": "unique-kebab-case-id",
  "title": "Short conceptual title",
  "comment": "What the reader should understand at this point.",
  "location": {
    "file": "relative/path/to/file.ext",
    "line": 123,
    "column": 1,
    "symbol": "optional_symbol_name",
    "anchor": "short exact source text"
  },
  "children": []
}
```

Narrative/group node:

```json
{
  "id": "group-id",
  "title": "Conceptual phase",
  "comment": "Why these child locations belong together.",
  "children": []
}
```

## Path rules

Use paths relative to `root`.

Prefer:

```text
src/auth.c
lib/router.py
crates/core/src/lib.rs
```

Do not emit machine-specific absolute paths unless explicitly requested.

## Line-number rules

Line numbers are 1-based.

Point to the first line that best identifies the landmark, usually:

- definition line
- call line
- branch condition
- assignment/mutation
- registration entry

Do not point at the closing brace merely because it was the last line examined.

## ID rules

IDs must:

- be unique within the guide
- remain reasonably stable across regeneration
- use descriptive kebab-case

Good:

```text
request-entry
route-lookup
auth-token-parse
permission-check
database-write
```

Bad:

```text
node-1
step-7
foo
```

## Tree-writing patterns

### Feature flow

```text
Feature X
├─ Public entry
├─ Input normalization
├─ Core decision
│  ├─ Fast path
│  └─ Slow path
└─ Observable effect
```

### Security / vulnerability

```text
Security boundary
├─ Attacker-controlled source
├─ Propagation
├─ Expected validation
├─ Missing/incorrect invariant
└─ Dangerous operation
```

Be precise about whether attacker control or exploitability is proven versus suspected.

### Architecture

```text
Subsystem
├─ Interface / API
├─ State model
├─ Main implementation
├─ Backend integration
└─ Tests / invariants
```

### Bug root cause

```text
Bug
├─ Trigger
├─ Incorrect assumption
├─ State corruption / wrong branch
├─ Failure manifestation
└─ Fix or relevant regression test
```

## Guide quality checklist

Before saving, ask:

- Could a developer follow this without the chat transcript?
- Does the first node provide a meaningful entry point?
- Does every node earn its place?
- Do comments explain relationships, not just syntax?
- Does the tree encode the mental model?
- Are there any unexplained jumps between unrelated files?
- Are important branches represented as siblings/children?
- Did I omit noisy implementation details?
- Are all locations verified against the current checkout?

## Do not

- fabricate file paths
- guess line numbers
- output raw grep results as the guide
- make every function a node
- mirror the directory tree
- include irrelevant helper functions
- make unsupported claims in comments
- treat an LSP/xref result as sufficient evidence without reading the code

## Saving location

If the repository has no convention, prefer:

```text
.code-guides/<short-topic>.codeguide.json
```

Examples:

```text
.code-guides/authentication.codeguide.json
.code-guides/request-lifecycle.codeguide.json
.code-guides/cache-invalidation.codeguide.json
```

## Final response after creating a guide

Briefly state:

- guide path
- what it covers
- any important uncertainty or unverified dynamic behavior

Do not paste the entire guide into chat unless requested.
