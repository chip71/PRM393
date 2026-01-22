import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  // Giả lập trạng thái đăng nhập (Sau này sẽ thay bằng AuthProvider)
  bool isLoggedIn = false;
  Map<String, String>? user = {
    "name": "User Name",
    "email": "user@example.com",
    "role": "customer"
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: isLoggedIn ? _buildLoggedInView() : _buildLoggedOutView(),
      ),
    );
  }

  // --- 1. GIAO DIỆN KHI ĐÃ ĐĂNG NHẬP ---
  Widget _buildLoggedInView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("MUSICX", style: TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
          const SizedBox(height: 20),
          const Text("👋 Welcome,", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w600, color: Colors.black54)),
          Text(user?['name'] ?? '', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold)),
          Text(user?['email'] ?? '', style: const TextStyle(fontSize: 16, color: Colors.grey)),
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
          
          // Nút Logout
          _profileButton(Icons.logout, "Logout", () {
            setState(() => isLoggedIn = false);
          }, isLogout: true),
        ],
      ),
    );
  }

  // --- 2. GIAO DIỆN KHI CHƯA ĐĂNG NHẬP ---
  Widget _buildLoggedOutView() {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text("MUSICX", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          const Text("My Profile", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
          const SizedBox(height: 15),
          const Text(
            "Please sign in or create an account to view your profile and orders.",
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
          ),
          const SizedBox(height: 30),
          
          // Nút Sign In
          ElevatedButton(
            onPressed: () => setState(() => isLoggedIn = true), // Demo: nhấn để login
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.black,
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Sign In", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
          
          const SizedBox(height: 15),
          
          // Nút Create Account
          OutlinedButton(
            onPressed: () => Navigator.pushNamed(context, '/register'),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: Colors.black, width: 2),
              minimumSize: const Size(double.infinity, 55),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            child: const Text("Create Account", style: TextStyle(color: Colors.black, fontSize: 18, fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  // Widget con tạo các dòng menu
  Widget _profileButton(IconData icon, String label, VoidCallback onTap, {bool isLogout = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 15),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
          decoration: BoxDecoration(
            color: isLogout ? Colors.transparent : Colors.grey[100],
            borderRadius: BorderRadius.circular(8),
            border: isLogout ? Border.all(color: Colors.red, width: 1.5) : null,
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: isLogout ? Colors.red : Colors.black87),
              const SizedBox(width: 12),
              Text(
                label,
                style: TextStyle(
                  fontSize: 16, 
                  fontWeight: FontWeight.w500, 
                  color: isLogout ? Colors.red : Colors.black87
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}