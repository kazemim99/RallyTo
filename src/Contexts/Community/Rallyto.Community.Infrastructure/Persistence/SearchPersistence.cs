using System.Text.Json;
using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Rallyto.Community.Application.Search;
using Rallyto.Community.Domain.Search;

namespace Rallyto.Community.Infrastructure.Persistence;

internal sealed class SavedSearchConfiguration : IEntityTypeConfiguration<SavedSearch>
{
    private static readonly JsonSerializerOptions Json = new(JsonSerializerDefaults.Web);

    public void Configure(EntityTypeBuilder<SavedSearch> builder)
    {
        builder.ToTable("saved_searches");
        builder.HasKey(s => s.Id);
        builder.Property(s => s.Id).ValueGeneratedNever();
        builder.Property(s => s.Name).HasMaxLength(40).IsRequired();
        // Criteria are read whole and never queried into, except sport and city, which are duplicated below.
        builder.Property(s => s.Criteria)
            .HasConversion(c => JsonSerializer.Serialize(c, Json), j => JsonSerializer.Deserialize<SearchCriteria>(j, Json)!)
            .HasColumnType("jsonb");
        builder.Property<Guid>("sport_id");
        builder.Property<int>("city_id");
        builder.HasIndex("sport_id", "city_id");
        builder.HasIndex(s => s.OwnerId);
    }
}

internal sealed class SavedSearchRepository(CommunityDbContext db) : ISavedSearchRepository
{
    public Task<SavedSearch?> GetAsync(Guid id, CancellationToken cancellationToken) => db.SavedSearches.FirstOrDefaultAsync(s => s.Id == id, cancellationToken);

    public async Task<IReadOnlyList<SavedSearch>> ListByOwnerAsync(Guid ownerId, CancellationToken cancellationToken) =>
        await db.SavedSearches.Where(s => s.OwnerId == ownerId).OrderBy(s => s.Name).ToListAsync(cancellationToken);

    public async Task<IReadOnlyList<SavedSearch>> ListAlertingAsync(Guid sportId, int cityId, CancellationToken cancellationToken) =>
        await db.SavedSearches
            .Where(s => s.AlertsEnabled && EF.Property<Guid>(s, "sport_id") == sportId && EF.Property<int>(s, "city_id") == cityId)
            .ToListAsync(cancellationToken);

    public void Add(SavedSearch search) => db.SavedSearches.Add(search);

    public void Remove(SavedSearch search) => db.SavedSearches.Remove(search);
}
