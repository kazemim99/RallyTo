// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'chat_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConversationSummaryModel _$ConversationSummaryModelFromJson(Map<String, dynamic> json) => ConversationSummaryModel(
  id: json['id'] as String,
  kind: json['kind'] as String,
  matchId: json['matchId'] as String?,
  title: json['title'] as String? ?? '',
  otherUserId: json['otherUserId'] as String?,
  lastMessage: json['lastMessage'] as String?,
  lastMessageAt: json['lastMessageAt'] as String?,
  unreadCount: (json['unreadCount'] as num?)?.toInt() ?? 0,
  isRequest: json['isRequest'] as bool? ?? false,
  canSend: json['canSend'] as bool? ?? false,
  muted: json['muted'] as bool? ?? false,
  isRequestRecipient: json['isRequestRecipient'] as bool? ?? false,
);

MessageViewModel _$MessageViewModelFromJson(Map<String, dynamic> json) => MessageViewModel(
  id: json['id'] as String,
  conversationId: json['conversationId'] as String,
  senderId: json['senderId'] as String,
  sentAt: json['sentAt'] as String,
  senderName: json['senderName'] as String? ?? '',
  body: json['body'] as String?,
  deleted: json['deleted'] as bool? ?? false,
  readByOthers: json['readByOthers'] as bool? ?? false,
  clientMessageId: json['clientMessageId'] as String? ?? '',
);

MessagePageModel _$MessagePageModelFromJson(Map<String, dynamic> json) => MessagePageModel(
  items:
      (json['items'] as List<dynamic>?)?.map((e) => MessageViewModel.fromJson(e as Map<String, dynamic>)).toList() ??
      const [],
  nextCursor: json['nextCursor'] as String?,
);

UnreadCountsModel _$UnreadCountsModelFromJson(Map<String, dynamic> json) => UnreadCountsModel(
  conversations: (json['conversations'] as num?)?.toInt() ?? 0,
  requests: (json['requests'] as num?)?.toInt() ?? 0,
);

Map<String, dynamic> _$OpenDirectRequestModelToJson(OpenDirectRequestModel instance) => <String, dynamic>{
  'playerId': instance.playerId,
};

Map<String, dynamic> _$SendMessageRequestModelToJson(SendMessageRequestModel instance) => <String, dynamic>{
  'clientMessageId': instance.clientMessageId,
  'body': instance.body,
};

Map<String, dynamic> _$MarkReadRequestModelToJson(MarkReadRequestModel instance) => <String, dynamic>{
  'upToMessageId': instance.upToMessageId,
};

Map<String, dynamic> _$MuteRequestModelToJson(MuteRequestModel instance) => <String, dynamic>{'muted': instance.muted};
