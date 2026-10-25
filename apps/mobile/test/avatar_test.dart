import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:shannon/features/identity/data/avatar_repository.dart';
import 'package:shannon/features/identity/data/identity_repository.dart';

import 'identity_test.dart' show MemoryStore;

Future<Uint8List> avatarFixture() async {
  final recorder = ui.PictureRecorder();
  ui.Canvas(recorder).drawColor(const ui.Color(0xFF3B82F6), ui.BlendMode.src);
  final picture = recorder.endRecording();
  final image = await picture.toImage(64, 32);
  try {
    return (await image.toByteData(format: ui.ImageByteFormat.png))!.buffer
        .asUint8List();
  } finally {
    image.dispose();
    picture.dispose();
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test(
    'avatar re-encodes, persists across reload and never changes keys',
    () async {
      final store = MemoryStore();
      store.values[IdentityRepository.identityKey] = 'untouched-key-record';
      await AvatarRepository(store).save(await avatarFixture());
      final saved = await AvatarRepository(store).read();
      final codec = await ui.instantiateImageCodec(saved!);
      final frame = await codec.getNextFrame();
      expect(frame.image.width, 256);
      expect(frame.image.height, 256);
      frame.image.dispose();
      codec.dispose();
      expect(
        store.values[IdentityRepository.identityKey],
        'untouched-key-record',
      );
      final before = store.values[AvatarRepository.storageKey];
      await expectLater(
        AvatarRepository(store).save(Uint8List.fromList([1, 2, 3])),
        throwsA(anything),
      );
      expect(store.values[AvatarRepository.storageKey], before);
    },
  );
  test('avatar cannot create an identity implicitly', () async {
    final store = MemoryStore();
    await expectLater(
      AvatarRepository(store).save(await avatarFixture()),
      throwsA(isA<IdentityFailure>()),
    );
    expect(store.values, isEmpty);
  });
}
