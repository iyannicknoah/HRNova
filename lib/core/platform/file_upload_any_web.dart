import 'dart:async';
import 'dart:html' as html;
import 'dart:typed_data';

Future<({String name, Uint8List bytes})?> pickAnyFile() async {
  final completer = Completer<({String name, Uint8List bytes})?>();
  final input = html.FileUploadInputElement()
    ..accept = '.pdf,image/jpeg,image/jpg,image/png,image/webp'
    ..click();

  input.onChange.listen((_) {
    if (input.files == null || input.files!.isEmpty) {
      completer.complete(null);
      return;
    }
    final file = input.files!.first;
    if (file.size > 5 * 1024 * 1024) {
      completer.completeError(Exception('File must be under 5 MB'));
      return;
    }
    final reader = html.FileReader();
    reader.readAsArrayBuffer(file);
    reader.onLoad.listen((_) {
      completer.complete((
        name: file.name,
        bytes: Uint8List.fromList(reader.result as List<int>),
      ));
    });
    reader.onError.listen((_) => completer.completeError(Exception('Failed to read file')));
  });
  input.onAbort.listen((_) => completer.complete(null));
  return completer.future;
}
