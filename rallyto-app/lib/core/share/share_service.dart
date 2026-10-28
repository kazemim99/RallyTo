import 'package:injectable/injectable.dart';
import 'package:share_plus/share_plus.dart';

/// Hands text to the system share sheet. Behind an interface so screens can be tested without the platform.
abstract class ShareService {
  /// Opens the share sheet with [text]; [subject] is used where the target takes one (e-mail). Throws when the
  /// platform cannot share.
  Future<void> shareText(String text, {String? subject});
}

/// [ShareService] over share_plus.
@LazySingleton(as: ShareService)
class SharePlusShareService implements ShareService {
  @override
  Future<void> shareText(String text, {String? subject}) async {
    await SharePlus.instance.share(ShareParams(text: text, subject: subject));
  }
}
