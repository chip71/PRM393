import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  // THAY ĐỔI Ở ĐÂY: Dùng link Render bạn đã cấu hình trong server.js
  // Lưu ý dùng https để Android không chặn kết nối
  static const String baseUrl = "https://prm393.onrender.com";

  // Hàm test thử kết nối
  Future<void> checkServerStatus() async {
    try {
      // Thêm /api nếu các route của bạn nằm trong router api
      final response = await http.get(Uri.parse('$baseUrl/'));
      
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        print("✅ Kết nối Backend ONLINE thành công: ${data['message']}");
      } else {
        print("❌ Lỗi Server: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Lỗi kết nối: Hãy kiểm tra Internet hoặc link Render!");
      print("Chi tiết lỗi: $e");
    }
  }
}