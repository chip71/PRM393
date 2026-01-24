import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/navbar.dart';
import '../widgets/wave_painter.dart'; // Đảm bảo bạn đã tạo file này trong thư mục widgets

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

  // Danh sách màu sắc cho các thẻ
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
    // Khởi tạo controller cho hiệu ứng sóng chạy vô tận
    _waveController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4), // Tốc độ sóng (càng lớn càng chậm)
    )..repeat();
    _fetchGenres();
  }

  @override
  void dispose() {
    _waveController.dispose();
    super.dispose();
  }

  Future<void> _fetchGenres() async {
    try {
      final response = await http.get(
        Uri.parse('https://prm393-1.onrender.com/api/genres'),
      );
      if (response.statusCode == 200) {
        setState(() {
          genres = json.decode(response.body);
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        isLoading = false;
        // Bạn có thể xử lý hiển thị lỗi ở đây
      });
    }
  }

  // Logic lọc thể loại dựa trên thanh tìm kiếm
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
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            // Thanh Navbar tích hợp tìm kiếm
            Navbar(
              searchText: searchText,
              setSearchText: (val) => setState(() => searchText = val),
              showSearch: true,
            ),

            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  "Duyệt tìm tất cả",
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            Expanded(
              child: isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                  : _buildGenreGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreGrid() {
    final list = _filteredGenres;

    if (list.isEmpty) {
      return const Center(child: Text("Không tìm thấy thể loại nào."));
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2, // 2 cột giống Spotify
        childAspectRatio: 1.6, // Tỷ lệ thẻ hình chữ nhật
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final genre = list[index];
        final baseColor = cardColors[index % cardColors.length];

        return GestureDetector(
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
                  blurRadius: 8,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias, // Quan trọng: Cắt phần sóng thừa
            child: Stack(
              children: [
                // Vẽ hiệu ứng sóng chuyển động
                AnimatedBuilder(
                  animation: _waveController,
                  builder: (context, child) {
                    return CustomPaint(
                      size: Size.infinite,
                      painter: WavePainter(
                        animationValue: _waveController.value,
                        color: Colors.white,
                      ),
                    );
                  },
                ),

                // Tên thể loại hiển thị phía trên
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    genre['name'],
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      shadows: [
                        Shadow(
                          color: Colors.black26,
                          blurRadius: 4,
                          offset: Offset(1, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
