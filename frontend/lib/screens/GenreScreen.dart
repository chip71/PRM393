import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/navbar.dart';
import '../widgets/wave_painter.dart';

class GenreScreen extends StatefulWidget {
  const GenreScreen({super.key});

  @override
  State<GenreScreen> createState() => _GenreScreenState();
}

class _GenreScreenState extends State<GenreScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _waveController;
  List<dynamic> genres = [];
  bool isLoading = true;
  String searchText = "";

  final List<Color> cardColors = [
    Colors.purple,
    Colors.blue,
    Colors.orange,
    Colors.pink,
    Colors.teal,
    Colors.indigo,
    Colors.redAccent,
    Colors.deepOrange,
  ];

  @override
  void initState() {
    super.initState();
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _fetchGenres();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _fetchGenres() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final response = await http.get(
        Uri.parse('${auth.apiUrl}/api/genres'),
      );
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            genres = json.decode(response.body);
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _filteredGenres {
    if (searchText.trim().isEmpty) return genres;
    return genres
        .where(
          (g) => g['name'].toString().toLowerCase().contains(
                searchText.toLowerCase(),
              ),
        )
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    // Xác định kích thước màn hình
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 900;
    
    // Tính toán số cột dựa trên chiều rộng màn hình
    int crossAxisCount = isDesktop ? (screenWidth ~/ 250) : 2;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Navbar(
              searchText: searchText,
              setSearchText: (val) => setState(() => searchText = val),
              showSearch: true,
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 24, 10),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "All Genres",
                  style: TextStyle(
                    fontSize: isDesktop ? 28 : 22, 
                    fontWeight: FontWeight.bold
                  ),
                ),
              ),
            ),

            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                  : _buildGenreGrid(crossAxisCount, isDesktop),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreGrid(int crossAxisCount, bool isDesktop) {
    final list = _filteredGenres;

    if (list.isEmpty) {
      return const Center(child: Text("Không tìm thấy thể loại nào."));
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: isDesktop ? 2.0 : 1.6,
        mainAxisSpacing: 20,
        crossAxisSpacing: 20,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final genre = list[index];
        final baseColor = cardColors[index % cardColors.length];

        return MouseRegion(
          cursor: SystemMouseCursors.click, // Hiệu ứng bàn tay trên Desktop
          child: GestureDetector(
            onTap: () {
              Navigator.pushNamed(
                context,
                '/genre-detail',
                arguments: {
                  'id': genre['_id'].toString(),
                  'name': genre['name'] ?? 'Genre',
                },
              );
            },
            child: Container(
              decoration: BoxDecoration(
                color: baseColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: baseColor.withOpacity(0.3),
                    blurRadius: 12,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              clipBehavior: Clip.antiAlias,
              child: Stack(
                children: [
                  AnimatedBuilder(
                    animation: _waveController,
                    builder: (context, child) {
                      return CustomPaint(
                        size: Size.infinite,
                        painter: WavePainter(
                          animationValue: _waveController.value,
                          color: Colors.white.withOpacity(0.15), // Giảm độ đậm sóng để text rõ hơn
                        ),
                      );
                    },
                  ),
                  Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Align(
                      alignment: isDesktop ? Alignment.center : Alignment.topLeft,
                      child: Text(
                        genre['name'],
                        textAlign: isDesktop ? TextAlign.center : TextAlign.left,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: isDesktop ? 22 : 18,
                          fontWeight: FontWeight.bold,
                          shadows: const [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(1, 1),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}