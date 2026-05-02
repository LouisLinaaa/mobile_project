# scripts

Local automation and collaboration helpers used by the course-report build workflow.

## Main Files

- [install-git-hooks.sh](install-git-hooks.sh): installs `.githooks` as the repo hook path
- [hooks/pre-commit-format-check.sh](hooks/pre-commit-format-check.sh): staged Swift formatting checks
- [hooks/pre-push-build-check.sh](hooks/pre-push-build-check.sh): scoped iOS build gate before push
- [tests/notification_planner_check.swift](tests/notification_planner_check.swift): focused notification planner validation helper

## Related Docs

- [HOOKS.md](../HOOKS.md)
- [hooks/README.md](hooks/README.md)
