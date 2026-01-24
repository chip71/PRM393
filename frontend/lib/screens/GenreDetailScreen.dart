import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
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

  final String apiUrl = 'https://prm393.onrender.com/api';

  @override
  void initState() {
    super.initState();
    _fetchAlbumsByGenre();
  }

  Future<void> _fetchAlbumsByGenre() async {
    try {
      final response = await http.get(Uri.parse('$apiUrl/albums/genre/${widget.genreId}'));
      if (response.statusCode == 200) {
        setState(() {
          albums = json.decode(response.body);
          filteredAlbums = albums;
          isLoading = false;
        });
        _applyFilters();
      }
    } catch (e) {
      setState(() => isLoading = false);
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
    return Scaffold(
      backgroundColor: Colors.white,
      // Đã bỏ hoàn toàn AppBar để không còn nút back và tiêu đề thừa
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

            // 2. Thanh sắp xếp (Sort Bar)
            _buildSortBar(),

            // 3. Tên Genre hiển thị ở ngay đầu list album
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 15, 16, 10),
              child: Text(
                widget.genreName,
                style: const TextStyle(
                  fontSize: 28, 
                  fontWeight: FontWeight.bold, 
                  color: Colors.black,
                  letterSpacing: -0.5
                ),
              ),
            ),

            // 4. Danh sách Album dạng Grid
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : _buildAlbumGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSortBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: SingleChildScrollView(
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
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      shape: const StadiumBorder(),
      backgroundColor: Colors.grey[200],
    );
  }

  Widget _buildAlbumGrid() {
    if (filteredAlbums.isEmpty) {
      return const Center(child: Text("Không tìm thấy album nào."));
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 0),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.62, // Tăng nhẹ tỷ lệ để tránh overflow khi tên dài
        crossAxisSpacing: 16,
        mainAxisSpacing: 16,
      ),
      itemCount: filteredAlbums.length,
      itemBuilder: (context, index) {
        return AlbumCard(album: filteredAlbums[index]);
      },
    );
  }
}