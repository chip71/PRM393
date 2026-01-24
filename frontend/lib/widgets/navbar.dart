import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

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
                      height: 36, // 👈 chỉnh 38–40 nếu muốn nổi hơn
                    ),
                  ),

                  /// CART ICON
                  IconButton(
                    icon: const Icon(
                      Icons.shopping_cart_outlined,
                      color: Colors.black,
                    ),
                    onPressed: () {
                      // Navigator.pushNamed(context, '/cart');
                    },
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
