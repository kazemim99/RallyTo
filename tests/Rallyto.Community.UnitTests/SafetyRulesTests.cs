using Rallyto.Community.Domain.Safety;
using Rallyto.Core.Domain.Exceptions;

namespace Rallyto.Community.UnitTests;

public sealed class SafetyRulesTests
{
    private static readonly DateTime Now = new(2026, 10, 23, 9, 0, 0, DateTimeKind.Utc);
    private static readonly Guid Target = Guid.NewGuid();
    private static readonly ReportEvidence NoEvidence = new(null, null, null, null, null);

    private static Report Filed(ReportReason reason, Guid? reporter = null, double daysAgo = 0) =>
        Report.File(reporter ?? Guid.NewGuid(), ReportTargetType.Player, Target.ToString(), Target, reason, null, NoEvidence, Now.AddDays(-daysAgo));

    [Theory]
    [InlineData(ReportReason.Harassment, true)]
    [InlineData(ReportReason.Underage, true)]
    [InlineData(ReportReason.Spam, false)]
    public void Harassment_and_underage_are_high_priority_on_their_own(ReportReason reason, bool high) =>
        ReportPriority.IsHigh([Filed(reason)], Now).Should().Be(high);

    [Fact]
    public void Three_distinct_reporters_within_seven_days_raise_priority()
    {
        ReportPriority.IsHigh([Filed(ReportReason.Spam), Filed(ReportReason.Spam), Filed(ReportReason.Other)], Now).Should().BeTrue();
    }

    [Fact]
    public void The_same_reporter_or_old_reports_do_not_count_twice()
    {
        var reporter = Guid.NewGuid();
        ReportPriority.IsHigh([Filed(ReportReason.Spam, reporter), Filed(ReportReason.Other, reporter), Filed(ReportReason.Spam)], Now).Should().BeFalse();
        ReportPriority.IsHigh([Filed(ReportReason.Spam), Filed(ReportReason.Spam), Filed(ReportReason.Spam, daysAgo: 8)], Now).Should().BeFalse();
    }

    [Fact]
    public void Players_cannot_report_themselves_and_details_are_limited()
    {
        var self = () => Report.File(Target, ReportTargetType.Player, Target.ToString(), Target, ReportReason.Other, null, NoEvidence, Now);
        var longDetails = () => Report.File(Guid.NewGuid(), ReportTargetType.Player, Target.ToString(), Target, ReportReason.Other, new string('x', 1001), NoEvidence, Now);

        self.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("CANNOT_REPORT_SELF");
        longDetails.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("DETAILS_TOO_LONG");
    }

    [Fact]
    public void A_report_is_closed_once()
    {
        var report = Filed(ReportReason.Spam);
        report.Dismiss(Guid.NewGuid(), "no violation", Now);

        var again = () => report.Resolve(Guid.NewGuid(), null, Now);

        report.Status.Should().Be(ReportStatus.Dismissed);
        again.Should().Throw<InvalidAggregateStateException>().Which.ErrorCode.Should().Be("REPORT_CLOSED");
    }
}
