import 'package:flutter/material.dart';
import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class AdminCommentsScreen extends StatefulWidget {
  const AdminCommentsScreen({super.key});

  @override
  State<AdminCommentsScreen> createState() => _AdminCommentsScreenState();
}

class _AdminCommentsScreenState extends State<AdminCommentsScreen> {
  List<dynamic> comments = [];
  bool isLoading = true;

  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, bool> _showReply = {};

  final Map<String, dynamic> _albumCache = {};

  @override
  void initState() {
    super.initState();
    _loadComments();
  }

  Future<void> _loadComments() async {
    setState(() => isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final apiUrl = auth.apiUrl;

    try {
      final res = await http.get(Uri.parse('$apiUrl/api/admin/comments'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        setState(() => comments = data);

        for (var c in data) {
          final albumData = c['albumId'];
          if (albumData is String) {
            _fetchAlbumIfNeeded(albumData);
          }
        }
      } else {
        throw Exception('Failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error loading: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _fetchAlbumIfNeeded(String albumId) async {
    if (_albumCache.containsKey(albumId)) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final apiUrl = auth.apiUrl;

    try {
      final res = await http.get(Uri.parse('$apiUrl/api/albums/$albumId'));
      if (res.statusCode == 200) {
        final album = json.decode(res.body);
        setState(() {
          _albumCache[albumId] = album;
        });
      }
    } catch (e) {
      debugPrint("Error fetching album: $e");
    }
  }

  Future<void> _deleteComment(String id) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final apiUrl = auth.apiUrl;

    try {
      final res =
          await http.delete(Uri.parse('$apiUrl/api/admin/comments/$id'));

      if (res.statusCode == 200) {
        setState(() =>
            comments.removeWhere((c) => (c['_id'] ?? c['id']).toString() == id));

        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Deleted')));
      } else {
        throw Exception('delete failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _replyToComment(
      String parentId, String albumId, TextEditingController controller) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final apiUrl = auth.apiUrl;

    final text = controller.text.trim();
    if (text.isEmpty) return;

    try {
      final res = await http.post(Uri.parse('$apiUrl/api/comments'),
          headers: {'Content-Type': 'application/json'},
          body: json.encode({
            'albumId': albumId,
            'userId': auth.user?['_id'] ?? auth.user?['id'],
            'username': auth.user?['name'] ?? 'Admin',
            'role': 'admin',
            'content': text,
            'rating': 5,
            'parentId': parentId,
          }));

      if (res.statusCode == 201) {
        controller.clear();
        await _loadComments();
      } else {
        throw Exception('Reply failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  List<Widget> _buildCommentTree() {
    final Map<String, List<dynamic>> childrenMap = {};
    final List<dynamic> roots = [];

    for (var c in comments) {
      if (c['parentId'] == null) {
        roots.add(c);
      } else {
        final pid = c['parentId'].toString();
        childrenMap.putIfAbsent(pid, () => []).add(c);
      }
    }

    return roots
        .map((root) => _buildCommentNode(root, childrenMap, 0))
        .toList();
  }

  Widget _buildCommentNode(
      dynamic comment, Map<String, List<dynamic>> childrenMap, int depth) {
    final id = (comment['_id'] ?? comment['id']).toString();

    String albumName = '';
    String albumId = '';
    String albumImage = '';

    final albumData = comment['albumId'];

    if (albumData is Map) {
      albumId = (albumData['_id'] ?? albumData['id'] ?? '').toString();
      albumName = (albumData['name'] ?? '').toString();
      albumImage = (albumData['image'] ?? '').toString();
    } else if (albumData is String) {
      albumId = albumData;

      if (_albumCache.containsKey(albumId)) {
        final album = _albumCache[albumId];
        albumName = album['name'] ?? '';
        albumImage = album['image'] ?? '';
      } else {
        albumName = "Loading album...";
      }
    }

    if (albumName.isEmpty) albumName = "Unknown Album";

    final userData = comment['userId'];
    final userName = (userData is Map)
        ? (userData['name'] ?? comment['username'] ?? 'Unknown')
        : (comment['username'] ?? 'Unknown');

    final isAdmin = comment['role'] == 'admin';
    final rating = comment['rating'] ?? 0;

    _replyControllers.putIfAbsent(id, () => TextEditingController());
    _showReply.putIfAbsent(id, () => false);

    final padding = EdgeInsets.only(left: depth * 24.0, bottom: 16);
    final children = childrenMap[id] ?? [];

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            elevation: 3,
            color: isAdmin ? Colors.blue[50] : Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: albumImage.isNotEmpty
                            ? Image.network(
                                albumImage,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                              )
                            : Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey[300],
                                child: const Icon(Icons.album),
                              ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              albumName,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              userName,
                              style: const TextStyle(
                                  color: Colors.grey, fontSize: 13),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  /// ⭐ Rating Stars
                  if (rating > 0)
                    Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < rating
                              ? Icons.star
                              : Icons.star_border,
                          color: Colors.blue,
                          size: 18,
                        ),
                      ),
                    ),

                  if (rating > 0) const SizedBox(height: 6),

                  Text(comment['content'] ?? ''),

                  const SizedBox(height: 12),

                  Row(
                    children: [
                      ElevatedButton.icon(
                        onPressed: () => _deleteComment(id),
                        icon: const Icon(Icons.delete, size: 16),
                        label: const Text('Delete'),
                        style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton.icon(
                        onPressed: () => setState(() {
                          _showReply[id] = !_showReply[id]!;
                        }),
                        icon: const Icon(Icons.reply, size: 16),
                        label: const Text('Reply'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                        ),
                      ),
                    ],
                  ),

                  if (_showReply[id] == true) ...[
                    const SizedBox(height: 10),
                    TextField(
                      controller: _replyControllers[id],
                      decoration: const InputDecoration(
                        hintText: 'Reply as Admin...',
                        border: OutlineInputBorder(),
                        isDense: true,
                      ),
                      maxLines: 2,
                    ),
                    const SizedBox(height: 6),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                        icon:
                            const Icon(Icons.send, color: Colors.blue),
                        onPressed: () =>
                            _replyToComment(id, albumId, _replyControllers[id]!),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          ...children
              .map((child) =>
                  _buildCommentNode(child, childrenMap, depth + 1))
              .toList(),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Comments')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : comments.isEmpty
              ? const Center(child: Text('No comments found'))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: _buildCommentTree(),
                ),
    );
  }
}