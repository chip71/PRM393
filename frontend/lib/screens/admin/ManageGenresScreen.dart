import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ManageGenresScreen extends StatefulWidget {
  const ManageGenresScreen({super.key});

  @override
  State<ManageGenresScreen> createState() => _ManageGenresScreenState();
}

class _ManageGenresScreenState extends State<ManageGenresScreen> {
  List<dynamic> _genres = [];
  List<dynamic> _filteredGenres = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchGenres();
  }

  Future<void> _fetchGenres() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      final res = await http.get(Uri.parse('${auth.apiUrl}/api/genres'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _genres = data;
            _filteredGenres = data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch Genres Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterGenres(String query) {
    setState(() {
      _filteredGenres = _genres
          .where((g) => g['name'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _deleteGenre(String id) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.delete(Uri.parse('${auth.apiUrl}/api/genres/$id'));
      if (res.statusCode == 200) {
        _fetchGenres();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Genre deleted successfully")),
          );
        }
      }
    } catch (e) {
      debugPrint("Delete Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Manage Genres", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Toolbar: Search + Add Button
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _filterGenres,
                    decoration: InputDecoration(
                      hintText: "Search genres by name...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showGenreForm(),
                  icon: const Icon(Icons.add),
                  label: const Text("Add New Genre"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            // Table view for Desktop
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : _buildGenreTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGenreTable() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
            columns: const [
              DataColumn(label: Text('Genre Name')),
              DataColumn(label: Text('ID')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _filteredGenres.map((genre) {
              return DataRow(cells: [
                DataCell(Text(genre['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(genre['_id'])),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                      onPressed: () => _showGenreForm(genre: genre),
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete_outlined, color: Colors.red),
                      onPressed: () => _confirmDelete(genre),
                    ),
                  ],
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showGenreForm({Map<String, dynamic>? genre}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _GenreFormDialog(
        genre: genre,
        onSave: () {
          Navigator.pop(ctx);
          _fetchGenres();
        },
      ),
    );
  }

  void _confirmDelete(dynamic genre) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Are you sure you want to delete the genre '${genre['name']}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteGenre(genre['_id']);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _GenreFormDialog extends StatefulWidget {
  final Map<String, dynamic>? genre;
  final VoidCallback onSave;

  const _GenreFormDialog({this.genre, required this.onSave});

  @override
  State<_GenreFormDialog> createState() => _GenreFormDialogState();
}

class _GenreFormDialogState extends State<_GenreFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.genre?['name'] ?? "");
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final payload = {"name": _nameCtrl.text.trim()};

    try {
      final String url = widget.genre == null 
          ? '${auth.apiUrl}/api/genres' 
          : '${auth.apiUrl}/api/genres/${widget.genre!['_id']}';
      
      final response = await (widget.genre == null 
          ? http.post(Uri.parse(url), headers: {"Content-Type": "application/json"}, body: json.encode(payload))
          : http.put(Uri.parse(url), headers: {"Content-Type": "application/json"}, body: json.encode(payload)));

      if (response.statusCode == 200 || response.statusCode == 201) {
        widget.onSave();
      }
    } catch (e) {
      debugPrint("Submit Genre Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.genre == null ? "Add New Genre" : "Edit Genre"),
      content: SizedBox(
        width: 400,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(
                controller: _nameCtrl, 
                decoration: const InputDecoration(labelText: "Genre Name", border: OutlineInputBorder()),
                validator: (v) => (v == null || v.isEmpty) ? "Genre name is required" : null
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: _submit, 
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black),
          child: const Text("Save Genre", style: TextStyle(color: Colors.white))
        ),
      ],
    );
  }
}