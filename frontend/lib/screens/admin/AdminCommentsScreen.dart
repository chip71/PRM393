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
  String searchQuery = ""; 

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
        final data = json.decode(res.body) as List<dynamic>;

        // Sắp xếp bình luận mới nhất lên đầu
        data.sort((a, b) {
          DateTime dateA =
              DateTime.tryParse(a['createdAt'] ?? '') ?? DateTime(2000);
          DateTime dateB =
              DateTime.tryParse(b['createdAt'] ?? '') ?? DateTime(2000);
          return dateB.compareTo(dateA);
        });

        setState(() => comments = data);

        for (var c in data) {
          final albumData = c['albumId'];
          if (albumData is String) {
            _fetchAlbumIfNeeded(albumData);
          } else if (albumData is Map) {
            // FIX: Nếu backend populate bị thiếu trường image, ép fetch lại full thông tin album
            if ((albumData['image'] ?? '').toString().isEmpty) {
               _fetchAlbumIfNeeded((albumData['_id'] ?? albumData['id'] ?? '').toString());
            }
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
    if (albumId.isEmpty || _albumCache.containsKey(albumId)) return;

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
        setState(() => comments
            .removeWhere((c) => (c['_id'] ?? c['id']).toString() == id));

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

  String _formatDate(String? dateStr) {
    if (dateStr == null) return "";
    try {
      DateTime dt = DateTime.parse(dateStr).toLocal();
      return "${dt.day}/${dt.month} ${dt.hour}:${dt.minute.toString().padLeft(2, '0')}";
    } catch (_) {
      return "";
    }
  }

  List<Widget> _buildCommentTree() {
    final Map<String, List<dynamic>> childrenMap = {};
    final List<dynamic> roots = [];

    final filteredComments = comments.where((c) {
      if (searchQuery.isEmpty) return true;
      String name = '';
      final albumData = c['albumId'];
      if (albumData is Map) {
        name = albumData['name']?.toString() ?? '';
      } else if (albumData is String && _albumCache.containsKey(albumData)) {
        name = _albumCache[albumData]['name']?.toString() ?? '';
      }
      return name.toLowerCase().contains(searchQuery.toLowerCase());
    }).toList();

    for (var c in filteredComments) {
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

      // FIX: Bù đắp ảnh từ Cache nếu API trả về thiếu
      if (albumImage.isEmpty && _albumCache.containsKey(albumId)) {
         albumImage = (_albumCache[albumId]['image'] ?? '').toString();
      }
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

    // FIX: Xử lý link ảnh cực kỳ an toàn (chống lỗi gạch chéo)
    if (albumImage.isNotEmpty && !albumImage.startsWith('http')) {
       final auth = Provider.of<AuthProvider>(context, listen: false);
       String base = auth.apiUrl;
       if (base.endsWith('/')) base = base.substring(0, base.length - 1);
       String path = albumImage.startsWith('/') ? albumImage : '/$albumImage';
       albumImage = '$base$path';
    }

    final userData = comment['userId'];
    final userName = (userData is Map)
        ? (userData['name'] ?? comment['username'] ?? 'Unknown')
        : (comment['username'] ?? 'Unknown');

    final isAdmin = comment['role'] == 'admin';
    final isReply = comment['parentId'] != null; 
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: albumImage.isNotEmpty
                            ? Image.network(
                                albumImage,
                                width: 50,
                                height: 50,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    Container(
                                  width: 50,
                                  height: 50,
                                  color: Colors.grey[300],
                                  child: const Icon(Icons.album, color: Colors.grey),
                                ),
                              )
                            : Container(
                                width: 50,
                                height: 50,
                                color: Colors.grey[300],
                                child: const Icon(Icons.album, color: Colors.grey),
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
                                  fontWeight: FontWeight.bold, fontSize: 15),
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 4),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  userName,
                                  style: TextStyle(
                                      color: isAdmin ? Colors.blue : Colors.grey[800], 
                                      fontSize: 13,
                                      fontWeight: isAdmin ? FontWeight.bold : FontWeight.w600),
                                ),
                                Text(
                                  _formatDate(comment['createdAt']),
                                  style: const TextStyle(
                                      color: Colors.grey, fontSize: 11),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),

                  /// ⭐ Rating Stars (Ẩn đối với Admin và Reply)
                  if (!isAdmin && !isReply && rating > 0)
                    Row(
                      children: List.generate(
                        5,
                        (index) => Icon(
                          index < rating ? Icons.star : Icons.star_border,
                          color: Colors.blue,
                          size: 18,
                        ),
                      ),
                    ),

                  if (!isAdmin && !isReply && rating > 0) const SizedBox(height: 6),

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
                        icon: const Icon(Icons.send, color: Colors.blue),
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
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Manage Comments'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(60),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
            child: TextField(
              onChanged: (val) => setState(() => searchQuery = val),
              decoration: InputDecoration(
                hintText: "Search by Album name...",
                prefixIcon: const Icon(Icons.search),
                fillColor: Colors.white,
                filled: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                  borderSide: BorderSide.none,
                ),
                contentPadding: EdgeInsets.zero,
              ),
            ),
          ),
        ),
      ),
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