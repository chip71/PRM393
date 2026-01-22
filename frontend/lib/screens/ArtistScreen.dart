import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/navbar.dart';

class ArtistScreen extends StatefulWidget {
  const ArtistScreen({super.key});

  @override
  State<ArtistScreen> createState() => _ArtistScreenState();
}

class _ArtistScreenState extends State<ArtistScreen> {
  List<dynamic> artists = [];
  bool isLoading = true;
  String? error;
  String searchText = "";
  
  // Thêm biến quản lý trạng thái sắp xếp
  bool isSortAscending = true;

  final String apiUrl = 'https://musicx-mobile-backend.onrender.com/api/artists';

  @override
  void initState() {
    super.initState();
    _fetchArtists();
  }

  Future<void> _fetchArtists() async {
    try {
      final response = await http.get(Uri.parse(apiUrl));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        
        // Sắp xếp mặc định A-Z ngay khi tải xong
        data.sort((a, b) => a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));
        
        setState(() {
          artists = data;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Artist not found";
        isLoading = false;
      });
    }
  }

  // Logic Lọc và Sắp xếp
  List<dynamic> get _processedArtists {
    List<dynamic> filtered = artists;
    
    if (searchText.trim().isNotEmpty) {
      filtered = artists
          .where((a) => a['name']
              .toString()
              .toLowerCase()
              .contains(searchText.toLowerCase()))
          .toList();
    }

    // Thực hiện sắp xếp dựa trên trạng thái nút
    filtered.sort((a, b) {
      int cmp = a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase());
      return isSortAscending ? cmp : -cmp;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
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
            
            // Thanh công cụ Sắp xếp
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "All Artists (${_processedArtists.length})",
                    style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.grey),
                  ),
                  TextButton.icon(
                    onPressed: () => setState(() => isSortAscending = !isSortAscending),
                    icon: Icon(
                      isSortAscending ? Icons.sort_by_alpha : Icons.sort_by_alpha_outlined,
                      size: 18,
                      color: Colors.black,
                    ),
                    label: Text(
                      isSortAscending ? "A - Z" : "Z - A",
                      style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            
            Expanded(
              child: isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : _buildArtistGrid(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistGrid() {
    final list = _processedArtists;
    
    if (list.isEmpty) {
      return const Center(child: Text("Không tìm thấy nghệ sĩ nào."));
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        mainAxisSpacing: 20,
        crossAxisSpacing: 10,
        childAspectRatio: 0.75,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final artist = list[index];
        return GestureDetector(
          onTap: () => Navigator.pushNamed(context, '/artist-detail', arguments: artist['_id'].toString()),
          child: Column(
            children: [
              CircleAvatar(
                radius: 42,
                backgroundColor: Colors.grey[200],
                backgroundImage: NetworkImage(artist['image'] ?? ''),
              ),
              const SizedBox(height: 8),
              Text(
                artist['name'] ?? '',
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
            ],
          ),
        );
      },
    );
  }
}