import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class AuthProvider with ChangeNotifier {
  Map<String, dynamic>? _user;
  List<dynamic> _cart = [];
  final String apiUrl = "https://musicx-mobile-backend.onrender.com";

  // Getters
  Map<String, dynamic>? get user => _user;
  List<dynamic> get cart => _cart;

  bool get isAdmin => _user != null && _user!['role'] == 'admin';

  AuthProvider() {
    _loadData();
  }

  Future<void> _loadData() async {
    final prefs = await SharedPreferences.getInstance();
    final savedUser = prefs.getString('user');
    final savedCart = prefs.getString('cart');

    if (savedUser != null) _user = json.decode(savedUser);
    if (savedCart != null) _cart = json.decode(savedCart);
    notifyListeners();
  }

  // ✅ Cập nhật Login: Thêm lưu vào SharedPreferences
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
        
        // Lưu dữ liệu user vào bộ nhớ máy để duy trì đăng nhập
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

  // ✅ Thêm phương thức Update Profile
  Future<bool> updateProfile(String newName) async {
    try {
      if (_user == null) return false;

      final response = await http.put(
        Uri.parse("$apiUrl/api/users/profile"),
        headers: {"Content-Type": "application/json"},
        body: json.encode({
          "name": newName,
          "userId": _user!['_id'], // Gửi userId tương tự logic JS của bạn
        }),
      );

      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        
        // 1. Cập nhật dữ liệu trong bộ nhớ (Memory)
        _user!['name'] = responseData['name'];
        
        // 2. Cập nhật dữ liệu trong bộ nhớ máy (SharedPreferences)
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(_user));
        
        // 3. Thông báo cho UI (EditProfileScreen) để gấu gật đầu và hiện tên mới
        notifyListeners(); 
        return true;
      }
      return false;
    } catch (e) {
      debugPrint("Update Profile Error: $e");
      return false;
    }
  }

  Future<Map<String, dynamic>> register(
    String name,
    String email,
    String password,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('$apiUrl/api/auth/register'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({'name': name, 'email': email, 'password': password}),
      );

      final responseData = json.decode(response.body);

      if (response.statusCode == 201) {
        _user = responseData;
        final prefs = await SharedPreferences.getInstance();
        await prefs.setString('user', json.encode(_user));
        notifyListeners();
        return {'success': true};
      } else {
        return {
          'success': false,
          'message': responseData['message'] ?? 'Registration failed',
        };
      }
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

  // --- Cart Functions ---
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

  Future<void> _saveCart() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('cart', json.encode(_cart));
  }
}