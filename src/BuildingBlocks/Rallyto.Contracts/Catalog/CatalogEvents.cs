using Rallyto.Core.Application.Abstractions;

namespace Rallyto.Contracts.Catalog;

public static class CatalogTopics
{
    public const string VenueHidden = "rallyto.catalog.venue-hidden";
}

/// <summary>A club was hidden (for example it closed): Community drops it from availability and warns match participants.</summary>
public sealed record VenueHidden(Guid VenueId) : IntegrationEvent
{
    public override string Topic => CatalogTopics.VenueHidden;
}
