# vulnerable-app

A deliberately vulnerable NestJS app. It exists for one reason: to be the target
of the `/api-secure-report` run reproduced in
[`../SECURITY-REPORT.example.md`](../SECURITY-REPORT.example.md), so the example
report is a real run against real (if synthetic) code rather than a mock-up.

**Do not deploy this. Do not copy patterns out of it.** Every file here is wrong
on purpose — unscoped lookups, string-concatenated SQL, a JWT secret behind a
default, MD5 passwords, request bodies in the log, stack traces in responses,
CORS reflecting any origin.

It is not installable — there is no lockfile and no build. It is a fixture the
report reads, not an app anyone runs.
