using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Rallyto.Community.Domain.Players;

namespace Rallyto.Community.Infrastructure.Persistence;

internal sealed class PlayerProfileConfiguration : IEntityTypeConfiguration<PlayerProfile>
{
    public void Configure(EntityTypeBuilder<PlayerProfile> builder)
    {
        builder.ToTable("player_profiles");
        builder.HasKey(p => p.Id);
        builder.Property(p => p.Id).ValueGeneratedNever();
        builder.Property(p => p.DisplayName).HasMaxLength(40).IsRequired();
        builder.Property(p => p.Bio).HasMaxLength(300);
        builder.Property(p => p.PhotoKey).HasMaxLength(200);
        builder.Property(p => p.Gender).HasConversion<string>().HasMaxLength(8);
        builder.Property(p => p.Visibility).HasConversion<string>().HasMaxLength(16);
        builder.Property(p => p.Status).HasConversion<string>().HasMaxLength(16);
        builder.Property<List<Guid>>("_homeVenueIds").HasColumnName("home_venue_ids").HasColumnType("uuid[]");
        builder.Ignore(p => p.HomeVenueIds);
        builder.HasIndex(p => new { p.CityId, p.Status });

        // Sport profiles get their own table: partner search filters on sport and level.
        builder.OwnsMany(p => p.Sports, s =>
        {
            s.ToTable("sport_profiles");
            s.WithOwner().HasForeignKey("player_id");
            s.Property<int>("id").ValueGeneratedOnAdd();
            s.HasKey("id");
            s.Property(x => x.Level).HasConversion<int>();
            s.Property(x => x.Experience).HasConversion<int>();
            s.Property(x => x.Goals).HasConversion<int>();
            s.Property(x => x.Formats).HasConversion(
                    v => v.Select(f => (int)f).ToArray(),
                    v => v.Select(f => (Core.Domain.SharedKernel.PlayFormat)f).ToList())
                .HasColumnType("integer[]")
                .Metadata.SetValueComparer(new Microsoft.EntityFrameworkCore.ChangeTracking.ValueComparer<IReadOnlyList<Core.Domain.SharedKernel.PlayFormat>>(
                    (a, b) => a!.SequenceEqual(b!), v => v.Aggregate(0, (h, f) => HashCode.Combine(h, f)), v => v.ToList()));
            s.HasIndex(x => new { x.SportId, x.Level });
        });
        builder.Navigation(p => p.Sports).HasField("_sports");
    }
}

internal sealed class BlockConfiguration : IEntityTypeConfiguration<Block>
{
    public void Configure(EntityTypeBuilder<Block> builder)
    {
        builder.ToTable("blocks");
        builder.HasKey(b => b.Id);
        builder.Property(b => b.Id).ValueGeneratedNever();
        builder.HasIndex(b => new { b.BlockerId, b.BlockedId }).IsUnique();
        builder.HasIndex(b => b.BlockedId);
    }
}
