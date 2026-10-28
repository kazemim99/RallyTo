using Rallyto.Core.Application.Cqrs;
using Rallyto.Core.Application.Exceptions;
using Rallyto.Core.Application.Localization;

namespace Rallyto.Community.Application.Safety;

/// <param name="CompletionRate">Completed ÷ resolved matches in the period, or null when none were resolved.</param>
public sealed record UsageStatsView(
    string From,
    string To,
    int SignUps,
    int ActivePlayers,
    int Posts,
    int Invitations,
    int ConfirmedMatches,
    int CompletedMatches,
    int ResolvedMatches,
    double? CompletionRate,
    int Reports,
    int OpenReports);

public sealed record UsageCounts(int SignUps, int ActivePlayers, int Posts, int Invitations, int ConfirmedMatches, int CompletedMatches, int ResolvedMatches, int Reports, int OpenReports);

public interface IUsageStatsReader
{
    Task<UsageCounts> CountAsync(DateTime fromUtc, DateTime toUtc, CancellationToken cancellationToken);
}

/// <summary>The admin usage dashboard (tasks 10.9): Jalali dates, Tehran days, both ends inclusive; the last 30 days by default.</summary>
public sealed record AdminUsageStatsQuery(string? From, string? To) : IQuery<UsageStatsView>;

internal sealed class AdminUsageStatsHandler(IUsageStatsReader reader, TimeProvider clock) : IQueryHandler<AdminUsageStatsQuery, UsageStatsView>
{
    public async Task<UsageStatsView> Handle(AdminUsageStatsQuery request, CancellationToken cancellationToken)
    {
        var today = PersianFormat.TehranToday(clock.GetUtcNow().UtcDateTime);
        var to = Parse(request.To) ?? today;
        var from = Parse(request.From) ?? to.AddDays(-29);
        if (from > to)
            throw new ValidationFailedException("INVALID_DATE", "تاریخ شروع بعد از تاریخ پایان است.");
        var counts = await reader.CountAsync(Utc(from), Utc(to.AddDays(1)), cancellationToken);
        return new UsageStatsView(PersianFormat.JalaliAscii(from), PersianFormat.JalaliAscii(to), counts.SignUps, counts.ActivePlayers, counts.Posts, counts.Invitations,
            counts.ConfirmedMatches, counts.CompletedMatches, counts.ResolvedMatches,
            counts.ResolvedMatches == 0 ? null : Math.Round(counts.CompletedMatches / (double)counts.ResolvedMatches, 3), counts.Reports, counts.OpenReports);
    }

    private static DateOnly? Parse(string? jalali)
    {
        if (string.IsNullOrWhiteSpace(jalali))
            return null;
        return PersianFormat.TryParseJalali(jalali, out var day) ? day : throw new ValidationFailedException("INVALID_DATE", "تاریخ معتبر نیست.");
    }

    private static DateTime Utc(DateOnly day) =>
        TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(day.ToDateTime(TimeOnly.MinValue), DateTimeKind.Unspecified), PersianFormat.Tehran);
}
