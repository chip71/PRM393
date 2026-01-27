import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/auth_provider.dart';

class CartScreen extends StatelessWidget {
  const CartScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Lắng nghe sự thay đổi từ AuthProvider
    final auth = Provider.of<AuthProvider>(context);
    final cart = auth.cart;
    final user = auth.user;

    // Tính tổng tiền dựa trên giá và số lượng trong giỏ hàng
    final double totalAmount = cart.fold(
      0,
      (sum, item) => sum + (item['pricePerUnit'] * item['quantity']),
    );

    // Điều hướng sang Checkout hoặc yêu cầu đăng nhập
    void handleCheckout() {
      if (user == null) {
        showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Please Log In'),
            content: const Text(
              'You must be logged in to proceed to checkout.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
              ),
              TextButton(
                onPressed: () {
                  Navigator.pop(ctx);
                  Navigator.pushNamed(context, '/login');
                },
                child: const Text(
                  'Log In',
                  style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        );
      } else {
        Navigator.pushNamed(context, '/checkout');
      }
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          "My Cart",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        centerTitle: false,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: cart.isEmpty
          ? _buildEmptyCart()
          : Column(
              children: [
                Expanded(
                  child: ListView.builder(
                    itemCount: cart.length,
                    itemBuilder: (ctx, i) => _CartItemWidget(item: cart[i]),
                  ),
                ),
                _buildFooter(context, totalAmount, user, handleCheckout),
              ],
            ),
    );
  }

  // Giao diện khi giỏ hàng trống
  Widget _buildEmptyCart() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.shopping_cart_outlined, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 10),
          const Text(
            "Your cart is empty.",
            style: TextStyle(fontSize: 18, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // Phần tóm tắt tổng tiền và nút thanh toán
  Widget _buildFooter(
    BuildContext context,
    double total,
    dynamic user,
    VoidCallback onCheckout,
  ) {
    final currencyFormat = NumberFormat("#,###", "en_US");

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: Colors.grey[200]!)),
        boxShadow: [
          BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, -5))
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Total", style: TextStyle(fontSize: 18, color: Colors.grey)),
              Text(
                "${currencyFormat.format(total)} VND",
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const SizedBox(height: 15),
          ElevatedButton(
            onPressed: onCheckout,
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              elevation: 0,
            ),
            child: const Text(
              "Proceed to Checkout",
              style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
            ),
          ),
          if (user == null) ...[
            const SizedBox(height: 10),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/login'),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: Colors.black),
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              child: const Text(
                "Sign In Now",
                style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CartItemWidget extends StatelessWidget {
  final dynamic item;
  const _CartItemWidget({required this.item});

  @override
  Widget build(BuildContext context) {
    // Sử dụng listen: false vì chúng ta chỉ gọi hàm, không cần rebuild Widget này từ đây
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final currencyFormat = NumberFormat("#,###", "en_US");

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: Colors.grey[100]!)),
      ),
      child: Row(
        children: [
          // Ảnh Album
          ClipRRect(
            borderRadius: BorderRadius.circular(8),
            child: Image.network(
              item['image'],
              width: 80,
              height: 80,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) => 
                Container(width: 80, height: 80, color: Colors.grey[200], child: const Icon(Icons.broken_image)),
            ),
          ),
          const SizedBox(width: 15),
          // Thông tin tên và giá
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item['name'],
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  "${currencyFormat.format(item['pricePerUnit'])} VND",
                  style: const TextStyle(color: Colors.grey, fontSize: 14),
                ),
                const SizedBox(height: 8),
                // Bộ điều khiển số lượng (Tăng/Giảm)
                Row(
                  children: [
                    _qtyButton(
                      Icons.remove,
                      () => auth.decrementItem(item['albumId']),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 15),
                      child: Text(
                        "${item['quantity']}",
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                    ),
                    _qtyButton(
                      Icons.add,
                      () => auth.addToCart(item),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // Nút Xóa sản phẩm khỏi giỏ
          IconButton(
            icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
            onPressed: () => auth.removeFromCart(item['albumId']),
          ),
        ],
      ),
    );
  }

  // Widget dùng chung cho nút + và -
  Widget _qtyButton(IconData icon, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey[300]!),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Icon(icon, size: 18, color: Colors.black),
      ),
    );
  }
}