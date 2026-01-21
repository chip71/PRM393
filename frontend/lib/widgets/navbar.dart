import 'package:flutter/material.dart';

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
    return Container(
      color: Colors.white,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // --- Top Row: Logo + Icons ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Logo có tính năng Click để quay về Home
                  GestureDetector(
                    onTap: () {
                      // Kiểm tra nếu không phải đang ở trang chủ thì mới điều hướng
                      if (ModalRoute.of(context)?.settings.name != '/') {
                        Navigator.pushNamedAndRemoveUntil(context, '/', (route) => false);
                      }
                    },
                    child: const Text(
                      'MUSICX',
                      style: TextStyle(
                        color: Colors.black,
                        fontSize: 28,
                        fontWeight: FontWeight.w900,
                        letterSpacing: -1,
                      ),
                    ),
                  ),
                  
                  // Khu vực chứa các Icon (Cart, Profile...)
                  Row(
                    children: [
                      IconButton(
                        icon: const Icon(Icons.shopping_cart_outlined, color: Colors.black),
                        onPressed: () {
                          // Điều hướng sang trang Giỏ hàng khi bạn làm xong trang đó
                          // Navigator.pushNamed(context, '/cart');
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // --- Search Bar (Chỉ hiển thị khi showSearch = true) ---
            if (showSearch)
              Padding(
                padding: const EdgeInsets.fromLTRB(15, 0, 15, 10),
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: const Color(0xFFF2F2F2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      const Icon(Icons.search, size: 18, color: Color(0xFF555555)),
                      const SizedBox(width: 8),
                      Expanded(
                        child: TextField(
                          onChanged: setSearchText,
                          decoration: const InputDecoration(
                            hintText: "Search MusicX",
                            hintStyle: TextStyle(color: Color(0xFF888888), fontSize: 16),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                          style: const TextStyle(color: Colors.black, fontSize: 16),
                          textInputAction: TextInputAction.search,
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