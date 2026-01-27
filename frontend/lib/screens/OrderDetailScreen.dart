import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class OrderDetailScreen extends StatefulWidget {
  final dynamic order;
  const OrderDetailScreen({super.key, required this.order});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  late String _status;
  bool _isProcessing = false;

  @override
  void initState() {
    super.initState();
    _status = widget.order['status'];
  }

  Future<void> _handleCancelOrder() async {
    setState(() => _isProcessing = true);
    
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await auth.cancelOrder(widget.order['_id']);

    if (mounted) {
      setState(() => _isProcessing = false);
      if (result['success']) {
        setState(() => _status = 'cancelled');
        _showDialog('Success', result['message']);
      } else {
        _showDialog('Error', result['message']);
      }
    }
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("OK"))
        ],
      ),
    );
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return Colors.orange;
      case 'pending_payment': return Colors.amber;
      case 'shipped': return Colors.blue;
      case 'delivered': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    final currency = widget.order['currency'] ?? 'VND';
    final items = widget.order['items'] as List;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Order Details", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSection("Order ID:", widget.order['orderId']),
            _buildSection("Order Date:", DateFormat('MMM d, yyyy, HH:mm').format(DateTime.parse(widget.order['orderDate']))),
            
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text("Status:", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
                Text(_status.toUpperCase(), style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: _getStatusColor(_status))),
              ],
            ),
            const SizedBox(height: 14),

            Container(
              padding: const EdgeInsets.symmetric(vertical: 10),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: Color(0xFFEEEEEE)), bottom: BorderSide(color: Color(0xFFEEEEEE)))),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text("Items:", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
                  const SizedBox(height: 8),
                  ...items.map((item) => Padding(
                    padding: const EdgeInsets.only(bottom: 6, left: 10),
                    child: Text(
                      "• ${item['name']} (x${item['quantity']}) — ${NumberFormat("#,###").format(item['pricePerUnit'])} $currency",
                      style: const TextStyle(fontSize: 15, color: Color(0xFF333333)),
                    ),
                  )),
                ],
              ),
            ),
            const SizedBox(height: 14),

            _buildSection("Total Amount:", "${NumberFormat("#,###").format(widget.order['totalAmount'])} $currency", isTotal: true),

            if (widget.order['shippingAddress'] != null)
              _buildSection(
                "Shipping Address:", 
                "${widget.order['shippingAddress']['street']}, ${widget.order['shippingAddress']['city']}, ${widget.order['shippingAddress']['country']}"
              ),

            const SizedBox(height: 30),

            // SỬA LỖI: Xóa const và dùng Icon đúng tên
            if (_status != 'shipped' && _status != 'delivered' && _status != 'cancelled')
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: _isProcessing ? null : _handleCancelOrder,
                  icon: const Icon(Icons.cancel_outlined, color: Colors.white), // Sửa Icons.close_border_rounded
                  label: Text(
                    _isProcessing ? "Cancelling..." : "Cancel Order", 
                    style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.redAccent,
                    padding: const EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection(String label, String value, {bool isTotal = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: Color(0xFF444444))),
          const SizedBox(height: 4),
          Text(
            value, 
            style: TextStyle(
              fontSize: isTotal ? 18 : 16, 
              fontWeight: isTotal ? FontWeight.bold : FontWeight.normal,
              color: isTotal ? const Color(0xFF1DB954) : const Color(0xFF111111)
            )
          ),
        ],
      ),
    );
  }
}