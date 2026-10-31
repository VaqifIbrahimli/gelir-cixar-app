import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// Account card photos (DESIGN.md §18.2.3), stored as files inside
/// `<app documents>/card_images/`. The database keeps only the file name
/// (`Account.cardImagePath`), never a path, so a crafted backup can not
/// point the app at other files.
class CardImageStore {
  CardImageStore(this._root);

  /// Resolves the `card_images` directory (created on demand).
  final Future<Directory> Function() _root;

  /// Longest side after re-encoding.
  static const int maxSide = 1200;
  static const int jpegQuality = 80;

  /// Largest image kept in a backup (after re-encoding), and accepted on
  /// restore.
  static const int maxBytes = 1024 * 1024;

  static final RegExp _name = RegExp(r'^[A-Za-z0-9_-]{1,64}\.(jpg|png)$');

  /// A plain file name of ours: no separators, no "..".
  static bool isValidName(String? name) => name != null && _name.hasMatch(name);

  /// JPEG (FF D8 FF) or PNG (89 50 4E 47 0D 0A 1A 0A) magic bytes.
  static bool isImage(List<int> b) {
    if (b.length >= 3 && b[0] == 0xFF && b[1] == 0xD8 && b[2] == 0xFF) return true;
    const List<int> png = <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A];
    if (b.length < png.length) return false;
    for (int i = 0; i < png.length; i++) {
      if (b[i] != png[i]) return false;
    }
    return true;
  }

  /// Decodes [bytes] (any format the `image` package reads), downscales to
  /// [maxSide] on the long side and re-encodes as JPEG quality 80. Returns
  /// null for undecodable input. CPU-heavy: run it through `compute`.
  static Uint8List? reencode(Uint8List bytes) {
    final img.Image? decoded = img.decodeImage(bytes);
    if (decoded == null) return null;
    img.Image image = img.bakeOrientation(decoded);
    final int longSide = math.max(image.width, image.height);
    if (longSide > maxSide) {
      image = image.width >= image.height
          ? img.copyResize(image, width: maxSide, interpolation: img.Interpolation.average)
          : img.copyResize(image, height: maxSide, interpolation: img.Interpolation.average);
    }
    return img.encodeJpg(image, quality: jpegQuality);
  }

  static final math.Random _rng = math.Random.secure();

  Future<Directory> dir() async {
    final Directory d = await _root();
    if (!d.existsSync()) await d.create(recursive: true);
    return d;
  }

  Future<File?> fileOf(String? name) async {
    if (!isValidName(name)) return null;
    return File('${(await dir()).path}${Platform.pathSeparator}$name');
  }

  /// Writes already re-encoded JPEG bytes under a new random name.
  Future<String> saveJpeg(Uint8List jpeg) async {
    final String name =
        'card_${DateTime.now().millisecondsSinceEpoch}_${_rng.nextInt(1 << 32).toRadixString(16)}.jpg';
    await write(name, jpeg);
    return name;
  }

  Future<void> write(String name, List<int> bytes) async {
    final File? f = await fileOf(name);
    if (f == null) throw ArgumentError('bad image name');
    final File tmp = File('${f.path}.tmp');
    await tmp.writeAsBytes(bytes, flush: true);
    await tmp.rename(f.path);
  }

  Future<Uint8List?> read(String? name) async {
    final File? f = await fileOf(name);
    if (f == null || !f.existsSync()) return null;
    return f.readAsBytes();
  }

  Future<void> delete(String? name) async {
    final File? f = await fileOf(name);
    if (f != null && f.existsSync()) await f.delete();
  }

  /// Removes every stored image whose name is not in [keep].
  Future<void> deleteExcept(Set<String> keep) async {
    final Directory d = await dir();
    await for (final FileSystemEntity e in d.list()) {
      if (e is! File) continue;
      final String name = e.uri.pathSegments.last;
      if (!keep.contains(name)) {
        try {
          await e.delete();
        } on FileSystemException {
          // Best effort: an orphan file is harmless.
        }
      }
    }
  }
}
