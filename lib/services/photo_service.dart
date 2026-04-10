import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;

/// Copia a foto do cache temporário para um diretório permanente
/// dentro do app (Documents), garantindo que o arquivo persiste.
class PhotoService {
  static Future<String> savePermanently(String tempPath) async {
    final dir = await getApplicationDocumentsDirectory();
    final photosDir = Directory(p.join(dir.path, 'rdv_photos'));
    if (!await photosDir.exists()) {
      await photosDir.create(recursive: true);
    }

    final filename = 'foto_${DateTime.now().millisecondsSinceEpoch}.jpg';
    final dest = p.join(photosDir.path, filename);

    await File(tempPath).copy(dest);
    return dest;
  }

  static Future<void> deletePhoto(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } catch (_) {}
  }
}
