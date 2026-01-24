import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import '../widgets/navbar.dart';
import '../widgets/album_row.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // --- State Variables ---
  List<dynamic> albums = [];
  List<dynamic> artists = [];
  List<dynamic> genres = [];
  bool isLoading = true;
  String? error;
  String searchText = '';
  String selectedFormat = 'All';

  final String apiUrl = 'https://prm393-1.onrender.com/api';

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  // --- API Fetching ---
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
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load data from server');
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load data. Is the server running?';
        isLoading = false;
      });
    }
  }

  // --- Helper & Filter Logic ---
  // lib/screens/HomeScreen.dart

// lib/screens/HomeScreen.dart

List<dynamic> get _filteredAlbums {
  Iterable<dynamic> results = albums;
  final searchLower = searchText.toLowerCase().trim();

  if (searchLower.isNotEmpty) {
    results = results.where((a) {
      // Ép kiểu ID về String để so sánh chính xác giữa danh sách Album và Artist/Genre
      final artist = artists.firstWhere(
        (art) => art['_id'].toString() == a['artistID'].toString(), 
        orElse: () => null
      );
      final genre = genres.firstWhere(
        (g) => g['_id'].toString() == a['genreID'].toString(), 
        orElse: () => null
      );
      
      final nameMatch = a['name'].toString().toLowerCase().contains(searchLower);
      final artistMatch = artist != null && artist['name'].toString().toLowerCase().contains(searchLower);
      final genreMatch = genre != null && genre['name'].toString().toLowerCase().contains(searchLower);

      return nameMatch || artistMatch || genreMatch;
    });
  }

  if (selectedFormat != 'All') {
    results = results.where((a) => a['format'] == selectedFormat);
  }
  return results.toList();
}
  List<dynamic> get _matchingArtists {
    if (searchText.trim().isEmpty) return [];
    return artists.where((a) => a['name'].toString().toLowerCase().contains(searchText.toLowerCase())).toList();
  }

  List<dynamic> get _mostValuableAlbums {
    List<dynamic> sorted = List.from(albums);
    sorted.sort((a, b) => (b['price'] ?? 0).compareTo(a['price'] ?? 0));
    return sorted;
  }

  // --- Sub-Widgets (Builders) ---
  Widget _buildArtistCard(dynamic artist) {
    return GestureDetector(
      onTap: () => Navigator.pushNamed(context, '/artist-detail', arguments: artist['_id']),
      child: Container(
        width: 100,
        margin: const EdgeInsets.only(right: 15),
        child: Column(
          children: [
            CircleAvatar(
              radius: 40,
              backgroundColor: Colors.grey[300],
              backgroundImage: NetworkImage(artist['image'] ?? ''),
            ),
            const SizedBox(height: 8),
            Text(
              artist['name'] ?? '',
              textAlign: TextAlign.center,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
          ],
        ),
      ),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    if (error != null) {
      return Scaffold(
        body: Center(child: Text(error!, style: const TextStyle(color: Colors.red))),
      );
    }

    bool showSearchPage = searchText.trim().isNotEmpty;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Navbar(
              searchText: searchText,
              setSearchText: (val) => setState(() => searchText = val),
            ),
            Expanded(
              child: showSearchPage ? _buildSearchResults() : _buildHomeView(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHomeView() {
    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        _buildSectionTitle('Top Selling Albums'),
        AlbumRow(albums: albums, artists: artists, genres: genres),
        _buildSectionTitle('Most Valuable Albums'),
        AlbumRow(albums: _mostValuableAlbums, artists: artists, genres: genres),
        _buildSectionTitle('Featured Artists'),
        SizedBox(
          height: 120,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: artists.length,
            itemBuilder: (context, index) => _buildArtistCard(artists[index]),
          ),
        ),
      ],
    );
  }

  Widget _buildSearchResults() {
    final filtered = _filteredAlbums;
    final matchingArt = _matchingArtists;

    return ListView(
      padding: const EdgeInsets.only(bottom: 20),
      children: [
        if (matchingArt.isNotEmpty) ...[
          _buildSectionTitle('Artists (${matchingArt.length})'),
          SizedBox(
            height: 120,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: matchingArt.length,
              itemBuilder: (context, index) => _buildArtistCard(matchingArt[index]),
            ),
          ),
        ],
        _buildFilterBar(),
        _buildSectionTitle('Albums (${filtered.length})'),
        AlbumRow(albums: filtered, artists: artists, genres: genres),
        if (filtered.isEmpty && matchingArt.isEmpty)
          const Padding(
            padding: EdgeInsets.only(top: 30),
            child: Text('No results found', textAlign: TextAlign.center, style: TextStyle(color: Colors.grey)),
          ),
      ],
    );
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 15, 16, 12),
      child: Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
    );
  }

  Widget _buildFilterBar() {
    return Container(
      height: 50,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: ['All', 'Vinyl', 'CD'].map((format) {
          bool isActive = selectedFormat == format;
          return Padding(
            padding: const EdgeInsets.only(right: 10),
            child: ChoiceChip(
              label: Text(format),
              selected: isActive,
              onSelected: (val) => setState(() => selectedFormat = format),
              selectedColor: Colors.black,
              labelStyle: TextStyle(color: isActive ? Colors.white : Colors.black),
            ),
          );
        }).toList(),
      ),
    );
  }
}