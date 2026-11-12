# C# / .NET risk-based review reference

This reference is optional. First inspect the repository's actual framework/version, project files and tests. Do not run sample commands blindly or propose an unrelated framework upgrade.

| Topic | Failure to consider | Better evidence |
| --- | --- | --- |
| API contracts | Changed JSON naming, nullability, defaults, errors | Consumer/contract test with independently expected values |
| ASP.NET authentication/authorization | Tenant/resource-level access check missing | Negative cross-user or cross-tenant access test |
| Async + cancellation | Token not propagated; blocking .Result; lost exception | Cancellation and timeout behavior, observed cleanup |
| EF Core + DB | Wrong transaction boundary, migration incompatibility, N+1 | Provider-realistic integration test, migration smoke test, query plan |
| Retries + concurrency | Duplicate external side effects, races, partial commit | Duplicate-delivery and interleaving test with observable effects |
| DI scopes | Singleton captures a scoped dependency or per-request state | Registration graph and parallel usage where relevant |
| Error handling | Retried 4xx or failed operation reported as success | Inject 4xx/5xx/timeouts and inspect recovery |
| Logging + security | Credential or PII leaks, injection, SSRF, unsafe deserialization | Redacted logs, explicit negative test |
| Agent tool use | Untrusted prompt content triggers unauthorized actions | Tool boundary audit, adversarial instruction test |
| Performance | Unbounded query, serialization, network amplification | Representative benchmark or query analysis |

Inspect solution/test project files before choosing commands. Example **only**:

```bash
git diff --check
dotnet test YourSolution.sln
```

Record exact commands, exit status, test totals, and **what is not exercised**. A passing in-memory persistence test does not prove production database behavior.

**Drill-mode question examples (only when the developer chose Drill):** "What happens if the ERP call succeeds but the acknowledgement times out?" "Why is authorization in a UI guard insufficient?" "Which transaction invariant changes if this call moves outside the scope?"
