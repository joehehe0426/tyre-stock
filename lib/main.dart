import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
// ignore_for_file: deprecated_member_use
import 'package:excel/excel.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(MaterialApp(
  title: '呔妹輪胎',
  debugShowCheckedModeBanner: false,
  theme: ThemeData(colorSchemeSeed: const Color(0xFFD81B60), useMaterial3: true),
  home: const HomePage(),
));

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _tab = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    body: IndexedStack(index: _tab, children: const [StockPage(), FitmentPage()]),
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

// ===================== STOCK =====================
class StockPage extends StatefulWidget {
  const StockPage({super.key});
  @override
  State<StockPage> createState() => _StockPageState();
}

class _StockPageState extends State<StockPage> {
  List<Map<String, dynamic>> _all = [];
  List<Map<String, dynamic>> _filtered = [];
  String _search = '', _brandF = '', _rimF = '';
  bool _loaded = false;
  String? _err;
  String? _sheetUrl;

  @override
  void initState() { super.initState(); _init(); }

  Future<void> _init() async {
    final p = await SharedPreferences.getInstance();
    _sheetUrl = p.getString('sheet_url');
    try {
      final s = p.getString('d');
      if (s != null && s.isNotEmpty) {
        _all = (jsonDecode(s) as List).cast<Map<String, dynamic>>();
      } else {
        if (!await _loadFromSheet() && !await _loadFromFile()) _all = _fb();
      }
    } catch (e) { _err = 'error: $e'; _all = _fb(); }
    _reload();
    if (mounted) setState(() => _loaded = true);
  }

  Future<bool> _loadFromSheet() async {
    if (_sheetUrl == null || _sheetUrl!.isEmpty) return false;
    try {
      final url = _sheetUrl!.startsWith('http') ? _sheetUrl! : 'https://docs.google.com/spreadsheets/d/$_sheetUrl/export?format=csv';
      final res = await http.get(Uri.parse(url)).timeout(const Duration(seconds: 15));
      if (res.statusCode != 200) throw 'HTTP ${res.statusCode}';
      final rows = res.body.split('\n').where((r) => r.trim().isNotEmpty).toList();
      if (rows.length < 2) throw 'no data rows';
      _all.clear();
      for (int r = 1; r < rows.length; r++) {
        final cols = _parseCsvRow(rows[r]);
        if (cols.length < 8) continue;
        _all.add({
          'br': cols[0].trim(),
          'pt': cols[1].trim(),
          'w': int.tryParse(cols[2].trim())??0,
          'a': int.tryParse(cols[3].trim())??0,
          'ri': int.tryParse(cols[4].trim())??0,
          'st': int.tryParse(cols[7].trim())??0,
          'su': cols.length > 9 ? cols[9].trim() : '',
          'de': cols.length > 10 ? cols[10].trim() : '',
        });
      }
      if (_all.isNotEmpty) {
        final p = await SharedPreferences.getInstance();
        await p.setString('d', jsonEncode(_all));
        _err = null;
        return true;
      }
    } catch (e) { _err = 'Google Sheet 載入失敗: $e'; }
    return false;
  }

  List<String> _parseCsvRow(String row) {
    final result = <String>[];
    bool inQuote = false;
    String current = '';
    for (int i = 0; i < row.length; i++) {
      final c = row[i];
      if (c == '"') { inQuote = !inQuote; continue; }
      if (c == ',' && !inQuote) { result.add(current); current = ''; continue; }
      current += c;
    }
    result.add(current);
    return result;
  }

  Future<void> _setSheetUrl() async {
    final c = TextEditingController(text: _sheetUrl ?? '');
    final url = await showDialog<String>(context: context, builder: (ctx) => AlertDialog(
      title: const Text('Google Sheet 連結'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('貼上 Google Sheet 分享連結或 ID', style: TextStyle(fontSize: 13)),
        const SizedBox(height: 8),
        TextField(controller: c, decoration: const InputDecoration(hintText: 'https://docs.google.com/spreadsheets/d/...', isDense: true, border: OutlineInputBorder()), maxLines: 2),
        const SizedBox(height: 8),
        const Text('📌 Sheet 必須發佈到網絡 (File → Share → Publish to web → CSV)', style: TextStyle(fontSize: 11, color: Colors.grey)),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, ''), child: const Text('清除')),
        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('取消')),
        FilledButton(onPressed: () => Navigator.pop(ctx, c.text.trim()), child: const Text('儲存')),
      ],
    ));
    c.dispose();
    if (url == null) return;
    _sheetUrl = url;
    final p = await SharedPreferences.getInstance();
    if (url.isEmpty) { await p.remove('sheet_url'); } else { await p.setString('sheet_url', url); }
    if (url.isNotEmpty) {
      setState(() => _loaded = false);
      final ok = await _loadFromSheet();
      if (ok) { _reload(); if (mounted) setState(() => _loaded = true); }
      else { if (mounted) setState(() => _loaded = true); }
    }
  }

  Future<bool> _loadFromFile() async {
    for (final path in ['/storage/emulated/0/Download/stock.xlsx','/storage/emulated/0/stock.xlsx']) {
      try {
        final f = File(path);
        if (await f.exists()) { await _parseXlsx(await f.readAsBytes()); _err = null; return true; }
      } catch (_) {}
    }
    try {
      final d = await rootBundle.load('assets/stock.xlsx');
      await _parseXlsx(d.buffer.asUint8List()); _err = null; return true;
    } catch (_) {}
    _err = '無數據 — 用 + 新增輪胎，或設定 Google Sheet';
    return false;
  }

  Future<void> _parseXlsx(List<int> bytes) async {
    final x = Excel.decodeBytes(bytes);
    final sh = x.tables['tyre_stock'];
    if (sh == null) throw '找不到 tyre_stock sheet';
    _all.clear();
    for (int r = 1; r < sh.rows.length; r++) {
      final row = sh.rows[r];
      if (row[0]?.value == null) continue;
      _all.add({'br':row[0]!.value.toString(),'pt':row[1]!.value.toString(),'w':int.tryParse(row[2]?.value.toString()??'0')??0,'a':int.tryParse(row[3]?.value.toString()??'0')??0,'ri':int.tryParse(row[4]?.value.toString()??'0')??0,'st':int.tryParse(row[7]?.value.toString()??'0')??0,'su':row[9]?.value?.toString()??'','de':row[10]?.value?.toString()??'',});
    }
    final p = await SharedPreferences.getInstance();
    await p.setString('d', jsonEncode(_all));
  }

  List<Map<String, dynamic>> _fb() => [{'br':'Michelin','pt':'Primacy 4+','w':225,'a':55,'ri':17,'st':15,'su':'','de':'旗艦舒適呔'},{'br':'Bridgestone','pt':'Turanza T005','w':205,'a':55,'ri':16,'st':12,'su':'合誠輪呔','de':'舒適寧靜'}];
  String _size(Map m) => '${m['w']}/${m['a']}R${m['ri']}';
  String _rimL(Map m) => '${m['ri']}"';
  Future<void> _save() async => (await SharedPreferences.getInstance()).setString('d', jsonEncode(_all));
  Future<void> _reloadAll() async { setState(() => _loaded = false); await _init(); }
  void _reload() {
    _filtered = _all.where((t) {
      if (_brandF.isNotEmpty && t['br'] != _brandF) return false;
      if (_rimF.isNotEmpty && _rimL(t) != _rimF) return false;
      if (_search.isNotEmpty) { final q=_search.toLowerCase(); return t['br'].toString().toLowerCase().contains(q)||t['pt'].toString().toLowerCase().contains(q)||_size(t).toLowerCase().contains(q)||t['su'].toString().toLowerCase().contains(q); }
      return true;
    }).toList();
  }
  void _apply() { _reload(); setState(() {}); }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) {
      return Scaffold(
        appBar: AppBar(title: const Text('呔妹輪胎')),
        body: Center(child: _err!=null
          ? Padding(padding: const EdgeInsets.all(24), child: Column(mainAxisSize:MainAxisSize.min,children:[const Icon(Icons.cloud_off,size:64,color:Colors.grey),const SizedBox(height:16),Text(_err!,textAlign:TextAlign.center,style:const TextStyle(color:Colors.red)),const SizedBox(height:16),Row(mainAxisSize:MainAxisSize.min,children:[FilledButton.icon(onPressed:_reloadAll,icon:const Icon(Icons.refresh),label:const Text('重試')),const SizedBox(width:8),OutlinedButton.icon(onPressed:_setSheetUrl,icon:const Icon(Icons.link),label:const Text('設定 Sheet'))])]))
          : const CircularProgressIndicator()),
      );
    }
    final brands = _all.map((t)=>t['br'].toString()).toSet().toList()..sort();
    final rims = _all.map((t)=>_rimL(t)).toSet().toList()..sort((a,b)=>int.parse(a.replaceAll('"','')).compareTo(int.parse(b.replaceAll('"',''))));
    return Scaffold(
      appBar: AppBar(title:const Text('呔妹輪胎'),actions:[
        if (_sheetUrl != null && _sheetUrl!.isNotEmpty)
          Padding(padding:const EdgeInsets.only(right:4),child:Tooltip(message: '已連接 Google Sheet',child: Icon(Icons.cloud_done, size: 18, color: Colors.green.shade300))),
        IconButton(icon:const Icon(Icons.link),tooltip:'Google Sheet 設定',onPressed:_setSheetUrl),
        IconButton(icon:const Icon(Icons.refresh),tooltip:'重新載入',onPressed:_reloadAll),
        Padding(padding:const EdgeInsets.symmetric(horizontal:8),child:Center(child:Text('${_all.length}款 共${_all.fold(0,(s,t)=>s+(t['st'] as int))}條',style:Theme.of(context).textTheme.bodySmall))),
      ]),
      body: Column(children:[
        Padding(padding:const EdgeInsets.fromLTRB(12,8,12,0),child:TextField(decoration:InputDecoration(hintText:'搜索...',prefixIcon:const Icon(Icons.search),border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)),isDense:true,contentPadding:const EdgeInsets.symmetric(vertical:10,horizontal:12)),onChanged:(v){_search=v;_apply();})),
        Padding(padding:const EdgeInsets.symmetric(horizontal:12,vertical:6),child:Row(children:[
          Expanded(child:DropdownButtonFormField<String>(value:_brandF.isEmpty?'':_brandF,decoration:const InputDecoration(labelText:'品牌',isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:8,vertical:8)),items:[DropdownMenuItem(value:'',child:const Text('全部'))].followedBy(brands.map((b)=>DropdownMenuItem(value:b,child:Text(b)))).toList(),onChanged:(v){_brandF=v??'';_apply();})),
          const SizedBox(width:8),
          Expanded(child:DropdownButtonFormField<String>(value:_rimF.isEmpty?'':_rimF,decoration:const InputDecoration(labelText:'鈴',isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:8,vertical:8)),items:[DropdownMenuItem(value:'',child:const Text('全部'))].followedBy(rims.map((r)=>DropdownMenuItem(value:r,child:Text(r)))).toList(),onChanged:(v){_rimF=v??'';_apply();})),
        ])),
        Expanded(child:_filtered.isEmpty?const Center(child:Text('無匹配')):ListView.builder(itemCount:_filtered.length,itemBuilder:(_,i){final t=_filtered[i];return Card(margin:const EdgeInsets.symmetric(horizontal:12,vertical:3),child:ListTile(title:Text('${t['br']} ${t['pt']}',style:const TextStyle(fontWeight:FontWeight.w500)),subtitle:Text('${_size(t)}${(t['su'] as String).isNotEmpty?'  ${t['su']}':''}'),trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text('${t['st']}',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:(t['st'] as int)<10?Colors.red:Theme.of(context).colorScheme.primary)),const SizedBox(width:4),Text('條',style:Theme.of(context).textTheme.bodySmall)]),onTap:()=>_edit(t)));})),
      ]),
      floatingActionButton:FloatingActionButton(onPressed:_add,child:const Icon(Icons.add)),
    );
  }

  void _edit(Map<String,dynamic>t)async{final r=await _dialog(t,false);if(r==null)return;final i=_all.indexWhere((x)=>x['br']==t['br']&&x['pt']==t['pt']&&x['ri']==t['ri']);if(i>=0){_all[i]=r;await _save();_reload();if(mounted)setState((){});}}
  void _add()async{final r=await _dialog(null,true);if(r!=null){_all.add(r);await _save();_reload();if(mounted)setState((){});}}

  Future<Map<String,dynamic>?>_dialog(Map<String,dynamic>?t,bool isNew)async{
    final bc=TextEditingController(text:t?['br']??'');final pc=TextEditingController(text:t?['pt']??'');final sc=TextEditingController(text:'${t?['st']??0}');final suc=TextEditingController(text:t?['su']??'');final dc=TextEditingController(text:t?['de']??'');
    int w=t?['w']??205,a=t?['a']??55,ri=t?['ri']??16;final fk=GlobalKey<FormState>();
    final r=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>AlertDialog(title:Text(isNew?'新增':'編輯'),content:Form(key:fk,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextFormField(controller:bc,decoration:const InputDecoration(labelText:'品牌',isDense:true),validator:(v)=>v?.isEmpty==true?'必填':null),
      TextFormField(controller:pc,decoration:const InputDecoration(labelText:'型號',isDense:true),validator:(v)=>v?.isEmpty==true?'必填':null),
      Row(children:[Expanded(child:TextFormField(initialValue:'$w',decoration:const InputDecoration(labelText:'闊',isDense:true),keyboardType:TextInputType.number,onChanged:(v)=>w=int.tryParse(v)??0)),const SizedBox(width:6),Expanded(child:TextFormField(initialValue:'$a',decoration:const InputDecoration(labelText:'扁平',isDense:true),keyboardType:TextInputType.number,onChanged:(v)=>a=int.tryParse(v)??0)),const SizedBox(width:6),Expanded(child:TextFormField(initialValue:'$ri',decoration:const InputDecoration(labelText:'鈴',isDense:true),keyboardType:TextInputType.number,onChanged:(v)=>ri=int.tryParse(v)??0))]),
      TextFormField(controller:suc,decoration:const InputDecoration(labelText:'供應商',isDense:true)),
      TextFormField(controller:dc,decoration:const InputDecoration(labelText:'描述',isDense:true),maxLines:2),
      const SizedBox(height:12),Text('庫存',style:Theme.of(context).textTheme.labelMedium),const SizedBox(height:4),
      Wrap(spacing:6,runSpacing:6,children:[0,2,4,6,8,10,20,50,100].map((q)=>ChoiceChip(label:Text('$q',style:const TextStyle(fontSize:13)),selected:int.tryParse(sc.text)==q,onSelected:(_){sc.text='$q';setState((){});})).toList()),
      const SizedBox(height:8),Row(children:[IconButton.filledTonal(onPressed:(){int v=int.tryParse(sc.text)??0;sc.text='${(v+1).clamp(0,99999)}';setState((){});},icon:const Icon(Icons.add)),const SizedBox(width:8),Expanded(child:TextFormField(controller:sc,decoration:const InputDecoration(isDense:true,hintText:'數量'),keyboardType:TextInputType.number,textAlign:TextAlign.center,style:const TextStyle(fontSize:20,fontWeight:FontWeight.bold))),const SizedBox(width:8),IconButton.filledTonal(onPressed:(){int v=int.tryParse(sc.text)??0;sc.text='${(v-1).clamp(0,99999)}';setState((){});},icon:const Icon(Icons.remove))]),
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('取消')),FilledButton(onPressed:(){if(fk.currentState?.validate()!=true)return;Navigator.pop(ctx,{'br':bc.text,'pt':pc.text,'w':w,'a':a,'ri':ri,'st':int.tryParse(sc.text)??0,'su':suc.text,'de':dc.text});},child:Text(isNew?'新增':'儲存'))]));
    bc.dispose();pc.dispose();sc.dispose();suc.dispose();dc.dispose();
    return r;
  }
}

// ===================== FITMENT LOOKUP =====================
class FitmentPage extends StatefulWidget {
  const FitmentPage({super.key});
  @override
  State<FitmentPage> createState() => _FitmentPageState();
}

class _FitmentPageState extends State<FitmentPage> {
  Map<String, dynamic>? _data;
  bool _loaded = false;
  String? _selectedMake, _selectedModel;
  int? _selectedGen;
  Map<String, dynamic>? _result;

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    final d = await rootBundle.loadString('assets/fitment_data.json');
    _data = jsonDecode(d) as Map<String, dynamic>;
    if (mounted) setState(() => _loaded = true);
  }

  List<String> get _makes => (_data?.keys.toList()?..sort()) ?? [];
  List<Map<String, dynamic>>? get _models => _selectedMake != null ? _data![_selectedMake!]['models']?.cast<Map<String, dynamic>>() : null;

  List<Map<String, dynamic>>? _getGens(Map<String, dynamic> model) {
    final raw = model['g'] ?? model['generations'];
    if (raw == null) return null;
    final list = (raw as List).cast<Map<String, dynamic>>();
    return list.where((g) {
      final name = (g['name'] ?? g['n'] ?? '').toString().trim();
      return name.isNotEmpty && !name.startsWith('---');
    }).map((g) => {
      'name': g['name'] ?? g['n'] ?? '',
      'year': g['year'] ?? g['y'] ?? '',
      'pcd': g['pcd'] ?? g['p'] ?? '',
      'offset': g['offset'] ?? g['o'] ?? '',
      'cb': g['cb'] ?? g['c'] ?? '',
      'thread': g['thread'] ?? g['t'] ?? '',
      'torque': g['torque'] ?? g['q'] ?? '',
    }).toList();
  }

  List<Map<String, dynamic>>? get _gens => _selectedModel != null && _models != null ? _getGens(_models!.firstWhere((m) => m['name'] == _selectedModel)) : null;

  List<String> _getTyres(Map<String, dynamic> model) => ((model['ts'] ?? model['tyreSizes'] ?? []) as List).cast<String>();
  List<String> _getRims(Map<String, dynamic> model) => ((model['rs'] ?? model['rimSizes'] ?? []) as List).cast<String>();

  void _onMakeChanged(String? v) { setState(() { _selectedMake = v; _selectedModel = null; _selectedGen = null; _result = null; }); }
  void _onModelChanged(String? v) { setState(() { _selectedModel = v; _selectedGen = null; _result = null; }); }
  void _onGenChanged(int? v) { setState(() { _selectedGen = v; _result = null; }); if (v == null) return; WidgetsBinding.instance.addPostFrameCallback((_) => _lookup()); }

  void _lookup() {
    if (_selectedMake == null || _selectedModel == null || _selectedGen == null) return;
    final gen = _gens![_selectedGen!];
    final model = _models!.firstWhere((m) => m['name'] == _selectedModel);
    setState(() => _result = {'gen': gen, 'ts': _getTyres(model), 'rs': _getRims(model)});
  }

  @override
  Widget build(BuildContext context) {
    if (!_loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    return Scaffold(
      appBar: AppBar(title: const Text('輪胎配對')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('選擇車輛', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _selectedMake,
            decoration: const InputDecoration(labelText: '品牌', border: OutlineInputBorder(), isDense: true),
            items: _makes.map((m) => DropdownMenuItem(value: m, child: Text(m))).toList(),
            onChanged: _onMakeChanged,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<String>(
            initialValue: _selectedModel,
            decoration: const InputDecoration(labelText: '型號', border: OutlineInputBorder(), isDense: true),
            items: _models?.map((m) => DropdownMenuItem(value: m['name']?.toString(), child: Text(m['name']?.toString() ?? ''))).toList() ?? [],
            onChanged: _selectedMake != null ? _onModelChanged : null,
          ),
          const SizedBox(height: 8),
          DropdownButtonFormField<int>(
            initialValue: _selectedGen,
            decoration: const InputDecoration(labelText: '世代 / 年份', border: OutlineInputBorder(), isDense: true),
            items: _gens?.asMap().entries.map((e) {
              final y = e.value['year']?.toString() ?? '';
              final label = y.contains('Present') || y.toLowerCase().contains('new')
                ? '${e.value['name']} — 新款'
                : y.isNotEmpty ? '${e.value['name']} ($y)' : e.value['name'] ?? '';
              return DropdownMenuItem(value: e.key, child: Text(label));
            }).toList() ?? [],
            onChanged: _selectedModel != null ? _onGenChanged : null,
          ),
          const SizedBox(height: 20),
          if (_result != null) ...[
            const Divider(),
            const SizedBox(height: 8),
            Text('規格', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Theme.of(context).colorScheme.primary)),
            const SizedBox(height: 8),
            _specRow('PCD', _result!['gen']['pcd']),
            _specRow('Offset', _result!['gen']['offset']),
            _specRow('Centre Bore', _result!['gen']['cb']),
            _specRow('Thread', _result!['gen']['thread']),
            _specRow('Torque', _result!['gen']['torque']),
            const SizedBox(height: 12),
            if ((_result!['ts'] as List).isNotEmpty) ...[
              Text('適用輪胎尺寸', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...(_result!['ts'] as List).map((s) => Card(
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: ListTile(dense: true, title: Text(s, style: const TextStyle(fontWeight: FontWeight.w500)), trailing: Icon(Icons.check_circle, color: Colors.green.shade600)),
              )),
            ],
            if ((_result!['rs'] as List).isNotEmpty) ...[
              const SizedBox(height: 8),
              Text('適用鈴尺寸', style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
              const SizedBox(height: 4),
              ...(_result!['rs'] as List).map((s) => Card(
                margin: const EdgeInsets.symmetric(vertical: 2),
                child: ListTile(dense: true, title: Text(s)),
              )),
            ],
          ],
        ]),
      ),
    );
  }

  Widget _specRow(String label, String? value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(children: [SizedBox(width: 110, child: Text(label, style: const TextStyle(fontWeight: FontWeight.w500))), Text(value ?? '-')]),
  );
}
