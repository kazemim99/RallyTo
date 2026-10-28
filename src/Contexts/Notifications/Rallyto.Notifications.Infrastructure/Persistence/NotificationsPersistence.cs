using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Rallyto.Notifications.Application.Abstractions;
using Rallyto.Notifications.Domain;

namespace Rallyto.Notifications.Infrastructure.Persistence;

internal sealed class NotificationConfiguration : IEntityTypeConfiguration<Notification>
{
    public void Configure(EntityTypeBuilder<Notification> builder)
    {
        builder.ToTable("notifications");
        builder.HasKey(n => n.Id);
        builder.Property(n => n.Id).ValueGeneratedNever();
        builder.Property(n => n.Code).HasMaxLength(64);
        builder.Property(n => n.Category).HasConversion<string>().HasMaxLength(16);
        builder.Property(n => n.Title).HasMaxLength(200);
        builder.Property(n => n.Body).HasMaxLength(1000);
        builder.Property(n => n.DeepLink).HasMaxLength(200);
        // CAP delivers at least once: one notification per source event and recipient (design D9).
        builder.HasIndex(n => new { n.SourceEventId, n.RecipientId }).IsUnique();
        builder.HasIndex(n => new { n.RecipientId, n.InInbox, n.NotifiedAt });
        builder.HasIndex(n => n.NotifiedAt);
        builder.Ignore(n => n.IsRead);
    }
}

internal sealed class NotificationPreferencesConfiguration : IEntityTypeConfiguration<NotificationPreferences>
{
    public void Configure(EntityTypeBuilder<NotificationPreferences> builder)
    {
        builder.ToTable("notification_preferences");
        builder.HasKey(p => p.Id);
        builder.Property(p => p.Id).HasColumnName("user_id").ValueGeneratedNever();
    }
}

internal sealed class DeviceTokenConfiguration : IEntityTypeConfiguration<DeviceToken>
{
    public void Configure(EntityTypeBuilder<DeviceToken> builder)
    {
        builder.ToTable("device_tokens");
        builder.HasKey(t => t.Id);
        builder.Property(t => t.Id).ValueGeneratedNever();
        builder.Property(t => t.Token).HasMaxLength(DeviceToken.MaxTokenLength);
        builder.Property(t => t.Platform).HasMaxLength(16);
        builder.Property(t => t.RevokedReason).HasMaxLength(100);
        builder.HasIndex(t => t.Token).IsUnique();
        builder.HasIndex(t => t.UserId);
        builder.Ignore(t => t.IsActive);
    }
}

internal sealed class NotificationRepository(NotificationsDbContext db) : INotificationRepository
{
    public Task<bool> ExistsAsync(Guid sourceEventId, Guid recipientId, CancellationToken cancellationToken) =>
        db.Notifications.AnyAsync(n => n.SourceEventId == sourceEventId && n.RecipientId == recipientId, cancellationToken);

    public async Task<Notification?> GetAsync(Guid id, CancellationToken cancellationToken) => await db.Notifications.FindAsync([id], cancellationToken);

    public async Task<IReadOnlyList<Notification>> InboxAsync(Guid recipientId, int skip, int take, CancellationToken cancellationToken) =>
        await db.Notifications.AsNoTracking().Where(n => n.RecipientId == recipientId && n.InInbox)
            .OrderByDescending(n => n.NotifiedAt).ThenByDescending(n => n.Id).Skip(skip).Take(take).ToListAsync(cancellationToken);

    public Task<int> CountInboxAsync(Guid recipientId, CancellationToken cancellationToken) =>
        db.Notifications.CountAsync(n => n.RecipientId == recipientId && n.InInbox, cancellationToken);

    public Task<int> UnreadCountAsync(Guid recipientId, CancellationToken cancellationToken) =>
        db.Notifications.CountAsync(n => n.RecipientId == recipientId && n.InInbox && n.ReadAt == null, cancellationToken);

    public Task MarkAllReadAsync(Guid recipientId, DateTime now, CancellationToken cancellationToken) =>
        db.Notifications.Where(n => n.RecipientId == recipientId && n.ReadAt == null).ExecuteUpdateAsync(s => s.SetProperty(n => n.ReadAt, now), cancellationToken);

    public Task<int> PurgeOlderThanAsync(DateTime cutoff, CancellationToken cancellationToken) =>
        db.Notifications.Where(n => n.NotifiedAt < cutoff).ExecuteDeleteAsync(cancellationToken);

    public void Add(Notification notification) => db.Notifications.Add(notification);

    public async Task<NotificationPreferences?> PreferencesAsync(Guid userId, CancellationToken cancellationToken) =>
        await db.Preferences.FindAsync([userId], cancellationToken);

    public void Add(NotificationPreferences preferences) => db.Preferences.Add(preferences);

    public Task<DeviceToken?> TokenAsync(string token, CancellationToken cancellationToken) =>
        db.DeviceTokens.FirstOrDefaultAsync(t => t.Token == token, cancellationToken);

    public async Task<IReadOnlyList<DeviceToken>> ActiveTokensAsync(Guid userId, CancellationToken cancellationToken) =>
        await db.DeviceTokens.Where(t => t.UserId == userId && t.RevokedAt == null).ToListAsync(cancellationToken);

    public Task RevokeAllTokensAsync(Guid userId, string reason, DateTime now, CancellationToken cancellationToken) =>
        db.DeviceTokens.Where(t => t.UserId == userId && t.RevokedAt == null)
            .ExecuteUpdateAsync(s => s.SetProperty(t => t.RevokedAt, now).SetProperty(t => t.RevokedReason, reason), cancellationToken);

    public void Add(DeviceToken token) => db.DeviceTokens.Add(token);
}
