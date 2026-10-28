import 'package:flutter_test/flutter_test.dart';
import 'package:rallyto_app/core/storage/secure_storage_service.dart';

import '../../helpers/memory_secure_storage.dart';

/// A stored value that can no longer be decrypted throws from the plugin instead of reading as absent; every caller
/// expects null for "nothing stored". And writes that overlap lost values on the web, so operations never overlap.
void main() {
  group('readSafely', () {
    test('returns the value on a normal read', () async {
      final result = await SecureStorageService.readSafely(
        read: () async => 'token',
        delete: () async => fail('must not delete on a successful read'),
      );
      expect(result, 'token');
    });

    test('returns null when nothing is stored, without deleting', () async {
      final result = await SecureStorageService.readSafely(
        read: () async => null,
        delete: () async => fail('nothing to delete'),
      );
      expect(result, isNull);
    });

    test('returns null instead of throwing when the read fails, and deletes the unreadable value', () async {
      var deleted = false;
      final result = await SecureStorageService.readSafely(
        read: () async => throw Exception('OperationError'),
        delete: () async => deleted = true,
      );
      expect(result, isNull);
      expect(deleted, isTrue);
    });

    test('still returns null when the cleanup delete fails too', () async {
      final result = await SecureStorageService.readSafely(
        read: () async => throw Exception('OperationError'),
        delete: () async => throw Exception('delete failed'),
      );
      expect(result, isNull);
    });
  });

  test('writes, reads and deletes through the plugin', () async {
    final storage = MemorySecureStorage();
    final service = SecureStorageService(storage);

    await service.write('a', '1');
    await service.write('b', '2');
    expect(await service.read('a'), '1');

    await service.write('a', null);
    expect(await service.read('a'), isNull);

    await service.delete('b');
    await service.write('c', '3');
    await service.deleteAll();
    expect(storage.values, isEmpty);
  });

  test('operations started together never overlap, and run in order', () async {
    final storage = MemorySecureStorage();
    final service = SecureStorageService(storage);

    final writes = [service.write('k', '1'), service.write('k', '2')];
    final afterWrites = service.read('k');
    final delete = service.delete('k');
    final afterDelete = service.read('k');
    await Future.wait([...writes, delete]);

    expect(await afterWrites, '2');
    expect(await afterDelete, isNull);
    expect(storage.maxInFlight, 1);
  });

  test('one failed operation does not stop the ones queued after it', () async {
    final storage = MemorySecureStorage()..failReads = true;
    final service = SecureStorageService(storage);

    expect(await service.read('k'), isNull);
    storage.failReads = false;
    await service.write('k', 'v');
    expect(await service.read('k'), 'v');
  });
}
