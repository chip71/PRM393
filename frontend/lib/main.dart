import 'package:flutter/material.dart';
import 'screens/HomeScreen.dart';
import 'screens/AlbumDetailScreen.dart'; // Import trang detail
import 'screens/ArtistDetailScreen.dart';
void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MusicX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
      ),
      // Cách 1: Sử dụng bảng Routes (Đơn giản nhất)
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (context) => const HomeScreen());
        }

        if (settings.name == '/album-detail') {
          // Kiểm tra xem arguments có tồn tại không trước khi ép kiểu String
          final args = settings.arguments;

          if (args is String) {
            return MaterialPageRoute(
              builder: (context) => AlbumDetailScreen(albumId: args),
            );
          }

          // Nếu ID bị null, quay về trang Home hoặc hiển thị trang lỗi nhẹ
          return MaterialPageRoute(builder: (context) => const HomeScreen());
        }
        // Trong main.dart -> onGenerateRoute
        if (settings.name == '/artist-detail') {
          final String artistId = settings.arguments as String;
          return MaterialPageRoute(
            builder: (context) => ArtistDetailScreen(artistId: artistId),
          );
        }

        return null;
      },
    );
  }
}
