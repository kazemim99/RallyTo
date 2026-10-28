using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Diagnostics;
using Rallyto.Core.Application.Abstractions;
using Rallyto.Core.Domain.Abstractions;

namespace Rallyto.Infrastructure.Core.Persistence;

public sealed class AuditingInterceptor(TimeProvider clock, ICurrentUserService currentUser) : SaveChangesInterceptor
{
    public override ValueTask<InterceptionResult<int>> SavingChangesAsync(
        DbContextEventData eventData, InterceptionResult<int> result, CancellationToken cancellationToken = default)
    {
        if (eventData.Context is { } context)
            Stamp(context);
        return base.SavingChangesAsync(eventData, result, cancellationToken);
    }

    public override InterceptionResult<int> SavingChanges(DbContextEventData eventData, InterceptionResult<int> result)
    {
        if (eventData.Context is { } context)
            Stamp(context);
        return base.SavingChanges(eventData, result);
    }

    private void Stamp(DbContext context)
    {
        var now = clock.GetUtcNow().UtcDateTime;
        var by = currentUser.UserId?.ToString();
        foreach (var entry in context.ChangeTracker.Entries<IAuditableEntity>())
        {
            if (entry.State == EntityState.Added)
                entry.Entity.MarkCreated(now, by);
            else if (entry.State == EntityState.Modified)
                entry.Entity.MarkModified(now, by);
        }
    }
}
