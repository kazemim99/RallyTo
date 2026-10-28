using Rallyto.Identity.Domain;
using Rallyto.Identity.Domain.Verification;

namespace Rallyto.Identity.UnitTests;

public sealed class PhoneVerificationTests
{
    private static readonly DateTime Now = new(2026, 10, 23, 9, 0, 0, DateTimeKind.Utc);
    private static readonly TimeSpan Lifetime = TimeSpan.FromMinutes(5);
    private static readonly TimeSpan Block = TimeSpan.FromHours(1);

    private static PhoneVerification NewCode() =>
        PhoneVerification.Create(PhoneNumber.Parse("09123456789"), VerificationPurpose.SignIn, "right", Now, Lifetime);

    [Fact]
    public void Correct_code_verifies_once()
    {
        var verification = NewCode();

        verification.Verify("right", Now.AddMinutes(1), 5, Block).Should().Be(VerificationOutcome.Verified);
        verification.Verify("right", Now.AddMinutes(1), 5, Block).Should().Be(VerificationOutcome.NotUsable);
    }

    [Fact]
    public void Code_expires_after_its_lifetime()
    {
        NewCode().Verify("right", Now.AddMinutes(5), 5, Block).Should().Be(VerificationOutcome.Expired);
    }

    [Fact]
    public void Fifth_wrong_attempt_blocks_for_an_hour()
    {
        var verification = NewCode();
        for (var i = 0; i < 4; i++)
            verification.Verify("wrong", Now, 5, Block).Should().Be(VerificationOutcome.WrongCode);
        verification.BlockedUntil.Should().BeNull();

        verification.Verify("wrong", Now, 5, Block);

        verification.BlockedUntil.Should().Be(Now + Block);
        verification.Verify("right", Now, 5, Block).Should().Be(VerificationOutcome.NotUsable);
    }

    [Fact]
    public void Superseded_and_cancelled_codes_never_verify()
    {
        var superseded = NewCode();
        superseded.Supersede();
        var cancelled = NewCode();
        cancelled.Cancel();

        superseded.Verify("right", Now, 5, Block).Should().Be(VerificationOutcome.NotUsable);
        cancelled.Verify("right", Now, 5, Block).Should().Be(VerificationOutcome.NotUsable);
    }
}
