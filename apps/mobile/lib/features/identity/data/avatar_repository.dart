import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'identity_repository.dart';

/// Local-only profile pixels; separate from cryptographic key records.
class AvatarRepository {
  AvatarRepository(this.store);
  final SecureKeyStore store;
  static const storageKey = 'avatar_v1';

  Future<Uint8List?> read() async {
    final encoded = await store.read(storageKey);
    return encoded == null ? null : base64Decode(encoded);
  }

  Future<void> save(Uint8List source) async {
    if (await store.read(IdentityRepository.identityKey) == null) {
      throw const IdentityFailure(
        'Create an identity before choosing a photo.',
      );
    }
    if (source.isEmpty || source.length > 8 * 1024 * 1024) {
      throw const IdentityFailure('Choose a smaller image.');
    }
    final buffer = await ui.ImmutableBuffer.fromUint8List(source);
    ui.ImageDescriptor? descriptor;
    final ui.Codec codec;
    try {
      descriptor = await ui.ImageDescriptor.encoded(buffer);
      if (descriptor.width * descriptor.height > 40000000 ||
          descriptor.width > descriptor.height * 8 ||
          descriptor.height > descriptor.width * 8) {
        throw const IdentityFailure(
          'Choose a photo with a less extreme size or shape.',
        );
      }
      final scale =
          256 /
          (descriptor.width < descriptor.height
              ? descriptor.width
              : descriptor.height);
      codec = await descriptor.instantiateCodec(
        targetWidth: (descriptor.width * scale).round(),
        targetHeight: (descriptor.height * scale).round(),
      );
    } catch (_) {
      descriptor?.dispose();
      rethrow;
    } finally {
      buffer.dispose();
    }
    try {
      final frame = await codec.getNextFrame();
      try {
        final recorder = ui.PictureRecorder();
        final canvas = ui.Canvas(recorder);
        canvas.drawImage(
          frame.image,
          ui.Offset(
            (256 - frame.image.width) / 2,
            (256 - frame.image.height) / 2,
          ),
          ui.Paint(),
        );
        final picture = recorder.endRecording();
        ui.Image? cropped;
        final ByteData? bytes;
        try {
          cropped = await picture.toImage(256, 256);
          bytes = await cropped.toByteData(format: ui.ImageByteFormat.png);
        } finally {
          cropped?.dispose();
          picture.dispose();
        }
        if (bytes == null || bytes.lengthInBytes > 512 * 1024) {
          throw const IdentityFailure('Photo could not be resized.');
        }
        // Re-encoding pixels discards EXIF and other source metadata.
        await store.write(storageKey, base64Encode(bytes.buffer.asUint8List()));
      } finally {
        frame.image.dispose();
      }
    } finally {
      codec.dispose();
      descriptor.dispose();
    }
  }
}
