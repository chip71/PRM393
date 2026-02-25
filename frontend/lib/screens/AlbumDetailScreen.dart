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
  List<dynamic> comments = [];
  bool isLoading = true;
  String? error;
  final TextEditingController _commentController = TextEditingController();
  int _selectedRating = 5;
  bool _isSubmittingComment = false;

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

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final String apiUrl = auth.apiUrl; // Sử dụng API URL từ Provider

    try {
      if (!mounted) return;
      setState(() => isLoading = true);

      final albumRes = await http.get(Uri.parse('$apiUrl/api/albums/${widget.albumId}'));
      if (albumRes.statusCode != 200) throw Exception('Album not found');
      final fetchedAlbum = json.decode(albumRes.body);

      final metaResponses = await Future.wait([
        http.get(Uri.parse('$apiUrl/api/artists')),
        http.get(Uri.parse('$apiUrl/api/genres')),
      ]);

      if (mounted) {
        setState(() {
          album = fetchedAlbum;
          artists = json.decode(metaResponses[0].body);
          genres = json.decode(metaResponses[1].body);
        });

        final String? genreId = fetchedAlbum['genreID'] is Map ? fetchedAlbum['genreID']['_id'] : fetchedAlbum['genreID'];
        final String? artistId = fetchedAlbum['artistID'] is Map ? fetchedAlbum['artistID']['_id'] : fetchedAlbum['artistID'];

        if (genreId != null) {
          final recRes = await http.get(Uri.parse('$apiUrl/api/albums/genre/$genreId?exclude=${widget.albumId}'));
          if (mounted) setState(() => recommendedAlbums = json.decode(recRes.body));
        }

        if (artistId != null) {
          final artRes = await http.get(Uri.parse('$apiUrl/api/albums/artist/$artistId?exclude=${widget.albumId}'));
          if (mounted) setState(() => artistAlbums = json.decode(artRes.body));
        }

        // Load comments separately so it doesn't break the page if comments fail
        try {
          final commentsRes = await http.get(Uri.parse('$apiUrl/api/comments/album/${widget.albumId}'));
          if (commentsRes.statusCode == 200 && mounted) {
            setState(() => comments = json.decode(commentsRes.body));
          }
        } catch (e) {
          if (mounted) setState(() => comments = []);
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not launch URL')));
      }
    }
  }

  Future<void> _submitComment() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final String apiUrl = auth.apiUrl;
    final String content = _commentController.text.trim();
    final int rating = _selectedRating;

    if (content.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a comment'))
      );
      return;
    }

    if (auth.user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please log in to post a comment'))
      );
      return;
    }

    if (rating < 1 || rating > 5) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Rating must be between 1 and 5'))
      );
      return;
    }

    setState(() => _isSubmittingComment = true);

    try {
        final response = await http.post(
        Uri.parse('$apiUrl/api/comments'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'albumId': widget.albumId,
          'userId': auth.user?['_id'] ?? auth.user?['id'],
          'username': auth.user?['name'] ?? 'Anonymous',
          'role': auth.user?['role'] ?? 'user',
          'content': content,
          'rating': rating,
        }),
      );

      if (response.statusCode == 201) {
      _commentController.clear();
        await _loadData(); // Reload comments
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Comment posted successfully!'))
          );
        }
      } else {
        throw Exception('Failed to post comment');
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error posting comment: $e'))
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmittingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.black)));
    }

    if (error != null || album == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(error ?? 'Album not found', style: const TextStyle(color: Colors.red)),
              const SizedBox(height: 10),
              ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Go Back')),
            ],
          ),
        ),
      );
    }

    final currentAlbum = album!;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 900;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Navbar(showSearch: false, searchText: '', setSearchText: (val) {}),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isDesktop ? screenWidth * 0.1 : 0, 
                  vertical: 20
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Header Section (Adaptive)
                    isDesktop ? _buildDesktopHeader(currentAlbum) : _buildMobileHeader(currentAlbum),
                    
                    // Social Links Section
                    if (currentAlbum['spotify'] != null || currentAlbum['youtube'] != null)
                      _buildSocialLinks(currentAlbum),

                                // Main Info Section
                                _buildMainInfo(currentAlbum, isDesktop),

                                // Comments Section
                                _buildCommentsSection(),

                                // Recommendations
                    if (artistAlbums.isNotEmpty)
                      _buildRecommendationSection('More from ${currentAlbum['artistID']['name']}', artistAlbums),
                    if (recommendedAlbums.isNotEmpty)
                      _buildRecommendationSection('More ${currentAlbum['genreID']['name']} Music', recommendedAlbums),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(Map<String, dynamic> data) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAlbumImage(data['image'], 300),
        const SizedBox(width: 40),
        Expanded(child: _buildHeaderInfo(data, true)),
      ],
    );
  }

  Widget _buildMobileHeader(Map<String, dynamic> data) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildAlbumImage(data['image'], 150),
          const SizedBox(width: 20),
          Expanded(child: _buildHeaderInfo(data, false)),
        ],
      ),
    );
  }

  Widget _buildAlbumImage(String? imageUrl, double size) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Image.network(
        imageUrl ?? 'https://via.placeholder.com/150',
        width: size, height: size, fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: size),
      ),
    );
  }

  Widget _buildHeaderInfo(Map<String, dynamic> data, bool isDesktop) {
    final String artistName = data['artistID']['name'] ?? 'Unknown Artist';
    final String genreName = data['genreID']['name'] ?? 'Related';
    final int stock = data['stock'] ?? 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(data['name'] ?? 'No Name', 
            style: TextStyle(fontSize: isDesktop ? 36 : 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        _buildClickableText(artistName, Colors.blueAccent, 18, () {
          Navigator.pushNamed(context, '/artist-detail', arguments: data['artistID']['_id']);
        }),
        const SizedBox(height: 6),
        _buildClickableText('Genre: $genreName', Colors.black54, 15, () {
          Navigator.pushNamed(context, '/genre-detail', 
              arguments: {'id': data['genreID']['_id'], 'name': genreName});
        }),
        const SizedBox(height: 16),
        Text('${data['price']?.toString() ?? '—'} ${data['currency'] ?? 'VND'}',
            style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        Text(stock > 0 ? 'In Stock: $stock' : 'SOLD OUT',
            style: TextStyle(
              color: stock > 0 ? Colors.green : Colors.red, 
              fontWeight: FontWeight.bold,
              fontSize: 16
            )),
      ],
    );
  }

  Widget _buildClickableText(String text, Color color, double size, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Text(text, style: TextStyle(
        fontSize: size, 
        color: color, 
        fontWeight: FontWeight.w500,
        decoration: TextDecoration.none
      )),
    );
  }

  Widget _buildMainInfo(Map<String, dynamic> data, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 10),
          _buildDetailRow('Format', data['format']),
          _buildDetailRow('SKU', data['sku']),
          const SizedBox(height: 30),
          const Text('Description', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(data['description'] ?? 'No description available.',
              style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87)),
          
          if ((data['stock'] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    minimumSize: Size(isDesktop ? 400 : double.infinity, 64),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    elevation: 4,
                  ),
                  onPressed: () {
                    Provider.of<AuthProvider>(context, listen: false).addToCart(data);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Added to cart!'), duration: Duration(seconds: 1))
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
            ),
        ],
      ),
    );
  }

  Widget _buildSocialLinks(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        border: Border.symmetric(horizontal: BorderSide(color: Colors.grey[200]!))
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (data['spotify'] != null) 
            _socialIcon(Icons.music_note, const Color(0xFF1DB954), () => _launchURL(data['spotify'])),
          if (data['spotify'] != null && data['youtube'] != null) const SizedBox(width: 60),
          if (data['youtube'] != null) 
            _socialIcon(Icons.play_circle_fill, const Color(0xFFFF0000), () => _launchURL(data['youtube'])),
        ],
      ),
    );
  }

  Widget _socialIcon(IconData icon, Color color, VoidCallback onPress) => 
      InkWell(onTap: onPress, child: Icon(icon, size: 44, color: color));

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
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
        const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 60)),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), 
          child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))
        ),
        AlbumRow(albums: data, artists: artists, genres: genres),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _buildCommentsSection() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 30),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Divider(height: 60),
          const Text('Reviews & Ratings', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),

          // Comment Form
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey[300]!),
              borderRadius: BorderRadius.circular(12),
              color: Colors.grey[50],
            ),
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Add Your Review', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: _commentController,
                  maxLines: 4,
                  decoration: InputDecoration(
                    hintText: 'Share your thoughts about this album...',
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.all(12),
                  ),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    // Star selector for rating
                    Row(
                      children: List.generate(5, (i) {
                        final idx = i + 1;
                        return InkWell(
                          onTap: () {
                            setState(() => _selectedRating = idx);
                          },
                          child: Icon(
                            idx <= _selectedRating ? Icons.star : Icons.star_border,
                            color: Colors.amber,
                            size: 28,
                          ),
                        );
                      }),
                    ),
                    const Spacer(),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                      ),
                      onPressed: _isSubmittingComment ? null : _submitComment,
                      child: _isSubmittingComment
                          ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                          : const Text('Post Review', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Comments List
          if (comments.isEmpty)
            Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 20),
                child: Text('No reviews yet. Be the first to review!', style: TextStyle(color: Colors.grey[600], fontSize: 14)),
              ),
            )
          else
            Column(
              children: comments.map<Widget>((comment) {
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.grey[200]!),
                    borderRadius: BorderRadius.circular(8),
                    color: Colors.white,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            comment['username'] ?? 'Anonymous',
                            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                          ),
                          Row(
                            children: List.generate(5, (index) {
                              final rating = comment['rating'] ?? 5;
                              return Icon(
                                index < rating ? Icons.star : Icons.star_border,
                                color: Colors.amber,
                                size: 16,
                              );
                            }),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        comment['content'] ?? '',
                        style: const TextStyle(fontSize: 14, color: Colors.black87),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        comment['createdAt'] != null
                            ? _formatDate(comment['createdAt'])
                            : '',
                        style: TextStyle(fontSize: 12, color: Colors.grey[600]),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
        ],
      ),
    );
  }

  String _formatDate(String dateString) {
    try {
      final date = DateTime.parse(dateString);
      final now = DateTime.now();
      final difference = now.difference(date);

      if (difference.inDays == 0) {
        if (difference.inHours == 0) {
          return '${difference.inMinutes} minutes ago';
        }
        return '${difference.inHours} hours ago';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} days ago';
      } else {
        return '${date.day}/${date.month}/${date.year}';
      }
    } catch (e) {
      return '';
    }
  }
}