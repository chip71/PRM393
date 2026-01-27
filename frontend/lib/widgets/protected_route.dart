import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ProtectedRoute extends StatelessWidget {
  final Widget child;
  final bool adminOnly;

  const ProtectedRoute({super.key, required this.child, this.adminOnly = false});

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    // 1. Nếu chưa đăng nhập -> Về trang Login
    if (auth.user == null) {
      return const Scaffold(body: Center(child: Text("Please login first.")));
    }

    // 2. Nếu là Admin-only route nhưng user không phải admin -> Chặn
    if (adminOnly && !auth.isAdmin) {
      return _errorPage("Access Denied: Admin only.");
    }

    // 3. Nếu là User-only route (mặc định) nhưng user lại là admin -> Chặn
    // Điều này ngăn Admin đi vào trang Checkout/Cart của User
    if (!adminOnly && auth.isAdmin) {
      return _errorPage("Admins must use the Dashboard.");
    }

    return child;
  }

  Widget _errorPage(String message) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.lock_person, size: 64, color: Colors.red),
            Text(message, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }
}