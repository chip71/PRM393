import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
// Providers
import 'providers/auth_provider.dart';
// Core Screens
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
import 'screens/EditProfileScreen.dart';
import 'screens/ChangePasswordScreen.dart';
import 'screens/CartScreen.dart';
import 'screens/CheckoutScreen.dart';
import 'screens/OrderHistoryScreen.dart';
import 'screens/OrderDetailScreen.dart';

// Admin Screens
import 'screens/admin/AdminDashboardScreen.dart';
import 'screens/admin/ManageAlbumsScreen.dart';
import 'screens/admin/ManageArtistsScreen.dart';
import 'screens/admin/ManageGenresScreen.dart';
import 'screens/admin/ManageOrdersScreen.dart';
import 'screens/admin/ManageUsersScreen.dart';
import 'screens/admin/AdminCommentsScreen.dart';

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
    // SỬ DỤNG CONSUMER ĐỂ LẮNG NGHE BIẾN ISINITIALIZED TỪ AUTHPROVIDER
    return Consumer<AuthProvider>(
      builder: (context, auth, child) {
        return MaterialApp(
          title: 'MusicX',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
            useMaterial3: true,
            scaffoldBackgroundColor: Colors.white,
          ),
          // QUAN TRỌNG: Nếu chưa load xong dữ liệu, hiển thị vòng xoay tại home
          home: !auth.isInitialized 
              ? const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.black)))
              : (auth.isAdmin ? const AdminDashboardScreen() : const MainTabs()),
          
          onGenerateRoute: (settings) => _onGenerateAppRoute(settings, auth),
        );
      },
    );
  }

  // Tách logic Route Guard ra hàm riêng để code sạch hơn
  Route<dynamic> _onGenerateAppRoute(RouteSettings settings, AuthProvider auth) {
    final bool isAdmin = auth.isAdmin;
    final bool isLoggedIn = auth.isAuthenticated;

    // --- 🛡️ PHÂN NHÓM ROUTES ---
    final adminRoutes = [
      '/admin-dashboard',
      '/manage-albums',
      '/manage-artists',
      '/manage-genres',
      '/manage-orders',
      '/admin-comments',
      '/manage-users',
    ];
    
    final guestRoutes = ['/login', '/register'];

    // --- 🔒 LOGIC BẢO VỆ ĐỊNH TUYẾN (ROUTE GUARD) ---
    
    // 1. Nếu là ADMIN: CHẶN TUYỆT ĐỐI các trang của User thường
    if (isAdmin && !adminRoutes.contains(settings.name) && !guestRoutes.contains(settings.name) && settings.name != '/') {
      return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());
    }

    // 2. Nếu là USER thường: Chặn vào trang Admin
    if (isLoggedIn && !isAdmin && adminRoutes.contains(settings.name)) {
      return MaterialPageRoute(
        builder: (_) => const AccessDeniedScreen(message: "Admin Rights Required"),
      );
    }

    // 3. Chặn người đã đăng nhập vào lại Login/Register
    if (isLoggedIn && guestRoutes.contains(settings.name)) {
      return MaterialPageRoute(
        builder: (_) => isAdmin ? const AdminDashboardScreen() : const MainTabs(),
      );
    }

    // --- 🚀 KHAI BÁO CÁC TUYẾN ĐƯỜNG ---
    switch (settings.name) {
      case '/':
        return MaterialPageRoute(
          builder: (_) => isAdmin ? const AdminDashboardScreen() : const MainTabs(),
        );

      case '/album-detail':
        final args = settings.arguments as String;
        return MaterialPageRoute(builder: (context) => AlbumDetailScreen(albumId: args));

      case '/artist-detail':
        final args = settings.arguments as String;
        return MaterialPageRoute(builder: (context) => ArtistDetailScreen(artistId: args));

      case '/genre-detail':
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (context) => GenreDetailScreen(genreId: args['id'], genreName: args['name']),
        );

      case '/login':
        return MaterialPageRoute(builder: (context) => const LoginScreen());
      
      case '/register':
        return MaterialPageRoute(builder: (context) => const RegisterScreen());

      case '/edit-profile':
        return MaterialPageRoute(builder: (context) => const EditProfileScreen());

      case '/change-password':
        return MaterialPageRoute(builder: (context) => const ChangePasswordScreen());

      case '/cart':
        return MaterialPageRoute(builder: (context) => const CartScreen());

      case '/checkout':
        return MaterialPageRoute(builder: (context) => const CheckoutScreen());

      case '/order-history':
        return MaterialPageRoute(builder: (context) => const OrderHistoryScreen());

      case '/order-detail':
        final args = settings.arguments;
        return MaterialPageRoute(builder: (context) => OrderDetailScreen(order: args));

      // --- 🧠 ADMIN ROUTES ---
      case '/admin-dashboard':
        return MaterialPageRoute(builder: (context) => const AdminDashboardScreen());

      case '/manage-albums':
        return MaterialPageRoute(builder: (context) => const ManageAlbumsScreen());

      case '/manage-artists':
        return MaterialPageRoute(builder: (context) => const ManageArtistsScreen());

      case '/manage-genres':
        return MaterialPageRoute(builder: (context) => const ManageGenresScreen());

      case '/manage-orders':
        return MaterialPageRoute(builder: (context) => const ManageOrdersScreen());

      case '/manage-users':
        return MaterialPageRoute(builder: (context) => const ManageUsersScreen());

      case '/admin-comments':
        return MaterialPageRoute(builder: (context) => const AdminCommentsScreen());

      default:
        return MaterialPageRoute(
          builder: (_) => isAdmin ? const AdminDashboardScreen() : const MainTabs(),
        );
    }
  }
}

// --- 🚫 MÀN HÌNH BÁO LỖI QUYỀN TRUY CẬP ---
class AccessDeniedScreen extends StatelessWidget {
  final String message;
  const AccessDeniedScreen({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.lock_person_outlined, size: 100, color: Colors.black),
              const SizedBox(height: 20),
              Text(
                message,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 10),
              const Text(
                "You do not have permission to view this page.",
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.grey),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: () => Navigator.pushReplacementNamed(context, '/'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(200, 50),
                ),
                child: const Text("Return Home", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ... Giữ nguyên class MainTabs ...
class MainTabs extends StatefulWidget {
  const MainTabs({super.key});

  @override
  State<MainTabs> createState() => _MainTabsState();
}

class _MainTabsState extends State<MainTabs> {
  int _selectedIndex = 0;

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
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: BottomNavigationBar(
        type: BottomNavigationBarType.fixed, 
        backgroundColor: Colors.black,
        selectedItemColor: Colors.white,
        unselectedItemColor: Colors.grey, 
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