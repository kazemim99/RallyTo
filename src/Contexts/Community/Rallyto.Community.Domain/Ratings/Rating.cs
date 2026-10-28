using Rallyto.Core.Domain.Base;
using Rallyto.Core.Domain.Exceptions;

namespace Rallyto.Community.Domain.Ratings;

/// <summary>The fixed tag list of spec player-ratings › Rating content.</summary>
[Flags]
public enum RatingTags
{
    None = 0,
    OnTime = 1,
    Friendly = 2,
    FairCalls = 4,
    GoodRally = 8,
    Sportsmanship = 16,
    WellOrganised = 32,
}

/// <summary>How the ratee's declared level compared with how they played.</summary>
public enum LevelAccuracy
{
    Lower = 1,
    AboutRight = 2,
    Higher = 3,
}

/// <summary>
/// One player's rating of another for one Completed match (design D7). It is immutable once submitted, hidden
/// until revealed (double-blind), and only an admin can remove it.
/// </summary>
public sealed class Rating : AggregateRoot<Guid>
{
    public const int MaxTags = 3;
    public const int MaxNoteLength = 500;

    private Rating() { }

    public Guid MatchId { get; private set; }
    public Guid SportId { get; private set; }
    public Guid RaterId { get; private set; }
    public Guid RateeId { get; private set; }
    public int Stars { get; private set; }
    public RatingTags Tags { get; private set; }
    public LevelAccuracy Level { get; private set; }
    public string? PrivateNote { get; private set; }
    public DateTime SubmittedAt { get; private set; }

    /// <summary>The match's rating window end; a hidden rating is revealed then at the latest.</summary>
    public DateTime WindowClosesAt { get; private set; }

    public DateTime? RevealedAt { get; private set; }
    public DateTime? RemovedAt { get; private set; }
    public Guid? RemovedBy { get; private set; }
    public string? RemovalReason { get; private set; }

    public bool IsRevealed => RevealedAt is not null;

    /// <summary>Whether the rating feeds the public aggregates.</summary>
    public bool Counts => IsRevealed && RemovedAt is null;

    /// <summary>Eligibility against the match is checked by <see cref="Matches.Match.EnsureCanRate"/> before this.</summary>
    public static Rating Create(Guid matchId, Guid sportId, Guid raterId, Guid rateeId, int stars, IReadOnlyCollection<RatingTags> tags,
        LevelAccuracy? level, string? privateNote, DateTime now, DateTime windowClosesAt)
    {
        if (stars is < 1 or > 5)
            throw new BusinessRuleViolationException("INVALID_STARS", "امتیاز باید بین ۱ تا ۵ ستاره باشد.");
        var distinct = tags.Where(t => t != RatingTags.None).Distinct().ToList();
        if (distinct.Count > MaxTags)
            throw new BusinessRuleViolationException("TOO_MANY_TAGS", $"حداکثر {MaxTags} برچسب می‌توانید انتخاب کنید.");
        if (distinct.Any(t => !Enum.IsDefined(t)))
            throw new BusinessRuleViolationException("INVALID_TAG", "برچسب انتخاب‌شده معتبر نیست.");
        if (level is not { } accuracy || !Enum.IsDefined(accuracy))
            throw new BusinessRuleViolationException("LEVEL_ACCURACY_REQUIRED", "بگویید سطح اعلام‌شدهٔ این بازیکن چقدر درست بود.");
        var note = string.IsNullOrWhiteSpace(privateNote) ? null : privateNote.Trim();
        if (note is { Length: > MaxNoteLength })
            throw new BusinessRuleViolationException("NOTE_TOO_LONG", $"یادداشت حداکثر {MaxNoteLength} نویسه است.");
        return new Rating
        {
            Id = Guid.NewGuid(),
            MatchId = matchId,
            SportId = sportId,
            RaterId = raterId,
            RateeId = rateeId,
            Stars = stars,
            Tags = distinct.Aggregate(RatingTags.None, (all, t) => all | t),
            Level = accuracy,
            PrivateNote = note,
            SubmittedAt = now,
            WindowClosesAt = windowClosesAt,
        };
    }

    public void Reveal(DateTime now) => RevealedAt ??= now;

    public void Remove(Guid adminId, string reason, DateTime now)
    {
        if (string.IsNullOrWhiteSpace(reason))
            throw new BusinessRuleViolationException("REASON_REQUIRED", "دلیل حذف را بنویسید.");
        if (RemovedAt is not null)
            return;
        RemovedAt = now;
        RemovedBy = adminId;
        RemovalReason = reason.Trim();
    }
}
