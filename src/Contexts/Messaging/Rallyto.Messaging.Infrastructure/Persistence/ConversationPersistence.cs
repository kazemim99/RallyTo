using Microsoft.EntityFrameworkCore;
using Microsoft.EntityFrameworkCore.Metadata.Builders;
using Rallyto.Messaging.Application.Abstractions;
using Rallyto.Messaging.Domain.Conversations;

namespace Rallyto.Messaging.Infrastructure.Persistence;

internal sealed class ConversationConfiguration : IEntityTypeConfiguration<Conversation>
{
    public void Configure(EntityTypeBuilder<Conversation> builder)
    {
        builder.ToTable("conversations");
        builder.HasKey(c => c.Id);
        builder.Property(c => c.Id).ValueGeneratedNever();
        builder.Property(c => c.Kind).HasConversion<string>().HasMaxLength(16);
        builder.Property(c => c.RequestState).HasConversion<string>().HasMaxLength(16);
        builder.Property(c => c.Title).HasMaxLength(200);
        builder.Property(c => c.DirectKey).HasMaxLength(65);
        builder.Property(c => c.Version).IsRowVersion();
        builder.HasIndex(c => c.DirectKey).IsUnique().HasFilter("direct_key IS NOT NULL");
        builder.HasIndex(c => c.MatchId).IsUnique().HasFilter("match_id IS NOT NULL");
        builder.HasIndex(c => new { c.InitiatorId, c.StartedAt });
        builder.Ignore(c => c.IsPendingRequest);

        builder.HasMany(c => c.Members).WithOne().HasForeignKey(m => m.ConversationId).OnDelete(DeleteBehavior.Cascade);
        builder.Navigation(c => c.Members).HasField("_members").AutoInclude();
    }
}

internal sealed class ConversationMemberConfiguration : IEntityTypeConfiguration<ConversationMember>
{
    public void Configure(EntityTypeBuilder<ConversationMember> builder)
    {
        builder.ToTable("conversation_members");
        builder.HasKey(m => new { m.ConversationId, m.UserId });
        builder.HasIndex(m => m.UserId);
        builder.Ignore(m => m.IsCurrent);
    }
}

internal sealed class MessageConfiguration : IEntityTypeConfiguration<Message>
{
    public void Configure(EntityTypeBuilder<Message> builder)
    {
        builder.ToTable("messages");
        builder.HasKey(m => m.Id);
        builder.Property(m => m.Id).ValueGeneratedNever();
        builder.Property(m => m.Seq).UseIdentityByDefaultColumn();
        builder.Property(m => m.ClientMessageId).HasMaxLength(Message.MaxClientIdLength).IsRequired();
        builder.Property(m => m.Body).HasMaxLength(Conversation.MaxLength);
        builder.HasIndex(m => new { m.ConversationId, m.Seq });
        builder.HasIndex(m => new { m.ConversationId, m.SenderId, m.ClientMessageId }).IsUnique();
        builder.Ignore(m => m.IsDeleted);
    }
}

internal sealed class ConversationRepository(MessagingDbContext db) : IConversationRepository
{
    public Task<Conversation?> GetAsync(Guid id, CancellationToken cancellationToken) =>
        db.Conversations.FirstOrDefaultAsync(c => c.Id == id, cancellationToken);

    public Task<Conversation?> GetDirectAsync(Guid a, Guid b, CancellationToken cancellationToken)
    {
        var key = Conversation.KeyOf(a, b);
        return db.Conversations.FirstOrDefaultAsync(c => c.DirectKey == key, cancellationToken);
    }

    public Task<Conversation?> GetForMatchAsync(Guid matchId, CancellationToken cancellationToken) =>
        db.Conversations.FirstOrDefaultAsync(c => c.MatchId == matchId, cancellationToken);

    public async Task<IReadOnlyList<Conversation>> ListForMemberAsync(Guid userId, CancellationToken cancellationToken) =>
        await db.Conversations.Where(c => c.Members.Any(m => m.UserId == userId)).AsSplitQuery().ToListAsync(cancellationToken);

    public Task<int> CountStartedSinceAsync(Guid initiatorId, DateTime since, CancellationToken cancellationToken) =>
        db.Conversations.CountAsync(c => c.InitiatorId == initiatorId && c.StartedAt >= since, cancellationToken);

    public void Add(Conversation conversation) => db.Conversations.Add(conversation);
}

internal sealed class MessageRepository(MessagingDbContext db) : IMessageRepository
{
    public Task<Message?> GetAsync(Guid conversationId, Guid messageId, CancellationToken cancellationToken) =>
        db.Messages.FirstOrDefaultAsync(m => m.Id == messageId && m.ConversationId == conversationId, cancellationToken);

    public Task<Message?> FindByClientIdAsync(Guid conversationId, Guid senderId, string clientMessageId, CancellationToken cancellationToken) =>
        db.Messages.FirstOrDefaultAsync(m => m.ConversationId == conversationId && m.SenderId == senderId && m.ClientMessageId == clientMessageId, cancellationToken);

    public async Task<long> LastSeqAsync(Guid conversationId, CancellationToken cancellationToken) =>
        await db.Messages.Where(m => m.ConversationId == conversationId).MaxAsync(m => (long?)m.Seq, cancellationToken) ?? 0;

    public async Task<IReadOnlyList<Message>> HistoryAsync(Guid conversationId, long? beforeSeq, long? upToSeq, IReadOnlySet<Guid> hiddenSenders, int take, CancellationToken cancellationToken)
    {
        var hidden = hiddenSenders.ToList();
        var query = db.Messages.AsNoTracking().Where(m => m.ConversationId == conversationId && !hidden.Contains(m.SenderId));
        if (beforeSeq is { } before)
            query = query.Where(m => m.Seq < before);
        if (upToSeq is { } upTo)
            query = query.Where(m => m.Seq <= upTo);
        return await query.OrderByDescending(m => m.Seq).Take(take).ToListAsync(cancellationToken);
    }

    public async Task<IReadOnlyDictionary<Guid, LastMessage>> LastMessagesAsync(Guid userId, IReadOnlyCollection<Guid> conversationIds, IReadOnlySet<Guid> hiddenSenders, CancellationToken cancellationToken)
    {
        var hidden = hiddenSenders.ToList();
        var ids = conversationIds.ToList();
        var last = await (from m in db.Messages
                          join member in db.ConversationMembers on m.ConversationId equals member.ConversationId
                          where member.UserId == userId && ids.Contains(m.ConversationId) && !hidden.Contains(m.SenderId)
                                && (member.LeftAfterSeq == null || m.Seq <= member.LeftAfterSeq)
                          group m by m.ConversationId into g
                          select g.OrderByDescending(m => m.Seq).Select(m => new LastMessage(m.ConversationId, m.Body, m.DeletedAt != null, m.SentAt)).First())
            .ToListAsync(cancellationToken);
        return last.ToDictionary(l => l.ConversationId);
    }

    public async Task<IReadOnlyDictionary<Guid, int>> UnreadCountsAsync(Guid userId, IReadOnlyCollection<Guid> conversationIds, IReadOnlySet<Guid> hiddenSenders, CancellationToken cancellationToken)
    {
        var hidden = hiddenSenders.ToList();
        var ids = conversationIds.ToList();
        return await (from m in db.Messages
                      join member in db.ConversationMembers on m.ConversationId equals member.ConversationId
                      where member.UserId == userId && ids.Contains(m.ConversationId) && m.SenderId != userId && m.DeletedAt == null
                            && !hidden.Contains(m.SenderId) && m.Seq > member.LastReadSeq
                            && (member.LeftAfterSeq == null || m.Seq <= member.LeftAfterSeq)
                      group m by m.ConversationId into g
                      select new { g.Key, Count = g.Count() })
            .ToDictionaryAsync(x => x.Key, x => x.Count, cancellationToken);
    }

    public void Add(Message message) => db.Messages.Add(message);
}
