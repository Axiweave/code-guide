# Quickstart: Validate Remote Guide Support

## Prerequisites

- Emacs 29.1 or later for local and standard TRAMP checks.
- An SSH-accessible host with a checkout of this repository for the standard TRAMP scenario.
- For TRAMP-RPC, its supported Emacs and TRAMP versions, `msgpack`, a supported remote host, and a deployed RPC server.
- A remote guide that references at least two source nodes.

Set the examples below to your actual user, host, and repository path.

## 1. Run deterministic checks

From the repository root:

```sh
make test
make compile
```

Expected outcome:

- All local and connection-free remote filename checks pass.
- Byte compilation finishes without warnings.

## 2. Validate standard TRAMP selection

In Emacs, run:

```text
M-x code-guide-open
/ssh:user@host:/path/to/repo/.codeguide.json
```

Expected outcome:

- The guide tree opens without a local copy.
- The guide buffer identifies the complete remote guide.

Then exercise:

```text
RET  visit source
SPC  preview source
n/p  traverse nodes
g    reload guide
v    validate guide
```

Expected outcome:

- Every source buffer retains the `/ssh:user@host:` identity.
- Preview keeps the guide selected.
- Reload reads the same remote guide.
- Validation reports complete remote paths.

## 3. Validate remote project discovery

Visit any file inside the remote checkout, then run:

```text
M-x code-guide-open-project-guide
```

Expected outcome:

- The command finds guides only in the configured project locations.
- If several guides exist, the prompt lists complete remote filenames.

## 4. Validate same-basename separation

Open two guides with the same basename from different remote identities:

```text
/ssh:user@host-a:/path/to/repo/.codeguide.json
/ssh:user@host-b:/path/to/repo/.codeguide.json
```

Expected outcome:

- Both guide buffers remain open.
- Reloading or following a node in one guide does not change the other.

## 5. Validate TRAMP-RPC

After confirming the TRAMP-RPC prerequisites, run:

```text
M-x code-guide-open
/rpc:user@host:/path/to/repo/.codeguide.json
```

Repeat the selection, navigation, reload, validation, project-discovery, and same-basename scenarios above.

Expected outcome:

- Behavior matches standard TRAMP.
- Source buffers retain the `/rpc:user@host:` identity.

## 6. Validate failures

Try an unreadable guide, a missing source file, and a node path outside the guide root.

Expected outcome:

- Each operation reports the remote guide or source path.
- No operation opens a local substitute.
- Standard TRAMP remains usable when TRAMP-RPC is absent.

## Current environment limit

This repository session has no configured SSH host. Its installed TRAMP-RPC package also lacks the `msgpack` dependency in batch Emacs. Run sections 2 through 6 in an environment that satisfies the listed prerequisites.
