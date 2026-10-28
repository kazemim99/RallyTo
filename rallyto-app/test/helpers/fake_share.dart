import 'package:rallyto_app/core/share/share_service.dart';

/// A [ShareService] recording what was shared; [failure] makes the next share throw.
class FakeShareService implements ShareService {
  final List<(String text, String? subject)> shared = [];

  /// When set, sharing throws it.
  Object? failure;

  @override
  Future<void> shareText(String text, {String? subject}) async {
    final error = failure;
    if (error != null) throw error;
    shared.add((text, subject));
  }
}
