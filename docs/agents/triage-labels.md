# Triage roles

| Role | Local value | Meaning |
| --- | --- | --- |
| `needs-triage` | `needs-triage` | A maintainer must evaluate the item. |
| `needs-info` | `needs-info` | The item needs more information. |
| `ready-for-agent` | `ready-for-agent` | An agent can implement the item. |
| `ready-for-human` | `ready-for-human` | A human must implement the item. |
| `wontfix` | `wontfix` | The repository will not implement the item. |

For features, write the value as `Status: <role>` near the top of `spec.md`.

For tasks, write an indented `Status: <role>` below the task. Do not use task checkboxes for triage.
