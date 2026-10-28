using Microsoft.EntityFrameworkCore;
using Rallyto.Community.Application.Search;
using Rallyto.Community.Domain.Availabilities;
using Rallyto.Community.Domain.Players;
using Rallyto.Community.Domain.Search;
using Rallyto.Community.Infrastructure.Persistence;
using Rallyto.Core.Domain.SharedKernel;

namespace Rallyto.Community.Infrastructure.Search;

/// <summary>
/// SQL prefilter for partner search (design D6): one query joining windows, profiles, sport profiles and blocks in the
/// community schema. <see cref="PartnerMatchRules"/> re-checks every row in memory.
/// </summary>
internal sealed class PartnerSearchReader(CommunityDbContext db) : IPartnerSearchReader
{
    public async Task<IReadOnlyList<CandidateRow>> FindCandidatesAsync(SearchCriteria criteria, PlayerVisibilityFacts searcher, DateOnly todayTehran, int limit, CancellationToken cancellationToken)
    {
        var viewerId = searcher.UserId;
        var viewerGender = searcher.Gender;
        var viewerRestricted = searcher.Visibility == ProfileVisibility.SameGender;
        int startBound = criteria.FromMinute, endBound = criteria.ToMinute;

        var query =
            from a in db.Availability.AsNoTracking()
            join p in db.PlayerProfiles.AsNoTracking() on a.PlayerId equals p.Id
            from sp in p.Sports
            where a.SportId == criteria.SportId
                  && sp.SportId == a.SportId
                  && a.Status == AvailabilityStatus.Active
                  && a.CityId == criteria.CityId
                  && p.Status == ProfileStatus.Active
                  && p.Id != viewerId
                  && sp.Level >= criteria.MinLevel && sp.Level <= criteria.MaxLevel
                  && (p.Visibility == ProfileVisibility.Everyone || p.Gender == viewerGender)
                  && (!viewerRestricted || p.Gender == viewerGender)
                  && !db.Blocks.Any(b => (b.BlockerId == viewerId && b.BlockedId == p.Id) || (b.BlockerId == p.Id && b.BlockedId == viewerId))
                  && (a.EndMinute < endBound ? a.EndMinute : endBound) - (a.StartMinute > startBound ? a.StartMinute : startBound) >= PartnerMatchRules.MinimumOverlap
            select new { a, p, sp.Level, sp.Experience };

        if (criteria.Gender is { } gender)
            query = query.Where(x => x.p.Gender == gender);
        if (criteria.VenueIds.Count > 0)
        {
            var venues = criteria.VenueIds.ToList();
            query = query.Where(x => EF.Property<List<Guid>>(x.a, "_venueIds").Any(v => venues.Contains(v)));
        }

        if (criteria.Date is { } date)
        {
            var bit = IranianWeek.Of(date);
            query = query.Where(x =>
                (x.a.Kind == AvailabilityKind.OneOff && x.a.Date == date)
                || (x.a.Kind == AvailabilityKind.Recurring && (x.a.Weekdays & bit) != 0 && (x.a.ValidUntil == null || x.a.ValidUntil >= date)));
        }
        else
        {
            var days = criteria.Weekdays == IranianWeekdays.None ? (IranianWeekdays)127 : criteria.Weekdays;
            query = query.Where(x =>
                (x.a.Kind == AvailabilityKind.OneOff && x.a.Date >= todayTehran)
                || (x.a.Kind == AvailabilityKind.Recurring && (x.a.Weekdays & days) != 0));
        }

        var rows = await query.OrderByDescending(x => x.p.LastActiveAt).ThenBy(x => x.a.Id).Take(limit).ToListAsync(cancellationToken);
        return rows.Select(x => new CandidateRow(
                new WindowCandidate(x.a.Id, x.p.Id, x.p.Gender, x.p.Visibility, x.p.Status, x.Level, x.a.SportId, x.a.CityId, x.a.Status, x.a.Kind,
                    x.a.Weekdays, x.a.Date, x.a.ValidUntil, x.a.StartMinute, x.a.EndMinute, x.a.VenueIds, x.a.Formats),
                x.p.DisplayName, x.p.PhotoKey, x.p.BirthDate, x.p.LastActiveAt, x.Experience))
            .ToList();
    }
}
