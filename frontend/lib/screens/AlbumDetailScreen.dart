import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart'; // Required for brand icons
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
  List<dynamic> artistAlbums = [];
  List<dynamic> genreAlbums = [];
  List<dynamic> artists = [];
  List<dynamic> genres = [];
  List<dynamic> comments = [];

  final TextEditingController _commentController = TextEditingController();
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, bool> _showReply = {};

  int _selectedRating = 5;
  bool _isSubmittingComment = false;
  bool isLoading = true;
  String? error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _commentController.dispose();
    for (final c in _replyControllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _loadData() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final String apiUrl = auth.apiUrl;

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

        _fetchComments();

        final String? genreId = fetchedAlbum['genreID'] is Map ? fetchedAlbum['genreID']['_id'] : fetchedAlbum['genreID'];
        final String? artistId = fetchedAlbum['artistID'] is Map ? fetchedAlbum['artistID']['_id'] : fetchedAlbum['artistID'];

        await Future.wait([
          if (artistId != null)
            http.get(Uri.parse('$apiUrl/api/albums/artist/$artistId?exclude=${widget.albumId}')).then((res) {
              if (mounted) setState(() => artistAlbums = json.decode(res.body));
            }),
          if (genreId != null)
            http.get(Uri.parse('$apiUrl/api/albums/genre/$genreId?exclude=${widget.albumId}')).then((res) {
              if (mounted) setState(() => genreAlbums = json.decode(res.body));
            }),
        ]);
      }
    } catch (e) {
      if (mounted) setState(() => error = 'Could not load album details.');
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  Future<void> _fetchComments() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.get(Uri.parse('${auth.apiUrl}/api/comments/album/${widget.albumId}'));
      if (res.statusCode == 200 && mounted) {
        setState(() => comments = json.decode(res.body));
      }
    } catch (e) {
      debugPrint("Comment fetch error: $e");
    }
  }

  Future<void> _submitComment({String? parentId}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final String content = (parentId == null ? _commentController.text : (_replyControllers[parentId]?.text ?? '')).trim();

    if (content.isEmpty || auth.user == null) return;

    setState(() => _isSubmittingComment = true);

    try {
      final body = {
        'albumId': widget.albumId,
        'userId': auth.user?['_id'] ?? auth.user?['id'],
        'username': auth.user?['name'] ?? 'User',
        'role': auth.user?['role'] ?? 'customer',
        'content': content,
        'rating': parentId == null ? _selectedRating : 5,
      };
      if (parentId != null) body['parentId'] = parentId;

      final res = await http.post(Uri.parse('${auth.apiUrl}/api/comments'), headers: {'Content-Type': 'application/json'}, body: json.encode(body));

      if (res.statusCode == 201) {
        if (parentId == null) {
          _commentController.clear();
        } else {
          _replyControllers[parentId]?.clear();
          _showReply[parentId!] = false;
        }
        _fetchComments();
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      setState(() => _isSubmittingComment = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator(color: Colors.black)));
    if (error != null) return Scaffold(body: Center(child: Text(error!)));

    final currentAlbum = album!;
    double screenWidth = MediaQuery.of(context).size.width;
    bool isDesktop = screenWidth > 900;

    // Resolve Genre Name
    String genreName = "Genre";
    if (currentAlbum['genreID'] is Map) {
      genreName = currentAlbum['genreID']['name'] ?? "Genre";
    } else {
      final genreData = genres.firstWhere((g) => g['_id'] == currentAlbum['genreID'], orElse: () => null);
      if (genreData != null) genreName = genreData['name'];
    }

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Column(
          children: [
            Navbar(showSearch: false, searchText: '', setSearchText: (val) {}),
            Expanded(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? screenWidth * 0.12 : 20, vertical: 30),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    isDesktop ? _buildDesktopHeader(currentAlbum, genreName) : _buildMobileHeader(currentAlbum, genreName),
                    const Divider(height: 80, thickness: 1),
                    _buildCommentsSection(),
                    const SizedBox(height: 60),
                    if (artistAlbums.isNotEmpty) _buildRecommendationSection('More from ${currentAlbum['artistID']['name']}', artistAlbums),
                    if (genreAlbums.isNotEmpty) ...[
                      const SizedBox(height: 40),
                      _buildRecommendationSection('More $genreName Albums', genreAlbums),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDesktopHeader(Map<String, dynamic> data, String genreName) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildAlbumImage(data['image'], 400),
        const SizedBox(width: 50),
        Expanded(child: _buildHeaderInfo(data, genreName, true)),
      ],
    );
  }

  Widget _buildMobileHeader(Map<String, dynamic> data, String genreName) {
    return Column(
      children: [
        _buildAlbumImage(data['image'], screenWidth(context) * 0.8),
        const SizedBox(height: 30),
        _buildHeaderInfo(data, genreName, false),
      ],
    );
  }

  Widget _buildAlbumImage(String? imageUrl, double size) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.1), blurRadius: 15, offset: const Offset(0, 5))],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          imageUrl ?? 'https://via.placeholder.com/400',
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => Icon(Icons.broken_image, size: size),
        ),
      ),
    );
  }

  Widget _buildHeaderInfo(Map<String, dynamic> data, String genreName, bool isDesktop) {
    final String artistName = data['artistID']['name'] ?? 'Unknown Artist';
    final String artistId = data['artistID']['_id'] ?? data['artistID'];

    return Column(
      crossAxisAlignment: isDesktop ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(data['name'] ?? 'No Name', textAlign: isDesktop ? TextAlign.left : TextAlign.center, style: TextStyle(fontSize: isDesktop ? 40 : 28, fontWeight: FontWeight.bold, letterSpacing: -1)),
        const SizedBox(height: 10),
        InkWell(
          onTap: () => Navigator.pushNamed(context, '/artist-detail', arguments: artistId),
          child: Text(artistName, style: const TextStyle(fontSize: 20, color: Colors.blueAccent, fontWeight: FontWeight.w600, decoration: TextDecoration.underline)),
        ),
        const SizedBox(height: 20),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          alignment: isDesktop ? WrapAlignment.start : WrapAlignment.center,
          children: [
            _buildBadge(Icons.label, genreName, color: Colors.deepPurple), // Genre Badge
            _buildBadge(Icons.qr_code, data['sku'] ?? 'N/A'),
            _buildBadge(Icons.album, data['format'] ?? 'Vinyl'),
          ],
        ),
        const SizedBox(height: 25),
        Text('${NumberFormat('#,###').format(data['price'])} ${data['currency'] ?? 'VND'}', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
        const SizedBox(height: 30),
        Row(
          mainAxisAlignment: isDesktop ? MainAxisAlignment.start : MainAxisAlignment.center,
          children: [
            if (data['spotify'] != null) _buildSocialIcon(data['spotify'], FontAwesomeIcons.spotify, Colors.green),
            const SizedBox(width: 25),
            if (data['youtube'] != null) _buildSocialIcon(data['youtube'], FontAwesomeIcons.youtube, Colors.red),
          ],
        ),
        const SizedBox(height: 30),
        const Text('About this album', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(data['description'] ?? 'No description.', textAlign: isDesktop ? TextAlign.left : TextAlign.center, style: const TextStyle(fontSize: 16, height: 1.6, color: Colors.black87)),
        const SizedBox(height: 40),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 60), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
          onPressed: () {
            Provider.of<AuthProvider>(context, listen: false).addToCart(data);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart!')));
          },
          child: const Text('ADD TO CART', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        )
      ],
    );
  }

  Widget _buildBadge(IconData icon, String label, {Color color = Colors.grey}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.2))),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: color, fontWeight: FontWeight.bold)),
        ],
      ),
    );
  }

  Widget _buildSocialIcon(String url, IconData icon, Color color) {
    return InkWell(
      onTap: () async {
        final uri = Uri.parse(url);
        if (await canLaunchUrl(uri)) await launchUrl(uri);
      },
      child: FaIcon(icon, color: color, size: 32),
    );
  }

  Widget _buildCommentsSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Reviews & Community', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 24),
        _buildMainCommentForm(),
        const SizedBox(height: 40),
        if (comments.isEmpty) const Center(child: Text('No reviews yet. Be the first!')) else ..._buildCommentTree(),
      ],
    );
  }

  Widget _buildMainCommentForm() {
    final auth = Provider.of<AuthProvider>(context);
    if (auth.user == null) return const Text("Login to join the discussion.");

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        children: [
          Row(
            children: List.generate(
                5,
                (i) => IconButton(
                      onPressed: () => setState(() => _selectedRating = i + 1),
                      icon: Icon(i < _selectedRating ? Icons.star : Icons.star_border, color: Colors.amber),
                    )),
          ),
          TextField(controller: _commentController, maxLines: 3, decoration: const InputDecoration(hintText: 'Write a review...', border: InputBorder.none)),
          Align(
            alignment: Alignment.centerRight,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
              onPressed: _isSubmittingComment ? null : () => _submitComment(),
              child: const Text('Post Review', style: TextStyle(color: Colors.white)),
            ),
          )
        ],
      ),
    );
  }

  List<Widget> _buildCommentTree() {
    final Map<String, List<Map<String, dynamic>>> childrenMap = {};
    final List<Map<String, dynamic>> roots = [];

    for (var c in comments) {
      if (c['parentId'] == null) {
        roots.add(c);
      } else {
        final pid = c['parentId'].toString();
        childrenMap.putIfAbsent(pid, () => []).add(c);
      }
    }

    return roots.map((root) => _buildCommentNode(root, childrenMap)).toList();
  }

  Widget _buildCommentNode(Map<String, dynamic> node, Map<String, List<Map<String, dynamic>>> childrenMap) {
    final String id = node['_id'];
    final List<Map<String, dynamic>> replies = childrenMap[id] ?? [];

    _replyControllers.putIfAbsent(id, () => TextEditingController());
    _showReply.putIfAbsent(id, () => false);

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildCommentBubble(node, false),
          Padding(
            padding: const EdgeInsets.only(left: 12),
            child: TextButton(
              onPressed: () => setState(() => _showReply[id] = !_showReply[id]!),
              child: Text(_showReply[id]! ? 'Cancel' : 'Reply', style: const TextStyle(fontSize: 13, color: Colors.blueGrey)),
            ),
          ),
          if (_showReply[id] == true)
            Padding(
              padding: const EdgeInsets.only(left: 40, bottom: 16),
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _replyControllers[id], decoration: const InputDecoration(hintText: 'Write a reply...'))),
                  IconButton(icon: const Icon(Icons.send), onPressed: () => _submitComment(parentId: id)),
                ],
              ),
            ),
          ...replies.map((reply) => Padding(
                padding: const EdgeInsets.only(left: 40, top: 8),
                child: _buildCommentBubble(reply, true),
              )),
        ],
      ),
    );
  }

  Widget _buildCommentBubble(Map<String, dynamic> data, bool isReply) {
    final bool isAdmin = data['role'] == 'admin';

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isAdmin ? Colors.blue.shade50 : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: isAdmin ? Colors.blue.shade100 : Colors.grey.shade200),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(data['username'], style: TextStyle(fontWeight: FontWeight.bold, color: isAdmin ? Colors.blue.shade800 : Colors.black)),
              if (isAdmin)
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
                  child: const Text("ADMIN", style: TextStyle(color: Colors.white, fontSize: 10)),
                ),
              const Spacer(),
              Text(_formatDate(data['createdAt']), style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          if (!isAdmin && !isReply) Row(children: List.generate(5, (i) => Icon(Icons.star, size: 12, color: i < (data['rating'] ?? 5) ? Colors.amber : Colors.grey))),
          const SizedBox(height: 6),
          Text(data['content'] ?? '', style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  String _formatDate(String dateStr) {
    try {
      final date = DateTime.parse(dateStr);
      return DateFormat('dd/MM HH:mm').format(date);
    } catch (e) {
      return '';
    }
  }

  double screenWidth(BuildContext context) => MediaQuery.of(context).size.width;

  Widget _buildRecommendationSection(String title, List<dynamic> data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 20),
        AlbumRow(albums: data, artists: artists, genres: genres),
      ],
    );
  }
}