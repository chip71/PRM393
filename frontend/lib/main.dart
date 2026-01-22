import 'package:flutter/material.dart';
import 'screens/HomeScreen.dart';
import 'screens/AlbumScreen.dart';
// import 'screens/ArtistScreen.dart'; // Màn hình danh sách nghệ sĩ
// import 'screens/GenreScreen.dart';  // Màn hình thể loại
// import 'screens/ProfileScreen.dart';
import 'screens/AlbumDetailScreen.dart';
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
      initialRoute: '/',
      onGenerateRoute: (settings) {
        if (settings.name == '/') {
          return MaterialPageRoute(builder: (context) => const MainTabs());
        }

        // Route chi tiết Album
        if (settings.name == '/album-detail') {
          final args = settings.arguments;
          if (args is String) {
            return MaterialPageRoute(
              builder: (context) => AlbumDetailScreen(albumId: args),
            );
          }
        }

        // Route chi tiết Nghệ sĩ
        if (settings.name == '/artist-detail') {
          final args = settings.arguments;
          if (args is String) {
            return MaterialPageRoute(
              builder: (context) => ArtistDetailScreen(artistId: args),
            );
          }
        }

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

  // Cập nhật danh sách màn hình theo yêu cầu mới
  final List<Widget> _screens = [
    const HomeScreen(),
    const AlbumScreen(),
    // const ArtistScreen(), // Thay thế Cart
    // const GenreScreen(),  // Thêm mới Genre
    // const ProfileScreen(),
  ];

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, // Quan trọng khi có từ 4 tab trở lên
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey,
        currentIndex: _selectedIndex,
        onTap: _onItemTapped,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.search),
            label: 'Explore',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.album_outlined),
            label: 'Album',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.mic_external_on_outlined), // Icon cho Artist
            label: 'Artist',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.grid_view_outlined), // Icon cho Genre
            label: 'Genre',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}