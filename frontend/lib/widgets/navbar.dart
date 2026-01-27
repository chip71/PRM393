import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart'; // Thêm import Provider
import '../providers/auth_provider.dart'; // Thêm import AuthProvider

class Navbar extends StatelessWidget {
  final String searchText;
  final Function(String) setSearchText;
  final bool showSearch;

  const Navbar({
    super.key,
    required this.searchText,
    required this.setSearchText,
    this.showSearch = true,
  });

  @override
  Widget build(BuildContext context) {
    // Lắng nghe AuthProvider để lấy số lượng sản phẩm trong giỏ
    final authProvider = Provider.of<AuthProvider>(context);
    final int cartItemCount = authProvider.cart.length;

    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- Top Row: Logo + Cart ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  /// LOGO SVG
                  GestureDetector(
                    onTap: () {
                      if (ModalRoute.of(context)?.settings.name != '/') {
                        Navigator.pushNamedAndRemoveUntil(
                          context,
                          '/',
                          (route) => false,
                        );
                      }
                    },
                    child: SvgPicture.asset(
                      'assets/logo/musicx_logo.svg',
                      height: 36,
                    ),
                  ),

                  /// CART ICON WITH BADGE
                  Stack(
                    alignment: Alignment.center,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.shopping_cart_outlined,
                          color: Colors.black,
                          size: 28, // Tăng nhẹ kích thước cho cân đối
                        ),
                        onPressed: () {
                          // ✅ Kích hoạt điều hướng đến trang Giỏ hàng
                          Navigator.pushNamed(context, '/cart');
                        },
                      ),
                      // Hiển thị số lượng nếu giỏ hàng không trống
                      if (cartItemCount > 0)
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.all(2),
                            decoration: BoxDecoration(
                              color: Colors.red, // Màu đỏ nổi bật cho thông báo
                              borderRadius: BorderRadius.circular(10),
                            ),
                            constraints: const BoxConstraints(
                              minWidth: 16,
                              minHeight: 16,
                            ),
                            child: Text(
                              '$cartItemCount',
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            // --- Search Bar ---
            if (showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
                child: Container(
                  height: 42,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Row(
                    children: [
                      const Icon(Icons.search,
                          size: 20, color: Color(0xFF555555)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: setSearchText,
                          decoration: const InputDecoration(
                            hintText: "Search MusicX",
                            hintStyle: TextStyle(
                              color: Color(0xFF888888),
                              fontSize: 16,
                            ),
                            border: InputBorder.none,
                          ),
                          style: const TextStyle(
                            color: Colors.black,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}