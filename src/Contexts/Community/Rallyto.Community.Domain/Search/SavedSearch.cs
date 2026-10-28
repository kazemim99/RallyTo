using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;

namespace Rallyto.Community.Domain.Search;

/// <summary>
/// A search a player keeps, optionally with alerts (spec partner-search › Saved searches and alerts): at most one
/// alert per 6 hours; matches in between are counted and sent as one digest.
/// </summary>
public sealed class SavedSearch : AggregateRoot<Guid>
{
    public const int MaxPerPlayer = 5;
    public static readonly TimeSpan AlertInterval = TimeSpan.FromHours(6);

    private SavedSearch() { }

    public Guid OwnerId { get; private set; }
    public string Name { get; private set; } = string.Empty;
    public SearchCriteria Criteria { get; private set; } = null!;
    public bool AlertsEnabled { get; private set; }
    public DateOnly? ExpiresOn { get; private set; }
    public int AlertsSent { get; private set; }
    public int PendingMatches { get; private set; }
    public DateTime? LastAlertAt { get; private set; }

    public static SavedSearch Create(Guid ownerId, string name, SearchCriteria criteria, bool alertsEnabled)
    {
        var search = new SavedSearch { Id = Guid.NewGuid(), OwnerId = ownerId };
        search.Update(name, criteria, alertsEnabled);
        return search;
    }

    public void Update(string name, SearchCriteria criteria, bool alertsEnabled)
    {
        var trimmed = (name ?? string.Empty).Trim();
        if (trimmed.Length is 0 or > 40)
            throw new BusinessRuleViolationException("INVALID_SAVED_SEARCH_NAME", "نام جستجو ۱ تا ۴۰ نویسه است.");
        Name = trimmed;
        Criteria = criteria;
        AlertsEnabled = alertsEnabled;
        ExpiresOn = criteria.Date;
    }

    public bool IsExpired(DateOnly todayTehran) => ExpiresOn is { } date && date < todayTehran;

    /// <summary>A new window or post matched. Returns the number of matches to alert about now, or 0 when throttled.</summary>
    public int RecordMatch(DateTime now, DateOnly todayTehran)
    {
        if (!AlertsEnabled || IsExpired(todayTehran))
            return 0;
        if (LastAlertAt is { } last && now - last < AlertInterval)
        {
            PendingMatches++;
            return 0;
        }

        var count = PendingMatches + 1;
        MarkAlerted(now);
        return count;
    }

    /// <summary>Sends the matches that arrived while throttled, once the interval has passed. Returns their count.</summary>
    public int FlushDigest(DateTime now)
    {
        if (PendingMatches == 0 || (LastAlertAt is { } last && now - last < AlertInterval))
            return 0;
        var count = PendingMatches;
        MarkAlerted(now);
        return count;
    }

    private void MarkAlerted(DateTime now)
    {
        AlertsSent++;
        LastAlertAt = now;
        PendingMatches = 0;
    }
}
