import 'dart:convert';
import 'dart:html' as html;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

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
  static const String _defPin = 'tyre888';
  @override void initState() { super.initState(); _check(); }
  Future<void> _check() async {
    final p = await SharedPreferences.getInstance();
    if (p.getString('pin') == null) await p.setString('pin', _defPin);
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
      Text('🔑 預設密碼: tyre888', style: Theme.of(context).textTheme.bodySmall?.copyWith(color: Colors.grey)),
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
  String _search = '', _brandF = '', _rimF = '';
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
        if (parsed is List) _all = parsed.cast<Map<String, dynamic>>();
      }
      if (_all.isEmpty) {
        final ok = await _loadFromSheet();
        if (!ok) { _err = '上傳 stock.xlsx 開始使用'; }
      }
    } catch (_) { _err = '載入失敗'; }
    _reload();
    if (mounted) setState(() => _loaded = true);
  }

  void _pickFile() {
    final input = html.FileUploadInputElement()..accept = '.xlsx,.xls,.csv';
    input.click();
    input.onChange.listen((_) async {
      try {
        final files = input.files;
        if (files == null || files.isEmpty) return;
        final reader = html.FileReader();
        reader.readAsText(files[0]);
        await reader.onLoad.first;
        final text = reader.result;
        if (text == null || text is! String) throw '無法讀取檔案';
        final rows = text.split('\n')
            .map((r) => r.trim()).where((r) => r.isNotEmpty).toList();
        if (rows.length < 2) throw '檔案內容不足';
        _all.clear();
        final n = rows.length;
        for (int r = 1; r < n; r++) {
          final cells = _splitCsv(rows[r]);
          if (cells.length < 2) continue;
          final brand = cells[0].trim();
          final pattern = cells[1].trim();
          // Try to parse size from the first field if it looks like a size
          int w = 0, a = 0, ri = 0;
          double price = 0;
          String desc = pattern;
          // Check all cells for a size like "245/40/18" or "245/40R18"
          for (int ci = 0; ci < cells.length; ci++) {
            final cell = cells[ci].replaceAll(' ', '');
            final parts = cell.split(RegExp(r'[/Rr]'));
            if (parts.length >= 3) {
              final tw = int.tryParse(parts[0]);
              final ta = int.tryParse(parts[1]);
              final tr = int.tryParse(parts[2]);
              if (tw != null && tw > 100 && ta != null && ta > 0 && tr != null && tr > 10) {
                w = tw; a = ta; ri = tr;
                break;
              }
            }
          }
          // Try brand + pattern from cells
          String br = brand;
          String pt = pattern;
          if (br.isEmpty || pt.isEmpty) {
            br = cells.length > 1 ? cells[1].trim() : '';
            pt = cells.length > 2 ? cells[2].trim() : '';
          }
          // Try price from last numeric cell
          for (int ci = cells.length - 1; ci >= 0; ci--) {
            final pv = double.tryParse(cells[ci].replaceAll(RegExp(r'[^0-9.]'), ''));
            if (pv != null && pv > 0) { price = pv; break; }
          }
          // Try description from a cell that doesn't look like brand/pattern/size
          for (int ci = 0; ci < cells.length; ci++) {
            final c = cells[ci].trim();
            if (c.isNotEmpty && c != br && c != pt && !c.contains('/')) {
              desc = c;
            }
          }
          _all.add({'br': br, 'pt': pt, 'w': w, 'a': a, 'ri': ri, 'sp': price, 'st': 1, 'su': '', 'de': desc});
        }
        if (_all.isEmpty) throw '找不到有效數據 (檢查檔案格式)';
        await (await SharedPreferences.getInstance()).setString('d', jsonEncode(_all));
        _err = null;
        _reload();
        if (mounted) setState(() {});
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('已載入 ${_all.length} 款'), backgroundColor: Colors.green));
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('錯誤: $e'), backgroundColor: Colors.red));
      }
    });
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
        if (hasSize && cells.length >= 5) {
          final sz = cells[0].replaceAll(' ', '');
          final pp = sz.split(RegExp(r'[/Rr]'));
          if (pp.length >= 3) {
            final w = int.tryParse(pp[0]) ?? 0;
            final a = int.tryParse(pp[1]) ?? 0;
            final ri = int.tryParse(pp[2]) ?? 0;
            if (w == 0 && a == 0) continue;
            final b = cells[1].trim();
            final d = cells[2].trim();
            String pt = d;
            if (pt.toUpperCase().startsWith(b.toUpperCase())) pt = pt.substring(b.length).trim();
            if (pt.isEmpty) pt = d;
            final pr = double.tryParse(cells.last.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0;
            _all.add({'br': b, 'pt': pt, 'w': w, 'a': a, 'ri': ri, 'sp': pr, 'st': 1, 'su': '', 'de': d});
          }
        } else if (cells.length >= 3) {
          _all.add({
            'br': cells[0].trim(), 'pt': cells[1].trim(), 'w': 0, 'a': 0, 'ri': 0,
            'sp': double.tryParse(cells.last.replaceAll(RegExp(r'[^\d.]'), '')) ?? 0,
            'st': 1, 'su': '', 'de': cells.length > 2 ? cells[2].trim() : '',
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
      if (_rimF.isNotEmpty && (t['ri']?.toString() ?? '') != _rimF.replaceAll('"', '')) return false;
      if (_search.isNotEmpty) {
        final q = _search.toLowerCase();
        final br = t['br']?.toString()?.toLowerCase() ?? '';
        final pt = t['pt']?.toString()?.toLowerCase() ?? '';
        final sz = _size(t).toLowerCase();
        return br.contains(q) || pt.contains(q) || sz.contains(q);
      }
      return true;
    }).toList();
  }
  void _apply() { _reload(); setState(() {}); }
  Future<void> _reloadAll() async { setState(() => _loaded = false); await _init(); }

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
    final rims = _all.map((t) => t['ri']?.toString() ?? '').where((r) => r.isNotEmpty).toSet().toList()
      ..sort((a, b) => (int.tryParse(a) ?? 0).compareTo(int.tryParse(b) ?? 0));
    return Scaffold(
      appBar: AppBar(title: const Text('呔妹輪胎'), actions: [
        if (widget.onChangePin != null)
          IconButton(icon: const Icon(Icons.settings), tooltip: '更改密碼', onPressed: widget.onChangePin),
        if (_sheetUrl != null && _sheetUrl!.isNotEmpty)
          Tooltip(message: '已連結 Google Sheet',
            child: Padding(padding: const EdgeInsets.only(right: 4), child: Icon(Icons.cloud_done, size: 18, color: Colors.green.shade300))),
        IconButton(icon: const Icon(Icons.file_upload), tooltip: '上傳 stock.xlsx', onPressed: _pickFile),
        IconButton(icon: const Icon(Icons.link), tooltip: 'Google Sheet', onPressed: _setSheetUrl),
        IconButton(icon: const Icon(Icons.refresh), tooltip: '重新載入', onPressed: _reloadAll),
        Padding(padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('${_all.length}款', style: Theme.of(context).textTheme.bodySmall)),
      ]),
      body: Column(children: [
        Padding(padding: const EdgeInsets.fromLTRB(12, 8, 12, 0), child: TextField(
          decoration: InputDecoration(hintText: '搜索...', prefixIcon: const Icon(Icons.search),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            isDense: true, contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12)),
          onChanged: (v) { _search = v; _apply(); })),
        if (brands.isNotEmpty || rims.isNotEmpty)
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), child: Row(children: [
            if (brands.isNotEmpty) Expanded(child: DropdownButtonFormField<String>(
              value: _brandF.isEmpty ? null : _brandF,
              decoration: const InputDecoration(labelText: '品牌', isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              items: [const DropdownMenuItem<String>(value: null, child: Text('全部'))]
                  .followedBy(brands.map((b) => DropdownMenuItem(value: b, child: Text(b)))).toList(),
              onChanged: (v) { _brandF = v ?? ''; _apply(); })),
            if (brands.isNotEmpty) const SizedBox(width: 8),
            if (rims.isNotEmpty) Expanded(child: DropdownButtonFormField<String>(
              value: _rimF.isEmpty ? null : _rimF,
              decoration: const InputDecoration(labelText: '鈴', isDense: true,
                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8)),
              items: [const DropdownMenuItem<String>(value: null, child: Text('全部'))]
                  .followedBy(rims.map((r) => DropdownMenuItem(value: r, child: Text('${r}\"')))).toList(),
              onChanged: (v) { _rimF = v ?? ''; _apply(); })),
          ])),
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
    final i = _all.indexWhere((x) => x['br'] == t['br'] && x['pt'] == t['pt'] && x['ri'] == t['ri']);
    if (i >= 0) { _all[i] = r; await _save(); _reload(); if (mounted) setState(() {}); }
  }
  void _add() async {
    final r = await _dialog(null, true);
    if (r != null) { _all.add(r); await _save(); _reload(); if (mounted) setState(() {}); }
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
  Map<String, dynamic>? _data;
  bool _loaded = false;
  String? _make, _model;
  int? _gen;
  Map<String, dynamic>? _result;

  @override void initState() { super.initState(); _load(); }
  Future<void> _load() async {
    try { _data = jsonDecode(await rootBundle.loadString('assets/fitment_data.json')); } catch (_) {}
    if (mounted) setState(() => _loaded = true);
  }

  List<String> get _makes {
    final keys = _data?.keys;
    if (keys == null) return [];
    final list = keys.toList()..sort();
    return list;
  }
  List<Map<String, dynamic>>? _modelsForMake(String? make) {
    if (make == null || _data == null) return null;
    final models = _data![make]?['models'];
    if (models is! List) return null;
    return models.cast<Map<String, dynamic>>();
  }

  List<Map<String, dynamic>>? _gensForModel(String? model, List<Map<String, dynamic>>? models) {
    if (model == null || models == null) return null;
    Map<String, dynamic>? found;
    for (final m in models) {
      if (m['name'] == model) { found = m; break; }
    }
    if (found == null) return null;
    final raw = found['g'] ?? found['generations'];
    if (raw is! List) return null;
    return raw.cast<Map<String, dynamic>>().where((g) {
      final n = g['n']?.toString()?.trim() ?? '';
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
    return raw.cast<String>();
  }

  void _onMake(String? v) { setState(() { _make = v; _model = null; _gen = null; _result = null; }); }
  void _onModel(String? v) { setState(() { _model = v; _gen = null; _result = null; }); }
  void _onGen(int? v) { setState(() { _gen = v; _result = null; }); }
  void _doLook() {
    final make = _make;
    final model = _model;
    final gen = _gen;
    final data = _data;
    if (make == null || model == null || gen == null || data == null) return;
    final models = _modelsForMake(make);
    if (models == null) return;
    final gens = _gensForModel(model, models);
    if (gens == null || gen >= gens.length) return;
    final g = gens[gen];
    Map<String, dynamic>? found;
    for (final m in models) {
      if (m['name'] == model) { found = m; break; }
    }
    if (found == null) return;
    setState(() => _result = {'gen': g, 'ts': _getTs(found)});
  }

  @override Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    final models = _modelsForMake(_make);
    final gens = _gensForModel(_model, models);
    return Scaffold(
      appBar: AppBar(title: const Text('輪胎配對')),
      body: SingleChildScrollView(padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('選擇車輛', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(value: _make,
            decoration: const InputDecoration(labelText: '品牌', border: OutlineInputBorder(), isDense: true),
            items: _makes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: _onMake),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(value: _model,
            decoration: const InputDecoration(labelText: '型號', border: OutlineInputBorder(), isDense: true),
            items: models?.map((m) => DropdownMenuItem(
              value: m['name']?.toString(), child: Text(m['name']?.toString() ?? ''))).toList() ?? [],
            onChanged: _make != null ? _onModel : null),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(value: _gen,
            decoration: const InputDecoration(labelText: '世代 / 年份', border: OutlineInputBorder(), isDense: true),
            items: gens?.asMap().entries.map((e) {
              final y = e.value['year'] ?? '';
              final label = y.contains('Present') || y.contains('New') || y.contains('new')
                  ? '${e.value['name']} — 新車'
                  : y.isNotEmpty ? '${e.value['name']} ($y)' : '${e.value['name']} (N/A)';
              return DropdownMenuItem(value: e.key, child: Text(label));
            }).toList() ?? [],
            onChanged: _model != null ? _onGen : null),
          if (_model != null && _gen != null)
            Padding(padding: const EdgeInsets.symmetric(vertical: 8), child: FilledButton(
              onPressed: _doLook,
              child: const Text('查看規格'))),
          const SizedBox(height: 20),
          if (_result != null) ...[
            const Divider(), const SizedBox(height: 8),
            Text('規格', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold,
              color: Theme.of(context).colorScheme.primary)),
            _sr('Bolt Pattern', _result?['gen']?['pcd']),
            _sr('Offset', _result?['gen']?['offset']),
            _sr('Center Bore', _result?['gen']?['cb']),
            _sr('Thread', _result?['gen']?['thread']),
            _sr('Torque', _result?['gen']?['torque']),
            const SizedBox(height: 12),
            if ((_result?['ts'] as List?)?.isNotEmpty == true) ...[
              const Text('適用輪胎尺寸', style: TextStyle(fontWeight: FontWeight.w600)),
              ...(_result?['ts'] as List).map((s) => Card(
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: ListTile(dense: true, title: Text('$s'),
                  trailing: Icon(Icons.check_circle, color: Colors.green.shade600)))),
            ],
          ],
        ])),
    );
  }
  Widget _sr(String l, String? v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [
      const SizedBox(width: 110, child: Text('PCD', style: TextStyle(fontWeight: FontWeight.w500))),
      Text(v ?? '-'),
    ]),
  );
}
