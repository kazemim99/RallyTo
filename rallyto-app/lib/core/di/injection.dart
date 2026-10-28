import 'package:get_it/get_it.dart';
import 'package:injectable/injectable.dart';

import 'injection.config.dart';

final GetIt getIt = GetIt.instance;

/// Registers every `@injectable`, `@lazySingleton` and `@module` class. The registrations are generated into
/// `injection.config.dart` by `dart run build_runner build --delete-conflicting-outputs`; regenerate after adding or
/// changing an annotated class, and commit the result.
@InjectableInit(initializerName: 'init', preferRelativeImports: true, asExtension: true)
Future<void> configureDependencies() async {
  getIt.init();
}
