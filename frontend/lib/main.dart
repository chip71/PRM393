import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Import Providers
import 'providers/auth_provider.dart';
// Import Screens
import 'screens/HomeScreen.dart';
import 'screens/AlbumScreen.dart';
import 'screens/ArtistScreen.dart';
import 'screens/GenreScreen.dart';
import 'screens/ProfileScreen.dart';
import 'screens/AlbumDetailScreen.dart';
import 'screens/ArtistDetailScreen.dart';
import 'screens/GenreDetailScreen.dart';
import 'screens/LoginScreen.dart';
import 'screens/RegisterScreen.dart';
import 'screens/EditProfileScreen.dart'; // THÊM IMPORT MỚI

void main() {
  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => AuthProvider()),
      ],
      child: const MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'MusicX',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        // Cấu hình SeedColor màu đen và Material3
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white, // Nền trắng cho toàn bộ ứng dụng
      ),
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (context) => const MainTabs());
        }

        // --- Album Detail Route ---
        if (settings.name == '/album-detail') {
          final args = settings.arguments;
          if (args is String) {
            return MaterialPageRoute(
              builder: (context) => AlbumDetailScreen(albumId: args),
            );
          }
        }

        // --- Artist Detail Route ---
        if (settings.name == '/artist-detail') {
          final args = settings.arguments;
          if (args is String) {
            return MaterialPageRoute(
              builder: (context) => ArtistDetailScreen(artistId: args),
            );
          }
        }

        // --- Genre Detail Route ---
        if (settings.name == '/genre-detail') {
          final args = settings.arguments as Map<String, dynamic>;
          return MaterialPageRoute(
            builder: (context) => GenreDetailScreen(
              genreId: args['id'],
              genreName: args['name'],
            ),
          );
        }

        // --- Authentication Routes ---
        if (settings.name == '/login') {
          return MaterialPageRoute(builder: (context) => const LoginScreen());
        }
        
        if (settings.name == '/register') {
          return MaterialPageRoute(builder: (context) => const RegisterScreen());
        }

        // --- Profile & Edit Routes ---
        if (settings.name == '/edit-profile') { // THÊM ROUTE CHỈNH SỬA HỒ SƠ
          return MaterialPageRoute(builder: (context) => const EditProfileScreen());
        }

        // Mặc định quay về MainTabs nếu không tìm thấy route
        return MaterialPageRoute(builder: (context) => const MainTabs());
      },
    );
  }
}

class MainTabs extends StatefulWidget {
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _selectedIndex = 0;

  // Danh sách 5 màn hình chính sử dụng IndexedStack để giữ trạng thái
  final List<Widget> _screens = [
    const HomeScreen(),
    const AlbumScreen(),
    const ArtistScreen(),
    const GenreScreen(),
    const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Scaffold cung cấp Material ancestor cần thiết cho các TextField bên trong tab
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, 
        backgroundColor: Colors.black, // Thanh điều hướng màu đen
        selectedItemColor: Colors.white, // Item được chọn màu trắng
        unselectedItemColor: Colors.grey, // Item không chọn màu xám
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.explore_outlined), label: 'Explore'),
          BottomNavigationBarItem(icon: Icon(Icons.album_outlined), label: 'Album'),
          BottomNavigationBarItem(icon: Icon(Icons.mic_external_on_outlined), label: 'Artist'),
          BottomNavigationBarItem(icon: Icon(Icons.grid_view_outlined), label: 'Genre'),
          BottomNavigationBarItem(icon: Icon(Icons.person_outline), label: 'Profile'),
        ],
      ),
    );
  }
}