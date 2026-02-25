import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
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
    for (final c in _replyControllers.values) { c.dispose(); }
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

  Future<void> _fetchComments() async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.get(Uri.parse('${auth.apiUrl}/api/comments/album/${widget.albumId}'));
      if (res.statusCode == 200 && mounted) {
        setState(() => comments = json.decode(res.body));
      }
    } catch (e) { debugPrint("Comment fetch error: $e"); }
  }

  Future<void> _submitComment({String? parentId}) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final String content = (parentId == null 
        ? _commentController.text 
        : (_replyControllers[parentId]?.text ?? '')).trim();

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

      final res = await http.post(
        Uri.parse('${auth.apiUrl}/api/comments'), 
        headers: {'Content-Type': 'application/json'}, 
        body: json.encode(body)
      );

      if (res.statusCode == 201) {
        if (parentId == null) _commentController.clear(); 
        else {
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
    if (isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
                padding: EdgeInsets.symmetric(horizontal: isDesktop ? screenWidth * 0.1 : 20, vertical: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    isDesktop ? _buildDesktopHeader(currentAlbum) : _buildMobileHeader(currentAlbum),
                    _buildMainInfo(currentAlbum, isDesktop),
                    const Divider(height: 80),
                    _buildCommentsSection(),
                    const SizedBox(height: 50),
                    if (artistAlbums.isNotEmpty)
                      _buildRecommendationSection('More from ${currentAlbum['artistID']['name']}', artistAlbums),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
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
        if (comments.isEmpty)
          const Center(child: Text('No reviews yet. Be the first!'))
        else
          ..._buildCommentTree(),
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
            children: List.generate(5, (i) => IconButton(
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
    final String id = node['_id'] ?? node['id'];
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

          // ✅ PHẦN LÙI DÒNG CHO PHẢN HỒI
          ...replies.map((reply) => Padding(
            padding: const EdgeInsets.only(left: 40, top: 8), // Lùi 40px cho reply
            child: _buildCommentBubble(reply, true),
          )),
        ],
      ),
    );
  }

  Widget _buildCommentBubble(Map<String, dynamic> data, bool isReply) {
    final bool isAdmin = (data['role'] ?? '').toString().toLowerCase() == 'admin';

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
              if (isReply) const Icon(Icons.subdirectory_arrow_right, size: 16, color: Colors.blueGrey),
              const SizedBox(width: 4),
              Text(data['username'], style: TextStyle(fontWeight: FontWeight.bold, color: isAdmin ? Colors.blue.shade800 : Colors.black)),
              if (isAdmin) 
                Container(
                  margin: const EdgeInsets.only(left: 8),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.blue, borderRadius: BorderRadius.circular(4)),
                  child: const Text("ADMIN", style: TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                ),
              const Spacer(),
              Text(_formatDate(data['createdAt']), style: const TextStyle(color: Colors.grey, fontSize: 11)),
            ],
          ),
          if (!isAdmin && !isReply) 
            Row(children: List.generate(5, (i) => Icon(Icons.star, size: 12, color: i < (data['rating'] ?? 5) ? Colors.amber : Colors.grey))),
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
    } catch (e) { return ''; }
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(data['name'] ?? 'No Name', style: TextStyle(fontSize: isDesktop ? 36 : 24, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Text(artistName, style: const TextStyle(fontSize: 18, color: Colors.blueAccent)),
        const SizedBox(height: 16),
        Text('${data['price']} VND', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)),
      ],
    );
  }

  Widget _buildMainInfo(Map<String, dynamic> data, bool isDesktop) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Description', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(data['description'] ?? 'No description.', style: const TextStyle(fontSize: 16, height: 1.6)),
        const SizedBox(height: 30),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 60)),
          onPressed: () {
            Provider.of<AuthProvider>(context, listen: false).addToCart(data);
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Added to cart!')));
          },
          child: const Text('ADD TO CART', style: TextStyle(color: Colors.white)),
        )
      ],
    );
  }

  Widget _buildDesktopHeader(Map<String, dynamic> data) => Row(children: [_buildAlbumImage(data['image'], 300), const SizedBox(width: 40), Expanded(child: _buildHeaderInfo(data, true))]);
  Widget _buildMobileHeader(Map<String, dynamic> data) => Column(children: [_buildAlbumImage(data['image'], 150), const SizedBox(height: 20), _buildHeaderInfo(data, false)]);
  Widget _buildRecommendationSection(String title, List<dynamic> data) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)), const SizedBox(height: 20), AlbumRow(albums: data, artists: artists, genres: genres)]);
}