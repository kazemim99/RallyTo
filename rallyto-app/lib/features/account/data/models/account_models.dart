import 'package:json_annotation/json_annotation.dart';

part 'account_models.g.dart';

/// Body of `POST /api/v1/account/deletion`: the SMS code that confirms the deletion.
@JsonSerializable(createFactory: false)
class AccountDeletionRequest {
  const AccountDeletionRequest({required this.code});

  final String code;

  Map<String, dynamic> toJson() => _$AccountDeletionRequestToJson(this);
}
