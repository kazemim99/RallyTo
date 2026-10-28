using Microsoft.EntityFrameworkCore.Design;
using Rallyto.Infrastructure.Core.Persistence;

namespace Rallyto.Notifications.Infrastructure.Persistence;

internal sealed class NotificationsDesignTimeFactory : IDesignTimeDbContextFactory<NotificationsDbContext>
{
    public NotificationsDbContext CreateDbContext(string[] args) => new(DesignTimeOptions.For<NotificationsDbContext>(NotificationsModule.Schema));
}
