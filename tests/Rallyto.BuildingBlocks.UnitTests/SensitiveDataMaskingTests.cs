using Serilog.Events;
using Serilog.Parsing;
using Rallyto.Infrastructure.Web.Observability;

namespace Rallyto.BuildingBlocks.UnitTests;

/// <summary>spec identity-access › Phone number privacy: logs must mask phone numbers and codes.</summary>
public sealed class SensitiveDataMaskingTests
{
    [Theory]
    [InlineData("Code", "1234")]
    [InlineData("RefreshToken", "abc.def")]
    [InlineData("otp_code", "9876")]
    [InlineData("SecretKey", "s3cret")]
    public void Secrets_are_redacted(string property, string value)
    {
        Render(property, value).Should().Be(SensitiveDataMaskingEnricher.Redacted);
    }

    [Theory]
    [InlineData("PhoneNumber", "09123456789", "0912*****89")]
    [InlineData("Recipient", "+989123456789", "+989*******89")]
    [InlineData("Whatever", "09123456789", "0912*****89")]
    public void Phone_numbers_are_masked(string property, string value, string expected)
    {
        Render(property, value).Should().Be(expected);
    }

    [Fact]
    public void Phone_numbers_inside_free_text_are_masked()
    {
        SensitiveDataMaskingEnricher.ScrubText("call 09123456789 now").Should().Be("call 0912*****89 now");
    }

    [Fact]
    public void Ordinary_values_are_left_alone()
    {
        Render("Path", "/api/v1/auth/otp/send").Should().Be("/api/v1/auth/otp/send");
    }

    private static string? Render(string property, string value)
    {
        var logEvent = new LogEvent(DateTimeOffset.UtcNow, LogEventLevel.Information, null,
            new MessageTemplateParser().Parse("x"), [new LogEventProperty(property, new ScalarValue(value))]);
        new SensitiveDataMaskingEnricher().Enrich(logEvent, null!);
        return (logEvent.Properties[property] as ScalarValue)?.Value as string;
    }
}
