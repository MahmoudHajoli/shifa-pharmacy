import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class AppDatabase extends ChangeNotifier {
  late SharedPreferences _prefs;
  String pharmacyName = 'صيدلية شفاء (نسخة تجريبية)';
  String currency = 'ر.س';
  double taxRate = 15.0;
  bool taxConfirmed = false;
  String activeRole = 'مدير النظام';

  List> medicines = [];
  List> sales = [];
  List> purchases = [];
  List> suppliers = [];
  List> customers = [];
  List> users = [];
  List> auditLogs = [];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final saved = _prefs.getString('shifa_db_v1');
    if (saved != null) {
      restoreFromJsonString(saved, logAction: false);
    } else {
      loadSampleData();
    }
  }

  Future<void> saveToDisk() async {
    await _prefs.setString('shifa_db_v1', exportToJsonString());
    notifyListeners();
  }

  void addLog(String action) {
    auditLogs.insert(0, {'time': DateTime.now().toString().substring(0, 16), 'user': activeRole, 'action': action});
  }

  void loadSampleData() {
    taxConfirmed = false;
    medicines = [
      {'id': '1', 'barcode': '6281001', 'name': 'باراسيتامول 500 ملغ (تجريبي)', 'category': 'مسكنات', 'supplier': 'مستودع الشفاء', 'costPrice': 4.5, 'sellPrice': 8.0, 'qty': 45, 'minQty': 10, 'batch': 'B-101', 'expiry': '2027-08-15'},
      {'id': '2', 'barcode': '6281002', 'name': 'أموكسيسيلين 500 ملغ (تجريبي)', 'category': 'مضادات', 'supplier': 'الشركة المتحدة', 'costPrice': 14.0, 'sellPrice': 24.0, 'qty': 4, 'minQty': 10, 'batch': 'B-204', 'expiry': '2026-12-01'},
      {'id': '3', 'barcode': '6281003', 'name': 'فيتامين سي (منتهي للتجربة)', 'category': 'مكملات', 'supplier': 'مستودع الشفاء', 'costPrice': 10.0, 'sellPrice': 18.0, 'qty': 12, 'minQty': 5, 'batch': 'EXP-99', 'expiry': '2025-01-10'},
    ];
    suppliers = [{'id': '1', 'name': 'مستودع الشفاء', 'phone': '0551112223'}];
    customers = [{'id': '1', 'name': 'أحمد محمود (عميل تجريبي)', 'phone': '0501234567', 'debt': 45.0, 'history': ['رصيد افتتاحي: 45.0']}];
    users = [{'name': 'أحمد (المدير)', 'role': 'مدير النظام'}, {'name': 'د. منى', 'role': 'صيدلي'}, {'name': 'خالد', 'role': 'كاشير'}];
    sales = [];
    purchases = [];
    auditLogs = [];
    addLog('تم تحميل البيانات التجريبية');
    saveToDisk();
  }

  void clearAllSampleData() {
    medicines.clear(); sales.clear(); purchases.clear(); suppliers.clear(); customers.clear();
    addLog('تم مسح البيانات التجريبية');
    saveToDisk();
  }

  void confirmTaxSettings({required String newCurr, required double newTax, required String newName}) {
    pharmacyName = newName; currency = newCurr; taxRate = newTax; taxConfirmed = true;
    addLog('تأكيد الضريبة ($newTax%) والعملة ($newCurr)');
    saveToDisk();
  }

  void changeRole(String r) { activeRole = r; notifyListeners(); }

  bool isExpired(String d) => (DateTime.tryParse(d) ?? DateTime(2099)).isBefore(DateTime.now());
  bool isNearExpiry(String d) {
    final diff = (DateTime.tryParse(d) ?? DateTime(2099)).difference(DateTime.now()).inDays;
    return diff >= 0 && diff <= 90;
  }

  String? completeSale({required List> cartItems, required double discount, required String paymentMethod, String? customerId}) {
    if (!taxConfirmed) return 'يرجى تأكيد إعدادات الضريبة أولاً!';
    if (cartItems.isEmpty) return 'السلة فارغة!';
    for (var item in cartItems) {
      final med = medicines.firstWhere((m) => m['id'] == item['id']);
      if (isExpired(med['expiry'])) return 'الدواء (${med['name']}) منتهي الصلاحية!';
      if (item['cartQty'] > med['qty']) return 'الكمية تتجاوز الرصيد المتاح!';
    }
    double sub = 0, cost = 0;
    for (var i in cartItems) {
      sub += (i['sellPrice'] as num) * (i['cartQty'] as int);
      cost += (i['costPrice'] as num) * (i['cartQty'] as int);
    }
    final after = (sub - discount).clamp(0.0, double.infinity);
    final tax = after * (taxRate / 100.0);
    final total = after + tax;

    for (var i in cartItems) {
      final idx = medicines.indexWhere((m) => m['id'] == i['id']);
      medicines[idx]['qty'] = (medicines[idx]['qty'] as int) - (i['cartQty'] as int);
    }
    if (paymentMethod == 'آجل') {
      if (customerId == null) return 'اختر العميل لتسجيل الدين!';
      final cIdx = customers.indexWhere((c) => c['id'] == customerId);
      customers[cIdx]['debt'] = (customers[cIdx]['debt'] as num).toDouble() + total;
      (customers[cIdx]['history'] as List).add('فاتورة آجل: ${total.toStringAsFixed(2)} $currency');
    }
    sales.insert(0, {'id': 'INV-${1001 + sales.length}', 'date': DateTime.now().toString().substring(0, 16), 'subtotal': sub, 'discount': discount, 'tax': tax, 'total': total, 'profit': after - cost, 'method': paymentMethod});
    addLog('بيع فاتورة ${sales.first['id']} بقيمة ${total.toStringAsFixed(2)}');
    saveToDisk();
    return null;
  }

  void saveMedicine(Map<String, dynamic> m) {
    final idx = medicines.indexWhere((x) => x['id'] == m['id']);
    if (idx >= 0) medicines[idx] = m; else medicines.add(m);
    addLog('حفظ دواء: ${m['name']}');
    saveToDisk();
  }

  void deleteMedicine(String id) {
    medicines.removeWhere((m) => m['id'] == id);
    addLog('حذف دواء');
    saveToDisk();
  }

  void recordPurchase({required String supplierName, required String medId, required int qty, required double unitCost, required String newBatch, required String newExpiry}) {
    final idx = medicines.indexWhere((m) => m['id'] == medId);
    if (idx < 0) return;
    medicines[idx]['qty'] = (medicines[idx]['qty'] as int) + qty;
    medicines[idx]['costPrice'] = unitCost;
    if (newBatch.isNotEmpty) medicines[idx]['batch'] = newBatch;
    if (newExpiry.isNotEmpty) medicines[idx]['expiry'] = newExpiry;
    purchases.insert(0, {'id': 'PUR-${101 + purchases.length}', 'date': DateTime.now().toString().substring(0, 16), 'supplier': supplierName, 'medName': medicines[idx]['name'], 'qty': qty, 'total': qty * unitCost});
    addLog('شراء ${medicines[idx]['name']} كمية $qty');
    saveToDisk();
  }

  void payCustomerDebt(String cId, double amt) {
    final idx = customers.indexWhere((c) => c['id'] == cId);
    if (idx < 0) return;
    customers[idx]['debt'] = ((customers[idx]['debt'] as num).toDouble() - amt).clamp(0.0, double.infinity);
    (customers[idx]['history'] as List).add('سداد: $amt $currency');
    addLog('سداد دين عميل بقيمة $amt');
    saveToDisk();
  }

  String exportToJsonString() => jsonEncode({'pharmacyName': pharmacyName, 'currency': currency, 'taxRate': taxRate, 'taxConfirmed': taxConfirmed, 'medicines': medicines, 'sales': sales, 'purchases': purchases, 'suppliers': suppliers, 'customers': customers, 'users': users, 'auditLogs': auditLogs});

  bool restoreFromJsonString(String s, {bool logAction = true}) {
    try {
      final d = jsonDecode(s);
      pharmacyName = d['pharmacyName'] ?? pharmacyName; currency = d['currency'] ?? currency;
      taxRate = (d['taxRate'] as num?)?.toDouble() ?? 15.0; taxConfirmed = d['taxConfirmed'] ?? false;
      medicines = List>.from(d['medicines'] ?? []);
      sales = List>.from(d['sales'] ?? []);
      purchases = List>.from(d['purchases'] ?? []);
      suppliers = List>.from(d['suppliers'] ?? []);
      customers = List>.from(d['customers'] ?? []);
      users = List>.from(d['users'] ?? []);
      auditLogs = List>.from(d['auditLogs'] ?? []);
      if (logAction) { addLog('استعادة نسخة احتياطية'); saveToDisk(); }
      notifyListeners();
      return true;
    } catch (_) { return false; }
  }
}