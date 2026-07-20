# DevOps & Infrastructure

Use this when reviewing infrastructure or when the task is "set up CI/CD / review infra".

## CI/CD principles
- **Every commit is potentially shippable**: green pipeline = deployable.
- **Fast feedback loops**: keep CI under 10 minutes; parallelize where possible.
- **Build once, deploy many**: build the artifact once and promote it through environments (dev → staging → prod).
- **Rollback strategy**: every deploy must have a documented and tested rollback path.

## Environment hygiene
- **Never hardcode config or secrets** — use environment variables or secret managers.
- **Dev/staging/prod parity**: if it works locally but not in prod, environments are diverging.
- **Infrastructure as Code**: all infra changes go through code review (Terraform, Pulumi, etc.).
- **Immutable infrastructure**: prefer replacing instances over patching them.

## Observability (you can't fix what you can't see)
- **Structured logging**: machine-readable (JSON), includes request IDs and user context.
- **Metrics**: latency, error rate, saturation — the RED method (Rate, Errors, Duration).
- **Alerting**: alert on user-visible impact, not noise; every alert should have a clear action.
- **Tracing**: distributed traces for cross-service calls.

## Security baseline
- Principle of least privilege on all credentials and service accounts.
- Secrets never in source control, never in logs.
- Dependencies: audit regularly; automate vulnerability scanning in CI.
- All external input is validated at system boundaries.
