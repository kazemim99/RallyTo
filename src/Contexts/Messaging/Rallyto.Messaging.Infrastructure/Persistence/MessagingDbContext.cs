using Microsoft.EntityFrameworkCore;
using Rallyto.Infrastructure.Core.Persistence;
using Rallyto.Messaging.Domain.Conversations;

namespace Rallyto.Messaging.Infrastructure.Persistence;

public sealed class MessagingDbContext(DbContextOptions<MessagingDbContext> options) : RallytoDbContext(options)
{
    public override string Schema => MessagingModule.Schema;

    public DbSet<Conversation> Conversations => Set<Conversation>();
    public DbSet<ConversationMember> ConversationMembers => Set<ConversationMember>();
    public DbSet<Message> Messages => Set<Message>();
}
