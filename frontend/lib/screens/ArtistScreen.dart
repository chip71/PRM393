import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
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
  bool isSortAscending = true;

  @override
  void initState() {
    super.initState();
    _fetchArtists();
  }

  Future<void> _fetchArtists() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final response = await http.get(Uri.parse('${auth.apiUrl}/api/artists'));
      if (response.statusCode == 200) {
        List<dynamic> data = json.decode(response.body);
        
        // Sắp xếp mặc định A-Z
        data.sort((a, b) => a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase()));
        
        if (mounted) {
          setState(() {
            artists = data;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = "Artist not found";
          isLoading = false;
        });
      }
    }
  }

  List<dynamic> get _processedArtists {
    List<dynamic> filtered = List.from(artists);
    
    if (searchText.trim().isNotEmpty) {
      filtered = filtered
          .where((a) => a['name']
              .toString()
              .toLowerCase()
              .contains(searchText.toLowerCase()))
          .toList();
    }

    filtered.sort((a, b) {
      int cmp = a['name'].toString().toLowerCase().compareTo(b['name'].toString().toLowerCase());
      return isSortAscending ? cmp : -cmp;
    });

    return filtered;
  }

  @override
  Widget build(BuildContext context) {
    // Xác định kích thước màn hình để tùy chỉnh số cột
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 900;
    int crossAxisCount = isDesktop ? (screenWidth ~/ 180) : 3;

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
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
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
                  : _buildArtistGrid(crossAxisCount, isDesktop),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistGrid(int crossAxisCount, bool isDesktop) {
    final list = _processedArtists;
    
    if (list.isEmpty) {
      return const Center(child: Text("Không tìm thấy nghệ sĩ nào."));
    }

    return GridView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 30,
        crossAxisSpacing: 20,
        childAspectRatio: isDesktop ? 0.85 : 0.75,
      ),
      itemCount: list.length,
      itemBuilder: (context, index) {
        final artist = list[index];
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          child: GestureDetector(
            onTap: () => Navigator.pushNamed(context, '/artist-detail', arguments: artist['_id'].toString()),
            child: Column(
              children: [
                Expanded(
                  child: Container(
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.05),
                          blurRadius: 10,
                          offset: const Offset(0, 5),
                        )
                      ],
                    ),
                    child: CircleAvatar(
                      radius: double.infinity,
                      backgroundColor: Colors.grey[100],
                      backgroundImage: NetworkImage(artist['image'] ?? ''),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  artist['name'] ?? '',
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w600, 
                    fontSize: isDesktop ? 15 : 13,
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