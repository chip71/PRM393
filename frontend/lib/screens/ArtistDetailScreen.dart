import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../widgets/album_card.dart';

class ArtistDetailScreen extends StatefulWidget {
  final String artistId;

  const ArtistDetailScreen({super.key, required this.artistId});

  @override
  State<ArtistDetailScreen> createState() => _ArtistDetailScreenState();
}

class _ArtistDetailScreenState extends State<ArtistDetailScreen> {
  Map<String, dynamic>? artist;
  List<dynamic> albums = [];
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _fetchArtistData();
  }

  Future<void> _fetchArtistData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final String apiUrl = auth.apiUrl;

    try {
      if (!mounted) return;
      setState(() => isLoading = true);

      final responses = await Future.wait([
        http.get(Uri.parse('$apiUrl/api/artists/${widget.artistId}')),
        http.get(Uri.parse('$apiUrl/api/albums/artist/${widget.artistId}')),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        if (mounted) {
          setState(() {
            artist = json.decode(responses[0].body);
            albums = json.decode(responses[1].body);
            isLoading = false;
          });
        }
      } else {
        throw Exception('Failed to load artist data');
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          error = 'Failed to load artist details.';
          isLoading = false;
        });
      }
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

    if (error != null || artist == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(error ?? 'Artist not found.', style: const TextStyle(color: Colors.red)),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
            ],
          ),
        ),
      );
    }

    // --- LOGIC RESPONSIVE ---
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 900;
    // Desktop bóp nội dung vào giữa (80%), Mobile dùng toàn màn hình (100%)
    double contentPadding = isDesktop ? screenWidth * 0.15 : 20.0;
    // Số cột Album: Desktop (4-6 cột), Mobile (2 cột)
    int crossAxisCount = isDesktop ? (screenWidth ~/ 250).clamp(3, 6) : 2;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text('Artist Details', 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- Artist Header Section ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: const BoxDecoration(color: Color(0xFFFAFAFA)),
              child: Column(
                children: [
                  _buildArtistImage(isDesktop),
                  const SizedBox(height: 20),
                  Text(
                    artist!['name'] ?? '',
                    style: TextStyle(
                      fontSize: isDesktop ? 36 : 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${albums.length} Albums',
                    style: const TextStyle(fontSize: 16, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // --- Social Links ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (artist!['spotify'] != null)
                    _socialIcon(Icons.music_note, const Color(0xFF1DB954), artist!['spotify']),
                  if (artist!['spotify'] != null && artist!['youtube'] != null) const SizedBox(width: 30),
                  if (artist!['youtube'] != null)
                    _socialIcon(Icons.play_circle_fill, const Color(0xFFFF0000), artist!['youtube']),
                ],
              ),
            ),

            // --- About Section ---
            Padding(
              padding: EdgeInsets.symmetric(horizontal: contentPadding, vertical: 15),
              child: Column(
                crossAxisAlignment: isDesktop ? CrossAxisAlignment.center : CrossAxisAlignment.start,
                children: [
                  const Text('About', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(
                    artist!['description'] ?? 'No description available.',
                    textAlign: isDesktop ? TextAlign.center : TextAlign.start,
                    style: const TextStyle(fontSize: 16, color: Colors.black87, height: 1.6),
                  ),
                ],
              ),
            ),

            // --- Discography (Grid) ---
            Padding(
              padding: EdgeInsets.symmetric(horizontal: contentPadding, vertical: 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Discography', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  albums.isNotEmpty
                      ? GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: crossAxisCount,
                            childAspectRatio: 0.62,
                            crossAxisSpacing: 15,
                            mainAxisSpacing: 15,
                          ),
                          itemCount: albums.length,
                          itemBuilder: (context, index) {
                            final album = albums[index];
                            final Map<String, dynamic> albumWithArtist = Map.from(album);
                            albumWithArtist['artistID'] = artist; // Truyền data artist vào AlbumCard
                            return AlbumCard(album: albumWithArtist);
                          },
                        )
                      : const Text('No albums found.', style: TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            const SizedBox(height: 50),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistImage(bool isDesktop) {
    double size = isDesktop ? 220 : MediaQuery.of(context).size.width * 0.46;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: const Color(0xFFD4AF37), width: 3),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: ClipOval(
        child: Image.network(
          artist!['image'] ?? '',
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Container(color: Colors.grey[200]),
        ),
      ),
    );
  }

  Widget _socialIcon(IconData icon, Color color, String url) {
    return MouseRegion(
      cursor: SystemMouseCursors.click,
      child: IconButton(
        icon: Icon(icon, size: 38, color: color),
        onPressed: () => _launchURL(url),
      ),
    );
  }
}