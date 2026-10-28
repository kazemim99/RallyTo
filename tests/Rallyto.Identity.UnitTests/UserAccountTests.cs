using Rallyto.Core.Domain.Exceptions;
using Rallyto.Identity.Domain;
using Rallyto.Identity.Domain.Accounts;

namespace Rallyto.Identity.UnitTests;

public sealed class UserAccountTests
{
    private static readonly DateTime Now = new(2026, 10, 23, 9, 0, 0, DateTimeKind.Utc);

    private static UserAccount NewAccount(bool admin = false) => UserAccount.Register(PhoneNumber.Parse("09123456789"), admin, Now);

    [Fact]
    public void New_account_is_an_active_player()
    {
        var account = NewAccount();

        account.Status.Should().Be(AccountStatus.Active);
        account.Roles.Should().Be(AccountRoles.Player);
        account.ProfileCompleted.Should().BeFalse();
    }

    [Fact]
    public void Initial_admin_gets_both_roles()
    {
        NewAccount(admin: true).Roles.Should().Be(AccountRoles.Player | AccountRoles.Admin);
    }

    [Fact]
    public void Suspension_counts_as_active_after_its_end_date()
    {
        var account = NewAccount();
        account.Suspend(Now.AddDays(1), "cooling off", Now);

        account.StatusAt(Now.AddHours(23)).Should().Be(AccountStatus.Suspended);
        account.StatusAt(Now.AddDays(1)).Should().Be(AccountStatus.Active);
        account.ExpireSuspensionIfDue(Now.AddDays(2)).Should().BeTrue();
        account.Status.Should().Be(AccountStatus.Active);
    }

    [Fact]
    public void Suspension_must_end_in_the_future()
    {
        var suspend = () => NewAccount().Suspend(Now.AddMinutes(-1), "x", Now);

        suspend.Should().Throw<BusinessRuleViolationException>().Which.ErrorCode.Should().Be("SUSPENSION_END_IN_PAST");
    }

    [Fact]
    public void Deletion_forgets_the_phone_number()
    {
        var account = NewAccount();

        account.Delete(Now);

        account.Status.Should().Be(AccountStatus.Deleted);
        account.Phone.Should().BeNull();
        account.DeletedAt.Should().Be(Now);
    }

    [Fact]
    public void A_banned_account_cannot_be_suspended()
    {
        var account = NewAccount();
        account.Ban("harassment");

        var suspend = () => account.Suspend(Now.AddDays(1), "x", Now);

        suspend.Should().Throw<InvalidAggregateStateException>();
    }

    [Fact]
    public void Refresh_token_rotation_keeps_the_family()
    {
        var token = RefreshToken.Issue(Guid.NewGuid(), Guid.NewGuid(), "h1", Now, TimeSpan.FromDays(30), null);

        var next = token.Rotate("h2", Now.AddHours(1), TimeSpan.FromDays(30), null);

        token.WasRotated.Should().BeTrue();
        token.IsUsable(Now.AddHours(1)).Should().BeFalse();
        next.FamilyId.Should().Be(token.FamilyId);
        next.IsUsable(Now.AddHours(1)).Should().BeTrue();
        next.IsUsable(Now.AddDays(31)).Should().BeFalse();
    }
}
