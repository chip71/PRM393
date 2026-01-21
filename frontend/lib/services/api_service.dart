import 'dart:convert';
import 'package:http/http.dart' as http;
import 'dart:io';

class ApiService {
  // 10.0.2.2 là địa chỉ đặc biệt để Android Emulator truy cập localhost máy tính
  // Nếu dùng Web/Windows/Linux, dùng localhost
  static String get baseUrl {
    if (Platform.isAndroid) return "http://10.0.2.2:9999";
    return "http://localhost:9999";
  }

  // Hàm test thử kết nối đến route '/' trong server.js của bạn
  Future<void> checkServerStatus() async {
    try {
      final response = await http.get(Uri.parse('$baseUrl/'));
      
      if (response.statusCode == 200) {
        var data = jsonDecode(response.body);
        print("✅ Kết nối Backend thành công: ${data['message']}");
      } else {
        print("❌ Lỗi Server: ${response.statusCode}");
      }
    } catch (e) {
      print("❌ Không thể kết nối tới Backend. Hãy chắc chắn Server đã chạy!");
      print("Chi tiết lỗi: $e");
    }
  }
}