// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
import 'dart:typed_data';

/// Returns null if user cancels. Throws Exception if file too large.
Future<({String name, Uint8List bytes})?> pickPdfFile() async {
  final input = html.FileUploadInputElement()
    ..accept = '.pdf,application/pdf'
    ..click();
  await input.onChange.first;
  if (input.files == null || input.files!.isEmpty) return null;
  final file = input.files![0];
  if (file.size > 5 * 1024 * 1024) {
    throw Exception('File is too large. Maximum size is 5 MB.');
  }
  final reader = html.FileReader();
  reader.readAsArrayBuffer(file);
  await reader.onLoad.first;
  final bytes = (reader.result as ByteBuffer).asUint8List();
  return (name: file.name, bytes: bytes);
}
