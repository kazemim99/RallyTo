using Microsoft.EntityFrameworkCore;
using Rallyto.Infrastructure.Core.Persistence;
using Rallyto.Notifications.Domain;

namespace Rallyto.Notifications.Infrastructure.Persistence;

public sealed class NotificationsDbContext(DbContextOptions<NotificationsDbContext> options) : RallytoDbContext(options)
{
    public override string Schema => NotificationsModule.Schema;

    public DbSet<Notification> Notifications => Set<Notification>();
    public DbSet<NotificationPreferences> Preferences => Set<NotificationPreferences>();
    public DbSet<DeviceToken> DeviceTokens => Set<DeviceToken>();
}
