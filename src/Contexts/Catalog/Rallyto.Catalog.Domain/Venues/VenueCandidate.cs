using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;

namespace Rallyto.Catalog.Domain.Venues;

public enum CandidateStatus
{
    Pending = 1,
    Approved = 2,
    Merged = 3,
    Rejected = 4,
}

/// <summary>
/// A club found by the Google Places import, waiting for an admin (design D15). Never visible to players. Its
/// place id stays known after a decision, so a rejected place does not come back on the next import.
/// </summary>
public sealed class VenueCandidate : AggregateRoot<Guid>
{
    private VenueCandidate() { }

    public int CityId { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public string? Address { get; private set; }
    public double? Latitude { get; private set; }
    public double? Longitude { get; private set; }
    public string PlaceId { get; private set; } = string.Empty;
    public string? Keyword { get; private set; }
    public DateTime ImportedAt { get; private set; }
    public CandidateStatus Status { get; private set; }
    public Guid? ResolvedVenueId { get; private set; }
    public string? RejectionReason { get; private set; }
    public Guid? ReviewedBy { get; private set; }
    public DateTime? ReviewedAt { get; private set; }

    public static VenueCandidate Import(int cityId, string name, string? address, double? latitude, double? longitude, string placeId, string? keyword, DateTime now)
    {
        if (string.IsNullOrWhiteSpace(placeId) || string.IsNullOrWhiteSpace(name))
            throw new BusinessRuleViolationException("INVALID_CANDIDATE", "شناسهٔ مکان و نام لازم است.");
        return new VenueCandidate
        {
            Id = Guid.NewGuid(),
            CityId = cityId,
            Name = name.Trim(),
            Address = address?.Trim(),
            Latitude = latitude,
            Longitude = longitude,
            PlaceId = placeId.Trim(),
            Keyword = keyword,
            ImportedAt = now,
            Status = CandidateStatus.Pending,
        };
    }

    public void MarkApproved(Guid venueId, Guid adminId, DateTime now) => Resolve(CandidateStatus.Approved, venueId, null, adminId, now);

    public void MarkMerged(Guid venueId, Guid adminId, DateTime now) => Resolve(CandidateStatus.Merged, venueId, null, adminId, now);

    public void Reject(string reason, Guid adminId, DateTime now) => Resolve(CandidateStatus.Rejected, null, reason, adminId, now);

    private void Resolve(CandidateStatus status, Guid? venueId, string? reason, Guid adminId, DateTime now)
    {
        if (Status != CandidateStatus.Pending)
            throw new InvalidAggregateStateException("CANDIDATE_ALREADY_REVIEWED", "این مورد قبلاً بررسی شده است.");
        Status = status;
        ResolvedVenueId = venueId;
        RejectionReason = reason;
        ReviewedBy = adminId;
        ReviewedAt = now;
    }
}
