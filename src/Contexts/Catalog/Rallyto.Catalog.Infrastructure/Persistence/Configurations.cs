using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Rallyto.Catalog.Domain.Locations;
using Rallyto.Catalog.Domain.Sports;
using Rallyto.Catalog.Domain.Venues;

namespace Rallyto.Catalog.Infrastructure.Persistence;

internal sealed class SportConfiguration : IEntityTypeConfiguration<Sport>
{
    public void Configure(EntityTypeBuilder<Sport> builder)
    {
        builder.ToTable("sports");
        builder.HasKey(s => s.Id);
        builder.Property(s => s.Id).ValueGeneratedNever();
        builder.Property(s => s.Code).HasMaxLength(32).IsRequired();
        builder.HasIndex(s => s.Code).IsUnique();
        builder.Property(s => s.NameFa).HasMaxLength(64).IsRequired();
        builder.Property(s => s.NameEn).HasMaxLength(64).IsRequired();
        builder.Property(s => s.Surfaces).HasColumnType("integer[]");
        // Formats and tier wording are read whole and never queried into: JSON columns.
        builder.OwnsMany(s => s.Formats, f =>
        {
            f.ToJson("formats");
            f.Property(x => x.Format).HasConversion<string>();
        });
        builder.OwnsMany(s => s.Levels, l =>
        {
            l.ToJson("levels");
            l.Property(x => x.Tier).HasConversion<string>();
        });
        builder.Navigation(s => s.Formats).HasField("_formats");
        builder.Navigation(s => s.Levels).HasField("_levels");
    }
}

internal sealed class ProvinceConfiguration : IEntityTypeConfiguration<Province>
{
    public void Configure(EntityTypeBuilder<Province> builder)
    {
        builder.ToTable("provinces");
        builder.HasKey(p => p.Id);
        builder.Property(p => p.Id).ValueGeneratedNever();
        builder.Property(p => p.Name).HasMaxLength(64).IsRequired();
    }
}

internal sealed class CityConfiguration : IEntityTypeConfiguration<City>
{
    public void Configure(EntityTypeBuilder<City> builder)
    {
        builder.ToTable("cities");
        builder.HasKey(c => c.Id);
        builder.Property(c => c.Id).ValueGeneratedNever();
        builder.Property(c => c.Name).HasMaxLength(64).IsRequired();
        builder.HasIndex(c => c.ProvinceId);
        builder.HasOne<Province>().WithMany().HasForeignKey(c => c.ProvinceId);
    }
}

internal sealed class VenueConfiguration : IEntityTypeConfiguration<Venue>
{
    public void Configure(EntityTypeBuilder<Venue> builder)
    {
        builder.ToTable("venues");
        builder.HasKey(v => v.Id);
        builder.Property(v => v.Id).ValueGeneratedNever();
        builder.Property(v => v.Name).HasMaxLength(120).IsRequired();
        builder.Property(v => v.NormalizedName).HasMaxLength(160).IsRequired();
        builder.Property(v => v.Address).HasMaxLength(300);
        builder.Property(v => v.Phone).HasMaxLength(32);
        builder.Property(v => v.GooglePlaceId).HasMaxLength(256);
        builder.Property(v => v.SourceRef).HasMaxLength(200);
        builder.Property(v => v.SourceUrl).HasMaxLength(300);
        builder.Property(v => v.GoogleRating).HasPrecision(2, 1);
        builder.HasIndex(v => v.SourceRef).IsUnique().HasFilter("source_ref IS NOT NULL");
        builder.ComplexProperty(v => v.Profile, p =>
        {
            p.Property(x => x.Tagline).HasColumnName("tagline").HasMaxLength(200);
            p.Property(x => x.Description).HasColumnName("description").HasMaxLength(4000);
            p.Property(x => x.Website).HasColumnName("website").HasMaxLength(300);
            p.Property(x => x.Instagram).HasColumnName("instagram").HasMaxLength(300);
            p.Property(x => x.Telegram).HasColumnName("telegram").HasMaxLength(300);
            p.Property(x => x.WorkingHours).HasColumnName("working_hours").HasMaxLength(200);
            p.PrimitiveCollection(x => x.Amenities).HasColumnName("amenities");
            p.PrimitiveCollection(x => x.CourtTypes).HasColumnName("court_types");
        });
        builder.Property(v => v.Status).HasConversion<string>().HasMaxLength(16);
        builder.Property(v => v.Version).IsRowVersion();
        builder.HasIndex(v => new { v.CityId, v.Status });
        builder.HasIndex(v => v.GooglePlaceId).IsUnique().HasFilter("google_place_id IS NOT NULL");
        builder.HasOne<City>().WithMany().HasForeignKey(v => v.CityId);
        // Venue sports are filtered on ("venues offering padel"), so they get their own table.
        builder.OwnsMany(v => v.Sports, s =>
        {
            s.ToTable("venue_sports");
            s.WithOwner().HasForeignKey("venue_id");
            s.Property<int>("id").ValueGeneratedOnAdd();
            s.HasKey("id");
            s.Property(x => x.Setting).HasConversion<string>().HasMaxLength(16);
            s.Property(x => x.Surface).HasConversion<string>().HasMaxLength(24);
            s.HasIndex(x => x.SportId);
        });
        builder.Navigation(v => v.Sports).HasField("_sports");
        builder.OwnsMany(v => v.Images, i =>
        {
            i.ToTable("venue_images");
            i.WithOwner().HasForeignKey("venue_id");
            i.Property<int>("id").ValueGeneratedOnAdd();
            i.HasKey("id");
            i.Property(x => x.Path).HasMaxLength(300).IsRequired();
            i.HasIndex("venue_id", nameof(VenueImage.SortOrder));
        });
        builder.Navigation(v => v.Images).HasField("_images");
    }
}

internal sealed class VenueCandidateConfiguration : IEntityTypeConfiguration<VenueCandidate>
{
    public void Configure(EntityTypeBuilder<VenueCandidate> builder)
    {
        builder.ToTable("venue_candidates");
        builder.HasKey(c => c.Id);
        builder.Property(c => c.Id).ValueGeneratedNever();
        builder.Property(c => c.Name).HasMaxLength(200).IsRequired();
        builder.Property(c => c.Address).HasMaxLength(400);
        builder.Property(c => c.PlaceId).HasMaxLength(256).IsRequired();
        builder.Property(c => c.Keyword).HasMaxLength(64);
        builder.Property(c => c.RejectionReason).HasMaxLength(500);
        builder.Property(c => c.Status).HasConversion<string>().HasMaxLength(16);
        builder.HasIndex(c => c.PlaceId).IsUnique();
        builder.HasIndex(c => new { c.CityId, c.Status });
    }
}
