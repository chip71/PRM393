import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/navbar.dart'; // Giả sử bạn lưu file navbar tại thư mục widgets

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Biến để quản lý trạng thái tìm kiếm (nếu cần dùng trong tương lai)
  String _searchText = "";

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final bool isLoggedIn = auth.user != null;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // --- SỬ DỤNG NAVBAR TÙY CHỈNH CỦA BẠN ---
          Navbar(
            searchText: _searchText,
            setSearchText: (value) {
              setState(() {
                _searchText = value;
              });
              // Thực hiện logic tìm kiếm của bạn tại đây
            },
            showSearch: !isLoggedIn, // Ẩn search bar nếu đã login để giao diện Profile gọn hơn
          ),
          
          Expanded(
            child: SafeArea(
              top: false, // Tránh SafeArea đè lên Navbar vì Navbar đã có SafeArea bên trong
              child: isLoggedIn
                  ? _buildLoggedInView(auth)
                  : _buildLoggedOutView(),
            ),
          ),
        ],
      ),
    );
  }

  // --- GIAO DIỆN KHI ĐÃ ĐĂNG NHẬP ---
  Widget _buildLoggedInView(AuthProvider auth) {
    final user = auth.user;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          const Text("👋 Welcome,",
              style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: Colors.black54)),
          Text(user?['name'] ?? 'User',
              style:
                  const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Text(user?['email'] ?? '',
              style: const TextStyle(fontSize: 16, color: Colors.grey)),
          const SizedBox(height: 40),

          _profileButton(Icons.receipt_long_outlined, "View Order History", () {
            Navigator.pushNamed(context, '/order-history');
          }),
          _profileButton(Icons.edit_outlined, "Edit Profile", () {
            Navigator.pushNamed(context, '/edit-profile');
          }),
          _profileButton(Icons.lock_outline, "Change Password", () {
            Navigator.pushNamed(context, '/change-password');
          }),

          const Spacer(),

          _profileButton(Icons.logout, "Logout", () {
            auth.logout();
          }, isLogout: true),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // --- GIAO DIỆN KHI CHƯA ĐĂNG NHẬP ---
  Widget _buildLoggedOutView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.account_circle_outlined, size: 100, color: Colors.grey),
          const SizedBox(height: 20),
          const Text("My Profile",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 15),
          const Text(
            "Please sign in or create an account to view your profile and orders.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 30),
          ElevatedButton(
            onPressed: () => Navigator.pushNamed(context, '/login'),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
            child: const Text("Sign In",
                style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
          const SizedBox(height: 15),
          OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, '/register'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black, width: 2),
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(15)),
            ),
            child: const Text("Create Account",
                style: TextStyle(
                    color: Colors.black,
                    fontSize: 18,
                    fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Widget _profileButton(IconData icon, String label, VoidCallback onTap,
      {bool isLogout = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(15),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
          decoration: BoxDecoration(
            color: isLogout ? Colors.transparent : const Color(0xFFF5F5F5),
            borderRadius: BorderRadius.circular(15),
            border: isLogout ? Border.all(color: Colors.red, width: 1.5) : null,
          ),
          child: Row(
            children: [
              Icon(icon,
                  size: 22, color: isLogout ? Colors.red : Colors.black87),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: isLogout ? Colors.red : Colors.black87),
                ),
              ),
              if (!isLogout) const Icon(Icons.chevron_right, color: Colors.grey),
            ],
          ),
        ),
      ),
    );
  }
}