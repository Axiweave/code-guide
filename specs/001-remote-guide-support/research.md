# Research: Remote Guide Support

## Decision: Keep remote access behind Emacs file functions

**Decision**: Continue to use standard Emacs file operations for guide reads, path expansion, project discovery, source visits, reloads, and validation. Add no TRAMP-specific or TRAMP-RPC-specific adapter.

**Rationale**: `code-guide.el` already uses `insert-file-contents`, `expand-file-name`, `file-readable-p`, `file-truename`, `file-expand-wildcards`, and `find-file-noselect`. Emacs dispatches these operations through file-name handlers. Standard TRAMP and TRAMP-RPC both implement the required operations.

**Alternatives considered**:

- Add separate SSH and RPC branches. Rejected because they duplicate native dispatch and couple the package to connection methods.
- Add a remote-file abstraction. Rejected because Emacs already provides the seam.
- Fall back from `/rpc:` to `/ssh:` automatically. Rejected because it changes the user's selected remote identity and can hide dependency or connection failures.

## Decision: Preserve remote identity through the existing source path

**Decision**: Keep the complete selected guide path in `code-guide-document-source-file`. Resolve relative guide roots and node paths from that path.

**Rationale**: `expand-file-name` preserves the method, user, host, hop chain, and remote path when the base is a TRAMP filename. The existing document model already stores the source path and uses it for reload.

**Alternatives considered**:

- Store remote identity in a second field. Rejected because it duplicates information already present in the canonical filename.
- Parse and rebuild TRAMP names in this package. Rejected because TRAMP owns that syntax and supports more methods and hop forms than this package should know.

## Decision: Use complete file identity for guide buffer names

**Decision**: Derive the guide buffer name from the complete expanded guide filename rather than only its basename.

**Rationale**: The current basename-only name causes two guides named `.codeguide.json` to reuse one buffer. A complete filename distinguishes local paths, remote methods, users, hosts, and hop chains with one rule.

**Alternatives considered**:

- Generate an arbitrary numeric suffix. Rejected because reopening the same guide would not reliably reuse its buffer.
- Add only the remote host. Rejected because users, methods, hop chains, and paths can still collide.

## Decision: Use the native containment predicate

**Decision**: Replace manual canonical-prefix containment with `file-in-directory-p` while preserving the existing outside-root opt-out.

**Rationale**: The native predicate defines directory containment, handles the directory itself, and dispatches through remote file-name handlers. It avoids string-prefix edge cases and keeps canonicalization behavior in Emacs.

**Alternatives considered**:

- Keep `string-prefix-p` over canonical paths. Rejected because containment should use a filesystem predicate rather than filename text.
- Compare parsed TRAMP structures manually. Rejected because this creates method-specific path logic.

## Decision: Keep project discovery native and prove it with integration checks

**Decision**: Retain project discovery through `project-current`, `project-root`, and `file-expand-wildcards`. Verify real transport behavior through the quickstart before adding any fallback.

**Rationale**: Emacs 31 implements `file-expand-wildcards` with `file-accessible-directory-p` and `directory-files`, which dispatch through remote file-name handlers. Its source marks the function with the `remote-wildcards` feature so TRAMP does not advise it. TRAMP-RPC implements the directory and path handlers used by this flow. The earlier scout warning identified possible limitations but provided no failing case against this shallow, single-directory glob pattern.

**Alternatives considered**:

- Replace glob expansion with custom recursive directory scans. Rejected because the configured guide locations are shallow and the native operation already expresses the requirement.
- Run a remote shell command. Rejected because it bypasses file-name handlers and would break non-shell methods.

## Decision: Report native remote errors without protocol fallback

**Decision**: Preserve errors from the selected file-name handler and add guide/path context only where the current command loses it.

**Rationale**: Authentication, missing dependency, disconnect, and timeout errors belong to the selected remote method. The package must not hide them or substitute local files.

**Alternatives considered**:

- Preflight TRAMP-RPC dependencies in `code-guide.el`. Rejected because dependency management belongs to TRAMP-RPC and would create a hard integration.
- Convert every remote error to one generic message. Rejected because it removes actionable handler details.

## Decision: Split permanent tests from real-connection validation

**Decision**: Keep deterministic tests for filename identity, path resolution, containment, and buffer separation. Document standard TRAMP and TRAMP-RPC end-to-end checks in `quickstart.md`.

**Rationale**: The repository has no configured SSH host, and the installed TRAMP-RPC package cannot load in batch mode because `msgpack` is absent. Network and credential tests cannot be deterministic in the normal suite.

**Alternatives considered**:

- Require an SSH server in every test run. Rejected because it makes the suite environment-dependent.
- Mock all remote reads. Rejected because mock echoes would test wiring rather than actual file-handler behavior.

## Resolved dependencies

- Emacs 29.1 remains the package baseline.
- Standard TRAMP ships with Emacs and requires no package dependency.
- TRAMP-RPC remains optional and owns its Emacs, TRAMP, `msgpack`, server, and host prerequisites.
- No new package dependency is required.
