using DotNetCore.CAP;
using Microsoft.EntityFrameworkCore;
using Rallyto.Contracts.Community;
using Rallyto.Identity.Infrastructure.Persistence;

namespace Rallyto.Identity.Infrastructure.Subscribers;

/// <summary>Marks the account as onboarded once Community has its profile, so sign-in can route to the home screen.</summary>
public sealed class ProfileCreatedSubscriber(IdentityDbContext db) : ICapSubscribe
{
    [CapSubscribe(CommunityTopics.ProfileCreated, Group = IdentityModule.CapGroup)]
    public async Task OnProfileCreated(ProfileCreated message)
    {
        var account = await db.UserAccounts.FirstOrDefaultAsync(a => a.Id == message.UserId);
        if (account is null || account.ProfileCompleted)
            return;
        account.MarkProfileCompleted();
        await db.SaveChangesAsync();
    }
}
