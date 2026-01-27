import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ManageOrdersScreen extends StatefulWidget {
  const ManageOrdersScreen({super.key});

  @override
  State<ManageOrdersScreen> createState() => _ManageOrdersScreenState();
}

class _ManageOrdersScreenState extends State<ManageOrdersScreen> {
  List<dynamic> _orders = [];
  List<dynamic> _filteredOrders = [];
  bool _isLoading = true;
  String _searchQuery = "";

  final List<Map<String, String>> _statusItems = [
    {"label": "Pending", "value": "pending"},
    {"label": "Pending Payment", "value": "pending_payment"},
    {"label": "Shipped", "value": "shipped"},
    {"label": "Delivered", "value": "delivered"},
    {"label": "Cancelled", "value": "cancelled"},
  ];

  @override
  void initState() {
    super.initState();
    _fetchOrders();
  }

  Future<void> _fetchOrders() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      final res = await http.get(Uri.parse('${auth.apiUrl}/api/orders'));
      if (res.statusCode == 200) {
        final dynamic decodedData = json.decode(res.body);
        List<dynamic> data = decodedData is List ? decodedData : (decodedData['orders'] ?? []);
        
        // Sắp xếp đơn hàng mới nhất lên đầu
        data.sort((a, b) => DateTime.parse(b['orderDate']).compareTo(DateTime.parse(a['orderDate'])));

        if (mounted) {
          setState(() {
            _orders = data;
            _filteredOrders = data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch Orders Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterOrders(String query) {
    setState(() {
      _searchQuery = query;
      _filteredOrders = _orders
          .where((o) => o['orderId'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _updateStatus(String id, String newStatus) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.put(
        Uri.parse('${auth.apiUrl}/api/orders/$id'),
        headers: {"Content-Type": "application/json"},
        body: json.encode({"status": newStatus}),
      );
      if (res.statusCode == 200) {
        _fetchOrders();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Order status updated successfully")),
          );
        }
      }
    } catch (e) {
      debugPrint("Update Status Error: $e");
    }
  }

  Color _getStatusColor(String status) {
    switch (status) {
      case 'delivered': return Colors.green;
      case 'shipped': return Colors.orange;
      case 'cancelled': return Colors.red;
      case 'pending': return Colors.blue;
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Manage Orders", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(onPressed: _fetchOrders, icon: const Icon(Icons.refresh, color: Colors.black)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Search Bar
            TextField(
              onChanged: _filterOrders,
              decoration: InputDecoration(
                hintText: "Search by Order ID...",
                prefixIcon: const Icon(Icons.search),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
              ),
            ),
            const SizedBox(height: 24),
            // Order Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : _buildOrderTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderTable() {
    final currency = NumberFormat("#,###", "vi_VN");
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
            columns: const [
              DataColumn(label: Text('Order ID')),
              DataColumn(label: Text('Date')),
              DataColumn(label: Text('Total Amount')),
              DataColumn(label: Text('Current Status')),
              DataColumn(label: Text('Update Status')),
            ],
            rows: _filteredOrders.map((order) {
              final bool isLocked = order['status'] == 'delivered' || order['status'] == 'cancelled';
              
              return DataRow(cells: [
                DataCell(Text("#${order['orderId']}", style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(DateFormat('dd/MM/yyyy HH:mm').format(DateTime.parse(order['orderDate'])))),
                DataCell(Text("${currency.format(order['totalAmount'])}₫")),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: _getStatusColor(order['status']).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    order['status'].toString().toUpperCase().replaceAll("_", " "),
                    style: TextStyle(color: _getStatusColor(order['status']), fontWeight: FontWeight.bold, fontSize: 12),
                  ),
                )),
                DataCell(
                  isLocked 
                  ? const Text("Finalized", style: TextStyle(color: Colors.grey, fontSize: 12))
                  : DropdownButton<String>(
                      value: order['status'],
                      underline: const SizedBox(),
                      items: _statusItems.map((item) {
                        return DropdownMenuItem(
                          value: item['value'],
                          child: Text(item['label']!),
                        );
                      }).toList(),
                      onChanged: (val) {
                        if (val != null && val != order['status']) {
                          _updateStatus(order['_id'], val);
                        }
                      },
                    ),
                ),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }
}