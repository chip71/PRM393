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
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.black),
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.white,
      ),
      // Luôn bắt đầu từ '/', logic onGenerateRoute sẽ quyết định nơi đi tiếp
      initialRoute: '/',
      onGenerateRoute: (settings) {
        final auth = Provider.of<AuthProvider>(context, listen: false);
        final bool isLoggedIn = auth.user != null;
        final bool isAdmin = auth.isAdmin;

        // --- 🛡️ PHÂN NHÓM ROUTES ---
        final adminRoutes = [
          '/admin-dashboard',
          '/manage-albums',
          '/manage-artists',
          '/manage-genres',
          '/manage-orders',
          '/manage-users',
        ];

        final guestRoutes = ['/login', '/register'];

        // --- 🔒 LOGIC CHẶN TRUY CẬP (PROTECTION GUARD) ---

        // 1. Nếu là ADMIN: Chặn tuyệt đối không cho vào các trang User/Guest
        // Khi refresh hoặc điều hướng, nếu không thuộc danh sách adminRoutes thì đẩy về Dashboard
        if (isAdmin && !adminRoutes.contains(settings.name)) {
          return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());
        }

        // 2. Nếu là USER (không phải Admin): Chặn vào trang Admin
        if (isLoggedIn && !isAdmin && adminRoutes.contains(settings.name)) {
          return MaterialPageRoute(
            builder: (_) => const AccessDeniedScreen(message: "Admin Rights Required"),
          );
        }

        // 3. Chặn người đã đăng nhập (User/Admin) vào lại trang Login/Register
        if (isLoggedIn && guestRoutes.contains(settings.name)) {
          return MaterialPageRoute(
            builder: (_) => isAdmin ? const AdminDashboardScreen() : const MainTabs(),
          );
        }

        // --- 🚀 KHAI BÁO CÁC TUYẾN ĐƯỜNG (ROUTES DEFINITION) ---
        switch (settings.name) {
          case '/':
            return MaterialPageRoute(
              builder: (_) => isAdmin ? const AdminDashboardScreen() : const MainTabs(),
            );

          case '/album-detail':
            final args = settings.arguments as String;
            return MaterialPageRoute(builder: (_) => AlbumDetailScreen(albumId: args));

          case '/artist-detail':
            final args = settings.arguments as String;
            return MaterialPageRoute(builder: (_) => ArtistDetailScreen(artistId: args));

          case '/genre-detail':
            final args = settings.arguments as Map<String, dynamic>;
            return MaterialPageRoute(
              builder: (_) => GenreDetailScreen(genreId: args['id'], genreName: args['name']),
            );

          case '/login':
            return MaterialPageRoute(builder: (_) => const LoginScreen());
          
          case '/register':
            return MaterialPageRoute(builder: (_) => const RegisterScreen());

          case '/edit-profile':
            return MaterialPageRoute(builder: (_) => const EditProfileScreen());

          case '/change-password':
            return MaterialPageRoute(builder: (_) => const ChangePasswordScreen());

          case '/cart':
            return MaterialPageRoute(builder: (_) => const CartScreen());

          case '/checkout':
            return MaterialPageRoute(builder: (_) => const CheckoutScreen());

          case '/order-history':
            return MaterialPageRoute(builder: (_) => const OrderHistoryScreen());

          case '/order-detail':
            final args = settings.arguments;
            return MaterialPageRoute(builder: (_) => OrderDetailScreen(order: args));

          // --- ADMIN ROUTES ---
          case '/admin-dashboard':
            return MaterialPageRoute(builder: (_) => const AdminDashboardScreen());

          case '/manage-albums':
            return MaterialPageRoute(builder: (_) => const ManageAlbumsScreen());

          case '/manage-artists':
            return MaterialPageRoute(builder: (_) => const ManageArtistsScreen());

          case '/manage-genres':
            return MaterialPageRoute(builder: (_) => const ManageGenresScreen());

          case '/manage-orders':
            return MaterialPageRoute(builder: (_) => const ManageOrdersScreen());

          case '/manage-users':
            return MaterialPageRoute(builder: (_) => const ManageUsersScreen());

          default:
            return MaterialPageRoute(
              builder: (_) => isAdmin ? const AdminDashboardScreen() : const MainTabs(),
            );
        }
      },
    );
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