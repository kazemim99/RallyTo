namespace Rallyto.Tests.Commons.Api;

public sealed record AvailabilityView(
    Guid Id,
    Guid SportId,
    string SportCode,
    IReadOnlyList<NamedRef> Venues,
    string Kind,
    string[] Weekdays,
    string? Date,
    string StartTime,
    string EndTime,
    string[] Formats,
    string? Note,
    string Status,
    string? ValidUntil);

public static class AvailabilityApi
{
    public const string Root = "/api/v1/availability";

    public static object Recurring(Guid sportId, Guid[] venueIds, string[] weekdays, string start, string end, string[]? formats = null, string? note = null) =>
        new { sportId, venueIds, kind = "Recurring", weekdays, date = (string?)null, startTime = start, endTime = end, formats = formats ?? ["Singles", "Doubles"], note, validUntil = (string?)null };

    public static object OneOff(Guid sportId, Guid[] venueIds, string date, string start, string end, string[]? formats = null) =>
        new { sportId, venueIds, kind = "OneOff", weekdays = Array.Empty<string>(), date, startTime = start, endTime = end, formats = formats ?? ["Doubles"], note = (string?)null, validUntil = (string?)null };
}
