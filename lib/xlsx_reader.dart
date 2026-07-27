import 'dart:convert';
import 'dart:typed_data';

import 'package:archive/archive.dart';
import 'package:xml/xml.dart';

/// Minimal XLSX reader for stock sheets. Avoids the `excel` package,
/// which crashes on formula cells in this workbook.
class XlsxReader {
  static const _ns =
      'http://schemas.openxmlformats.org/spreadsheetml/2006/main';

  /// Returns a matrix of cell strings (row-major). Empty trailing cells omitted.
  static List<List<String>> readSheetMatrix(Uint8List bytes) {
    final archive = ZipDecoder().decodeBytes(bytes);
    final shared = _readSharedStrings(archive);
    final sheetPath = _firstSheetPath(archive);
    final sheetFile = archive.findFile(sheetPath);
    if (sheetFile == null) {
      throw '找不到工作表';
    }
    final sheetXml = utf8.decode(_fileBytes(sheetFile));
    return _parseSheet(sheetXml, shared);
  }

  static Uint8List _fileBytes(ArchiveFile file) =>
      Uint8List.fromList(file.content as List<int>);

  static List<String> _readSharedStrings(Archive archive) {
    final file = archive.findFile('xl/sharedStrings.xml');
    if (file == null) return const [];
    final doc = XmlDocument.parse(utf8.decode(_fileBytes(file)));
    final out = <String>[];
    for (final si in doc.findAllElements('si', namespace: _ns)) {
      final texts = si.findAllElements('t', namespace: _ns).map((e) => e.innerText);
      out.add(texts.join());
    }
    return out;
  }

  static String _firstSheetPath(Archive archive) {
    // Prefer sheet1.xml; otherwise first worksheet under xl/worksheets/
    final preferred = archive.findFile('xl/worksheets/sheet1.xml');
    if (preferred != null) return 'xl/worksheets/sheet1.xml';
    for (final f in archive.files) {
      final name = f.name.replaceAll('\\', '/');
      if (name.startsWith('xl/worksheets/sheet') && name.endsWith('.xml')) {
        return name;
      }
    }
    throw '工作簿沒有工作表';
  }

  static List<List<String>> _parseSheet(String xml, List<String> shared) {
    final doc = XmlDocument.parse(xml);
    final rowsOut = <List<String>>[];

    for (final row in doc.findAllElements('row', namespace: _ns)) {
      final cells = <int, String>{};
      var maxCol = -1;
      for (final c in row.findElements('c', namespace: _ns)) {
        final ref = c.getAttribute('r') ?? '';
        final col = _colIndex(ref);
        if (col < 0) continue;
        maxCol = col > maxCol ? col : maxCol;
        cells[col] = _cellValue(c, shared);
      }
      if (maxCol < 0) {
        rowsOut.add(const []);
        continue;
      }
      final list = List<String>.filled(maxCol + 1, '');
      cells.forEach((i, v) => list[i] = v);
      rowsOut.add(list);
    }
    return rowsOut;
  }

  static String _cellValue(XmlElement c, List<String> shared) {
    final type = c.getAttribute('t');
    // Prefer cached calculated value even when formula exists.
    final vEl = c.getElement('v', namespace: _ns);
    final inline = c.getElement('is', namespace: _ns);

    if (type == 'inlineStr' && inline != null) {
      return inline
          .findAllElements('t', namespace: _ns)
          .map((e) => e.innerText)
          .join()
          .trim();
    }

    final raw = vEl?.innerText;
    if (raw == null || raw.isEmpty) return '';

    if (type == 's') {
      final idx = int.tryParse(raw);
      if (idx == null || idx < 0 || idx >= shared.length) return '';
      return shared[idx].trim();
    }

    // t=str (formula result), n/null (number), b (bool), etc.
    return raw.trim();
  }

  /// Convert Excel ref like "B12" / "AA2" to 0-based column index.
  static int _colIndex(String ref) {
    final m = RegExp(r'^([A-Za-z]+)').firstMatch(ref);
    if (m == null) return -1;
    final letters = m.group(1);
    if (letters == null || letters.isEmpty) return -1;
    var n = 0;
    for (final cu in letters.toUpperCase().codeUnits) {
      n = n * 26 + (cu - 64);
    }
    return n - 1;
  }
}
