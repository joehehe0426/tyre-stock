#!/usr/bin/env python3
"""Generate the complete main.dart with all fixes."""
import os

# fmt: off
code = r"""
import 'dart:convert'; import 'dart:html' as html;
import 'package:flutter/material.dart'; import 'package:flutter/services.dart';
import 'package:excel/excel.dart'; import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(MaterialApp(title:'呔妹輪胎',debugShowCheckedModeBanner:false,
  theme:ThemeData(colorSchemeSeed:Color(0xFFD81B60),useMaterial3:true),home:PinGate()));

// PIN GATE
class PinGate extends StatefulWidget { const PinGate({super.key}); @override State<PinGate> createState() => _PinGateState(); }
class _PinGateState extends State<PinGate> {
  bool _authed=false; static const _defPin='250183418';
  @override void initState(){super.initState();_check();}
  Future<void>_check()async{final p=await SharedPreferences.getInstance();final e=p.getString('pin');if(e==null||e=='tyre888')await p.setString('pin',_defPin);if(mounted)setState(()=>_authed=p.getBool('authed')??false);}
  Future<bool>_tryPin(String pin)async{final p=await SharedPreferences.getInstance();final s=p.getString('pin')??_defPin;if(pin==s){await p.setBool('authed',true);return true;}return false;}
  Future<void>_changePin(BuildContext ctx)async{final ctrl=TextEditingController();final r=await showDialog<String>(ctx:ctx,builder:(c)=>AlertDialog(title:const Text('更改密碼'),content:TextField(controller:ctrl,obscureText:true,decoration:const InputDecoration(labelText:'新密碼',border:OutlineInputBorder(),isDense:true)),actions:[TextButton(onPressed:()=>Navigator.pop(c),child:const Text('取消')),FilledButton(onPressed:()=>Navigator.pop(c,ctrl.text.trim()),child:const Text('確定'))]));ctrl.dispose();if(r!=null&&r.isNotEmpty){(await SharedPreferences.getInstance()).setString('pin',r);if(ctx.mounted)ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content:Text('密碼已更改'),backgroundColor:Colors.green));}}
  @override Widget build(BuildContext context){if(_authed)return HomePage(onChangePin:()=>_changePin(context));return Scaffold(body:Center(child:_PinForm(onPin:(pin)async{final ok=await _tryPin(pin);if(ok&&mounted)setState(()=>_authed=true);return ok;})));}
}
class _PinForm extends StatefulWidget{final Future<bool>Function(String)onPin;const _PinForm({required this.onPin});@override State<_PinForm> createState()=>_PinFormState();}
class _PinFormState extends State<_PinForm>{final _c=TextEditingController();bool _wrong=false;Future<void>_submit()async{final ok=await widget.onPin(_c.text);setState(()=>_wrong=!ok);if(!ok)_c.clear();}@override void dispose(){_c.dispose();super.dispose();}
  @override Widget build(BuildContext context)=>Padding(padding:EdgeInsets.all(32),child:Column(mainAxisSize:MainAxisSize.min,children:[
    Container(width:80,height:80,decoration:BoxDecoration(color:Theme.of(context).colorScheme.primary,borderRadius:BorderRadius.circular(40)),child:Icon(Icons.lock,color:Colors.white,size:36)),
    SizedBox(height:16),Text('呔妹輪胎庫存',style:TextStyle(fontSize:22,fontWeight:FontWeight.bold)),SizedBox(height:8),Text('請輸入密碼',style:TextStyle(color:Colors.grey)),SizedBox(height:20),
    TextField(controller:_c,obscureText:true,autofocus:true,textAlign:TextAlign.center,style:TextStyle(fontSize:24,letterSpacing:8),
      decoration:InputDecoration(border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)),isDense:true,contentPadding:EdgeInsets.symmetric(vertical:14,horizontal:16),errorText:_wrong?'密碼錯誤':null),onSubmitted:(_)=>_submit()),
    SizedBox(height:12),FilledButton.icon(onPressed:_submit,icon:Icon(Icons.login),label:Text('登入'),style:FilledButton.styleFrom(minimumSize:Size(double.infinity,48))),
    SizedBox(height:12),Text('🔑 密碼: 250183418',style:Theme.of(context).textTheme.bodySmall?.copyWith(color:Colors.grey)),
  ]));
}

// HOME
class HomePage extends StatefulWidget {final VoidCallback? onChangePin;const HomePage({super.key,this.onChangePin});@override State<HomePage> createState()=>_HomePageState();}
class _HomePageState extends State<HomePage>{int _tab=0;
  @override Widget build(BuildContext context)=>Scaffold(
    body:IndexedStack(index:_tab,children:[StockPage(onChangePin:widget.onChangePin),const FitmentPage()]),
    bottomNavigationBar:NavigationBar(selectedIndex:_tab,onDestinationSelected:(i)=>setState(()=>_tab=i),destinations:const[
      NavigationDestination(icon:Icon(Icons.inventory_2),label:'庫存'),
      NavigationDestination(icon:Icon(Icons.search),label:'配對'),
    ]));
}

// STOCK PAGE
class StockPage extends StatefulWidget {final VoidCallback? onChangePin;const StockPage({super.key,this.onChangePin});@override State<StockPage> createState()=>_StockPageState();}
class _StockPageState extends State<StockPage>{
  List<Map<String,dynamic>>_all=[];List<Map<String,dynamic>>_filtered=[];
  String _search='',_brandF='',_rimF='',?_sheetUrl;bool _loaded=false;String?_err;

  @override void initState(){super.initState();_init();}
  Future<void>_init()async{final p=await SharedPreferences.getInstance();_sheetUrl=p.getString('sheet_url');
    try{final s=p.getString('d');if(s!=null&&s.isNotEmpty){_all=(jsonDecode(s)as List).cast<Map<String,dynamic>>();}else{if(!await _loadFromSheet()&&!await _loadFromBundle())_all=_fb();}}
    catch(e){_err='error: $e';_all=_fb();}_reload();if(mounted)setState(()=>_loaded=true);}

  void _pickFile(){final input=html.FileUploadInputElement()..accept='.xlsx,.xls';input.click();
    input.onChange.listen((_)async{if(input.files!.isEmpty)return;final reader=html.FileReader();reader.readAsArrayBuffer(input.files![0]);
      reader.onLoadEnd.listen((_)async{try{await _parseXlsx(reader.result as List<int>);await(await SharedPreferences.getInstance()).setString('d',jsonEncode(_all));_err=null;_reload();if(mounted)setState((){});if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('已載入 ${_all.length} 款'),backgroundColor:Colors.green));}catch(e){if(mounted)ScaffoldMessenger.of(context).showSnackBar(SnackBar(content:Text('檔案錯誤: $e'),backgroundColor:Colors.red));}});});}

  Future<bool>_loadFromSheet()async{if(_sheetUrl==null||_sheetUrl!.isEmpty)return false;
    try{final url=_sheetUrl!.startsWith('http')?_sheetUrl!:'https://docs.google.com/spreadsheets/d/$_sheetUrl/export?format=csv';final res=await http.get(Uri.parse(url)).timeout(const Duration(seconds:15));if(res.statusCode!=200)throw 'HTTP ${res.statusCode}';
      _all.clear();final rows=res.body.split('\n').where((r)=>r.trim().isNotEmpty).toList();if(rows.length>=2){for(int r=1;r<rows.length;r++){final cols=rows[r].split(',');if(cols.length<8)continue;_all.add({'br':cols[0].trim(),'pt':cols[1].trim(),'w':int.tryParse(cols[2].trim())??0,'a':int.tryParse(cols[3].trim())??0,'ri':int.tryParse(cols[4].trim())??0,'bp':double.tryParse(cols[5].trim())??0,'sp':double.tryParse(cols[6].trim())??0,'st':int.tryParse(cols[7].trim())??0,'su':cols.length>9?cols[9].trim():'','de':cols.length>10?cols[10].trim():'',});}}
      if(_all.isNotEmpty){await(await SharedPreferences.getInstance()).setString('d',jsonEncode(_all));_err=null;return true;}}catch(e){_err='Google Sheet error: $e';}return false;}

  Future<bool>_loadFromBundle()async{try{final d=await rootBundle.load('assets/stock.xlsx');await _parseXlsx(d.buffer.asUint8List());_err=null;return true;}catch(_){}_err='上傳 stock.xlsx 或設定 Google Sheet';return false;}

  Future<void>_parseXlsx(List<int>bytes)async{final ex=Excel.decodeBytes(bytes);var sh=ex.tables['tyre_stock']??ex.tables['工作表1'];if(sh==null)sh=ex.tables.values.first;if(sh==null||sh.rows.length<2)throw'no data';
    _all.clear();final hdr=sh.rows[0];final isNew=hdr.isNotEmpty&&(hdr[1]?.value?.toString()??'').contains('Size');
    for(int r=1;r<sh.rows.length;r++){final row=sh.rows[r];
      if(isNew){final sz=(row[1]?.value?.toString()??'').replaceAll(' ','');final p=sz.split('/');if(p.length<3)continue;final w=int.tryParse(p[0])??0;final a=int.tryParse(p[1])??0;final ri=int.tryParse(p[2])??0;if(w==0&&a==0)continue;final b=(row[2]?.value?.toString()??'').trim();final d=(row[3]?.value?.toString()??'').trim();String pt=d;if(pt.toUpperCase().startsWith(b.toUpperCase()))pt=pt.substring(b.length).trim();if(pt.isEmpty)pt=d;final pr=double.tryParse(row[5]?.value?.toString()??'0')??0;
        _all.add({'br':b,'pt':pt,'w':w,'a':a,'ri':ri,'bp':pr*0.6,'sp':pr,'st':1,'su':'','de':d});}
      else{if(row[0]?.value==null)continue;_all.add({'br':row[0]!.value.toString(),'pt':row[1]!.value.toString(),'w':int.tryParse(row[2]?.value.toString()??'0')??0,'a':int.tryParse(row[3]?.value.toString()??'0')??0,'ri':int.tryParse(row[4]?.value.toString()??'0')??0,'bp':double.tryParse(row[5]?.value.toString()??'0')??0,'sp':double.tryParse(row[6]?.value.toString()??'0')??0,'st':int.tryParse(row[7]?.value.toString()??'0')??0,'su':row[9]?.value?.toString()??'','de':row[10]?.value?.toString()??'',});}}}}

  Future<void>_setSheetUrl()async{final ctrl=TextEditingController(text:_sheetUrl??'');final url=await showDialog<String>(context:context,builder:(ctx)=>AlertDialog(title:const Text('Google Sheet'),content:Column(mainAxisSize:MainAxisSize.min,children:[const Text('貼上 Google Sheet 分享連結'),SizedBox(height:8),TextField(controller:ctrl,decoration:const InputDecoration(hintText:'https://...',isDense:true,border:OutlineInputBorder()),maxLines:2)]),actions:[TextButton(onPressed:()=>Navigator.pop(ctx,''),child:const Text('清除')),TextButton(onPressed:()=>Navigator.pop(ctx),child:const Text('取消')),FilledButton(onPressed:()=>Navigator.pop(ctx,ctrl.text.trim()),child:const Text('儲存'))]));ctrl.dispose();if(url==null)return;_sheetUrl=url;final p=await SharedPreferences.getInstance();if(url.isEmpty)await p.remove('sheet_url');else await p.setString('sheet_url',url);}

  List<Map<String,dynamic>>_fb()=>[{'br':'Michelin','pt':'Primacy 4+','w':225,'a':55,'ri':17,'bp':650,'sp':950,'st':15,'su':'','de':'旗艦舒適呔'},{'br':'Bridgestone','pt':'Turanza T005','w':205,'a':55,'ri':16,'bp':520,'sp':780,'st':12,'su':'合誠輪呔','de':'舒適寧靜'}];
  String _size(Map m)=>'${m['w']}/${m['a']}R${m['ri']}';String _rimL(Map m)=>'${m['ri']}"';
  Future<void>_save()async=>(await SharedPreferences.getInstance()).setString('d',jsonEncode(_all));
  void _reload(){_filtered=_all.where((t){if(_brandF.isNotEmpty&&t['br']!=_brandF)return false;if(_rimF.isNotEmpty&&_rimL(t)!=_rimF)return false;if(_search.isNotEmpty){final q=_search.toLowerCase();return t['br'].toString().toLowerCase().contains(q)||t['pt'].toString().toLowerCase().contains(q)||_size(t).toLowerCase().contains(q)||t['su'].toString().toLowerCase().contains(q);}return true;}).toList();}
  void _apply(){_reload();setState((){});}Future<void>_reloadAll()async{setState(()=>_loaded=false);await _init();}

  @override Widget build(BuildContext context){
    if(!_loaded)return Scaffold(appBar:AppBar(title:const Text('呔妹輪胎'),actions:[if(widget.onChangePin!=null)IconButton(icon:const Icon(Icons.settings),tooltip:'更改密碼',onPressed:widget.onChangePin)]),body:Center(child:_err!=null?Padding(padding:const EdgeInsets.all(24),child:Column(mainAxisSize:MainAxisSize.min,children:[Icon(Icons.upload_file,size:64,color:Colors.grey),SizedBox(height:16),Text(_err!,textAlign:TextAlign.center,style:TextStyle(color:Colors.red)),SizedBox(height:16),FilledButton.icon(onPressed:_pickFile,icon:Icon(Icons.file_upload),label:Text('上傳 stock.xlsx')),SizedBox(height:8),OutlinedButton.icon(onPressed:_setSheetUrl,icon:Icon(Icons.link),label:Text('或連結 Google Sheet'))])):const CircularProgressIndicator()));
    final brands=_all.map((t)=>t['br'].toString()).toSet().toList()..sort();final rims=_all.map((t)=>_rimL(t)).toSet().toList()..sort((a,b)=>int.parse(a.replaceAll('"','')).compareTo(int.parse(b.replaceAll('"',''))));
    return Scaffold(appBar:AppBar(title:const Text('呔妹輪胎'),actions:[
      if(widget.onChangePin!=null)IconButton(icon:const Icon(Icons.settings),tooltip:'更改密碼',onPressed:widget.onChangePin),
      if(_sheetUrl!=null&&_sheetUrl!.isNotEmpty)Tooltip(message:'已連結 Google Sheet',child:Icon(Icons.cloud_done,size:18,color:Colors.green.shade300)),
      IconButton(icon:Icon(Icons.file_upload),tooltip:'上傳 stock.xlsx',onPressed:_pickFile),IconButton(icon:Icon(Icons.link),tooltip:'Google Sheet',onPressed:_setSheetUrl),IconButton(icon:Icon(Icons.refresh),tooltip:'重新載入',onPressed:_reloadAll),
      Padding(padding:EdgeInsets.symmetric(horizontal:8),child:Text('${_all.length}款',style:Theme.of(context).textTheme.bodySmall))]),
      body:Column(children:[
        Padding(padding:EdgeInsets.fromLTRB(12,8,12,0),child:TextField(decoration:InputDecoration(hintText:'搜索...',prefixIcon:Icon(Icons.search),border:OutlineInputBorder(borderRadius:BorderRadius.circular(12)),isDense:true,contentPadding:EdgeInsets.symmetric(vertical:10,horizontal:12)),onChanged:(v){_search=v;_apply();})),
        Padding(padding:EdgeInsets.symmetric(horizontal:12,vertical:6),child:Row(children:[Expanded(child:DropdownButtonFormField<String>(value:_brandF.isEmpty?'':_brandF,decoration:InputDecoration(labelText:'品牌',isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:8,vertical:8)),items:[DropdownMenuItem(value:'',child:Text('全部'))].followedBy(brands.map((b)=>DropdownMenuItem(value:b,child:Text(b)))).toList(),onChanged:(v){_brandF=v??'';_apply();})),SizedBox(width:8),Expanded(child:DropdownButtonFormField<String>(value:_rimF.isEmpty?'':_rimF,decoration:InputDecoration(labelText:'鈴',isDense:true,contentPadding:EdgeInsets.symmetric(horizontal:8,vertical:8)),items:[DropdownMenuItem(value:'',child:Text('全部'))].followedBy(rims.map((r)=>DropdownMenuItem(value:r,child:Text(r)))).toList(),onChanged:(v){_rimF=v??'';_apply();}))])),
        Expanded(child:_filtered.isEmpty?Center(child:Text('無匹配')):ListView.builder(itemCount:_filtered.length,itemBuilder:(_,i){final t=_filtered[i];return Card(margin:EdgeInsets.symmetric(horizontal:12,vertical:3),child:ListTile(
          title:Text('${t['br']} ${t['pt']}',style:TextStyle(fontWeight:FontWeight.w500)),
          subtitle:Text('${_size(t)}  \$${t['sp']?.toInt()}'),
          trailing:Row(mainAxisSize:MainAxisSize.min,children:[Text('${t['st']}',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold,color:(t['st']as int)<10?Colors.red:Theme.of(context).colorScheme.primary)),SizedBox(width:4),Text('條',style:Theme.of(context).textTheme.bodySmall)]),onTap:()=>_edit(t)));})),
      ]),floatingActionButton:FloatingActionButton(onPressed:_add,child:Icon(Icons.add)));
  }
  void _edit(Map<String,dynamic>t)async{final r=await _dialog(t,false);if(r==null)return;final i=_all.indexWhere((x)=>x['br']==t['br']&&x['pt']==t['pt']&&x['ri']==t['ri']);if(i>=0){_all[i]=r;await _save();_reload();if(mounted)setState((){});}}
  void _add()async{final r=await _dialog(null,true);if(r!=null){_all.add(r);await _save();_reload();if(mounted)setState((){});}}
  Future<Map<String,dynamic>?>_dialog(Map<String,dynamic>?t,bool isNew)async{
    final bc=TextEditingController(text:t?['br']??'');final pc=TextEditingController(text:t?['pt']??'');final sc=TextEditingController(text:'${t?['st']??0}');final spc=TextEditingController(text:'${t?['sp']??0}');final suc=TextEditingController(text:t?['su']??'');final dc=TextEditingController(text:t?['de']??'');
    int w=t?['w']??205,a=t?['a']??55,ri=t?['ri']??16;final fk=GlobalKey<FormState>();
    final r=await showDialog<Map<String,dynamic>>(context:context,builder:(ctx)=>AlertDialog(title:Text(isNew?'新增':'編輯'),content:Form(key:fk,child:SingleChildScrollView(child:Column(mainAxisSize:MainAxisSize.min,children:[
      TextFormField(controller:bc,decoration:InputDecoration(labelText:'品牌',isDense:true),validator:(v)=>v?.isEmpty==true?'必填':null),
      TextFormField(controller:pc,decoration:InputDecoration(labelText:'型號',isDense:true),validator:(v)=>v?.isEmpty==true?'必填':null),
      Row(children:[Expanded(child:TextFormField(initialValue:'$w',decoration:InputDecoration(labelText:'闊',isDense:true),keyboardType:TextInputType.number,onChanged:(v)=>w=int.tryParse(v)??0)),SizedBox(width:6),Expanded(child:TextFormField(initialValue:'$a',decoration:InputDecoration(labelText:'扁平',isDense:true),keyboardType:TextInputType.number,onChanged:(v)=>a=int.tryParse(v)??0)),SizedBox(width:6),Expanded(child:TextFormField(initialValue:'$ri',decoration:InputDecoration(labelText:'鈴',isDense:true),keyboardType:TextInputType.number,onChanged:(v)=>ri=int.tryParse(v)??0))]),
      Row(children:[Expanded(child:TextFormField(controller:spc,decoration:InputDecoration(labelText:'賣出價 \$',isDense:true),keyboardType:TextInputType.number))]),
      TextFormField(controller:suc,decoration:InputDecoration(labelText:'供應商',isDense:true)),TextFormField(controller:dc,decoration:InputDecoration(labelText:'描述',isDense:true),maxLines:2),
      SizedBox(height:12),Text('庫存',style:Theme.of(context).textTheme.labelMedium),SizedBox(height:4),
      Wrap(spacing:6,runSpacing:6,children:[0,2,4,6,8,10,20,50,100].map((q)=>ChoiceChip(label:Text('$q',style:TextStyle(fontSize:13)),selected:int.tryParse(sc.text)==q,onSelected:(_){sc.text='$q';setState((){});})).toList()),
      SizedBox(height:8),Row(children:[IconButton.filledTonal(onPressed:(){int v=int.tryParse(sc.text)??0;sc.text='${(v+1).clamp(0,99999)}';setState((){});},icon:Icon(Icons.add)),SizedBox(width:8),Expanded(child:TextFormField(controller:sc,decoration:InputDecoration(isDense:true,hintText:'數量'),keyboardType:TextInputType.number,textAlign:TextAlign.center,style:TextStyle(fontSize:20,fontWeight:FontWeight.bold))),SizedBox(width:8),IconButton.filledTonal(onPressed:(){int v=int.tryParse(sc.text)??0;sc.text='${(v-1).clamp(0,99999)}';setState((){});},icon:Icon(Icons.remove))]),
    ]))),actions:[TextButton(onPressed:()=>Navigator.pop(ctx),child:Text('取消')),FilledButton(onPressed:(){if(fk.currentState?.validate()!=true)return;Navigator.pop(ctx,{'br':bc.text,'pt':pc.text,'w':w,'a':a,'ri':ri,'sp':double.tryParse(spc.text)??0,'st':int.tryParse(sc.text)??0,'su':suc.text,'de':dc.text});},child:Text(isNew?'新增':'儲存'))]));
    bc.dispose();pc.dispose();sc.dispose();spc.dispose();suc.dispose();dc.dispose();return r;
  }
}

// FITMENT PAGE
class FitmentPage extends StatefulWidget {const FitmentPage({super.key});@override State<FitmentPage> createState()=>_FitmentPageState();}
class _FitmentPageState extends State<FitmentPage>{
  Map<String,dynamic>?_data;bool _loaded=false;String?_make,_model;int?_gen;Map<String,dynamic>?_result;
  @override void initState(){super.initState();_load();}
  Future<void>_load()async{try{_data=jsonDecode(await rootBundle.loadString('assets/fitment_data.json'));}catch(_){}if(mounted)setState(()=>_loaded=true);}
  List<String>get _makes=>_data?.keys.toList()?..sort()??[];
  List<Map<String,dynamic>>?get _models=>_make!=null?_data![_make!]['models']?.cast<Map<String,dynamic>>():null;
  List<Map<String,dynamic>>?_gens(){if(_model==null||_models==null)return null;
    final model=_models!.firstWhere((m)=>m['name']==_model,orElse:()=><String,dynamic>{});
    final raw=model['g']??model['generations']??[];if(raw is!List)return null;
    return raw.cast<Map<String,dynamic>>().where((g)=>g['n']?.toString().trim().isNotEmpty==true&&!g['n'].toString().startsWith('---')).map((g)=>{'name':g['n']??'','year':g['y']??'','pcd':g['p']??'','offset':g['o']??'','cb':g['c']??'','thread':g['t']??'','torque':g['q']??'',}).toList();}
  List<String>_ts(Map m)=>((m['ts']??m['tyreSizes']??[])as List).cast<String>();
  void _onMake(String?v){setState((){_make=v;_model=null;_gen=null;_result=null;});}
  void _onModel(String?v){setState((){_model=v;_gen=null;_result=null;});}
  void _onGen(int?v){setState((){_gen=v;_result=null;});if(v==null)return;WidgetsBinding.instance.addPostFrameCallback((_)=>_look());}
  void _look(){if(_make==null||_model==null||_gen==null)return;final g=_gens()![_gen!];final m=_models!.firstWhere((m)=>m['name']==_model,orElse:()=><String,dynamic>{});setState(()=>_result={'gen':g,'ts':_ts(m)});}
  @override Widget build(BuildContext context){if(!_loaded)return const Scaffold(body:Center(child:CircularProgressIndicator()));final gens=_gens();
    return Scaffold(appBar:AppBar(title:const Text('輪胎配對')),body:SingleChildScrollView(padding:const EdgeInsets.all(16),child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
      const Text('選擇車輛',style:TextStyle(fontSize:18,fontWeight:FontWeight.bold)),SizedBox(height:12),
      DropdownButtonFormField<String>(value:_make,decoration:const InputDecoration(labelText:'品牌',border:OutlineInputBorder(),isDense:true),items:_makes.map((m)=>DropdownMenuItem(value:m,child:Text(m))).toList(),onChanged:_onMake),SizedBox(height:8),
      DropdownButtonFormField<String>(value:_model,decoration:const InputDecoration(labelText:'型號',border:OutlineInputBorder(),isDense:true),items:_models?.map((m)=>DropdownMenuItem(value:m['name']?.toString(),child:Text(m['name']?.toString()??''))).toList()??[],onChanged:_make!=null?_onModel:null),SizedBox(height:8),
      DropdownButtonFormField<int>(value:_gen,decoration:const InputDecoration(labelText:'世代/年份',border:OutlineInputBorder(),isDense:true),items:gens?.asMap().entries.map((e){final y=e.value['year']?.toString()??'';return DropdownMenuItem(value:e.key,child:Text('${e.value['name']} (${y.contains('Present')||y.contains('new')||y.contains('New')?'新車':y.isEmpty?'N/A':y})'));}).toList()??[],onChanged:_model!=null?_onGen:null),SizedBox(height:20),
      if(_result!=null)...[const Divider(),SizedBox(height:8),Text('規格',style:TextStyle(fontSize:16,fontWeight:FontWeight.bold,color:Theme.of(context).colorScheme.primary)),
        _sr('PCD',_result!['gen']['pcd']),_sr('Offset',_result!['gen']['offset']),_sr('Centre Bore',_result!['gen']['cb']),_sr('Thread',_result!['gen']['thread']),_sr('Torque',_result!['gen']['torque']),SizedBox(height:12),
        if((_result!['ts']as List).isNotEmpty)...[Text('適用輪胎尺寸',style:TextStyle(fontWeight:FontWeight.w600)),...(_result!['ts']as List).map((s)=>Card(margin:EdgeInsets.symmetric(vertical:2),child:ListTile(dense:true,title:Text('$s'),trailing:Icon(Icons.check_circle,color:Colors.green.shade600))))],
      ],
    ])));
  }
  Widget _sr(String l,String?v)=>Padding(padding:EdgeInsets.symmetric(vertical:2),child:Row(children:[SizedBox(width:110,child:Text(l,style:TextStyle(fontWeight:FontWeight.w500))),Text(v??'-')]));
}
"""

path = "C:/Users/User/Documents/tyre_stock_app/lib/main.dart"
with open(path, 'w', encoding='utf-8') as f:
    f.write(code.strip())

print(f"Written {os.path.getsize(path)} bytes")
