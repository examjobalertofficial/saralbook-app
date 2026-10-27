import 'dart:math' as math;
import 'dart:typed_data';

int _counter = 0;

/// A short id that is different for every item and page made in this session.
String newEditId() => 'e${DateTime.now().microsecondsSinceEpoch}_${_counter++}';

double clamp01(double v) => v.isNaN ? 0.0 : (v < 0 ? 0.0 : (v > 1 ? 1.0 : v));

/// Everything the person adds on top of a PDF page. Positions and sizes are
/// fractions of the page (0..1), so they look the same on screen and in the file.
abstract class EditItem {
  final String id;
  EditItem(String? id) : id = id ?? newEditId();
}

/// Typed text. [x], [y] = top-left corner; [size] = letter height as a fraction of the page width.
class TextItem extends EditItem {
  String text;
  double x;
  double y;
  double size;
  int color;
  bool bold;
  TextItem({
    String? id,
    required this.text,
    required this.x,
    required this.y,
    this.size = 0.035,
    this.color = 0xFF000000,
    this.bold = false,
  }) : super(id);
}

/// A pen or highlighter stroke. [points] = x0,y0,x1,y1,... (fractions); [width] = fraction of page width.
class InkItem extends EditItem {
  final List<double> points;
  final int color;
  final double width;
  final bool highlight;
  InkItem({
    String? id,
    required this.points,
    required this.color,
    required this.width,
    this.highlight = false,
  }) : super(id);
}

/// A filled rectangle (white-out) that hides what is below it.
class CoverItem extends EditItem {
  double x;
  double y;
  double w;
  double h;
  int color;
  CoverItem({String? id, required this.x, required this.y, required this.w, required this.h, this.color = 0xFFFFFFFF})
      : super(id);
}

/// A picture or signature. [w] = width as a fraction of the page width; [aspect] = width / height of the picture.
class PictureItem extends EditItem {
  final Uint8List bytes;
  double x;
  double y;
  double w;
  final double aspect;
  PictureItem({
    String? id,
    required this.bytes,
    required this.x,
    required this.y,
    required this.w,
    required this.aspect,
  }) : super(id);
}

/// One page of the PDF as a picture, plus what was added on it.
class EditPage {
  final String key;
  Uint8List base; // JPEG of the page
  int width;
  int height;
  final List<EditItem> items = [];

  EditPage({required this.base, required this.width, required this.height, String? key}) : key = key ?? newEditId();

  double get aspect => width / height;
  bool get hasEdits => items.isNotEmpty;
}

enum PageNumberPos { none, bottomCenter, bottomRight, bottomLeft, topRight }

/// A rectangle from two corners (any order), kept inside the page.
({double x, double y, double w, double h}) rectFromCorners(double x1, double y1, double x2, double y2) {
  final left = clamp01(math.min(x1, x2));
  final top = clamp01(math.min(y1, y2));
  final right = clamp01(math.max(x1, x2));
  final bottom = clamp01(math.max(y1, y2));
  return (x: left, y: top, w: right - left, h: bottom - top);
}

/// Moves [item] to ([x],[y]) but keeps its top-left corner inside the page.
({double x, double y}) keepInside(double x, double y) => (x: clamp01(x), y: clamp01(y));

/// Page number text for the page at [index] (0-based).
String pageNumberText(int index, int startAt) => '${startAt + index}';

/// Takes the item out of [list] at [from] and puts it at [to].
void moveInList<T>(List<T> list, int from, int to) {
  if (from < 0 || from >= list.length) return;
  final item = list.removeAt(from);
  list.insert(math.max(0, math.min(to, list.length)), item);
}
