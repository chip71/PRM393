import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  Map<String, dynamic>? _user;
  List<dynamic> _cart = [];
  bool _isInitialized = false; // Cờ hiệu xác định đã load xong dữ liệu từ bộ nhớ
  final String apiUrl = "https://prm393.onrender.com";

  // --- 🔍 GETTERS ---
  Map<String, dynamic>? get user => _user;
  List<dynamic> get cart => _cart;
  
  // Getter quan trọng để tránh chuyển trang sai khi Refresh trình duyệt
  bool get isInitialized => _isInitialized; 
  
  // Phân quyền dựa trên vai trò
  bool get isAdmin => _user != null && _user!['role'] == 'admin';
  bool get isUser => _user != null && (_user!['role'] == 'user' || _user!['role'] == 'customer');
  bool get isAuthenticated => _user != null;

  AuthProvider() {
    _loadData();
  }

  // Tải dữ liệu từ SharedPreferences khi khởi tạo ứng dụng
  Future<void> _loadData() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedUser = prefs.getString('user');
      final savedCart = prefs.getString('cart');

      if (savedUser != null) {
        _user = json.decode(savedUser);
      }
      if (savedCart != null) {
        _cart = json.decode(savedCart);
      }
    } catch (e) {
      debugPrint("Load Data Error: $e");
    } finally {
      // Đánh dấu đã hoàn tất khởi tạo dù có lỗi hay không
      // notifyListeners() ở đây sẽ báo cho Consumer ở main.dart ngừng hiển thị Loading
      _isInitialized = true; 
      notifyListeners();
    }
  }

  // --- 🔐 XÁC THỰC (AUTHENTICATION) ---

  Future<Map<String, dynamic>> login(String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/api/auth/login'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'email': email, 'password': password}),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        _user = data;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(_user));
        notifyListeners();
        return {'success': true};
      }
      return {'success': false, 'message': data['message'] ?? 'Login failed'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  Future<Map<String, dynamic>> register(String name, String email, String password) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'email': email, 'password': password}),
      );
      final data = json.decode(response.body);
      if (response.statusCode == 201) {
        _user = data;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(_user));
        notifyListeners();
        return {'success': true};
      }
      return {'success': false, 'message': data['message'] ?? 'Registration failed'};
    } catch (e) {
      return {'success': false, 'message': 'Cannot connect to server'};
    }
  }

  Future<void> logout() async {
    _user = null;
    _cart = [];
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('user');
    await prefs.remove('cart');
    notifyListeners();
  }

  // --- 👤 QUẢN LÝ TÀI KHOẢN ---

  Future<bool> updateProfile(String newName) async {
    try {
      if (_user == null) return false;
      final String userId = _user!['_id'];

      final response = await http.put(
        Uri.parse("$apiUrl/api/users/$userId"), 
        headers: {"Content-Type": "application/json"},
        body: json.encode({"name": newName}),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        _user!['name'] = responseData['name'];
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(_user));
        notifyListeners(); 
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Update Profile Error: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> changePassword(String currentPassword, String newPassword) async {
    try {
      if (_user == null) return {'success': false, 'message': 'User not found'};
      final String userId = _user!['_id'];

      final response = await http.put(
        Uri.parse("$apiUrl/api/admin/users/$userId/password"), 
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "currentPassword": currentPassword,
          "newPassword": newPassword,
        }),
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {'success': true, 'message': data['message']};
      }
      return {'success': false, 'message': data['message'] ?? 'Failed to update password'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // --- 📦 QUẢN LÝ ĐƠN HÀNG & GIAO DỊCH ---

  Future<List<dynamic>> fetchOrderHistory() async {
    try {
      if (_user == null) return [];
      final String userId = _user!['_id'];

      final response = await http.get(
        Uri.parse("$apiUrl/api/users/$userId/orders"),
        headers: {"Content-Type": "application/json"},
      );

      if (response.statusCode == 200) {
        List<dynamic> orders = json.decode(response.body);
        // Sắp xếp đơn hàng mới nhất lên trên đầu
        orders.sort((a, b) => DateTime.parse(b['orderDate']).compareTo(DateTime.parse(a['orderDate'])));
        return orders;
      }
      return [];
    } catch (e) {
      return [];
    }
  }

  Future<Map<String, dynamic>> cancelOrder(String orderId) async {
    try {
      final response = await http.put(
        Uri.parse("$apiUrl/api/orders/$orderId/cancel"),
        headers: {"Content-Type": "application/json"},
      );

      final data = json.decode(response.body);
      if (response.statusCode == 200) {
        return {
          'success': true, 
          'message': data['message'] ?? 'Order cancelled successfully',
          'order': data['order']
        };
      }
      return {'success': false, 'message': data['message'] ?? 'Failed to cancel order'};
    } catch (e) {
      return {'success': false, 'message': 'Connection error'};
    }
  }

  // --- 🛒 GIỎ HÀNG (CART) ---

  void addToCart(Map<String, dynamic> itemData) {
    final id = itemData['_id'] ?? itemData['albumId'];
    final price = itemData['price'] ?? itemData['pricePerUnit'];
    final existingIndex = _cart.indexWhere((item) => item['albumId'] == id);

    if (existingIndex >= 0) {
      _cart[existingIndex]['quantity'] += 1;
    } else {
      _cart.add({
        'albumId': id,
        'name': itemData['name'],
        'sku': itemData['sku'],
        'pricePerUnit': price,
        'image': itemData['image'],
        'quantity': 1,
      });
    }
    _saveCart();
    notifyListeners();
  }

  void decrementItem(String albumId) {
    final index = _cart.indexWhere((item) => item['albumId'] == albumId);
    if (index >= 0) {
      if (_cart[index]['quantity'] > 1) {
        _cart[index]['quantity'] -= 1;
      } else {
        _cart.removeAt(index);
      }
      _saveCart();
      notifyListeners();
    }
  }

  void removeFromCart(String albumId) {
    _cart.removeWhere((item) => item['albumId'] == albumId);
    _saveCart();
    notifyListeners();
  }

  void clearCart() {
    _cart = [];
    _saveCart();
    notifyListeners();
  }

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cart', json.encode(_cart));
  }
}