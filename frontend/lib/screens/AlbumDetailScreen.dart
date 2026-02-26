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
  double _selectedRating = 5;
  bool isLoading = true;
  String? error;
  int? _filterRating; // null = all
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

        final String? genreId = fetchedAlbum['genreID'] is Map
            ? fetchedAlbum['genreID']['_id']
            : fetchedAlbum['genreID'];
        final String? artistId = fetchedAlbum['artistID'] is Map
            ? fetchedAlbum['artistID']['_id']
            : fetchedAlbum['artistID'];

        if (genreId != null) {
          final recRes = await http.get(
            Uri.parse(
              '$apiUrl/api/albums/genre/$genreId?exclude=${widget.albumId}',
            ),
          );
          if (mounted)
            setState(() => recommendedAlbums = json.decode(recRes.body));
        }

        if (artistId != null) {
          final artRes = await http.get(
            Uri.parse(
              '$apiUrl/api/albums/artist/$artistId?exclude=${widget.albumId}',
            ),
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

  Future<void> _submitComment() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    if (!auth.isAuthenticated || auth.user?['_id'] == null) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Please login again')));
      return;
    }

    String content = _commentController.text.trim();
    if (content.isEmpty) return;

    print("Sending comment with userId: ${auth.user!['_id']}");

    final response = await http.post(
      Uri.parse('${auth.apiUrl}/api/comments'),
      headers: {'Content-Type': 'application/json'},
      body: json.encode({
        'albumId': widget.albumId,
        'userId': auth.user!['_id'],
        'content': content,
        if (replyingToId != null) 'parentId': replyingToId,
        if (replyingToId == null) 'rating': _selectedRating.toInt(),
      }),
    );

    print("Status: ${response.statusCode}");
    print("Body: ${response.body}");
  }

  Future<void> _launchURL(String urlString) async {
    final Uri url = Uri.parse(urlString);
    if (!await launchUrl(url, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Could not launch URL')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading)
      return const Scaffold(
        body: Center(child: CircularProgressIndicator(color: Colors.black)),
      );

    if (error != null || album == null) {
      return Scaffold(
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                error ?? 'Album not found',
                style: const TextStyle(color: Colors.red),
              ),
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
                  vertical: 20,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    isDesktop
                        ? _buildDesktopHeader(currentAlbum)
                        : _buildMobileHeader(currentAlbum),
                    if (currentAlbum['spotify'] != null ||
                        currentAlbum['youtube'] != null)
                      _buildSocialLinks(currentAlbum),
                    _buildMainInfo(currentAlbum, isDesktop),

                    const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 20),
                      child: Divider(height: 60, thickness: 1),
                    ),

                    // --- COMMENT SECTION ---
                    _buildCommentSection(),

                    if (artistAlbums.isNotEmpty)
                      _buildRecommendationSection(
                        'More from ${currentAlbum['artistID']['name']}',
                        artistAlbums,
                      ),
                    if (recommendedAlbums.isNotEmpty)
                      _buildRecommendationSection(
                        'Recommended for you',
                        recommendedAlbums,
                      ),
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
    // Chỉ lấy comment cha
    final parentComments = comments
        .where((c) => c['parentId'] == null)
        .toList();

    // Filter theo số sao nếu có chọn
    final filteredComments = _filterRating == null
        ? parentComments
        : parentComments.where((c) => c['rating'] == _filterRating).toList();

    // Tính average rating
    double averageRating = 0;

    if (parentComments.isNotEmpty) {
      final total = parentComments.fold<double>(
        0.0,
        (sum, c) => sum + ((c['rating'] ?? 0) as num).toDouble(),
      );

      averageRating = total / parentComments.length;
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 10),

          /// ⭐ SUMMARY SECTION
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Text(
                averageRating.toStringAsFixed(1),
                style: const TextStyle(
                  fontSize: 36,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.star, color: Colors.amber, size: 32),
              const SizedBox(width: 12),
              Text(
                "(${parentComments.length} reviews)",
                style: const TextStyle(color: Colors.grey),
              ),
            ],
          ),

          const SizedBox(height: 20),

          /// ⭐ FILTER BUTTONS
          Wrap(
            spacing: 10,
            children: [
              _buildFilterChip("All", null),
              for (int i = 5; i >= 1; i--) _buildFilterChip("$i★", i),
            ],
          ),

          const SizedBox(height: 25),

          /// COMMENT INPUT
          _buildCommentInput(),

          const SizedBox(height: 30),

          if (filteredComments.isEmpty)
            const Center(
              child: Padding(
                padding: EdgeInsets.all(20.0),
                child: Text(
                  'No reviews yet.',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ),

          ...filteredComments
              .map((comment) => _buildSingleComment(comment))
              .toList(),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, int? value) {
    final bool isSelected = _filterRating == value;

    return ChoiceChip(
      label: Text(label),
      selected: isSelected,
      selectedColor: Colors.black,
      labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black),
      onSelected: (_) {
        setState(() {
          _filterRating = value;
        });
      },
    );
  }

  Widget _buildCommentInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[50],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (replyingToId != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Text(
                    'Replying to $replyingToName',
                    style: const TextStyle(
                      color: Colors.blue,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    onTap: () {
                      setState(() {
                        replyingToId = null;
                        replyingToName = null;
                      });
                    },
                    child: const Icon(Icons.close, color: Colors.red),
                  ),
                ],
              ),
            ),

          if (replyingToId == null) ...[
            const Text(
              "Your Rating",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Row(
              children: List.generate(5, (index) {
                return IconButton(
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    index < _selectedRating ? Icons.star : Icons.star_border,
                    color: Colors.amber,
                  ),
                  onPressed: () {
                    setState(() {
                      _selectedRating = index + 1;
                    });
                  },
                );
              }),
            ),
            const SizedBox(height: 12),
          ],

          TextField(
            controller: _commentController,
            focusNode: _commentFocusNode,
            maxLines: null,
            decoration: InputDecoration(
              hintText: replyingToId == null
                  ? 'Write your review...'
                  : 'Write a reply...',
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
    final replies = comments
        .where((c) => c['parentId'] == comment['_id'])
        .toList();

    return Container(
      margin: const EdgeInsets.only(bottom: 30),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[300]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // USERNAME + DATE
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                comment['username'] ?? 'User',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              Text(
                comment['createdAt'].toString().split('T')[0],
                style: const TextStyle(fontSize: 12, color: Colors.grey),
              ),
            ],
          ),

          const SizedBox(height: 6),

          // RATING (only parent comment)
          if (comment['rating'] != null)
            Row(
              children: List.generate(5, (index) {
                return Icon(
                  index < comment['rating'] ? Icons.star : Icons.star_border,
                  color: Colors.amber,
                  size: 18,
                );
              }),
            ),

          const SizedBox(height: 10),

          // CONTENT
          Text(
            comment['content'] ?? '',
            style: const TextStyle(fontSize: 15, height: 1.5),
          ),

          const SizedBox(height: 10),

          // REPLY BUTTON
          InkWell(
            onTap: () {
              setState(() {
                replyingToId = comment['_id'];
                replyingToName = comment['username'];
              });
              _commentFocusNode.requestFocus();
            },
            child: const Text(
              "Reply",
              style: TextStyle(color: Colors.blue, fontWeight: FontWeight.w600),
            ),
          ),

          // REPLY BOX SECTION
          if (replies.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: Colors.grey[100],
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                children: replies.map((reply) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: Colors.grey[300]!),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        /// USERNAME + DATE
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              reply['username'] ?? 'User',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              reply['createdAt'].toString().split('T')[0],
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 6),

                        /// CONTENT
                        Text(
                          reply['content'] ?? '',
                          style: const TextStyle(fontSize: 14, height: 1.4),
                        ),
                      ],
                    ),
                  );
                }).toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
  // --- EXISTING UI COMPONENTS ---

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
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) =>
            Icon(Icons.broken_image, size: size),
      ),
    );
  }

  Widget _buildHeaderInfo(Map<String, dynamic> data, bool isDesktop) {
    final String artistName = data['artistID'] != null
        ? data['artistID']['name']
        : 'Unknown Artist';
    final String genreName = data['genreID'] != null
        ? data['genreID']['name']
        : 'Genre';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          data['name'] ?? 'No Name',
          style: TextStyle(
            fontSize: isDesktop ? 36 : 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 12),
        _buildClickableText(artistName, Colors.blueAccent, 18, () {
          Navigator.pushNamed(
            context,
            '/artist-detail',
            arguments: data['artistID']['_id'],
          );
        }),
        const SizedBox(height: 6),
        _buildClickableText('Genre: $genreName', Colors.black54, 15, () {
          Navigator.pushNamed(
            context,
            '/genre-detail',
            arguments: {'id': data['genreID']['_id'], 'name': genreName},
          );
        }),
        const SizedBox(height: 16),
        Text(
          '${data['price']?.toString() ?? '—'} ${data['currency'] ?? 'VND'}',
          style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        Text(
          (data['stock'] ?? 0) > 0 ? 'Stock: ${data['stock']}' : 'OUT OF STOCK',
          style: TextStyle(
            color: (data['stock'] ?? 0) > 0 ? Colors.green : Colors.red,
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
      ],
    );
  }

  Widget _buildClickableText(
    String text,
    Color color,
    double size,
    VoidCallback onTap,
  ) {
    return InkWell(
      onTap: onTap,
      child: Text(
        text,
        style: TextStyle(
          fontSize: size,
          color: color,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  Widget _buildMainInfo(Map<String, dynamic> data, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.all(20.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Details',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 10),
          _buildDetailRow('Format', data['format']),
          _buildDetailRow('SKU', data['sku']),
          const SizedBox(height: 30),
          const Text(
            'Description',
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          Text(
            data['description'] ?? 'No description available.',
            style: const TextStyle(
              fontSize: 16,
              height: 1.6,
              color: Colors.black87,
            ),
          ),
          if ((data['stock'] ?? 0) > 0)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Center(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    minimumSize: Size(isDesktop ? 400 : double.infinity, 64),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  onPressed: () {
                    Provider.of<AuthProvider>(
                      context,
                      listen: false,
                    ).addToCart(data);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Added to cart!'),
                        duration: Duration(seconds: 1),
                      ),
                    );
                  },
                  child: const Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.shopping_cart_outlined, color: Colors.white),
                      SizedBox(width: 12),
                      Text(
                        'ADD TO CART',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
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
        border: Border.symmetric(
          horizontal: BorderSide(color: Colors.grey[200]!),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (data['spotify'] != null)
            _socialIcon(
              Icons.music_note,
              const Color(0xFF1DB954),
              () => _launchURL(data['spotify']),
            ),
          if (data['spotify'] != null && data['youtube'] != null)
            const SizedBox(width: 60),
          if (data['youtube'] != null)
            _socialIcon(
              Icons.play_circle_fill,
              const Color(0xFFFF0000),
              () => _launchURL(data['youtube']),
            ),
        ],
      ),
    );
  }

  Widget _socialIcon(IconData icon, Color color, VoidCallback onPress) =>
      InkWell(
        onTap: onPress,
        child: Icon(icon, size: 44, color: color),
      );

  Widget _buildDetailRow(String label, dynamic value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 16,
              color: Colors.grey,
              fontWeight: FontWeight.w500,
            ),
          ),
          Text(
            value?.toString() ?? '—',
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildRecommendationSection(String title, List<dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20),
          child: Divider(height: 60),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Text(
            title,
            style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
        ),
        AlbumRow(albums: data, artists: artists, genres: genres),
        const SizedBox(height: 30),
      ],
    );
  }
}
