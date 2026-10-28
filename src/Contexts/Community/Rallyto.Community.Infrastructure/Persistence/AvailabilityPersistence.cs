using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.ChangeTracking;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Rallyto.Community.Application.Abstractions;
using Rallyto.Community.Domain.Availabilities;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.Infrastructure.Persistence;

internal sealed class AvailabilityConfiguration : IEntityTypeConfiguration<Availability>
{
    public void Configure(EntityTypeBuilder<Availability> builder)
    {
        builder.ToTable("availability");
        builder.HasKey(a => a.Id);
        builder.Property(a => a.Id).ValueGeneratedNever();
        builder.Property(a => a.Kind).HasConversion<string>().HasMaxLength(16);
        builder.Property(a => a.Status).HasConversion<string>().HasMaxLength(16);
        builder.Property(a => a.Weekdays).HasConversion<int>();
        builder.Property(a => a.Note).HasMaxLength(200);
        builder.Property<List<Guid>>("_venueIds").HasColumnName("venue_ids").HasColumnType("uuid[]");
        builder.Ignore(a => a.VenueIds);
        builder.Property<List<PlayFormat>>("_formats")
            .HasColumnName("formats")
            .HasConversion(v => v.Select(f => (int)f).ToArray(), v => v.Select(f => (PlayFormat)f).ToList())
            .HasColumnType("integer[]")
            .Metadata.SetValueComparer(new ValueComparer<List<PlayFormat>>((a, b) => a!.SequenceEqual(b!), v => v.Aggregate(0, (h, f) => HashCode.Combine(h, f)), v => v.ToList()));
        builder.Ignore(a => a.Formats);
        builder.Ignore(a => a.Window);
        // Search: active windows of a sport in a city; GIN index for "any of these clubs".
        builder.HasIndex(a => new { a.SportId, a.Status, a.CityId });
        builder.HasIndex("_venueIds").HasMethod("gin");
        builder.HasIndex(a => a.PlayerId);
    }
}

internal sealed class AvailabilityRepository(CommunityDbContext db) : IAvailabilityRepository
{
    /// <summary>FindAsync also returns a window added earlier in this unit of work and not yet saved (needed by domain event handlers).</summary>
    public async Task<Availability?> GetAsync(Guid id, CancellationToken cancellationToken) =>
        await db.Availability.FindAsync([id], cancellationToken);

    public async Task<IReadOnlyList<Availability>> ListByPlayerAsync(Guid playerId, CancellationToken cancellationToken) =>
        await db.Availability.Where(a => a.PlayerId == playerId && a.Status != AvailabilityStatus.Expired).OrderBy(a => a.StartMinute).ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<Availability>> ListByPlayerAndSportAsync(Guid playerId, Guid sportId, CancellationToken cancellationToken) =>
        await db.Availability.Where(a => a.PlayerId == playerId && a.SportId == sportId).ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<Availability>> ListContainingVenueAsync(Guid venueId, CancellationToken cancellationToken) =>
        await db.Availability.Where(a => EF.Property<List<Guid>>(a, "_venueIds").Contains(venueId)).ToListAsync(cancellationToken);

    public void Add(Availability availability) => db.Availability.Add(availability);

    public void Remove(Availability availability) => db.Availability.Remove(availability);
}
