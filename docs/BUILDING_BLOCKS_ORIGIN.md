# Building blocks origin

Rallyto's shared projects under `src/BuildingBlocks/` were ported from AsanRezerve (`c:\Repos\Booking`), design
decision D1. The port was made from:

- **Commit:** `c10bd20e0d16576abc7fb71075782496e6a47a22`. This is AsanRezerve's `master` on 2026-10-05, "docs(openspec):
  sync living specs and knowledge after the 2026-10-05 round". The working tree had 3 uncommitted files, none in the
  ported projects.
- **Ported on:** 2026-10-23.

The code was **adapted, not copied verbatim**. Rallyto builds with nullable reference types and warnings as errors
in every project, and AsanRezerve's code does not compile cleanly that way: obsolete serialization constructors on
exceptions, and `null` passed where `string` is required in `Result.Success()`. Type names and the patterns they
encode were kept so knowledge transfers between the two products.

| Rallyto project | Ported from | What was kept | What was dropped or changed |
|---|---|---|---|
| `Rallyto.Core.Domain` | `AsanRezerve.Core.Domain` (`Base/`, `Abstractions/`, `Exceptions/`) | `Entity<TId>` with audit fields, `AggregateRoot<TId>` with domain events and `CheckRule`, `ValueObject`, `DomainEvent`, `IBusinessRule`, `BusinessRuleViolationException` | Soft delete (`IsDeleted`), aggregate `Version` (EF `xmin` is used instead), specifications, event store, every excluded folder, money/address/salon value objects. The phone number type moved to Identity (design D11). |
| `Rallyto.Core.Application` | `AsanRezerve.Core.Application` | `ICommand`/`IQuery` with cache members, `Result<T>`, `ErrorResult`, pipeline behaviors Logging, Validation, Performance and Caching, application exceptions | `TransactionBehavior`: it committed whichever unit of work was registered last, so it was replaced by per-context unit-of-work markers (design D12). Also dropped: Authorization and Idempotency behaviors (not needed yet), payments and SMS types (SMS now lives in Identity), and `IDateTimeProvider` (`TimeProvider` is used directly). |
| `Rallyto.Infrastructure.Core` | `AsanRezerve.Infrastructure.Core` | CAP registration with the once-per-process guard (PostgreSQL outbox, schema `cap`, in-memory transport), HybridCache over Redis with a circuit breaker, UTC `DateTime` conversion, audit stamping, current user service | `EfCoreUnitOfWork` rewritten as `EfUnitOfWork<TContext>`, which dispatches domain events and then saves changes plus integration events in one CAP transaction. Snake_case naming is applied in every context; AsanRezerve referenced the package but never called it. Event store, custom outbox and the in-memory event bus were dropped. |
| `Rallyto.Infrastructure.Web` | `AsanRezerve.API`, `.Infrastructure.Security`, `.Infrastructure.Observability` | The response envelope `{success, statusCode, message, data, metadata}` and the error envelope, exception mapping, JWT validation (HS256, zero skew, `Token-Expired`), the SignalR `access_token` extractor, the authenticated fallback policy, the Serilog-as-provider pipeline, sensitive-data masking, request telemetry | `statusCode` is a number in error responses too (AsanRezerve wrote a string). Rate limiting uses only the built-in ASP.NET Core limiter (AsanRezerve also used AspNetCoreRateLimit). Dropped: AES encryption, business-hours and age policies, the log store database, the admin observability API. |

Where AsanRezerve's code and its documentation disagreed, the code was treated as the source.
