# Issue tracker: Spec Kit

Spec Kit specifications and tasks are the local issue tracker for this repository.

## Source of truth

- A feature lives under `specs/<feature>/`.
- Its source files are `spec.md`, `plan.md`, and `tasks.md`.
- Spec Kit infrastructure lives under `.specify/`.
- Respect Spec Kit numbering and explicit `SPECIFY_FEATURE_DIRECTORY` overrides.
- Resolve current paths with `.specify/scripts/bash/check-prerequisites.sh --paths-only --json`.
- Never create `.sdd/` or separate issue files.

## Workflow

- Use `/speckit.specify` to create or update `spec.md`.
- Use `/speckit.plan` to create or update `plan.md`.
- Use `/speckit.tasks` to publish implementation tickets in `tasks.md`.
- Use `/speckit.implement` to implement tasks.
- Preserve task IDs, checkboxes, phases, and dependencies.
- Fetch a ticket by its feature path and task ID.

## Triage and discussion

- Record feature triage as `Status: <role>` near the top of `spec.md`.
- Record task triage as an indented `Status: <role>` below the task.
- Use checkboxes only for completion.
- Append feature discussion under `## Comments` in `spec.md`.
- Append task discussion below its task in `tasks.md`.

## Wayfinder

- Store the map in the feature-local `map.md`.
- Store child tasks in `tasks.md`.
- Record each child task's type, blocking task IDs, claimant, and answer below that task.
- Select the first unchecked, unclaimed task whose prerequisites are complete.
- Record the claimant before work starts.
- On resolution, record the answer and complete the checkbox.
- Append a decision summary and task reference to `map.md`.

## External references

GitHub issues and pull requests are external references. Local publication never creates external issues, comments, or labels.

Apply repository approval rules to requested external operations. Resolve fork versus upstream before selecting a target.
