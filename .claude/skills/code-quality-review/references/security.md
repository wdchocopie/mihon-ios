# Security standards

Security is a code review concern, not just an infra one. Flag these as **🔴 Blockers**.
When you spot one, explain the exploit vector briefly — "this allows an attacker to..." —
so the developer understands the stakes, not just the rule.

- **Injection** (SQL, shell, LDAP): always use parameterized queries / safe APIs; never interpolate user input into queries or commands.
- **Authentication & authorization**: missing auth checks, insecure token storage, broken access control.
- **Secrets in code**: hardcoded API keys, passwords, tokens belong in environment variables or a secret manager, never in source.
- **Input validation**: all external input (user, API, file) must be validated at system boundaries; never trust it downstream.
- **Sensitive data exposure**: PII or credentials in logs, error messages, or API responses.
- **Dependency risk**: flag outdated or known-vulnerable packages.
