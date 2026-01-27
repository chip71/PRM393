import 'package:flutter/material.dart';
import 'package:intl/intl.dart'; 
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class OrderHistoryScreen extends StatefulWidget {
  const OrderHistoryScreen({super.key});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  late Future<List<dynamic>> _ordersFuture;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  // Hàm tải dữ liệu đơn hàng
  void _loadOrders() {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    _ordersFuture = auth.fetchOrderHistory();
  }

  // Hàm xử lý khi người dùng kéo xuống để làm mới
  Future<void> _handleRefresh() async {
    setState(() {
      _loadOrders();
    });
    // Đợi cho đến khi Future hoàn thành để tắt vòng xoay loading
    await _ordersFuture;
  }

  String _formatDate(String dateString) {
    DateTime date = DateTime.parse(dateString);
    return DateFormat('MMM d, yyyy, HH:mm').format(date);
  }

  Color _getStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending': return const Color(0xFFFF960C);
      case 'pending_payment': return const Color(0xFFBF9F00);
      case 'shipped': return const Color(0xFF1E90FF);
      case 'delivered': return const Color(0xFF1DB954);
      case 'cancelled': return const Color(0xFFFF3B30);
      default: return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("My Orders", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      // Sử dụng RefreshIndicator bao bọc FutureBuilder hoặc ListView
      body: RefreshIndicator(
        color: Colors.black, // Màu của vòng xoay loading
        onRefresh: _handleRefresh, // Gọi hàm làm mới khi kéo xuống
        child: FutureBuilder<List<dynamic>>(
          future: _ordersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator(color: Colors.black));
            }

            if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
              // Để RefreshIndicator hoạt động khi danh sách trống, 
              // empty state cũng cần là một ListView hoặc ScrollView
              return SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Container(
                  height: MediaQuery.of(context).size.height * 0.7,
                  alignment: Alignment.center,
                  child: _buildEmptyState(),
                ),
              );
            }

            final orders = snapshot.data!;
            return ListView.builder(
              physics: const AlwaysScrollableScrollPhysics(), // Đảm bảo luôn kéo được ngay cả khi ít item
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) => _buildOrderCard(orders[index]),
            );
          },
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.receipt_long_outlined, size: 80, color: Colors.grey[300]),
        const SizedBox(height: 16),
        const Text("You haven't placed any orders yet.", style: TextStyle(color: Colors.grey, fontSize: 16)),
        const SizedBox(height: 8),
        const Text("Pull down to refresh", style: TextStyle(color: Colors.grey, fontSize: 12)),
      ],
    );
  }

  Widget _buildOrderCard(dynamic order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFF9F9F9),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFEEEEEE)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(order['orderId'] ?? 'ID N/A', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              Text(_formatDate(order['orderDate']), style: const TextStyle(color: Colors.grey, fontSize: 12)),
            ],
          ),
          const Divider(height: 24),
          ...(order['items'] as List).map((item) => Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: Text("• ${item['name']} (x${item['quantity']})", style: const TextStyle(color: Color(0xFF444444))),
          )),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _getStatusColor(order['status']),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  order['status'].toString().toUpperCase(),
                  style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold),
                ),
              ),
              Text(
                "${NumberFormat("#,###").format(order['totalAmount'])} ${order['currency']}",
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () {
              // Sau khi xem chi tiết và quay lại, tự động làm mới để cập nhật trạng thái nếu có thay đổi
              Navigator.pushNamed(context, '/order-detail', arguments: order)
                  .then((_) => _handleRefresh());
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 45),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("View Details", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}