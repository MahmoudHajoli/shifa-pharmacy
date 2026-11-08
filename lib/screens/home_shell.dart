import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../data/app_database.dart';

class HomeShell extends StatefulWidget {
  final AppDatabase db;
  const HomeShell({super.key, required this.db});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;
  String _posQ = '', _invQ = '', _payMethod = 'نقدي';
  String? _custId;
  double _disc = 0.0;
  final List> _cart = [];

  final _tabs = const [
    {'t': 'لوحة التحكم', 'i': Icons.dashboard},
    {'t': 'نقطة البيع (POS)', 'i': Icons.point_of_sale},
    {'t': 'إدارة المخزون', 'i': Icons.medication},
    {'t': 'المشتريات والموردون', 'i': Icons.local_shipping},
    {'t': 'العملاء والديون', 'i': Icons.people},
    {'t': 'التقارير والتصدير', 'i': Icons.analytics},
    {'t': 'المستخدمون والسجل', 'i': Icons.security},
    {'t': 'الإعدادات والنسخ', 'i': Icons.settings},
  ];

  void _msg(String m, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: err ? Colors.red : Colors.teal));
  }

  @override
  Widget build(BuildContext context) {
    final wide = MediaQuery.of(context).size.width >= 850;
    final db = widget.db;
    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF134E4A),
        foregroundColor: Colors.white,
        title: Text(db.pharmacyName, style: const TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          DropdownButton<String>(
            dropdownColor: const Color(0xFF134E4A),
            value: db.activeRole,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'مدير النظام', child: Text('👤 مدير النظام')),
              DropdownMenuItem(value: 'صيدلي', child: Text('👤 صيدلي')),
              DropdownMenuItem(value: 'كاشير', child: Text('👤 كاشير')),
            ],
            onChanged: (v) { if (v != null) db.changeRole(v); },
          ),
          const SizedBox(width: 12),
        ],
      ),
      drawer: wide ? null : Drawer(child: _menu(false)),
      body: Column(
        children: [
          Container(
            width: double.infinity, color: const Color(0xFF1E293B), padding: const EdgeInsets.all(6),
            child: const Text('⚠️ بيانات تجريبية للمعاينة فقط (قابلة للحذف من الإعدادات) - لا يقدم النظام أي تشخيص أو توصيات علاجية.', style: TextStyle(color: Colors.white70, fontSize: 12)),
          ),
          if (!db.taxConfirmed)
            Container(
              width: double.infinity, color: const Color(0xFFFEF3C7), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(child: Text('⚠️ يرجى تأكيد الضريبة (${db.taxRate}%) والعملة (${db.currency}) قبل إصدار الفواتير.', style: const TextStyle(fontWeight: FontWeight.bold))),
                  ElevatedButton(
                    onPressed: () { db.confirmTaxSettings(newCurr: db.currency, newTax: db.taxRate, newName: db.pharmacyName); _msg('تم تأكيد الضريبة'); },
                    child: const Text('تأكيد الآن'),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Row(
              children: [
                if (wide) SizedBox(width: 230, child: _menu(true)),
                Expanded(child: Padding(padding: const EdgeInsets.all(14), child: _body(wide))),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _menu(bool wide) {
    return Container(
      color: const Color(0xFF0F766E),
      child: ListView.builder(
        itemCount: _tabs.length,
        itemBuilder: (_, i) => ListTile(
          selected: _tab == i,
          selectedTileColor: Colors.teal.shade400,
          leading: Icon(_tabs[i]['i'] as IconData, color: Colors.white),
          title: Text(_tabs[i]['t'] as String, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
          onTap: () { setState(() => _tab = i); if (!wide) Navigator.pop(context); },
        ),
      ),
    );
  }

  Widget _body(bool wide) {
    final db = widget.db;
    switch (_tab) {
      case 0:
        final totalSales = db.sales.fold<double>(0, (s, e) => s + (e['total'] as num).toDouble());
        final low = db.medicines.where((m) => (m['qty'] as int) <= (m['minQty'] as int)).toList();
        final exp = db.medicines.where((m) => db.isExpired(m['expiry']) || db.isNearExpiry(m['expiry'])).toList();
        return ListView(children: [
          Wrap(spacing: 12, runSpacing: 12, children: [
            _card('مبيعات اليوم', '${totalSales.toStringAsFixed(2)} ${db.currency}'),
            _card('عدد الفواتير', '${db.sales.length}'),
            _card('منخفض المخزون', '${low.length}'),
            _card('منتهي/قريب الانتهاء', '${exp.length}'),
          ]),
          const SizedBox(height: 16),
          const Text('⚠️ تنبيهات المخزون والصلاحية:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          ...low.map((m) => Card(child: ListTile(title: Text(m['name']), subtitle: const Text('منخفض المخزون'), trailing: Text('الكمية: ${m['qty']}')))),
          ...exp.map((m) => Card(child: ListTile(title: Text(m['name']), subtitle: Text('الانتهاء: ${m['expiry']}'), trailing: Text(db.isExpired(m['expiry']) ? 'منتهي' : 'قريب الانتهاء', style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold))))),
        ]);

      case 1:
        final meds = db.medicines.where((m) => m['name'].toString().contains(_posQ) || m['barcode'].toString().contains(_posQ)).toList();
        double sub = 0;
        for (var c in _cart) { sub += (c['sellPrice'] as num) * (c['cartQty'] as int); }
        final after = (sub - _disc).clamp(0.0, double.infinity);
        final total = after + (after * db.taxRate / 100.0);

        return Column(children: [
          TextField(decoration: const InputDecoration(hintText: 'بحث بالاسم أو الباركود...', border: OutlineInputBorder()), onChanged: (v) => setState(() => _posQ = v)),
          const SizedBox(height: 8),
          Expanded(
            child: Row(children: [
              Expanded(
                child: ListView.builder(
                  itemCount: meds.length,
                  itemBuilder: (_, i) {
                    final m = meds[i];
                    final expired = db.isExpired(m['expiry']);
                    return Card(
                      color: expired ? Colors.red.shade50 : Colors.white,
                      child: ListTile(
                        title: Text(m['name'], style: const TextStyle(fontWeight: FontWeight.bold)),
                        subtitle: Text('باركود: ${m['barcode']} | المتاح: ${m['qty']} | انتهاء: ${m['expiry']}'),
                        trailing: ElevatedButton(
                          onPressed: expired || (m['qty'] as int) <= 0 ? null : () {
                            setState(() {
                              final idx = _cart.indexWhere((x) => x['id'] == m['id']);
                              if (idx >= 0) { if (_cart[idx]['cartQty'] < m['qty']) _cart[idx]['cartQty']++; }
                              else { _cart.add({...m, 'cartQty': 1}); }
                            });
                          },
                          child: Text('${m['sellPrice']} ${db.currency} +'),
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(children: [
                      const Text('الفاتورة الحالية', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _cart.length,
                          itemBuilder: (_, i) => ListTile(
                            dense: true,
                            title: Text(_cart[i]['name']),
                            trailing: Text('${_cart[i]['cartQty']} × ${_cart[i]['sellPrice']}'),
                            onTap: () => setState(() => _cart.removeAt(i)),
                          ),
                        ),
                      ),
                      DropdownButton<String>(
                        value: _payMethod, isExpanded: true,
                        items: const [DropdownMenuItem(value: 'نقدي', child: Text('نقدي')), DropdownMenuItem(value: 'بطاقة', child: Text('بطاقة')), DropdownMenuItem(value: 'آجل', child: Text('آجل (ذمم)'))],
                        onChanged: (v) => setState(() => _payMethod = v ?? 'نقدي'),
                      ),
                      if (_payMethod == 'آجل')
                        DropdownButton<String>(
                          value: _custId, hint: const Text('اختر العميل'), isExpanded: true,
                          items: db.customers.map((c) => DropdownMenuItem<String>(value: c['id'].toString(), child: Text(c['name']))).toList(),
                          onChanged: (v) => setState(() => _custId = v),
                        ),
                      Text('الإجمالي شامل الضريبة: ${total.toStringAsFixed(2)} ${db.currency}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                      const SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () {
                          final err = db.completeSale(cartItems: _cart, discount: _disc, paymentMethod: _payMethod, customerId: _custId);
                          if (err != null) _msg(err, err: true);
                          else { setState(() => _cart.clear()); _msg('تمت عملية البيع وخصم المخزون بنجاح'); }
                        },
                        child: const Text('إتمام البيع وطباعة الفاتورة'),
                      ),
                    ]),
                  ),
                ),
              ),
            ]),
          ),
        ]);

      case 2:
        return ListView(children: [
          ElevatedButton(
            onPressed: () {
              db.saveMedicine({'id': DateTime.now().millisecondsSinceEpoch.toString(), 'barcode': '6281999', 'name': 'دواء جديد', 'category': 'عام', 'supplier': 'مستودع الشفاء', 'costPrice': 5.0, 'sellPrice': 10.0, 'qty': 30, 'minQty': 5, 'batch': 'B-99', 'expiry': '2028-01-01'});
              _msg('تمت إضافة الدواء');
            },
            child: const Text('+ إضافة دواء سريع'),
          ),
          const SizedBox(height: 10),
          ...db.medicines.map((m) => Card(
            child: ListTile(
              title: Text('${m['name']} (${m['barcode']})'),
              subtitle: Text('الكمية: ${m['qty']} | البيع: ${m['sellPrice']} | الانتهاء: ${m['expiry']}'),
              trailing: IconButton(icon: const Icon(Icons.delete, color: Colors.red), onPressed: () => db.deleteMedicine(m['id'])),
            ),
          )),
        ]);

      case 3:
        return ListView(children: [
          ElevatedButton(
            onPressed: () {
              if (db.medicines.isNotEmpty) {
                db.recordPurchase(supplierName: 'مستودع الشفاء', medId: db.medicines.first['id'], qty: 15, unitCost: 4.5, newBatch: 'B-2028', newExpiry: '2028-05-01');
                _msg('تم توريد 15 علبة وتحديث المخزون');
              }
            },
            child: const Text('+ تسجيل فاتورة شراء وتوريد للمخزون'),
          ),
          ...db.purchases.map((p) => Card(child: ListTile(title: Text('${p['medName']} (+${p['qty']})'), subtitle: Text('${p['supplier']} - ${p['date']}')))),
        ]);

      case 4:
        return ListView(children: db.customers.map((c) => Card(
          child: ListTile(
            title: Text(c['name']),
            subtitle: Text('الدين المستحق: ${(c['debt'] as num).toStringAsFixed(2)} ${db.currency}'),
            trailing: ElevatedButton(onPressed: () { db.payCustomerDebt(c['id'], 10.0); _msg('تم سداد 10'); }, child: const Text('سداد 10')),
          ),
        )).toList());

      case 5:
        return ListView(children: [
          ElevatedButton(
            onPressed: () {
              Clipboard.setData(ClipboardData(text: db.sales.toString()));
              _msg('تم نسخ التقرير للحافظة');
            },
            child: const Text('نسخ تقرير المبيعات والأرباح'),
          ),
          ...db.sales.map((s) => Card(child: ListTile(title: Text('فاتورة ${s['id']} - الإجمالي: ${s['total']}'), subtitle: Text('الربح: ${s['profit']} | ${s['date']}')))),
        ]);

      case 6:
        return ListView(children: db.auditLogs.map((l) => ListTile(title: Text(l['action']), subtitle: Text('${l['user']} - ${l['time']}'))).toList());

      case 7:
        return ListView(children: [
          ElevatedButton(onPressed: () { Clipboard.setData(ClipboardData(text: db.exportToJsonString())); _msg('تم نسخ النسخة الاحتياطية'); }, child: const Text('نسخ النسخة الاحتياطية (JSON)')),
          const SizedBox(height: 10),
          ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.red, foregroundColor: Colors.white), onPressed: () { db.clearAllSampleData(); _msg('تم مسح البيانات التجريبية'); }, child: const Text('حذف البيانات التجريبية والبدء من الصفر')),
          const SizedBox(height: 10),
          ElevatedButton(onPressed: () { db.loadSampleData(); _msg('تمت استعادة البيانات التجريبية'); }, child: const Text('إعادة تحميل البيانات التجريبية')),
        ]);

      default:
        return const SizedBox();
    }
  }

  Widget _card(String t, String v) => Card(child: Padding(padding: const EdgeInsets.all(16), child: Column(children: [Text(t), Text(v, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold))])));
}