import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/navbar.dart';
import '../widgets/album_row.dart';

class AlbumDetailScreen extends StatefulWidget {
  final String albumId;

  const AlbumDetailScreen({super.key, required this.albumId});

  @override
  State<AlbumDetailScreen> createState() => _AlbumDetailScreenState();
}

class _AlbumDetailScreenState extends State<AlbumDetailScreen> {
  Map<String, dynamic>? album;
  List<dynamic> recommendedAlbums = [];
  List<dynamic> artistAlbums = [];
  List<dynamic> artists = [];
  List<dynamic> genres = [];
  bool isLoading = true;
  String? error;

  final String apiUrl = 'https://prm393.onrender.com/api';

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void didUpdateWidget(AlbumDetailScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.albumId != widget.albumId) {
      _loadData();
    }
  }

  Future<void> _loadData() async {
    try {
      if (!mounted) return;
      setState(() => isLoading = true);

      final albumRes = await http.get(
        Uri.parse('$apiUrl/albums/${widget.albumId}'),
      );
      if (albumRes.statusCode != 200) throw Exception('Album not found');
      final fetchedAlbum = json.decode(albumRes.body);

      final metaResponses = await Future.wait([
        http.get(Uri.parse('$apiUrl/artists')),
        http.get(Uri.parse('$apiUrl/genres')),
      ]);

      if (mounted) {
        setState(() {
          album = fetchedAlbum;
          artists = json.decode(metaResponses[0].body);
          genres = json.decode(metaResponses[1].body);
        });

        final String? genreId = fetchedAlbum['genreID'] is Map
            ? fetchedAlbum['genreID']['_id']
            : fetchedAlbum['genreID'];
        final String? artistId = fetchedAlbum['artistID'] is Map
            ? fetchedAlbum['artistID']['_id']
            : fetchedAlbum['artistID'];

        if (genreId != null) {
          final recRes = await http.get(
            Uri.parse('$apiUrl/albums/genre/$genreId?exclude=${widget.albumId}'),
          );
          if (mounted) setState(() => recommendedAlbums = json.decode(recRes.body));
        }

        if (artistId != null) {
          final artRes = await http.get(
            Uri.parse('$apiUrl/albums/artist/$artistId?exclude=${widget.albumId}'),
          );
          if (mounted) setState(() => artistAlbums = json.decode(artRes.body));
        }
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Could not load album details.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not launch URL')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );
    }

    final currentAlbum = album;
    if (error != null || currentAlbum == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(error ?? 'Album not found', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 10),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final String artistName = currentAlbum['artistID'] is Map
        ? (currentAlbum['artistID']['name'] ?? 'Unknown Artist')
        : 'Unknown Artist';
    final String artistId = currentAlbum['artistID'] is Map
        ? (currentAlbum['artistID']['_id'] ?? '')
        : (currentAlbum['artistID'] ?? '');

    final String genreName = currentAlbum['genreID'] is Map
        ? (currentAlbum['genreID']['name'] ?? 'Related')
        : 'Related';
    final String genreId = currentAlbum['genreID'] is Map
        ? (currentAlbum['genreID']['_id'] ?? '')
        : (currentAlbum['genreID'] ?? '');

    final int stock = currentAlbum['stock'] ?? 0;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Navbar(showSearch: false, searchText: '', setSearchText: (val) {}),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: 40),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              currentAlbum['image'] ?? 'https://via.placeholder.com/150',
                              width: 150, height: 150, fit: BoxFit.cover,
                              errorBuilder: (context, error, stackTrace) =>
                                  const Icon(Icons.broken_image, size: 150),
                            ),
                          ),
                          const SizedBox(width: 20),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentAlbum['name'] ?? 'No Name',
                                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                                ),
                                const SizedBox(height: 8),
                                
                                // ✅ ĐIỀU HƯỚNG ARTIST DETAIL - KHÔNG GẠCH CHÂN
                                InkWell(
                                  onTap: () {
                                    if (artistId.isNotEmpty) {
                                      Navigator.pushNamed(context, '/artist-detail', 
                                          arguments: artistId);
                                    }
                                  },
                                  child: Text(
                                    artistName,
                                    style: const TextStyle(
                                      fontSize: 18, 
                                      color: Colors.blueAccent,
                                      fontWeight: FontWeight.w500,
                                      decoration: TextDecoration.none, // Bỏ gạch chân
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 4),

                                // ✅ ĐIỀU HƯỚNG GENRE DETAIL - KHÔNG GẠCH CHÂN
                                InkWell(
                                  onTap: () {
                                    if (genreId.isNotEmpty) {
                                      Navigator.pushNamed(context, '/genre-detail', 
                                          arguments: {'id': genreId, 'name': genreName});
                                    }
                                  },
                                  child: Text(
                                    'Genre: $genreName',
                                    style: const TextStyle(
                                      fontSize: 15, 
                                      color: Colors.black54,
                                      decoration: TextDecoration.none, // Bỏ gạch chân
                                    ),
                                  ),
                                ),
                                const SizedBox(height: 12),
                                Text(
                                  '${currentAlbum['price']?.toString() ?? '—'} ${currentAlbum['currency'] ?? 'VND'}',
                                  style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: Colors.black),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  stock > 0 ? 'In Stock: $stock' : 'SOLD OUT',
                                  style: TextStyle(
                                    color: stock > 0 ? Colors.green : Colors.red,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),

                    if (currentAlbum['spotify'] != null || currentAlbum['youtube'] != null)
                      _buildSocialLinks(currentAlbum),

                    Padding(
                      padding: const EdgeInsets.all(20.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Details', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 10),
                          _buildDetailRow('Format', currentAlbum['format']),
                          _buildDetailRow('SKU', currentAlbum['sku']),
                          const SizedBox(height: 25),
                          const Text('Description', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 8),
                          Text(
                            currentAlbum['description'] ?? 'No description available.',
                            style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87),
                          ),

                          if (stock > 0)
                            Padding(
                              padding: const EdgeInsets.only(top: 30),
                              child: ElevatedButton(
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: Colors.black,
                                  minimumSize: const Size(double.infinity, 60),
                                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                                  elevation: 5,
                                ),
                                onPressed: () {
                                  final authProvider = Provider.of<AuthProvider>(context, listen: false);
                                  authProvider.addToCart(currentAlbum);
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Added to cart!'), duration: Duration(seconds: 1)),
                                  );
                                },
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.shopping_cart_outlined, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text('ADD TO CART', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                                  ],
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    if (artistAlbums.isNotEmpty)
                      _buildRecommendationSection('More from $artistName', artistAlbums),
                    if (recommendedAlbums.isNotEmpty)
                      _buildRecommendationSection('More $genreName Music', recommendedAlbums),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSocialLinks(Map<String, dynamic> data) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 20),
      decoration: BoxDecoration(color: Colors.grey[50], border: const Border.symmetric(horizontal: BorderSide(color: Color(0xFFEEEEEE)))),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (data['spotify'] != null)
            _socialIcon(Icons.music_note, const Color(0xFF1DB954), () => _launchURL(data['spotify'])),
          if (data['spotify'] != null && data['youtube'] != null) const SizedBox(width: 50),
          if (data['youtube'] != null)
            _socialIcon(Icons.play_circle_fill, const Color(0xFFFF0000), () => _launchURL(data['youtube'])),
        ],
      ),
    );
  }

  Widget _socialIcon(IconData icon, Color color, VoidCallback onPress) {
    return InkWell(onTap: onPress, child: Icon(icon, size: 40, color: color));
  }

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
          Text(value?.toString() ?? '—', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildRecommendationSection(String title, List<dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 40)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 15),
          child: Text(title, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        ),
        AlbumRow(albums: data, artists: artists, genres: genres),
        const SizedBox(height: 20),
      ],
    );
  }
}