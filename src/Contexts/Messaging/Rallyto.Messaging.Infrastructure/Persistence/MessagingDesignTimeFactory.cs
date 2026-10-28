using Microsoft.EntityFrameworkCore.Design;
using Rallyto.Infrastructure.Core.Persistence;

namespace Rallyto.Messaging.Infrastructure.Persistence;

internal sealed class MessagingDesignTimeFactory : IDesignTimeDbContextFactory<MessagingDbContext>
{
    public MessagingDbContext CreateDbContext(string[] args) => new(DesignTimeOptions.For<MessagingDbContext>(MessagingModule.Schema));
}
