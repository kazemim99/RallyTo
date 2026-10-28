namespace Rallyto.Tests.Commons.Api;

public sealed record SportRef(Guid Id, string Code, string Name);

public sealed record HostRef(Guid UserId, string DisplayName, string? Level);

public sealed record ParticipantView(Guid UserId, string DisplayName, string State, bool OutOfRange, string? Message);

public sealed record MatchView(
    Guid Id,
    string Visibility,
    string Status,
    SportRef Sport,
    string Format,
    int Capacity,
    int OpenSpots,
    NamedRef Venue,
    string Date,
    string StartTime,
    string EndTime,
    int DurationMinutes,
    DateTime StartsAt,
    HostRef Host,
    string MinLevel,
    string MaxLevel,
    string PartnerGender,
    bool CourtBooked,
    string? CostNote,
    string? Description,
    int PlayersBrought,
    string? ShareUrl,
    IReadOnlyList<ParticipantView>? Participants,
    string? MyState);

public sealed record ShareSummaryView(string Sport, string Format, string Venue, string City, string Date, string StartTime, string MinLevel, string MaxLevel, int OpenSpots, bool CourtBooked, string HostName, string? HostLevel);

public static class MatchApi
{
    public const string Posts = "/api/v1/matches/posts";
    public const string Invitations = "/api/v1/matches/invitations";
    public const string Matches = "/api/v1/matches";
    public const string Share = "/api/v1/share";

    /// <summary>Saturday 1405/08/02 is tomorrow relative to the test clock (Friday 1405/08/01, 12:30 Tehran).</summary>
    public const string Saturday = "1405/08/02";

    public static object Post(Guid sportId, Guid venueId, string format = "Singles", string date = Saturday, string startTime = "19:00", int? duration = null,
        int playersBrought = 0, string? minLevel = null, string? maxLevel = null, string partnerGender = "Any", bool courtBooked = true,
        string? costNote = null, string? description = null) => new
    {
        sportId, venueId, format, date, startTime, durationMinutes = duration, playersBrought, minLevel, maxLevel, partnerGender, courtBooked, costNote, description,
    };

    public static object Invitation(Guid sportId, Guid venueId, Guid[] invitees, string format = "Singles", string date = Saturday, string startTime = "19:00",
        int? duration = 90, int playersBrought = 0, string? message = null) => new
    {
        sportId, venueId, format, date, startTime, durationMinutes = duration, playersBrought, invitees, message,
    };
}
