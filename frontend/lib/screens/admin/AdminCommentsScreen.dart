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
        setState(() => comments.removeWhere((c) => (c['_id'] ?? c['id']).toString() == id));
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Deleted')));
      } else {
        throw Exception('delete failed');
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  Future<void> _replyToComment(String parentId, TextEditingController controller) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final apiUrl = auth.apiUrl;
    final text = controller.text.trim();
    if (text.isEmpty) return;

    try {
      final res = await http.post(Uri.parse('$apiUrl/api/comments'), headers: {'Content-Type':'application/json'}, body: json.encode({
        'albumId': (comments.firstWhere((c) => (c['_id'] ?? c['id']).toString() == parentId)['albumId'] ?? {})['_id'] ?? comments.firstWhere((c) => (c['_id'] ?? c['id']).toString() == parentId)['albumId'],
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Manage Comments')),
      body: isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: comments.length,
              itemBuilder: (context, i) {
                final c = comments[i];
                final id = (c['_id'] ?? c['id']).toString();
                final album = c['albumId'] ?? {};
                final user = c['userId'] ?? {};
                final replyController = TextEditingController();

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(user['name'] ?? c['username'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold)),
                            Text(album['name'] ?? 'Unknown album', style: const TextStyle(color: Colors.grey)),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(c['content'] ?? ''),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            ElevatedButton(onPressed: () => _deleteComment(id), child: const Text('Delete')),
                            const SizedBox(width: 8),
                            ElevatedButton(onPressed: () => _replyToComment(id, replyController), child: const Text('Reply as Admin')),
                          ],
                        ),
                        const SizedBox(height: 8),
                        TextField(controller: replyController, decoration: const InputDecoration(hintText: 'Reply...')),
                      ],
                    ),
                  ),
                );
              }),
    );
  }
}
