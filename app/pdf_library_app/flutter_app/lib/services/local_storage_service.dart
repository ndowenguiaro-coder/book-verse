import 'dart:io';
import 'dart:typed_data';
import 'package:path_provider/path_provider.dart';

/// Gère le cache local des PDF téléchargés pour la lecture hors-ligne
/// ("Téléchargés"). L'identité de l'utilisateur (device_id) n'est plus
/// gérée ici : elle est remplacée par le jeton JWT d'AuthService.
class LocalStorageService {
  Future<Directory> _booksDir() async {
    final dir = await getApplicationDocumentsDirectory();
    final booksDir = Directory('${dir.path}/downloaded_books');
    if (!await booksDir.exists()) {
      await booksDir.create(recursive: true);
    }
    return booksDir;
  }

  Future<File> _fileFor(int bookId) async {
    final dir = await _booksDir();
    return File('${dir.path}/$bookId.pdf');
  }

  Future<bool> isDownloaded(int bookId) async {
    final file = await _fileFor(bookId);
    return file.exists();
  }

  Future<File> saveBook(int bookId, Uint8List bytes) async {
    final file = await _fileFor(bookId);
    return file.writeAsBytes(bytes, flush: true);
  }

  Future<Uint8List?> readBook(int bookId) async {
    final file = await _fileFor(bookId);
    if (!await file.exists()) return null;
    return file.readAsBytes();
  }

  Future<void> deleteBook(int bookId) async {
    final file = await _fileFor(bookId);
    if (await file.exists()) await file.delete();
  }

  Future<List<int>> listDownloadedIds() async {
    final dir = await _booksDir();
    final files = dir.listSync().whereType<File>();
    return files
        .map((f) => f.uri.pathSegments.last.replaceAll('.pdf', ''))
        .map((s) => int.tryParse(s))
        .whereType<int>()
        .toList();
  }
}
