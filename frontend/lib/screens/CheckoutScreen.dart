import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../providers/auth_provider.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final _formKey = GlobalKey<FormState>();
  final currencyFormat = NumberFormat("#,###", "en_US");

  // Form states
  String _recipient = '';
  String _street = '';
  String _city = '';
  String _country = 'Vietnam';
  String _shippingMethod = 'standard';
  String _paymentMethod = 'cod';
  String _promoCode = '';
  int _discount = 0;
  bool _isLoading = false;

  final String apiUrl = "https://prm393.onrender.com/api";

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _recipient = auth.user?['name'] ?? '';
  }

  void _handleApplyPromo(int subtotal) {
    if (_promoCode.trim().toUpperCase() == 'MUSICX10') {
      setState(() => _discount = (subtotal * 0.1).round());
      _showAlert('✅ Success', '10% discount applied!');
    } else {
      setState(() => _discount = 0);
      _showAlert('❌ Invalid Code', 'Please enter a valid promo code.');
    }
  }

  void _showAlert(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))],
      ),
    );
  }

  Future<void> _handlePlaceOrder(int subtotal, int shippingPrice, int totalAmount) async {
    if (!_formKey.currentState!.validate()) return;
    _formKey.currentState!.save();

    final auth = Provider.of<AuthProvider>(context, listen: false);
    setState(() => _isLoading = true);

    final orderItems = auth.cart.map((item) => {
      "albumId": item['albumId'],
      "sku": item['sku'] ?? "SKU_${item['albumId']}",
      "name": item['name'] ?? "Unknown Album",
      "quantity": item['quantity'] ?? 1,
      "pricePerUnit": item['pricePerUnit'] ?? 0,
    }).toList();

    final orderPayload = {
      "userId": auth.user?['_id'],
      "items": orderItems,
      "shippingAddress": {
        "recipient": _recipient,
        "street": _street,
        "city": _city,
        "country": _country,
      },
      "paymentMethod": _paymentMethod,
      "shippingMethod": _shippingMethod,
      "subtotal": subtotal,
      "shippingPrice": shippingPrice,
      "discount": _discount,
      "totalAmount": totalAmount,
    };

    try {
      if (_paymentMethod == 'momo') {
        // MoMo Payment Logic
        final res = await http.post(
          Uri.parse('$apiUrl/payments/momo/create-link'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(orderPayload),
        );
        final data = json.decode(res.body);

        if (res.statusCode != 200) throw Exception(data['message'] ?? 'Failed');
        
        final Uri url = Uri.parse(data['payUrl']);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication); //
          auth.clearCart(); // Bạn cần thêm hàm clearCart vào AuthProvider
          _navigateBackHome();
        }
      } else {
        // COD / CARD Logic
        final res = await http.post(
          Uri.parse('$apiUrl/orders'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode(orderPayload),
        );
        if (res.statusCode != 200 && res.statusCode != 201) throw Exception('Order failed');

        _showAlert('Order Placed', 'Your order has been placed successfully!');
        auth.clearCart();
        _navigateBackHome();
      }
    } catch (e) {
      _showAlert('Error', e.toString());
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _navigateBackHome() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final int subtotal = auth.cart.fold(0, (sum, item) => sum + (item['pricePerUnit'] * item['quantity']) as int);
    final int shippingPrice = _shippingMethod == 'express' ? 70000 : 30000;
    final int totalAmount = subtotal + shippingPrice - _discount;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(title: const Text("Checkout", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)), backgroundColor: Colors.white, elevation: 0, iconTheme: const IconThemeData(color: Colors.black)),
      body: _isLoading 
        ? const Center(child: CircularProgressIndicator(color: Colors.black))
        : Form(
            key: _formKey,
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _sectionTitle("Your Cart"),
                  _buildCartSummary(auth.cart, subtotal),
                  
                  _sectionTitle("Shipping Address"),
                  _buildTextForm("Recipient Name", (v) => _recipient = v!, initial: _recipient),
                  _buildTextForm("Street", (v) => _street = v!),
                  _buildTextForm("City", (v) => _city = v!),
                  _buildTextForm("Country", (v) => _country = v!, initial: _country),

                  _sectionTitle("Shipping Method"),
                  _buildRadioOption("Standard (30,000 VND)", "standard", _shippingMethod, (v) => setState(() => _shippingMethod = v!)),
                  _buildRadioOption("Express (70,000 VND)", "express", _shippingMethod, (v) => setState(() => _shippingMethod = v!)),

                  _sectionTitle("Payment Method"),
                  _buildRadioOption("Cash on Delivery (COD)", "cod", _paymentMethod, (v) => setState(() => _paymentMethod = v!)),
                  _buildRadioOption("MoMo Wallet", "momo", _paymentMethod, (v) => setState(() => _paymentMethod = v!)),

                  _sectionTitle("Promo Code"),
                  _buildPromoInput(subtotal),

                  _sectionTitle("Preview Summary"),
                  _buildTotalSummary(subtotal, shippingPrice, totalAmount),

                  const SizedBox(height: 30),
                  ElevatedButton(
                    onPressed: () => _handlePlaceOrder(subtotal, shippingPrice, totalAmount),
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 55), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                    child: const Text("Place Order", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
            ),
          ),
    );
  }

  // --- UI Helper Widgets ---
  Widget _sectionTitle(String title) => Padding(padding: const EdgeInsets.only(top: 25, bottom: 10), child: Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)));

  Widget _buildTextForm(String hint, Function(String?) onSave, {String initial = ''}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextFormField(
        initialValue: initial,
        decoration: InputDecoration(hintText: hint, filled: true, fillColor: const Color(0xFFF2F2F2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)),
        validator: (v) => (v == null || v.isEmpty) ? "$hint is required" : null,
        onSaved: onSave,
      ),
    );
  }

  Widget _buildRadioOption(String label, String value, String groupValue, Function(String?) onChanged) {
    return RadioListTile<String>(
      title: Text(label),
      value: value,
      groupValue: groupValue,
      onChanged: onChanged,
      activeColor: Colors.black,
      contentPadding: EdgeInsets.zero,
    );
  }

  Widget _buildCartSummary(List cart, int subtotal) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          ...cart.map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: Row(children: [Expanded(child: Text(item['name'])), Text("x${item['quantity']}"), const SizedBox(width: 20), Text("${currencyFormat.format(item['pricePerUnit'] * item['quantity'])} VND")]),
          )),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text("Subtotal", style: TextStyle(fontWeight: FontWeight.bold)), Text("${currencyFormat.format(subtotal)} VND", style: const TextStyle(fontWeight: FontWeight.bold))]),
        ],
      ),
    );
  }

  Widget _buildPromoInput(int subtotal) {
    return Row(
      children: [
        Expanded(child: TextField(onChanged: (v) => _promoCode = v, decoration: InputDecoration(hintText: "Enter code", filled: true, fillColor: const Color(0xFFF2F2F2), border: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide.none)))),
        const SizedBox(width: 10),
        ElevatedButton(onPressed: () => _handleApplyPromo(subtotal), style: ElevatedButton.styleFrom(backgroundColor: const Color(0xFF555555), padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20)), child: const Text("Apply", style: TextStyle(color: Colors.white))),
      ],
    );
  }

  Widget _buildTotalSummary(int subtotal, int shipping, int total) {
    return Container(
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(color: const Color(0xFFF9F9F9), borderRadius: BorderRadius.circular(8)),
      child: Column(
        children: [
          _summaryRow("Subtotal", subtotal),
          _summaryRow("Shipping", shipping),
          if (_discount > 0) _summaryRow("Discount", -_discount, color: Colors.red),
          const Divider(),
          _summaryRow("Total", total, isBold: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, int amount, {bool isBold = false, Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(label, style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal)), Text("${currencyFormat.format(amount)} VND", style: TextStyle(fontWeight: isBold ? FontWeight.bold : FontWeight.normal, color: color))]),
    );
  }
}