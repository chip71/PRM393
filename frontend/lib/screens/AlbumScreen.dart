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
  // --- Data State ---
  List<dynamic> albums = [];
  List<dynamic> artists = [];
  List<dynamic> genres = [];
  List<dynamic> filteredAlbums = [];
  bool isLoading = true;
  String? error;

  // --- Filter State ---
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
        setState(() {
          albums = json.decode(responses[0].body);
          artists = json.decode(responses[1].body);
          genres = json.decode(responses[2].body);
          filteredAlbums = albums;
          isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        error = "Failed to load albums. Is the server running?";
        isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<dynamic> result = List.from(albums);

    // Search filter
    if (searchText.trim().isNotEmpty) {
      result = result
          .where((a) => a['name']
              .toString()
              .toLowerCase()
              .contains(searchText.toLowerCase()))
          .toList();
    }

    // Artist filter
    if (selectedArtists.isNotEmpty) {
      result = result.where((a) {
        final id = a['artistID'] is Map ? a['artistID']['_id'] : a['artistID'];
        return selectedArtists.contains(id.toString());
      }).toList();
    }

    // Genre filter
    if (selectedGenres.isNotEmpty) {
      result = result.where((a) {
        final id = a['genreID'] is Map ? a['genreID']['_id'] : a['genreID'];
        return selectedGenres.contains(id.toString());
      }).toList();
    }

    // Sorting
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

            // Filter Toggle
            InkWell(
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
            ),

            // Filter Panel (Animated)
            AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              height: isFilterVisible ? 280 : 0,
              curve: Curves.easeInOut,
              child: SingleChildScrollView(
                child: _buildFilterContent(),
              ),
            ),

            // Album Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  childAspectRatio: 0.62,
                  crossAxisSpacing: 10,
                  mainAxisSpacing: 10,
                ),
                itemCount: filteredAlbums.length,
                itemBuilder: (context, index) {
                  final album = filteredAlbums[index];
                  return AlbumCard(album: album);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterContent() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Sort By", style: TextStyle(fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            children: [
              _filterChip("A-Z", "name", sortOption == "name", (val) => setState(() { sortOption = "name"; _applyFilters(); })),
              _filterChip("Z-A", "nameDesc", sortOption == "nameDesc", (val) => setState(() { sortOption = "nameDesc"; _applyFilters(); })),
              _filterChip("Low-High", "priceAsc", sortOption == "priceAsc", (val) => setState(() { sortOption = "priceAsc"; _applyFilters(); })),
              _filterChip("High-Low", "priceDesc", sortOption == "priceDesc", (val) => setState(() { sortOption = "priceDesc"; _applyFilters(); })),
            ],
          ),
          const SizedBox(height: 12),
          const Text("Artists", style: TextStyle(fontWeight: FontWeight.bold)),
          _horizontalFilterList(artists, selectedArtists),
          const SizedBox(height: 12),
          const Text("Genres", style: TextStyle(fontWeight: FontWeight.bold)),
          _horizontalFilterList(genres, selectedGenres),
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
      labelStyle: TextStyle(color: isActive ? Colors.white : Colors.black),
      backgroundColor: Colors.grey[200],
      shape: StadiumBorder(side: BorderSide.none),
    );
  }

  Widget _horizontalFilterList(List<dynamic> data, List<String> selectedList) {
    return SizedBox(
      height: 50,
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: data.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return _filterChip("All", "all", selectedList.isEmpty, (val) => setState(() { selectedList.clear(); _applyFilters(); }));
          }
          final item = data[index - 1];
          final String id = item['_id'].toString();
          return Padding(
            padding: const EdgeInsets.only(right: 8.0),
            child: _filterChip(item['name'], id, selectedList.contains(id), (val) => _toggleSelection(id, selectedList)),
          );
        },
      ),
    );
  }
}