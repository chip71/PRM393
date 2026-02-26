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
  
  // Comment States
  List<dynamic> comments = [];
  final TextEditingController _commentController = TextEditingController();
  final FocusNode _commentFocusNode = FocusNode();
  String? replyingToId;
  String? replyingToName;

  bool isLoading = true;
  String? error;

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
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final String apiUrl = auth.apiUrl;

    try {
      if (!mounted) return;
      setState(() => isLoading = true);

      // Fetch Album, Meta Data, and Comments in parallel
      final responses = await Future.wait([
        http.get(Uri.parse('$apiUrl/api/albums/${widget.albumId}')),
        http.get(Uri.parse('$apiUrl/api/artists')),
        http.get(Uri.parse('$apiUrl/api/genres')),
        http.get(Uri.parse('$apiUrl/api/comments/album/${widget.albumId}')),
      ]);

      if (responses[0].statusCode != 200) throw Exception('Album not found');

      if (mounted) {
        final fetchedAlbum = json.decode(responses[0].body);
        setState(() {
          album = fetchedAlbum;
          artists = json.decode(responses[1].body);
          genres = json.decode(responses[2].body);
          comments = json.decode(responses[3].body);
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
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Could not load album details.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _submitComment() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (!auth.isAuthenticated) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please login to comment')));
      return;
    }

    String content = _commentController.text.trim();
    if (content.isEmpty) return;

    try {
      final response = await http.post(
        Uri.parse('${auth.apiUrl}/api/comments'),
        headers: {'Content-Type': 'application/json'},
        body: json.encode({
          'albumId': widget.albumId,
          'userId': auth.user?['_id'],
          'username': auth.user?['username'] ?? 'User',
          'content': content,
          'parentId': replyingToId,
          'role': auth.user?['role'] ?? 'customer',
        }),
      );

      if (response.statusCode == 201) {
        _commentController.clear();
        setState(() {
          replyingToId = null;
          replyingToName = null;
        });
        _loadData(); // Refresh list
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Error posting comment')));
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

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.black)));

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
                    isDesktop ? _buildDesktopHeader(currentAlbum) : _buildMobileHeader(currentAlbum),
                    if (currentAlbum['spotify'] != null || currentAlbum['youtube'] != null)
                      _buildSocialLinks(currentAlbum),
                    _buildMainInfo(currentAlbum, isDesktop),
                    
                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(height: 60, thickness: 1),
                    ),

                    // --- COMMENT SECTION ---
                    _buildCommentSection(),

                    if (artistAlbums.isNotEmpty)
                      _buildRecommendationSection('More from ${currentAlbum['artistID']['name']}', artistAlbums),
                    if (recommendedAlbums.isNotEmpty)
                      _buildRecommendationSection('Recommended for you', recommendedAlbums),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCommentSection() {
    // Only get top-level comments (those without a parent)
    final parentComments = comments.where((c) => c['parentId'] == null).toList();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reviews (${comments.length})', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 20),
          _buildCommentInput(),
          const SizedBox(height: 30),
          if (parentComments.isEmpty)
            const Center(child: Padding(
              padding: EdgeInsets.all(20.0),
              child: Text('No reviews yet. Be the first to comment!', style: TextStyle(color: Colors.grey)),
            )),
          ...parentComments.map((comment) => _buildSingleComment(comment)).toList(),
        ],
      ),
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          if (replyingToId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  const Icon(Icons.reply, size: 16, color: Colors.blue),
                  const SizedBox(width: 5),
                  Text('Replying to $replyingToName', style: const TextStyle(fontSize: 12, color: Colors.blue, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  GestureDetector(
                    onTap: () => setState(() { replyingToId = null; replyingToName = null; }),
                    child: const Icon(Icons.close, size: 16, color: Colors.red),
                  )
                ],
              ),
            ),
          TextField(
            controller: _commentController,
            focusNode: _commentFocusNode,
            maxLines: null,
            decoration: InputDecoration(
              hintText: replyingToId == null ? 'Write a review...' : 'Write a reply...',
              border: InputBorder.none,
              suffixIcon: IconButton(
                icon: const Icon(Icons.send, color: Colors.black),
                onPressed: _submitComment,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleComment(Map<String, dynamic> comment) {
    // Get replies for THIS specific comment
    final replies = comments.where((c) => c['parentId'] == comment['_id']).toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 18,
                backgroundColor: Colors.black87,
                child: Text(comment['username']?[0].toUpperCase() ?? 'U', style: const TextStyle(color: Colors.white, fontSize: 14)),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(comment['username'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold)),
                  Text(comment['createdAt'].toString().split('T')[0], style: const TextStyle(color: Colors.grey, fontSize: 11)),
                ],
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.only(left: 48, top: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(comment['content'] ?? '', style: const TextStyle(fontSize: 15, height: 1.4)),
                const SizedBox(height: 4),
                InkWell(
                  onTap: () {
                    setState(() {
                      replyingToId = comment['_id'];
                      replyingToName = comment['username'];
                    });
                    _commentFocusNode.requestFocus();
                  },
                  child: const Padding(
                    padding: EdgeInsets.symmetric(vertical: 4),
                    child: Text('Reply', style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600, fontSize: 13)),
                  ),
                ),
                
                // Nested Replies Section
                if (replies.isNotEmpty)
                  ...replies.map((reply) => Container(
                    margin: const EdgeInsets.only(top: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.grey[200]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(reply['username'] ?? 'User', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                            if (reply['role'] == 'admin')
                              Container(
                                margin: const EdgeInsets.only(left: 6),
                                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                decoration: BoxDecoration(color: Colors.redAccent, borderRadius: BorderRadius.circular(4)),
                                child: const Text('SELLER', style: TextStyle(color: Colors.white, fontSize: 9, fontWeight: FontWeight.bold)),
                              ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(reply['content'] ?? '', style: const TextStyle(fontSize: 14)),
                      ],
                    ),
                  )).toList(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- EXISTING UI COMPONENTS ---

  Widget _buildDesktopHeader(Map<String, dynamic> data) {
    return Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildAlbumImage(data['image'], 300),
      const SizedBox(width: 40),
      Expanded(child: _buildHeaderInfo(data, true)),
    ]);
  }

  Widget _buildMobileHeader(Map<String, dynamic> data) {
    return Padding(padding: const EdgeInsets.all(20.0), child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _buildAlbumImage(data['image'], 150),
      const SizedBox(width: 20),
      Expanded(child: _buildHeaderInfo(data, false)),
    ]));
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
    final String artistName = data['artistID'] != null ? data['artistID']['name'] : 'Unknown Artist';
    final String genreName = data['genreID'] != null ? data['genreID']['name'] : 'Genre';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(data['name'] ?? 'No Name', style: TextStyle(fontSize: isDesktop ? 36 : 24, fontWeight: FontWeight.bold)),
      const SizedBox(height: 12),
      _buildClickableText(artistName, Colors.blueAccent, 18, () {
        Navigator.pushNamed(context, '/artist-detail', arguments: data['artistID']['_id']);
      }),
      const SizedBox(height: 6),
      _buildClickableText('Genre: $genreName', Colors.black54, 15, () {
        Navigator.pushNamed(context, '/genre-detail', arguments: {'id': data['genreID']['_id'], 'name': genreName});
      }),
      const SizedBox(height: 16),
      Text('${data['price']?.toString() ?? '—'} ${data['currency'] ?? 'VND'}', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      const SizedBox(height: 8),
      Text((data['stock'] ?? 0) > 0 ? 'Stock: ${data['stock']}' : 'OUT OF STOCK', 
        style: TextStyle(color: (data['stock'] ?? 0) > 0 ? Colors.green : Colors.red, fontWeight: FontWeight.bold, fontSize: 16)),
    ]);
  }

  Widget _buildClickableText(String text, Color color, double size, VoidCallback onTap) {
    return InkWell(onTap: onTap, child: Text(text, style: TextStyle(fontSize: size, color: color, fontWeight: FontWeight.w500)));
  }

  Widget _buildMainInfo(Map<String, dynamic> data, bool isDesktop) {
    return Padding(padding: const EdgeInsets.all(20.0), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Text('Details', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 10),
      _buildDetailRow('Format', data['format']),
      _buildDetailRow('SKU', data['sku']),
      const SizedBox(height: 30),
      const Text('Description', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
      const SizedBox(height: 8),
      Text(data['description'] ?? 'No description available.', style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87)),
      if ((data['stock'] ?? 0) > 0)
        Padding(padding: const EdgeInsets.only(top: 40), child: Center(child: ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: Size(isDesktop ? 400 : double.infinity, 64), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16))),
          onPressed: () {
            Provider.of<AuthProvider>(context, listen: false).addToCart(data);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart!'), duration: Duration(seconds: 1)));
          },
          child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.shopping_cart_outlined, color: Colors.white),
            SizedBox(width: 12),
            Text('ADD TO CART', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
          ]),
        ))),
    ]));
  }

  Widget _buildSocialLinks(Map<String, dynamic> data) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 20),
      padding: const EdgeInsets.symmetric(vertical: 24),
      decoration: BoxDecoration(color: Colors.grey[50], border: Border.symmetric(horizontal: BorderSide(color: Colors.grey[200]!))),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        if (data['spotify'] != null) _socialIcon(Icons.music_note, const Color(0xFF1DB954), () => _launchURL(data['spotify'])),
        if (data['spotify'] != null && data['youtube'] != null) const SizedBox(width: 60),
        if (data['youtube'] != null) _socialIcon(Icons.play_circle_fill, const Color(0xFFFF0000), () => _launchURL(data['youtube'])),
      ]),
    );
  }

  Widget _socialIcon(IconData icon, Color color, VoidCallback onPress) => InkWell(onTap: onPress, child: Icon(icon, size: 44, color: color));

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(label, style: const TextStyle(fontSize: 16, color: Colors.grey, fontWeight: FontWeight.w500)),
      Text(value?.toString() ?? '—', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
    ]));
  }

  Widget _buildRecommendationSection(String title, List<dynamic> data) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const Padding(padding: EdgeInsets.symmetric(horizontal: 20), child: Divider(height: 60)),
      Padding(padding: const EdgeInsets.fromLTRB(20, 0, 20, 20), child: Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold))),
      AlbumRow(albums: data, artists: artists, genres: genres),
      const SizedBox(height: 30),
    ]);
  }
}