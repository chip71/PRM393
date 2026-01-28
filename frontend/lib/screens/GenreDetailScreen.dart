import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/navbar.dart';
import '../widgets/album_card.dart';

class GenreDetailScreen extends StatefulWidget {
  final String genreId;
  final String genreName;

  const GenreDetailScreen({super.key, required this.genreId, required this.genreName});

  @override
  State<GenreDetailScreen> createState() => _GenreDetailScreenState();
}

class _GenreDetailScreenState extends State<GenreDetailScreen> {
  List<dynamic> albums = [];
  List<dynamic> filteredAlbums = [];
  bool isLoading = true;
  String searchText = "";
  String sortOption = "name";

  @override
  void initState() {
    super.initState();
    _fetchAlbumsByGenre();
  }

  Future<void> _fetchAlbumsByGenre() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final response = await http.get(Uri.parse('${auth.apiUrl}/api/albums/genre/${widget.genreId}'));
      if (response.statusCode == 200) {
        if (mounted) {
          setState(() {
            albums = json.decode(response.body);
            filteredAlbums = albums;
            isLoading = false;
          });
          _applyFilters();
        }
      }
    } catch (e) {
      if (mounted) setState(() => isLoading = false);
    }
  }

  void _applyFilters() {
    List<dynamic> result = List.from(albums);

    if (searchText.trim().isNotEmpty) {
      result = result.where((a) => 
        a['name'].toString().toLowerCase().contains(searchText.toLowerCase())
      ).toList();
    }

    if (sortOption == "name") {
      result.sort((a, b) => a['name'].toString().compareTo(b['name'].toString()));
    } else if (sortOption == "priceAsc") {
      result.sort((a, b) => (a['price'] ?? 0).compareTo(b['price'] ?? 0));
    } else if (sortOption == "priceDesc") {
      result.sort((a, b) => (b['price'] ?? 0).compareTo(a['price'] ?? 0));
    }

    setState(() => filteredAlbums = result);
  }

  @override
  Widget build(BuildContext context) {
    // --- LOGIC RESPONSIVE ---
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 900;
    
    // Desktop sẽ bóp lề rộng hơn (15% mỗi bên), Mobile lề hẹp (20px)
    double sidePadding = isDesktop ? screenWidth * 0.15 : 20.0;
    
    // Tính toán số cột Album: Desktop (4-6 cột), Mobile (2 cột)
    int crossAxisCount = isDesktop ? (screenWidth ~/ 250).clamp(3, 8) : 2;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 1. Thanh tìm kiếm nằm trên cùng
            Navbar(
              searchText: searchText,
              setSearchText: (val) {
                setState(() => searchText = val);
                _applyFilters();
              },
              showSearch: true,
            ),

            // 2. Nội dung chính (Sắp xếp + Tên Genre + Grid)
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: EdgeInsets.symmetric(horizontal: sidePadding),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      // Thanh sắp xếp (Sort Bar)
                      _buildSortBar(),

                      // Tên Genre
                      Padding(
                        padding: const EdgeInsets.fromLTRB(0, 20, 0, 15),
                        child: Text(
                          widget.genreName,
                          style: TextStyle(
                            fontSize: isDesktop ? 36 : 28, 
                            fontWeight: FontWeight.bold, 
                            color: Colors.black,
                            letterSpacing: -0.5
                          ),
                        ),
                      ),

                      // Danh sách Album
                      isLoading
                          ? const Center(
                              child: Padding(
                                padding: EdgeInsets.only(top: 50),
                                child: CircularProgressIndicator(color: Colors.black),
                              ),
                            )
                          : _buildAlbumGrid(crossAxisCount, isDesktop),
                      
                      const SizedBox(height: 50),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortBar() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          _sortChip("Sort by name", "name"),
          const SizedBox(width: 8),
          _sortChip("Low-High", "priceAsc"),
          const SizedBox(width: 8),
          _sortChip("High-Low", "priceDesc"),
        ],
      ),
    );
  }

  Widget _sortChip(String label, String value) {
    bool isSelected = sortOption == value;
    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      onSelected: (val) {
        setState(() => sortOption = value);
        _applyFilters();
      },
      selectedColor: Colors.black,
      labelStyle: TextStyle(
        color: isSelected ? Colors.white : Colors.black,
        fontSize: 13
      ),
      shape: const StadiumBorder(),
      backgroundColor: Colors.grey[100],
      visualDensity: VisualDensity.compact,
    );
  }

  Widget _buildAlbumGrid(int crossAxisCount, bool isDesktop) {
    if (filteredAlbums.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.only(top: 40),
          child: Text("Không tìm thấy album nào trong thể loại này."),
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true, // Cho phép nằm trong SingleChildScrollView
      physics: const NeverScrollableScrollPhysics(), // Scroll do cha quản lý
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        childAspectRatio: 0.65, // Điều chỉnh tỷ lệ để card đẹp hơn trên màn hình rộng
        crossAxisSpacing: 20,
        mainAxisSpacing: 20,
      ),
      itemCount: filteredAlbums.length,
      itemBuilder: (context, index) {
        return AlbumCard(album: filteredAlbums[index]);
      },
    );
  }
}