import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

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

  final String apiUrl = 'https://musicx-mobile-backend.onrender.com/api';

  @override
  void initState() {
    super.initState();
    _fetchArtistData();
  }

  Future<void> _fetchArtistData() async {
    try {
      setState(() => isLoading = true);

      // Fetch Artist và Albums đồng thời
      final responses = await Future.wait([
        http.get(Uri.parse('$apiUrl/artists/${widget.artistId}')),
        http.get(Uri.parse('$apiUrl/albums/artist/${widget.artistId}')),
      ]);

      if (responses[0].statusCode == 200 && responses[1].statusCode == 200) {
        setState(() {
          artist = json.decode(responses[0].body);
          albums = json.decode(responses[1].body);
          isLoading = false;
        });
      } else {
        throw Exception('Failed to load artist data');
      }
    } catch (e) {
      setState(() {
        error = 'Failed to load artist details. Check API connection.';
        isLoading = false;
      });
    }
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Could not launch URL')));
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
              Text(
                error ?? 'Artist not found.',
                style: const TextStyle(color: Colors.red),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'Artist Details',
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // --- Artist Header Section ---
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 35),
              decoration: const BoxDecoration(color: Color(0xFFFAFAFA)),
              child: Column(
                children: [
                  Container(
                    width: MediaQuery.of(context).size.width * 0.46,
                    height: MediaQuery.of(context).size.width * 0.46,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFFD4AF37),
                        width: 3,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.25),
                          blurRadius: 8,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: ClipOval(
                      child: Image.network(
                        artist!['image'] ?? '',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            Container(color: Colors.grey),
                      ),
                    ),
                  ),
                  const SizedBox(height: 15),
                  Text(
                    artist!['name'] ?? '',
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    '${albums.length} Albums',
                    style: const TextStyle(fontSize: 15, color: Colors.grey),
                  ),
                ],
              ),
            ),

            // --- Social Links ---
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 15),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (artist!['spotify'] != null)
                    IconButton(
                      icon: const Icon(
                        Icons.music_note,
                        size: 35,
                        color: Color(0xFF1DB954),
                      ),
                      onPressed: () => _launchURL(artist!['spotify']),
                    ),
                  const SizedBox(width: 20),
                  if (artist!['youtube'] != null)
                    IconButton(
                      icon: const Icon(
                        Icons.play_circle_fill,
                        size: 35,
                        color: Color(0xFFFF0000),
                      ),
                      onPressed: () => _launchURL(artist!['youtube']),
                    ),
                ],
              ),
            ),

            // --- About ---
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'About',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    artist!['description'] ?? 'No description available.',
                    style: const TextStyle(
                      fontSize: 16,
                      color: Colors.black87,
                      height: 1.5, // Thay lineHeight: 24 thành height: 1.5
                    ),
                  ),
                ],
              ),
            ),

            // --- Discography (Grid) ---
            // --- Discography (Grid) ---
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Discography',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 15),
                  albums.isNotEmpty
                      ? GridView.builder(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          gridDelegate:
                              const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                // Tăng từ 0.7 lên 0.6 hoặc 0.55 để dành thêm chỗ cho phần text phía dưới ảnh
                                childAspectRatio: 0.6,
                                crossAxisSpacing: 10,
                                mainAxisSpacing: 10,
                              ),
                          itemCount: albums.length,
                          itemBuilder: (context, index) {
                            // Đảm bảo dữ liệu truyền vào AlbumCard có đủ thông tin Artist để tránh "Unknown"
                            final album = albums[index];
                            final Map<String, dynamic> albumWithArtist =
                                Map.from(album);
                            albumWithArtist['artistID'] =
                                artist; // Gán object artist hiện tại vào

                            return AlbumCard(album: albumWithArtist);
                          },
                        )
                      : const Text(
                          'No albums found for this artist.',
                          style: TextStyle(color: Colors.grey),
                        ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
