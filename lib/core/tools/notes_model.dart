import 'dart:convert';

class TodoItem {
  final String id;
  String text;
  bool done;
  TodoItem({required this.id, required this.text, this.done = false});

  Map<String, dynamic> toMap() => {'id': id, 'text': text, 'done': done};

  static TodoItem? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final text = raw['text'];
    if (id is! String || text is! String || text.trim().isEmpty) return null;
    return TodoItem(id: id, text: text, done: raw['done'] == true);
  }
}

class NoteItem {
  final String id;
  String title;
  String body;
  int updated; // millisecondsSinceEpoch
  NoteItem({required this.id, required this.title, required this.body, required this.updated});

  Map<String, dynamic> toMap() => {'id': id, 'title': title, 'body': body, 'updated': updated};

  static NoteItem? fromMap(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['id'];
    final title = raw['title'];
    final body = raw['body'];
    final updated = raw['updated'];
    if (id is! String || title is! String || body is! String) return null;
    return NoteItem(id: id, title: title, body: body, updated: updated is int ? updated : 0);
  }
}

const int kMaxTodos = 300;
const int kMaxNotes = 200;

String encodeList(List<Map<String, dynamic>> items) => jsonEncode(items);

List<T> decodeList<T>(String? raw, T? Function(Object?) read, int max) {
  if (raw == null || raw.isEmpty) return [];
  try {
    final data = jsonDecode(raw);
    if (data is! List) return [];
    final out = <T>[];
    for (final e in data) {
      final v = read(e);
      if (v != null) out.add(v);
      if (out.length >= max) break;
    }
    return out;
  } catch (_) {
    return [];
  }
}
