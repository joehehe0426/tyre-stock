import 'dart:convert';
import 'dart:html' as html;
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'xlsx_reader.dart';

void main() => runApp(ErrorBoundary(child: MaterialApp(
  title: '呔妹輪胎', debugShowCheckedModeBanner: false,
  theme: ThemeData(colorSchemeSeed: const Color(0xFFD81B60), useMaterial3: true),
  home: PinGate(),
)));

class ErrorBoundary extends StatefulWidget {
  final Widget child;
  const ErrorBoundary({super.key, required this.child});
  @override State<ErrorBoundary> createState() => _ErrorBoundaryState();
}
class _ErrorBoundaryState extends State<ErrorBoundary> {
  String? _err;
  @override Widget build(BuildContext context) {
    if (_err != null) return Scaffold(
      appBar: AppBar(title: const Text('呔妹輪胎')),
      body: Center(child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.error_outline, size: 64, color: Colors.red),
          const SizedBox(height: 16),
          const Text('發生錯誤', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(_err!, textAlign: TextAlign.center),
          const SizedBox(height: 16),
          FilledButton(onPressed: () { setState(() => _err = null); }, child: const Text('重試')),
        ]),
      )),
    );
    return FlutterErrorOnDetails(
      onError: (d) => setState(() => _err = d.exception.toString()),
      child: widget.child,
    );
  }
}
class FlutterErrorOnDetails extends StatefulWidget {
  final Widget child;
  final void Function(FlutterErrorDetails) onError;
  const FlutterErrorOnDetails({super.key, required this.child, required this.onError});
  @override State<FlutterErrorOnDetails> createState() => _FlutterErrorOnDetailsState();
}
class _FlutterErrorOnDetailsState extends State<FlutterErrorOnDetails> {
  @override void initState() {
    super.initState();
    FlutterError.onError = (d) {
      widget.onError(d);
      FlutterError.presentError(d);
    };
  }
  @override Widget build(BuildContext context) => widget.child;
}

class PinGate extends StatefulWidget {
  const PinGate({super.key});
  @override State<PinGate> createState() => _PinGateState();
}
class _PinGateState extends State<PinGate> {
  bool _authed = false;
  static const String _defPin = '250183418';
  static const String _oldDefPin = 'tyre888';
  @override void initState() { super.initState(); _check(); }
  Future<void> _check() async {
    final p = await SharedPreferences.getInstance();
    final existing = p.getString('pin');
    if (existing == null || existing == _oldDefPin) {
      await p.setString('pin', _defPin);
    }
    if (mounted) setState(() => _authed = (p.getBool('authed') ?? false));
  }
  Future<bool> _tryPin(String pin) async {
    final p = await SharedPreferences.getInstance();
    final s = p.getString('pin') ?? _defPin;
    if (pin == s) { await p.setBool('authed', true); return true; }
    return false;
  }
  Future<void> _changePin(BuildContext ctx) async {
    final ctrl = TextEditingController();
    final r = await showDialog<String>(context: ctx, builder: (c) => AlertDialog(
      title: const Text('更改密碼'),
      content: TextField(controller: ctrl, obscureText: true,
        decoration: const InputDecoration(labelText: '新密碼', border: OutlineInputBorder(), isDense: true)),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(c, ctrl.text.trim()), child: const Text('確定')),
      ],
    ));
    ctrl.dispose();
    if (r != null && r.isNotEmpty) {
      (await SharedPreferences.getInstance()).setString('pin', r);
      if (ctx.mounted) ScaffoldMessenger.of(ctx).showSnackBar(
        const SnackBar(content: Text('密碼已更改'), backgroundColor: Colors.green));
    }
  }
  @override Widget build(BuildContext context) {
    if (_authed) return HomePage(onChangePin: () => _changePin(context));
    return Scaffold(body: Center(child: _PinForm(onPin: (pin) async {
      final ok = await _tryPin(pin);
      if (ok && mounted) setState(() => _authed = true);
      return ok;
    })));
  }
}
class _PinForm extends StatefulWidget {
  final Future<bool> Function(String) onPin;
  const _PinForm({required this.onPin});
  @override State<_PinForm> createState() => _PinFormState();
}
class _PinFormState extends State<_PinForm> {
  final _c = TextEditingController();
  bool _wrong = false;
  Future<void> _submit() async {
    final ok = await widget.onPin(_c.text);
    setState(() => _wrong = !ok);
    if (!ok) _c.clear();
  }
  @override void dispose() { _c.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.all(32),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Container(width: 80, height: 80,
        decoration: BoxDecoration(color: Theme.of(context).colorScheme.primary, borderRadius: BorderRadius.circular(40)),
        child: const Icon(Icons.lock, color: Colors.white, size: 36)),
      const SizedBox(height: 16),
      const Text('呔妹輪胎庫存', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      const Text('請輸入密碼', style: TextStyle(color: Colors.grey)),
      const SizedBox(height: 20),
      TextField(controller: _c, obscureText: true, autofocus: true,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 24, letterSpacing: 8),
        decoration: InputDecoration(
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          errorText: _wrong ? '密碼錯誤' : null),
        onSubmitted: (_) => _submit()),
      const SizedBox(height: 12),
      FilledButton.icon(onPressed: _submit, icon: const Icon(Icons.login), label: const Text('登入'),
        style: FilledButton.styleFrom(minimumSize: const Size(double.infinity, 48))),
      const SizedBox(height: 12),
      Text('🔑 預設密碼: 250183418', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
    ]),
  );
}

class HomePage extends StatefulWidget {
  final VoidCallback? onChangePin;
  const HomePage({super.key, this.onChangePin});
  @override State<HomePage> createState() => _HomePageState();
}
class _HomePageState extends State<HomePage> {
  int _tab = 0;
  @override Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _tab, children: [
      StockPage(onChangePin: widget.onChangePin),
      const FitmentPage(),
    ]),
    bottomNavigationBar: NavigationBar(
      selectedIndex: _tab,
      onDestinationSelected: (i) => setState(() => _tab = i),
      destinations: const [
        NavigationDestination(icon: Icon(Icons.inventory_2), label: '庫存'),
        NavigationDestination(icon: Icon(Icons.search), label: '配對'),
      ],
    ),
  );
}

class StockPage extends StatefulWidget {
  final VoidCallback? onChangePin;
  const StockPage({super.key, this.onChangePin});
  @override State<StockPage> createState() => _StockPageState();
}
class _StockPageState extends State<StockPage> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  String _search = '', _brandF = '', _widthF = '', _aspectF = '', _rimF = '';
  String? _sheetUrl;
  bool _loaded = false;
  String? _err;

  @override void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    try {
      final p = await SharedPreferences.getInstance();
      _sheetUrl = p.getString('sheet_url');
      final s = p.getString('d');
      if (s != null && s.isNotEmpty) {
        final parsed = jsonDecode(s);
        if (parsed is List) {
          final cleaned = <Map<String, dynamic>>[];
          for (final item in parsed) {
            if (item is! Map) continue;
            final m = Map<String, dynamic>.from(item);
            if (_isValidTyre(m)) cleaned.add(m);
          }
          _all = cleaned;
          final removed = _mergeAllDuplicates();
          // Drop corrupted / duplicate cache
          if (cleaned.length != parsed.length || removed > 0) {
            if (_all.isEmpty) {
              await p.remove('d');
            } else {
              await p.setString('d', jsonEncode(_all));
            }
          }
        }
      }
      if (_all.isEmpty) {
        final ok = await _loadFromSheet();
        if (!ok) { _err = '上傳 stock.xlsx 開始使用'; }
      }
    } catch (_) {
      try {
        await (await SharedPreferences.getInstance()).remove('d');
      } catch (_) {}
      _all = [];
      _err = '本機資料損壞，已清除。請重新上傳 stock.xlsx';
    }
    _reload();
    if (mounted) setState(() => _loaded = true);
  }

  /// Reject junk entries (minified JS, empty brand, impossible sizes).
  bool _isValidTyre(Map<String, dynamic> m) {
    final br = '${m['br'] ?? ''}'.trim();
    final pt = '${m['pt'] ?? ''}'.trim();
    if (br.isEmpty) return false;
    if (br.length > 80 || pt.length > 120) return false;
    final blob = '$br $pt'.toLowerCase();
    if (blob.contains('function') ||
        blob.contains('globalthis') ||
        blob.contains('prototype') ||
        blob.contains('__proto__') ||
        blob.contains('=>') ||
        blob.contains('{') ||
        blob.contains('}')) {
      return false;
    }
    final w = m['w'];
    final ri = m['ri'];
    final wi = w is num ? w.toInt() : int.tryParse('$w') ?? 0;
    final rii = ri is num ? ri.toInt() : int.tryParse('$ri') ?? 0;
    // Allow 0 size only if brand looks normal; prefer real sizes when present.
    if (wi < 0 || wi > 500 || rii < 0 || rii > 40) return false;
    return true;
  }

  /// Read uploaded file as bytes via Data URL (most reliable on Flutter web).
  Future<Uint8List> _readFileAsBytes(html.File file) async {
    final reader = html.FileReader();
    reader.readAsDataUrl(file);
    await reader.onLoadEnd.first.timeout(const Duration(seconds: 60));
    if (reader.error != null) throw '檔案讀取失敗';
    final dataUrl = reader.result;
    if (dataUrl is! String || dataUrl.isEmpty) throw '讀取結果為空';
    final comma = dataUrl.indexOf(',');
    if (comma < 0) throw '無法解析檔案內容';
    try {
      return base64Decode(dataUrl.substring(comma + 1));
    } catch (_) {
      throw '檔案解碼失敗（請使用 .xlsx）';
    }
  }

  String _rowCell(List<String> row, int idx) {
    if (idx < 0 || idx >= row.length) return '';
    return row[idx].trim();
  }

  /// Same tyre = same brand + size + pattern + year (case-insensitive).
  String _tyreKey(Map<String, dynamic> m) {
    final br = '${m['br'] ?? ''}'.trim().toUpperCase();
    final pt = '${m['pt'] ?? ''}'.trim().toUpperCase();
    final yr = '${m['yr'] ?? ''}'.trim();
    final w = m['w'] is num ? (m['w'] as num).toInt() : int.tryParse('${m['w']}') ?? 0;
    final a = m['a'] is num ? (m['a'] as num).toInt() : int.tryParse('${m['a']}') ?? 0;
    final ri = m['ri'] is num ? (m['ri'] as num).toInt() : int.tryParse('${m['ri']}') ?? 0;
    return '$br|$w|$a|$ri|$pt|$yr';
  }

  int _asInt(dynamic v, [int fallback = 0]) {
    if (v is num) return v.toInt();
    return int.tryParse('$v') ?? fallback;
  }

  double _asDouble(dynamic v, [double fallback = 0]) {
    if (v is num) return v.toDouble();
    return double.tryParse('$v') ?? fallback;
  }

  /// Insert or merge into [_all]: identical keys sum stock; keep non-empty fields.
  void _upsertTyre(Map<String, dynamic> row) {
    final key = _tyreKey(row);
    final i = _all.indexWhere((x) => _tyreKey(x) == key);
    if (i < 0) {
      _all.add(Map<String, dynamic>.from(row));
      return;
    }
    final cur = _all[i];
    cur['st'] = _asInt(cur['st']) + _asInt(row['st'], 1);
    final rowSp = _asDouble(row['sp']);
    if (rowSp > 0) cur['sp'] = rowSp;
    final rowDe = '${row['de'] ?? ''}'.trim();
    if (rowDe.isNotEmpty) cur['de'] = rowDe;
    final rowSu = '${row['su'] ?? ''}'.trim();
    if (rowSu.isNotEmpty) cur['su'] = rowSu;
    _all[i] = cur;
  }

  /// Collapse any existing duplicates in [_all]. Returns how many rows were removed.
  int _mergeAllDuplicates() {
    if (_all.length < 2) return 0;
    final before = _all.length;
    final merged = <Map<String, dynamic>>[];
    final indexByKey = <String, int>{};
    for (final row in _all) {
      final key = _tyreKey(row);
      final existing = indexByKey[key];
      if (existing == null) {
        indexByKey[key] = merged.length;
        merged.add(Map<String, dynamic>.from(row));
        continue;
      }
      final cur = merged[existing];
      cur['st'] = _asInt(cur['st']) + _asInt(row['st'], 1);
      final rowSp = _asDouble(row['sp']);
      if (rowSp > 0) cur['sp'] = rowSp;
      final rowDe = '${row['de'] ?? ''}'.trim();
      if (rowDe.isNotEmpty) cur['de'] = rowDe;
      final rowSu = '${row['su'] ?? ''}'.trim();
      if (rowSu.isNotEmpty) cur['su'] = rowSu;
    }
    _all = merged;
    return before - _all.length;
  }

  /// Parse tyre size: 255/55/19, 255/55/R19, 235/40 /18, /195/65/15, 215/70/16C
  ({int w, int a, int ri})? _parseSize(String raw) {
    var cleaned = raw.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    if (cleaned.isEmpty) return null;
    cleaned = cleaned.replaceAll('*', '/').replaceAll('-', '/');
    cleaned = cleaned.replaceFirst(RegExp(r'^/+'), '');
    cleaned = cleaned.replaceFirst(RegExp(r'C+$'), '');

    var m = RegExp(r'^(\d+)/(\d+)/R?(\d+)$').firstMatch(cleaned);
    if (m == null) {
      m = RegExp(r'^(\d+)/(\d{2})(\d{2})$').firstMatch(cleaned);
    }
    if (m == null) return null;
    final g1 = m.group(1);
    final g2 = m.group(2);
    final g3 = m.group(3);
    if (g1 == null || g2 == null || g3 == null) return null;
    final w = int.tryParse(g1) ?? 0;
    final a = int.tryParse(g2) ?? 0;
    final ri = int.tryParse(g3) ?? 0;
    if (w == 0 || ri == 0) return null;
    return (w: w, a: a, ri: ri);
  }

  int _findHeaderCol(List<String> hdr, List<String> aliases) {
    for (int i = 0; i < hdr.length; i++) {
      final h = hdr[i].trim().toLowerCase();
      for (final a in aliases) {
        if (h == a || h.contains(a)) return i;
      }
    }
    return -1;
  }

  void _pickFile() {
    final input = html.FileUploadInputElement()
      ..accept =
          '.xlsx,application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
    input.click();
    input.onChange.listen((_) async {
      try {
        final files = input.files;
        if (files == null || files.isEmpty) return;
        final file = files.first;
        final name = file.name.toLowerCase();
        if (name.endsWith('.xls') && !name.endsWith('.xlsx')) {
          throw '請另存為 .xlsx 後再上傳（不支援舊版 .xls）';
        }
        final bytes = await _readFileAsBytes(file);
        if (bytes.length < 4) throw '檔案太小或損壞';
        if (bytes[0] != 0x50 || bytes[1] != 0x4B) {
          throw '不是有效的 .xlsx 檔（請用 Excel「另存新檔」為 .xlsx）';
        }
        final rawRows = await _parseXlsxFromBytes(bytes);
        await (await SharedPreferences.getInstance())
            .setString('d', jsonEncode(_all));
        _err = null;
        _reload();
        if (mounted) setState(() {});
        if (mounted) {
          final merged = rawRows - _all.length;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(merged > 0
                  ? '已載入 ${_all.length} 款（合併了 $merged 筆重複）'
                  : '已載入 ${_all.length} 款'),
              backgroundColor: Colors.green,
            ),
          );
        }
      } catch (e, st) {
        debugPrint('upload failed: $e\n$st');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('上傳失敗: $e'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    });
  }

  /// Returns how many data rows were read before duplicate merge.
  Future<int> _parseXlsxFromBytes(Uint8List bytes) async {
    late final List<List<String>> rows;
    try {
      rows = XlsxReader.readSheetMatrix(bytes);
    } catch (e) {
      throw 'Excel 解碼失敗: $e';
    }
    if (rows.length < 2) throw '工作表無數據';

    _all.clear();
    var rawCount = 0;

    final hdr = rows[0];
    final sizeIdx = _findHeaderCol(hdr, ['size', '尺寸']);
    final brandIdx = _findHeaderCol(hdr, ['brand', '品牌']);
    final descIdx =
        _findHeaderCol(hdr, ['description', 'desc', '描述', '型號', 'pattern']);
    final priceIdx = _findHeaderCol(hdr, ['price', '售價', '賣價', 'sp']);
    final stockIdx =
        _findHeaderCol(hdr, ['stock', 'qty', 'quantity', '庫存', '數量']);
    final yearIdx = _findHeaderCol(hdr, ['year', '年份', '年']);
    final hasSizeLayout = sizeIdx >= 0;

    for (int r = 1; r < rows.length; r++) {
      final row = rows[r];
      if (row.every((c) => c.trim().isEmpty)) continue;

      if (hasSizeLayout) {
        final sz = _rowCell(row, sizeIdx);
        if (sz.isEmpty) continue;
        final parsed = _parseSize(sz);
        if (parsed == null) continue;

        var b = _rowCell(row, brandIdx);
        if (b.startsWith('=')) b = '';
        final d = _rowCell(row, descIdx);
        if (b.isEmpty && d.isNotEmpty) {
          final parts = d.split(RegExp(r'\s+'));
          b = parts.isNotEmpty ? parts.first : '';
        }
        if (b.isEmpty) continue;

        var pt = d;
        final bu = b.toUpperCase();
        final ptu = pt.toUpperCase();
        if (ptu.startsWith(bu)) {
          pt = pt.length > b.length ? pt.substring(b.length).trim() : '';
        }
        if (pt.isEmpty) pt = d.isNotEmpty ? d : b;

        final priceRaw =
            priceIdx >= 0 ? _rowCell(row, priceIdx) : _rowCell(row, 5);
        final pr =
            double.tryParse(priceRaw.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
        final stRaw = _rowCell(row, stockIdx);
        final st = int.tryParse(stRaw.replaceAll(RegExp(r'[^\d]'), '')) ?? 1;
        final year = _rowCell(row, yearIdx);

        rawCount++;
        _upsertTyre({
          'br': b,
          'pt': pt,
          'w': parsed.w,
          'a': parsed.a,
          'ri': parsed.ri,
          'sp': pr,
          'st': st,
          'su': '',
          'de': d.isNotEmpty ? d : (year.isNotEmpty ? year : sz),
          'yr': year,
        });
      } else {
        final c0 = _rowCell(row, 0);
        if (c0.isEmpty || c0.startsWith('=')) continue;
        final maybeSize = _parseSize(c0);
        if (maybeSize != null) {
          final b = _rowCell(row, 1);
          final d = _rowCell(row, 2);
          final brand = (b.startsWith('=') || b.isEmpty)
              ? (d.isNotEmpty ? d.split(RegExp(r'\s+')).first : '')
              : b;
          if (brand.isEmpty) continue;
          rawCount++;
          _upsertTyre({
            'br': brand,
            'pt': d,
            'w': maybeSize.w,
            'a': maybeSize.a,
            'ri': maybeSize.ri,
            'sp': double.tryParse(
                    _rowCell(row, 4).replaceAll(RegExp(r'[^\d.]'), '')) ??
                0,
            'st': 1,
            'su': '',
            'de': d,
            'yr': '',
          });
          continue;
        }
        rawCount++;
        _upsertTyre({
          'br': c0,
          'pt': _rowCell(row, 1),
          'w': int.tryParse(_rowCell(row, 2)) ?? 0,
          'a': int.tryParse(_rowCell(row, 3)) ?? 0,
          'ri': int.tryParse(_rowCell(row, 4)) ?? 0,
          'bp': double.tryParse(_rowCell(row, 5)) ?? 0,
          'sp': double.tryParse(_rowCell(row, 6)) ?? 0,
          'st': int.tryParse(_rowCell(row, 7)) ?? 0,
          'su': _rowCell(row, 9),
          'de': _rowCell(row, 10),
          'yr': '',
        });
      }
    }
    if (_all.isEmpty) {
      throw '找不到有效數據（請確認有 Size／Brand 欄，尺寸如 245/40/18）';
    }
    return rawCount;
  }
  List<String> _splitCsv(String row) {
    final r = <String>[];
    bool q = false;
    String c = '';
    for (int i = 0; i < row.length; i++) {
      if (row[i] == '"') { q = !q; continue; }
      if (row[i] == ',' && !q) { r.add(c); c = ''; continue; }
      c += row[i];
    }
    r.add(c);
    return r;
  }

  Future<bool> _loadFromSheet() async {
    if (_sheetUrl == null || _sheetUrl!.isEmpty) return false;
    try {
      final rawUrl = _sheetUrl!;
      final url = rawUrl.startsWith('http')
          ? rawUrl
          : 'https://docs.google.com/spreadsheets/d/$_sheetUrl/export?format=csv';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      _all.clear();
      final lines = res.body.split('\n')
          .map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
      if (lines.length < 2) return false;
      final hasSize = lines[0].toLowerCase().contains('size');
      for (int r = 1; r < lines.length; r++) {
        final cells = _splitCsv(lines[r]);
        if (hasSize && cells.length >= 3) {
          final parsed = _parseSize(cells[0]);
          if (parsed != null) {
            final b = cells.length > 1 ? cells[1].trim() : '';
            final d = cells.length > 2 ? cells[2].trim() : '';
            var brand = b.startsWith('=') ? '' : b;
            if (brand.isEmpty && d.isNotEmpty) {
              brand = d.split(RegExp(r'\s+')).first;
            }
            if (brand.isEmpty) continue;
            String pt = d;
            if (pt.toUpperCase().startsWith(brand.toUpperCase())) {
              pt = pt.substring(brand.length).trim();
            }
            if (pt.isEmpty) pt = d;
            final pr = double.tryParse(cells.last.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
            _upsertTyre({
              'br': brand,
              'pt': pt,
              'w': parsed.w,
              'a': parsed.a,
              'ri': parsed.ri,
              'sp': pr,
              'st': 1,
              'su': '',
              'de': d,
              'yr': '',
            });
          }
        } else if (cells.length >= 3) {
          _upsertTyre({
            'br': cells[0].trim(),
            'pt': cells[1].trim(),
            'w': 0,
            'a': 0,
            'ri': 0,
            'sp': double.tryParse(cells.last.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0,
            'st': 1,
            'su': '',
            'de': cells.length > 2 ? cells[2].trim() : '',
            'yr': '',
          });
        }
      }
      if (_all.isNotEmpty) {
        await (await SharedPreferences.getInstance()).setString('d', jsonEncode(_all));
        _err = null;
        return true;
      }
    } catch (e) { _err = 'Google Sheet error: $e'; }
    return false;
  }

  Future<void> _setSheetUrl() async {
    final ctrl = TextEditingController(text: _sheetUrl ?? '');
    final url = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Google Sheet'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('貼上 Google Sheet 分享連結'),
        const SizedBox(height: 8),
        TextField(controller: ctrl, decoration: const InputDecoration(
          hintText: 'https://docs.google.com/spreadsheets/d/...', isDense: true, border: OutlineInputBorder()), maxLines: 2),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('清除')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('儲存')),
      ],
    ));
    ctrl.dispose();
    if (url == null) return;
    _sheetUrl = url;
    final p = await SharedPreferences.getInstance();
    if (url.isEmpty) await p.remove('sheet_url');
    else await p.setString('sheet_url', url);
  }

  String _size(Map<String, dynamic> m) {
    final w = m['w'] ?? 0; final a = m['a'] ?? 0; final ri = m['ri'] ?? 0;
    if ((w is int && w > 0) || (w is double && w > 0)) return '${w.toString()}/${a.toString()}R${ri.toString()}';
    return '';
  }
  String _rimL(Map<String, dynamic> m) => '${m['ri']?.toString() ?? ''}"';
  Future<void> _save() async => (await SharedPreferences.getInstance()).setString('d', jsonEncode(_all));
  void _reload() {
    _filtered = _all.where((t) {
      if (_brandF.isNotEmpty && t['br'] != _brandF) return false;
      if (_widthF.isNotEmpty && '${t['w'] ?? ''}' != _widthF) return false;
      if (_aspectF.isNotEmpty && '${t['a'] ?? ''}' != _aspectF) return false;
      if (_rimF.isNotEmpty && '${t['ri'] ?? ''}' != _rimF.replaceAll('"', '')) {
        return false;
      }
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final br = t['br']?.toString().toLowerCase() ?? '';
        final pt = t['pt']?.toString().toLowerCase() ?? '';
        final sz = _size(t).toLowerCase();
        return br.contains(q) || pt.contains(q) || sz.contains(q);
      }
      return true;
    }).toList();
  }
  void _apply() { _reload(); setState(() {}); }
  Future<void> _reloadAll() async { setState(() => _loaded = false); await _init(); }

  Future<void> _clearLocal() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('清除本機庫存？'),
        content: const Text('會刪除瀏覽器內已儲存的輪胎資料，不會影響你的 Excel 檔。'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('清除')),
        ],
      ),
    );
    if (ok != true) return;
    final p = await SharedPreferences.getInstance();
    await p.remove('d');
    _all = [];
    _filtered = [];
    _brandF = '';
    _widthF = '';
    _aspectF = '';
    _rimF = '';
    _search = '';
    _err = '上傳 stock.xlsx 開始使用';
    if (mounted) setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('已清除本機庫存'), backgroundColor: Colors.green),
      );
    }
  }

  @override Widget build(BuildContext context) {
    if (!_loaded) return Scaffold(
      appBar: AppBar(title: const Text('呔妹輪胎'), actions: [
        if (widget.onChangePin != null)
          IconButton(icon: const Icon(Icons.settings), tooltip: '更改密碼', onPressed: widget.onChangePin),
      ]),
      body: Center(child: _err != null
        ? Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.upload_file, size: 64, color: Colors.grey),
            const SizedBox(height: 16),
            Text(_err ?? '', textAlign: TextAlign.center, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 16),
            FilledButton.icon(onPressed: _pickFile, icon: const Icon(Icons.file_upload), label: const Text('上傳 stock.xlsx')),
            const SizedBox(height: 8),
            OutlinedButton.icon(onPressed: _setSheetUrl, icon: const Icon(Icons.link), label: const Text('或連結 Google Sheet')),
          ]))
        : const CircularProgressIndicator()),
    );
    final brands = _all.map((t) => t['br']?.toString() ?? '').where((b) => b.isNotEmpty).toSet().toList()..sort();
    List<String> _uniqNums(String key) {
      final vals = _all
          .map((t) {
            final v = t[key];
            if (v is num && v > 0) return '${v.toInt()}';
            final p = int.tryParse('${v ?? ''}');
            return (p != null && p > 0) ? '$p' : '';
          })
          .where((s) => s.isNotEmpty)
          .toSet()
          .toList();
      vals.sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
      return vals;
    }
    final widths = _uniqNums('w');
    final aspects = _uniqNums('a');
    final rims = _uniqNums('ri');
    final hasSizeFilters = widths.isNotEmpty || aspects.isNotEmpty || rims.isNotEmpty;
    final hasAnyFilter = _brandF.isNotEmpty ||
        _widthF.isNotEmpty ||
        _aspectF.isNotEmpty ||
        _rimF.isNotEmpty ||
        _search.isNotEmpty;
    return Scaffold(
      appBar: AppBar(title: const Text('呔妹輪胎'), actions: [
        if (widget.onChangePin != null)
          IconButton(icon: const Icon(Icons.settings), tooltip: '更改密碼', onPressed: widget.onChangePin),
        if (_sheetUrl != null && _sheetUrl!.isNotEmpty)
          Tooltip(message: '已連結 Google Sheet',
            child: Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.cloud_done, size: 18, color: Colors.green.shade300))),
        IconButton(icon: const Icon(Icons.file_upload), tooltip: '上傳 stock.xlsx', onPressed: _pickFile),
        IconButton(icon: const Icon(Icons.link), tooltip: 'Google Sheet', onPressed: _setSheetUrl),
        IconButton(icon: const Icon(Icons.delete_outline), tooltip: '清除本機庫存', onPressed: _clearLocal),
        IconButton(icon: const Icon(Icons.refresh), tooltip: '重新載入', onPressed: _reloadAll),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('${_filtered.length}/${_all.length}款', style: Theme.of(context).textTheme.bodySmall)),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: TextField(
          decoration: InputDecoration(hintText: '搜索品牌／型號／尺寸...', prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12)),
          onChanged: (v) { _search = v; _apply(); })),
        if (brands.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: DropdownButtonFormField<String>(
              value: _brandF.isEmpty ? '' : _brandF,
              decoration: const InputDecoration(
                labelText: '品牌',
                isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              items: [
                const DropdownMenuItem<String>(value: '', child: Text('全部')),
                ...brands.map((b) => DropdownMenuItem(value: b, child: Text(b))),
              ],
              onChanged: (v) { _brandF = v ?? ''; _apply(); },
            ),
          ),
        if (hasSizeFilters)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
            child: Row(children: [
              if (widths.isNotEmpty)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _widthF.isEmpty ? '' : _widthF,
                    decoration: const InputDecoration(
                      labelText: '闊度',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: '', child: Text('全部')),
                      ...widths.map((w) => DropdownMenuItem(value: w, child: Text(w))),
                    ],
                    onChanged: (v) { _widthF = v ?? ''; _apply(); },
                  ),
                ),
              if (widths.isNotEmpty && (aspects.isNotEmpty || rims.isNotEmpty))
                const SizedBox(width: 8),
              if (aspects.isNotEmpty)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _aspectF.isEmpty ? '' : _aspectF,
                    decoration: const InputDecoration(
                      labelText: '扁平比',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: '', child: Text('全部')),
                      ...aspects.map((a) => DropdownMenuItem(value: a, child: Text(a))),
                    ],
                    onChanged: (v) { _aspectF = v ?? ''; _apply(); },
                  ),
                ),
              if (aspects.isNotEmpty && rims.isNotEmpty) const SizedBox(width: 8),
              if (rims.isNotEmpty)
                Expanded(
                  child: DropdownButtonFormField<String>(
                    value: _rimF.isEmpty ? '' : _rimF,
                    decoration: const InputDecoration(
                      labelText: '吋徑',
                      isDense: true,
                      contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                    ),
                    items: [
                      const DropdownMenuItem<String>(value: '', child: Text('全部')),
                      ...rims.map((r) => DropdownMenuItem(value: r, child: Text('${r}"'))),
                    ],
                    onChanged: (v) { _rimF = v ?? ''; _apply(); },
                  ),
                ),
            ]),
          ),
        if (hasAnyFilter)
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
            child: Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () {
                  _search = '';
                  _brandF = '';
                  _widthF = '';
                  _aspectF = '';
                  _rimF = '';
                  _apply();
                },
                icon: const Icon(Icons.filter_alt_off, size: 18),
                label: Text('清除篩選（顯示 ${_filtered.length} 款）'),
              ),
            ),
          ),
        Expanded(child: _filtered.isEmpty
          ? const Center(child: Text('無匹配'))
          : ListView.builder(itemCount: _filtered.length, itemBuilder: (_, i) {
              final t = _filtered[i];
              final sz = _size(t);
              final st = t['st'];
              final sp = t['sp'];
              final stOk = (st is int || st is double);
              final stVal = stOk ? (st as num).toInt() : 0;
              final spVal = (sp is int || sp is double) ? (sp as num).toInt() : 0;
              return Card(margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3), child: ListTile(
                title: Text('${t['br'] ?? ''} ${t['pt'] ?? ''}',
                  style: const TextStyle(fontWeight: FontWeight.w500)),
                subtitle: Text(sz.isNotEmpty ? '$sz  \$$spVal' : '\$$spVal'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Text(stVal.toString(), style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold,
                    color: stVal < 10 ? Colors.red : Theme.of(context).colorScheme.primary)),
                  const SizedBox(width: 4),
                  Text('條', style: Theme.of(context).textTheme.bodySmall),
                ]),
                onTap: () => _edit(t),
              ));
            })),
      ]),
      floatingActionButton: FloatingActionButton(onPressed: _add, child: const Icon(Icons.add)),
    );
  }

  void _edit(Map<String, dynamic> t) async {
    final r = await _dialog(t, false);
    if (r == null) return;
    r['yr'] = '${t['yr'] ?? ''}';
    final i = _all.indexWhere((x) => identical(x, t));
    if (i >= 0) {
      _all.removeAt(i);
    } else {
      final oldKey = _tyreKey(t);
      final i2 = _all.indexWhere((x) => _tyreKey(x) == oldKey);
      if (i2 >= 0) _all.removeAt(i2);
    }
    _upsertTyre(r);
    await _save();
    _reload();
    if (mounted) setState(() {});
  }

  void _add() async {
    final r = await _dialog(null, true);
    if (r == null) return;
    r['yr'] = '';
    final before = _all.length;
    _upsertTyre(r);
    final merged = _all.length == before;
    await _save();
    _reload();
    if (mounted) setState(() {});
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(merged ? '相同規格已合併數量' : '已新增庫存'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  Future<Map<String, dynamic>?> _dialog(Map<String, dynamic>? t, bool isNew) async {
    final bc = TextEditingController(text: t?['br']?.toString() ?? '');
    final pc = TextEditingController(text: t?['pt']?.toString() ?? '');
    final sc = TextEditingController(text: '${t?['st'] ?? 0}');
    final spc = TextEditingController(text: '${t?['sp'] ?? 0}');
    final suc = TextEditingController(text: t?['su']?.toString() ?? '');
    final dc = TextEditingController(text: t?['de']?.toString() ?? '');
    int w = (t?['w'] is num) ? (t!['w'] as num).toInt() : 205;
    int a = (t?['a'] is num) ? (t!['a'] as num).toInt() : 55;
    int ri = (t?['ri'] is num) ? (t!['ri'] as num).toInt() : 16;
    final fk = GlobalKey<FormState>();
    final r = await showDialog<Map<String, dynamic>>(context: context, builder: (ctx) => AlertDialog(
      title: Text(isNew ? '新增' : '編輯'),
      content: Form(key: fk, child: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextFormField(controller: bc, decoration: const InputDecoration(labelText: '品牌', isDense: true),
          validator: (v) => (v == null || v.isEmpty) ? '必填' : null),
        TextFormField(controller: pc, decoration: const InputDecoration(labelText: '型號', isDense: true),
          validator: (v) => (v == null || v.isEmpty) ? '必填' : null),
        Row(children: [
          Expanded(child: TextFormField(initialValue: w.toString(), decoration: const InputDecoration(labelText: '闊', isDense: true),
            keyboardType: TextInputType.number, onChanged: (v) => w = int.tryParse(v) ?? 0)),
          const SizedBox(width: 6),
          Expanded(child: TextFormField(initialValue: a.toString(), decoration: const InputDecoration(labelText: '扁平', isDense: true),
            keyboardType: TextInputType.number, onChanged: (v) => a = int.tryParse(v) ?? 0)),
          const SizedBox(width: 6),
          Expanded(child: TextFormField(initialValue: ri.toString(), decoration: const InputDecoration(labelText: '鈴', isDense: true),
            keyboardType: TextInputType.number, onChanged: (v) => ri = int.tryParse(v) ?? 0)),
        ]),
        TextFormField(controller: spc, decoration: const InputDecoration(labelText: '賣出價 \$', isDense: true),
          keyboardType: TextInputType.number),
        TextFormField(controller: suc, decoration: const InputDecoration(labelText: '供應商', isDense: true)),
        TextFormField(controller: dc, decoration: const InputDecoration(labelText: '描述', isDense: true), maxLines: 2),
        const SizedBox(height: 12),
        Text('庫存', style: Theme.of(context).textTheme.labelMedium),
        const SizedBox(height: 4),
        Wrap(spacing: 6, runSpacing: 6, children: [0, 2, 4, 6, 8, 10, 20, 50, 100].map((q) => ChoiceChip(
          label: Text(q.toString(), style: const TextStyle(fontSize: 13)),
          selected: int.tryParse(sc.text) == q,
          onSelected: (_) { sc.text = q.toString(); setState(() {}); },
        )).toList()),
        const SizedBox(height: 8),
        Row(children: [
          IconButton.filledTonal(
            onPressed: () { int v = int.tryParse(sc.text) ?? 0; sc.text = ((v + 1).clamp(0, 99999)).toString(); setState(() {}); },
            icon: const Icon(Icons.add)),
          const SizedBox(width: 8),
          Expanded(child: TextFormField(controller: sc, decoration: const InputDecoration(isDense: true, hintText: '數量'),
            keyboardType: TextInputType.number, textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))),
          const SizedBox(width: 8),
          IconButton.filledTonal(
            onPressed: () { int v = int.tryParse(sc.text) ?? 0; sc.text = ((v - 1).clamp(0, 99999)).toString(); setState(() {}); },
            icon: const Icon(Icons.remove)),
        ]),
      ]))),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () {
          if (fk.currentState?.validate() != true) return;
          Navigator.pop(ctx, {
            'br': bc.text, 'pt': pc.text, 'w': w, 'a': a, 'ri': ri,
            'sp': double.tryParse(spc.text) ?? 0,
            'st': int.tryParse(sc.text) ?? 0,
            'su': suc.text, 'de': dc.text,
          });
        }, child: Text(isNew ? '新增' : '儲存')),
      ],
    ));
    bc.dispose(); pc.dispose(); sc.dispose(); spc.dispose(); suc.dispose(); dc.dispose();
    return r;
  }
}

class FitmentPage extends StatefulWidget {
  const FitmentPage({super.key});
  @override State<FitmentPage> createState() => _FitmentPageState();
}

class _FitmentPageState extends State<FitmentPage> {
  /// Online Wheel Size API is only for tyre.autragroupltd.com.
  bool get _apiAllowed {
    final host = Uri.base.host;
    return host == 'tyre.autragroupltd.com' ||
        host == 'localhost' ||
        host == '127.0.0.1';
  }

  late bool _online;
  Map<String, dynamic>? _localData;
  bool _loaded = false;
  String? _err;
  bool _busy = false;

  // Local mode
  String? _lMake, _lModel;
  int? _lGen;
  Map<String, dynamic>? _lResult;

  // Online mode (slugs / values from API)
  List<Map<String, String>> _oMakes = [];
  List<Map<String, String>> _oModels = [];
  List<String> _oYears = [];
  List<Map<String, String>> _oMods = [];
  String? _oMake, _oModel, _oYear, _oMod;
  Map<String, dynamic>? _oResult;

  @override
  void initState() {
    super.initState();
    _online = _apiAllowed;
    _boot();
  }

  Future<void> _boot() async {
    try {
      _localData =
          jsonDecode(await rootBundle.loadString('assets/fitment_data.json'));
    } catch (_) {}
    if (mounted) setState(() => _loaded = true);
    if (_online && _apiAllowed) {
      await _loadOnlineMakes();
    }
  }

  String get _apiBase => Uri.base.origin;

  Future<Map<String, String>> _authHeaders() async {
    final p = await SharedPreferences.getInstance();
    final pin = p.getString('pin') ?? '250183418';
    final token = base64Encode(utf8.encode('madam:$pin'));
    return {'Authorization': 'Basic $token', 'Accept': 'application/json'};
  }

  Future<dynamic> _wsGet(String path, [Map<String, String>? query]) async {
    if (!_apiAllowed) {
      throw '線上 API 僅限 tyre.autragroupltd.com';
    }
    final uri = Uri.parse('$_apiBase/api/ws/$path')
        .replace(queryParameters: query);
    final res = await http
        .get(uri, headers: await _authHeaders())
        .timeout(const Duration(seconds: 20));
    if (res.statusCode == 401) {
      throw '未授權：請確認網站密碼／PIN';
    }
    if (res.statusCode == 503) {
      throw '尚未設定 Wheel Size API Key（Cloudflare Secret）';
    }
    if (res.statusCode != 200) {
      throw 'API ${res.statusCode}: ${res.body.length > 120 ? res.body.substring(0, 120) : res.body}';
    }
    return jsonDecode(res.body);
  }

  List<Map<String, String>> _slugNameList(dynamic raw) {
    final data = raw is Map ? raw['data'] : raw;
    if (data is! List) return [];
    final out = <Map<String, String>>[];
    for (final item in data) {
      if (item is! Map) continue;
      final slug = '${item['slug'] ?? ''}'.trim();
      final name = '${item['name'] ?? item['name_en'] ?? slug}'.trim();
      if (slug.isEmpty) continue;
      out.add({'slug': slug, 'name': name.isEmpty ? slug : name});
    }
    out.sort((a, b) => a['name']!.compareTo(b['name']!));
    return out;
  }

  Future<void> _loadOnlineMakes() async {
    setState(() {
      _busy = true;
      _err = null;
    });
    try {
      final raw = await _wsGet('makes');
      if (!mounted) return;
      setState(() {
        _oMakes = _slugNameList(raw);
        _oModels = [];
        _oYears = [];
        _oMods = [];
        _oMake = _oModel = _oYear = _oMod = null;
        _oResult = null;
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _err = '$e';
          _online = false; // fall back UX hint — user can still toggle
        });
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onOnlineMake(String? slug) async {
    setState(() {
      _oMake = slug;
      _oModel = _oYear = _oMod = null;
      _oModels = [];
      _oYears = [];
      _oMods = [];
      _oResult = null;
      _err = null;
    });
    if (slug == null) return;
    setState(() => _busy = true);
    try {
      final raw = await _wsGet('models', {'make': slug});
      if (!mounted) return;
      setState(() => _oModels = _slugNameList(raw));
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onOnlineModel(String? slug) async {
    setState(() {
      _oModel = slug;
      _oYear = _oMod = null;
      _oYears = [];
      _oMods = [];
      _oResult = null;
      _err = null;
    });
    if (slug == null || _oMake == null) return;
    setState(() => _busy = true);
    try {
      final raw = await _wsGet('years', {'make': _oMake!, 'model': slug});
      final data = raw is Map ? raw['data'] : raw;
      final years = <String>[];
      if (data is List) {
        for (final y in data) {
          if (y is Map) {
            final s = '${y['slug'] ?? y['name'] ?? ''}'.trim();
            if (s.isNotEmpty) years.add(s);
          } else {
            final s = '$y'.trim();
            if (s.isNotEmpty) years.add(s);
          }
        }
      }
      years.sort((a, b) => (int.tryParse(b) ?? 0).compareTo(int.tryParse(a) ?? 0));
      if (!mounted) return;
      setState(() => _oYears = years);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _onOnlineYear(String? year) async {
    setState(() {
      _oYear = year;
      _oMod = null;
      _oMods = [];
      _oResult = null;
      _err = null;
    });
    if (year == null || _oMake == null || _oModel == null) return;
    setState(() => _busy = true);
    try {
      final raw = await _wsGet('modifications', {
        'make': _oMake!,
        'model': _oModel!,
        'year': year,
      });
      final data = raw is Map ? raw['data'] : raw;
      final mods = <Map<String, String>>[];
      if (data is List) {
        for (final item in data) {
          if (item is! Map) continue;
          final slug = '${item['slug'] ?? ''}'.trim();
          if (slug.isEmpty) continue;
          final name = '${item['name'] ?? item['trim'] ?? slug}'.trim();
          final engine = item['engine'];
          final engName = engine is Map
              ? '${engine['name'] ?? engine['fuel'] ?? ''}'.trim()
              : '';
          final label = [
            name,
            if (engName.isNotEmpty) engName,
          ].where((s) => s.isNotEmpty).join(' · ');
          mods.add({'slug': slug, 'name': label.isEmpty ? slug : label});
        }
      }
      if (!mounted) return;
      setState(() => _oMods = mods);
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _doOnlineLook() async {
    if (_oMake == null || _oModel == null || _oYear == null || _oMod == null) {
      return;
    }
    setState(() {
      _busy = true;
      _err = null;
      _oResult = null;
    });
    try {
      final raw = await _wsGet('search', {
        'make': _oMake!,
        'model': _oModel!,
        'year': _oYear!,
        'modification': _oMod!,
        'region': 'jdm',
      });
      final data = raw is Map ? raw['data'] : null;
      if (data is! List || data.isEmpty) {
        throw '找不到此車規格（可試其他年份／改裝）';
      }
      Map<String, dynamic>? hit;
      for (final row in data) {
        if (row is Map && '${row['slug']}' == _oMod) {
          hit = Map<String, dynamic>.from(row);
          break;
        }
      }
      hit ??= Map<String, dynamic>.from(data.first as Map);
      final tech = hit['technical'] is Map
          ? Map<String, dynamic>.from(hit['technical'] as Map)
          : <String, dynamic>{};
      final tires = <String>{};
      final wheels = hit['wheels'];
      if (wheels is List) {
        for (final w in wheels) {
          if (w is! Map) continue;
          for (final side in ['front', 'rear']) {
            final s = w[side];
            if (s is! Map) continue;
            final t = '${s['tire'] ?? s['tire_full'] ?? ''}'.trim();
            if (t.isNotEmpty) tires.add(t);
            final rim = '${s['rim'] ?? ''}'.trim();
            final off = s['rim_offset'];
            if (rim.isNotEmpty) {
              tires.add(off != null ? '$rim ET$off' : rim);
            }
          }
        }
      }
      final torque = tech['wheel_tightening_torque'];
      if (!mounted) return;
      setState(() {
        _oResult = {
          'bolt': '${tech['bolt_pattern'] ?? '-'}',
          'pcd': '${tech['pcd'] ?? '-'}',
          'cb': '${tech['centre_bore'] ?? '-'}',
          'torque': torque == null ? '-' : '$torque',
          'tires': tires.toList()..sort(),
          'name': '${hit?['name'] ?? hit?['trim'] ?? ''}',
        };
      });
    } catch (e) {
      if (mounted) setState(() => _err = '$e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  // —— Local JSON helpers (unchanged behaviour) ——
  List<String> get _lMakes {
    final keys = _localData?.keys;
    if (keys == null) return [];
    return (keys.toList()..sort());
  }

  List<Map<String, dynamic>>? _modelsForMake(String? make) {
    if (make == null || _localData == null) return null;
    final models = _localData![make]?['models'];
    if (models is! List) return null;
    return models.cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>>? _gensForModel(
      String? model, List<Map<String, dynamic>>? models) {
    if (model == null || models == null) return null;
    Map<String, dynamic>? found;
    for (final m in models) {
      if (m['name'] == model) {
        found = m;
        break;
      }
    }
    if (found == null) return null;
    final raw = found['g'] ?? found['generations'];
    if (raw is! List) return null;
    return raw.cast<Map<String, dynamic>>().where((g) {
      final n = g['n']?.toString().trim() ?? '';
      return n.isNotEmpty && !n.startsWith('---');
    }).map((g) => {
          'name': g['n']?.toString() ?? '',
          'year': g['y']?.toString() ?? '',
          'pcd': g['p']?.toString() ?? '',
          'offset': g['o']?.toString() ?? '',
          'cb': g['c']?.toString() ?? '',
          'thread': g['t']?.toString() ?? '',
          'torque': g['q']?.toString() ?? '',
        }).toList();
  }

  List<String> _getTs(Map<String, dynamic>? m) {
    if (m == null) return [];
    final raw = m['ts'] ?? m['tyreSizes'];
    if (raw is! List) return [];
    return raw.map((e) => '$e').toList();
  }

  void _doLocalLook() {
    final make = _lMake;
    final model = _lModel;
    final gen = _lGen;
    if (make == null || model == null || gen == null) return;
    final models = _modelsForMake(make);
    if (models == null) return;
    final gens = _gensForModel(model, models);
    if (gens == null || gen >= gens.length) return;
    Map<String, dynamic>? found;
    for (final m in models) {
      if (m['name'] == model) {
        found = m;
        break;
      }
    }
    setState(() => _lResult = {'gen': gens[gen], 'ts': _getTs(found)});
  }

  Future<void> _setMode(bool online) async {
    if (online && !_apiAllowed) {
      setState(() {
        _err = '線上配對（Wheel Size）只在 https://tyre.autragroupltd.com 可用';
        _online = false;
      });
      return;
    }
    setState(() {
      _online = online;
      _err = null;
      _oResult = null;
      _lResult = null;
    });
    if (online && _oMakes.isEmpty) await _loadOnlineMakes();
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: const Text('輪胎配對'),
        actions: [
          if (_busy)
            const Padding(
              padding: EdgeInsets.all(16),
              child: SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_apiAllowed)
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(
                      value: true,
                      label: Text('線上'),
                      icon: Icon(Icons.cloud_outlined)),
                  ButtonSegment(
                      value: false,
                      label: Text('本機'),
                      icon: Icon(Icons.folder_outlined)),
                ],
                selected: {_online},
                onSelectionChanged: (s) => _setMode(s.first),
              )
            else
              Material(
                color: Colors.orange.shade50,
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                  padding: EdgeInsets.all(10),
                  child: Text(
                    '線上 Wheel Size 僅限 https://tyre.autragroupltd.com\n此站使用本機配對資料。',
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Text(
              _online && _apiAllowed
                  ? '資料來源：Wheel Size（僅 Autra 網域）'
                  : '資料來源：本機 fitment_data.json',
              style: Theme.of(context)
                  .textTheme
                  .bodySmall
                  ?.copyWith(color: Colors.grey[700]),
            ),
            if (_err != null) ...[
              const SizedBox(height: 8),
              Material(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
                child: Padding(
                  padding: const EdgeInsets.all(10),
                  child: Text(_err!, style: TextStyle(color: Colors.red.shade800)),
                ),
              ),
            ],
            const SizedBox(height: 12),
            const Text('選擇車輛',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_online) _buildOnlineForm() else _buildLocalForm(),
            const SizedBox(height: 20),
            if (_online && _oResult != null) _buildOnlineResult(),
            if (!_online && _lResult != null) _buildLocalResult(),
          ],
        ),
      ),
    );
  }

  Widget _buildOnlineForm() {
    final makeSlugs = _oMakes.map((e) => e['slug']!).toList();
    final modelSlugs = _oModels.map((e) => e['slug']!).toList();
    final modSlugs = _oMods.map((e) => e['slug']!).toList();
    String nameOf(List<Map<String, String>> list, String slug) {
      for (final e in list) {
        if (e['slug'] == slug) return e['name'] ?? slug;
      }
      return slug;
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: (_oMake != null && makeSlugs.contains(_oMake)) ? _oMake : null,
          hint: const Text('請選擇品牌'),
          decoration: const InputDecoration(
              labelText: '品牌', border: OutlineInputBorder(), isDense: true),
          items: _oMakes
              .map((m) => DropdownMenuItem(
                  value: m['slug'], child: Text(m['name'] ?? '')))
              .toList(),
          onChanged: _busy ? null : _onOnlineMake,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: (_oModel != null && modelSlugs.contains(_oModel))
              ? _oModel
              : null,
          hint: const Text('請選擇型號'),
          decoration: const InputDecoration(
              labelText: '型號', border: OutlineInputBorder(), isDense: true),
          items: _oModels
              .map((m) => DropdownMenuItem(
                  value: m['slug'], child: Text(m['name'] ?? '')))
              .toList(),
          onChanged: (_oMake != null && !_busy) ? _onOnlineModel : null,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: (_oYear != null && _oYears.contains(_oYear)) ? _oYear : null,
          hint: const Text('請選擇年份'),
          decoration: const InputDecoration(
              labelText: '年份', border: OutlineInputBorder(), isDense: true),
          items: _oYears
              .map((y) => DropdownMenuItem(value: y, child: Text(y)))
              .toList(),
          onChanged: (_oModel != null && !_busy) ? _onOnlineYear : null,
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: (_oMod != null && modSlugs.contains(_oMod)) ? _oMod : null,
          hint: const Text('請選擇改裝／引擎'),
          decoration: const InputDecoration(
              labelText: '改裝', border: OutlineInputBorder(), isDense: true),
          items: _oMods
              .map((m) => DropdownMenuItem(
                  value: m['slug'],
                  child: Text(nameOf(_oMods, m['slug']!))))
              .toList(),
          onChanged: (_oYear != null && !_busy)
              ? (v) => setState(() {
                    _oMod = v;
                    _oResult = null;
                  })
              : null,
        ),
        if (_oMod != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilledButton(
              onPressed: _busy ? null : _doOnlineLook,
              child: const Text('查看規格'),
            ),
          ),
      ],
    );
  }

  Widget _buildLocalForm() {
    final models = _modelsForMake(_lMake);
    final gens = _gensForModel(_lModel, models);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: (_lMake != null && _lMakes.contains(_lMake)) ? _lMake : null,
          hint: const Text('請選擇品牌'),
          decoration: const InputDecoration(
              labelText: '品牌', border: OutlineInputBorder(), isDense: true),
          items: _lMakes
              .map((m) => DropdownMenuItem(value: m, child: Text(m)))
              .toList(),
          onChanged: (v) => setState(() {
            _lMake = v;
            _lModel = null;
            _lGen = null;
            _lResult = null;
          }),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<String>(
          // ignore: deprecated_member_use
          value: () {
            final names = models
                    ?.map((m) => m['name']?.toString() ?? '')
                    .where((n) => n.isNotEmpty)
                    .toList() ??
                const <String>[];
            return (_lModel != null && names.contains(_lModel)) ? _lModel : null;
          }(),
          hint: const Text('請選擇型號'),
          decoration: const InputDecoration(
              labelText: '型號', border: OutlineInputBorder(), isDense: true),
          items: models
                  ?.map((m) => m['name']?.toString() ?? '')
                  .where((n) => n.isNotEmpty)
                  .map((n) => DropdownMenuItem(value: n, child: Text(n)))
                  .toList() ??
              const [],
          onChanged: _lMake == null
              ? null
              : (v) => setState(() {
                    _lModel = v;
                    _lGen = null;
                    _lResult = null;
                  }),
        ),
        const SizedBox(height: 8),
        DropdownButtonFormField<int>(
          // ignore: deprecated_member_use
          value: (gens != null &&
                  _lGen != null &&
                  _lGen! >= 0 &&
                  _lGen! < gens.length)
              ? _lGen
              : null,
          hint: const Text('請選擇世代'),
          decoration: const InputDecoration(
              labelText: '世代 / 年份',
              border: OutlineInputBorder(),
              isDense: true),
          items: gens?.asMap().entries.map((e) {
                final y = e.value['year'] ?? '';
                final label = y.contains('Present') ||
                        y.contains('New') ||
                        y.contains('new')
                    ? '${e.value['name']} — 新車'
                    : y.isNotEmpty
                        ? '${e.value['name']} ($y)'
                        : '${e.value['name']} (N/A)';
                return DropdownMenuItem(value: e.key, child: Text(label));
              }).toList() ??
              [],
          onChanged: _lModel == null
              ? null
              : (v) => setState(() {
                    _lGen = v;
                    _lResult = null;
                  }),
        ),
        if (_lModel != null && _lGen != null)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: FilledButton(
              onPressed: _doLocalLook,
              child: const Text('查看規格'),
            ),
          ),
      ],
    );
  }

  Widget _buildOnlineResult() {
    final r = _oResult!;
    final tires = (r['tires'] as List?) ?? const [];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text('規格',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
        if ('${r['name']}'.isNotEmpty) _sr('改裝', '${r['name']}'),
        _sr('Bolt Pattern', '${r['bolt']}'),
        _sr('PCD', '${r['pcd']}'),
        _sr('Center Bore', '${r['cb']}'),
        _sr('Torque', '${r['torque']}'),
        const SizedBox(height: 12),
        if (tires.isNotEmpty) ...[
          const Text('適用輪胎／鈴', style: TextStyle(fontWeight: FontWeight.w600)),
          ...tires.map((s) => Card(
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: ListTile(
                  dense: true,
                  title: Text('$s'),
                  trailing: Icon(Icons.check_circle,
                      color: Colors.green.shade600),
                ),
              )),
        ],
      ],
    );
  }

  Widget _buildLocalResult() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Divider(),
        const SizedBox(height: 8),
        Text('規格',
            style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
                color: Theme.of(context).colorScheme.primary)),
        _sr('Bolt Pattern', _lResult?['gen']?['pcd']),
        _sr('Offset', _lResult?['gen']?['offset']),
        _sr('Center Bore', _lResult?['gen']?['cb']),
        _sr('Thread', _lResult?['gen']?['thread']),
        _sr('Torque', _lResult?['gen']?['torque']),
        const SizedBox(height: 12),
        if ((_lResult?['ts'] as List?)?.isNotEmpty == true) ...[
          const Text('適用輪胎尺寸', style: TextStyle(fontWeight: FontWeight.w600)),
          ...((_lResult?['ts'] as List?) ?? const []).map((s) => Card(
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: ListTile(
                  dense: true,
                  title: Text('$s'),
                  trailing: Icon(Icons.check_circle,
                      color: Colors.green.shade600),
                ),
              )),
        ],
      ],
    );
  }

  Widget _sr(String l, String? v) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 2),
        child: Row(children: [
          SizedBox(
              width: 110,
              child:
                  Text(l, style: const TextStyle(fontWeight: FontWeight.w500))),
          Expanded(child: Text(v ?? '-')),
        ]),
      );
}
