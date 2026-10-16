import 'dart:io';
import 'dart:convert';
import 'package:path_provider/path_provider.dart';
import 'ports.dart';

class JsonStateStore implements StateStore {
  JsonStateStore({Directory? directory}) : _directory = directory;
  final Directory? _directory;
  Future<File> _file() async {
    final dir = _directory ?? await getApplicationDocumentsDirectory();
    await dir.create(recursive: true);
    return File('${dir.path}/pocket_music.json');
  }

  @override
  Future<Map<String, dynamic>?> read() async {
    final file = await _file();
    if (!await file.exists()) return null;
    final value = jsonDecode(await file.readAsString());
    if (value is! Map<String, dynamic>) {
      throw const FormatException('Saved library is not an object');
    }
    return value;
  }

  @override
  Future<void> write(Map<String, dynamic> value) async {
    final file = await _file();
    final temporary = File('${file.path}.tmp');
    await temporary.writeAsString(jsonEncode(value), flush: true);
    await temporary.rename(file.path);
  }
}
