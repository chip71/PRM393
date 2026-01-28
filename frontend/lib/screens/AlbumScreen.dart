import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/navbar.dart';
import '../widgets/album_card.dart';

class AlbumScreen extends StatefulWidget {
  const AlbumScreen({super.key});

  @override
  State<AlbumScreen> createState() => _AlbumScreenState();
}

class _AlbumScreenState extends State<AlbumScreen> {
  List<dynamic> albums = [];
  List<dynamic> artists = [];
  List<dynamic> genres = [];
  List<dynamic> filteredAlbums = [];
  bool isLoading = true;
  String? error;

  String searchText = "";
  List<String> selectedArtists = [];
  List<String> selectedGenres = [];
  String sortOption = "name";
  bool isFilterVisible = false;

  final String apiUrl = 'https://prm393.onrender.com/api';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    try {
      final responses = await Future.wait([
        http.get(Uri.parse('$apiUrl/albums')),
        http.get(Uri.parse('$apiUrl/artists')),
        http.get(Uri.parse('$apiUrl/genres')),
      ]);

      if (responses.every((res) => res.statusCode == 200)) {
        if (mounted) {
          setState(() {
            albums = json.decode(responses[0].body);
            artists = json.decode(responses[1].body);
            genres = json.decode(responses[2].body);
            filteredAlbums = albums;
            isLoading = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = "Failed to load albums.";
          isLoading = false;
        });
      }
    }
  }

  void _applyFilters() {
    List<dynamic> result = List.from(albums);

    if (searchText.trim().isNotEmpty) {
      result = result
          .where((a) => a['name'].toString().toLowerCase().contains(searchText.toLowerCase()))
          .toList();
    }

    if (selectedArtists.isNotEmpty) {
      result = result.where((a) {
        final id = a['artistID'] is Map ? a['artistID']['_id'] : a['artistID'];
        return selectedArtists.contains(id.toString());
      }).toList();
    }

    if (selectedGenres.isNotEmpty) {
      result = result.where((a) {
        final id = a['genreID'] is Map ? a['genreID']['_id'] : a['genreID'];
        return selectedGenres.contains(id.toString());
      }).toList();
    }

    if (sortOption == "name") {
      result.sort((a, b) => a['name'].compareTo(b['name']));
    } else if (sortOption == "nameDesc") {
      result.sort((a, b) => b['name'].compareTo(a['name']));
    } else if (sortOption == "priceAsc") {
      result.sort((a, b) => (a['price'] ?? 0).compareTo(b['price'] ?? 0));
    } else if (sortOption == "priceDesc") {
      result.sort((a, b) => (b['price'] ?? 0).compareTo(a['price'] ?? 0));
    }

    setState(() {
      filteredAlbums = result;
    });
  }

  void _toggleSelection(String id, List<String> list) {
    setState(() {
      if (list.contains(id)) {
        list.remove(id);
      } else {
        list.add(id);
      }
      _applyFilters();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Detect screen width for responsiveness
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 900;

    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.black)));
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Navbar(
              searchText: searchText,
              setSearchText: (val) {
                setState(() => searchText = val);
                _applyFilters();
              },
              showSearch: true,
            ),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Sidebar Filters for Desktop
                  if (isDesktop)
                    Container(
                      width: 280,
                      decoration: BoxDecoration(
                        border: Border(right: BorderSide(color: Colors.grey[200]!)),
                      ),
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(vertical: 20),
                        child: _buildFilterContent(isDesktop: true),
                      ),
                    ),

                  // Main Content
                  Expanded(
                    child: Column(
                      children: [
                        // Mobile Filter Toggle
                        if (!isDesktop)
                          _buildMobileFilterToggle(),

                        // Mobile Filter Panel (Animated)
                        if (!isDesktop)
                          AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            height: isFilterVisible ? 280 : 0,
                            curve: Curves.easeInOut,
                            child: SingleChildScrollView(
                              child: _buildFilterContent(isDesktop: false),
                            ),
                          ),

                        // Album Grid
                        Expanded(
                          child: GridView.builder(
                            padding: const EdgeInsets.all(12),
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              // Adjust columns based on width
                              crossAxisCount: isDesktop ? (screenWidth ~/ 250) : 2,
                              childAspectRatio: 0.65,
                              crossAxisSpacing: 15,
                              mainAxisSpacing: 15,
                            ),
                            itemCount: filteredAlbums.length,
                            itemBuilder: (context, index) => AlbumCard(album: filteredAlbums[index]),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMobileFilterToggle() {
    return InkWell(
      onTap: () => setState(() => isFilterVisible = !isFilterVisible),
      child: Padding(
        padding: const EdgeInsets.all(12.0),
        child: Row(
          children: [
            const Icon(Icons.tune, size: 20),
            const SizedBox(width: 8),
            const Text("Filters", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
            const Spacer(),
            Icon(isFilterVisible ? Icons.expand_less : Icons.expand_more),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterContent({required bool isDesktop}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Sort By", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              _filterChip("A-Z", "name", sortOption == "name", (val) => setState(() { sortOption = "name"; _applyFilters(); })),
              _filterChip("Z-A", "nameDesc", sortOption == "nameDesc", (val) => setState(() { sortOption = "nameDesc"; _applyFilters(); })),
              _filterChip("Low-High", "priceAsc", sortOption == "priceAsc", (val) => setState(() { sortOption = "priceAsc"; _applyFilters(); })),
              _filterChip("High-Low", "priceDesc", sortOption == "priceDesc", (val) => setState(() { sortOption = "priceDesc"; _applyFilters(); })),
            ],
          ),
          const SizedBox(height: 20),
          const Text("Artists", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          isDesktop ? _verticalFilterList(artists, selectedArtists) : _horizontalFilterList(artists, selectedArtists),
          const SizedBox(height: 20),
          const Text("Genres", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          isDesktop ? _verticalFilterList(genres, selectedGenres) : _horizontalFilterList(genres, selectedGenres),
        ],
      ),
    );
  }

  Widget _filterChip(String label, String value, bool isActive, Function(bool) onSelected) {
    return ChoiceChip(
      label: Text(label),
      selected: isActive,
      onSelected: onSelected,
      selectedColor: Colors.black,
      labelStyle: TextStyle(color: isActive ? Colors.white : Colors.black, fontSize: 12),
      backgroundColor: Colors.grey[100],
      shape: StadiumBorder(side: BorderSide.none),
      visualDensity: VisualDensity.compact,
    );
  }

  // Horizontal list for mobile space saving
  Widget _horizontalFilterList(List<dynamic> data, List<String> selectedList) {
    return SizedBox(
      height: 40,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: data.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: _filterChip("All", "all", selectedList.isEmpty, (val) => setState(() { selectedList.clear(); _applyFilters(); })),
            );
          }
          final item = data[index - 1];
          final String id = item['_id'].toString();
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: _filterChip(item['name'], id, selectedList.contains(id), (val) => _toggleSelection(id, selectedList)),
          );
        },
      ),
    );
  }

  // Vertical list for Desktop sidebar
  Widget _verticalFilterList(List<dynamic> data, List<String> selectedList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _filterChip("All", "all", selectedList.isEmpty, (val) => setState(() { selectedList.clear(); _applyFilters(); })),
        ...data.map((item) {
          final String id = item['_id'].toString();
          return Padding(
            padding: const EdgeInsets.only(top: 4),
            child: _filterChip(item['name'], id, selectedList.contains(id), (val) => _toggleSelection(id, selectedList)),
          );
        }),
      ],
    );
  }
}