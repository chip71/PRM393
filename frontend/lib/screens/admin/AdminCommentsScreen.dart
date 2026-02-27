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

  // Controllers & visibility state for reply inputs
  final Map<String, TextEditingController> _replyControllers = {};
  final Map<String, bool> _showReply = {};

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
        setState(() => comments = json.decode(res.body));
      } else {
        throw Exception('Failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error loading: $e')));
    } finally {
      setState(() => isLoading = false);
    }
  }

  Future<void> _deleteComment(String id) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final apiUrl = auth.apiUrl;
    try {
      final res = await http.delete(Uri.parse('$apiUrl/api/admin/comments/$id'));
      if (res.statusCode == 200) {
        setState(
            () => comments.removeWhere((c) => (c['_id'] ?? c['id']).toString() == id));
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

  /// Post a reply as an admin.  Requires the albumId of the original comment
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

  /// Build a tree of comment widgets with indentation.
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
    final album = comment['albumId'] ?? {};
    final user = comment['userId'] ?? {};

    _replyControllers.putIfAbsent(id, () => TextEditingController());
    _showReply.putIfAbsent(id, () => false);

    final padding = EdgeInsets.only(left: depth * 24.0, bottom: 12);
    final children = childrenMap[id] ?? [];

    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(user['name'] ?? comment['username'] ?? 'Unknown',
                          style:
                              const TextStyle(fontWeight: FontWeight.bold)),
                      Text(album['name'] ?? 'Unknown album',
                          style: const TextStyle(color: Colors.grey)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(comment['content'] ?? ''),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      ElevatedButton(
                          onPressed: () => _deleteComment(id),
                          child: const Text('Delete')),
                      const SizedBox(width: 8),
                      ElevatedButton(
                          onPressed: () => setState(() {
                                _showReply[id] = !_showReply[id]!;
                              }),
                          child: const Text('Reply as Admin')),
                    ],
                  ),
                  if (_showReply[id] == true) ...[
                    const SizedBox(height: 8),
                    TextField(
                      controller: _replyControllers[id],
                      decoration: const InputDecoration(hintText: 'Reply...'),
                    ),
                    Align(
                      alignment: Alignment.centerRight,
                      child: IconButton(
                          icon: const Icon(Icons.send),
                          onPressed: () =>
                              _replyToComment(id, album['_id'] ?? album, _replyControllers[id]!)),
                    ),
                  ],
                ],
              ),
            ),
          ),
          // recursively add children
          ...children
              .map((child) => _buildCommentNode(child, childrenMap, depth + 1))
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
          : ListView(
              padding: const EdgeInsets.all(16),
              children: _buildCommentTree(),
            ),
    );
  }
}
