import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ManageArtistsScreen extends StatefulWidget {
  const ManageArtistsScreen({super.key});

  @override
  State<ManageArtistsScreen> createState() => _ManageArtistsScreenState();
}

class _ManageArtistsScreenState extends State<ManageArtistsScreen> {
  List<dynamic> _artists = [];
  List<dynamic> _filteredArtists = [];
  bool _isLoading = true;
  final TextEditingController _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchArtists();
  }

  Future<void> _fetchArtists() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      final res = await http.get(Uri.parse('${auth.apiUrl}/api/artists'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _artists = data;
            _filteredArtists = data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch Artists Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterArtists(String query) {
    setState(() {
      _filteredArtists = _artists
          .where((a) => a['name'].toString().toLowerCase().contains(query.toLowerCase()))
          .toList();
    });
  }

  Future<void> _deleteArtist(String id) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.delete(Uri.parse('${auth.apiUrl}/api/artists/$id'));
      if (res.statusCode == 200) {
        _fetchArtists();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Artist deleted successfully")),
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
        title: const Text("Manage Artists", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(onPressed: _fetchArtists, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            // Toolbar
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    onChanged: _filterArtists,
                    decoration: InputDecoration(
                      hintText: "Search artists by name...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showArtistForm(),
                  icon: const Icon(Icons.add),
                  label: const Text("Add New Artist"),
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
            // Data Table
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : _buildArtistTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtistTable() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: BorderSide(color: Colors.grey[200]!),
        borderRadius: BorderRadius.circular(12),
      ),
      child: SingleChildScrollView(
        child: DataTable(
          headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
          columns: const [
            DataColumn(label: Text('Photo')),
            DataColumn(label: Text('Artist Name')),
            DataColumn(label: Text('Description')),
            DataColumn(label: Text('Social Links')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _filteredArtists.map((artist) {
            return DataRow(cells: [
              DataCell(ClipOval(
                child: Image.network(
                  artist['image'] ?? '',
                  width: 40, height: 40, fit: BoxFit.cover,
                  errorBuilder: (_, __, ___) => const CircleAvatar(radius: 20, child: Icon(Icons.person)),
                ),
              )),
              DataCell(Text(artist['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
              DataCell(SizedBox(
                width: 300,
                child: Text(artist['description'] ?? 'No description', maxLines: 1, overflow: TextOverflow.ellipsis),
              )),
              DataCell(Row(
                children: [
                  if (artist['spotify'] != null && artist['spotify'].isNotEmpty)
                    const Icon(Icons.music_note, color: Colors.green, size: 20),
                  if (artist['youtube'] != null && artist['youtube'].isNotEmpty)
                    const Icon(Icons.play_circle_fill, color: Colors.red, size: 20),
                ],
              )),
              DataCell(Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.edit_outlined, color: Colors.blue),
                    onPressed: () => _showArtistForm(artist: artist),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outlined, color: Colors.red),
                    onPressed: () => _confirmDelete(artist),
                  ),
                ],
              )),
            ]);
          }).toList(),
        ),
      ),
    );
  }

  void _showArtistForm({Map<String, dynamic>? artist}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _ArtistFormDialog(
        artist: artist,
        onSave: () {
          Navigator.pop(ctx);
          _fetchArtists();
        },
      ),
    );
  }

  void _confirmDelete(dynamic artist) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Are you sure you want to delete '${artist['name']}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteArtist(artist['_id']);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _ArtistFormDialog extends StatefulWidget {
  final Map<String, dynamic>? artist;
  final VoidCallback onSave;

  const _ArtistFormDialog({this.artist, required this.onSave});

  @override
  State<_ArtistFormDialog> createState() => _ArtistFormDialogState();
}

class _ArtistFormDialogState extends State<_ArtistFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _imgCtrl, _descCtrl, _spotifyCtrl, _youtubeCtrl;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.artist?['name'] ?? "");
    _imgCtrl = TextEditingController(text: widget.artist?['image'] ?? "");
    _descCtrl = TextEditingController(text: widget.artist?['description'] ?? "");
    _spotifyCtrl = TextEditingController(text: widget.artist?['spotify'] ?? "");
    _youtubeCtrl = TextEditingController(text: widget.artist?['youtube'] ?? "");
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final payload = {
      "name": _nameCtrl.text.trim(),
      "image": _imgCtrl.text.trim(),
      "description": _descCtrl.text.trim(),
      "spotify": _spotifyCtrl.text.trim(),
      "youtube": _youtubeCtrl.text.trim(),
    };

    try {
      final String url = widget.artist == null 
          ? '${auth.apiUrl}/api/artists' 
          : '${auth.apiUrl}/api/artists/${widget.artist!['_id']}';
      
      final response = await (widget.artist == null 
          ? http.post(Uri.parse(url), headers: {"Content-Type": "application/json"}, body: json.encode(payload))
          : http.put(Uri.parse(url), headers: {"Content-Type": "application/json"}, body: json.encode(payload)));

      if (response.statusCode == 200 || response.statusCode == 201) {
        widget.onSave();
      }
    } catch (e) {
      debugPrint("Submit Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.artist == null ? "Add New Artist" : "Edit Artist"),
      content: SizedBox(
        width: 600,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                TextFormField(
                  controller: _nameCtrl, 
                  decoration: const InputDecoration(labelText: "Artist Name", border: OutlineInputBorder()),
                  validator: (v) => (v == null || v.isEmpty) ? "Required" : null
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _imgCtrl, 
                  decoration: const InputDecoration(labelText: "Photo URL", border: OutlineInputBorder()),
                  onChanged: (v) => setState(() {}),
                ),
                const SizedBox(height: 10),
                if (_imgCtrl.text.isNotEmpty)
                  Center(
                    child: CircleAvatar(
                      radius: 50,
                      backgroundImage: NetworkImage(_imgCtrl.text),
                      onBackgroundImageError: (_, __) => const Icon(Icons.broken_image),
                    ),
                  ),
                const SizedBox(height: 15),
                TextFormField(controller: _spotifyCtrl, decoration: const InputDecoration(labelText: "Spotify Link", border: OutlineInputBorder(), prefixIcon: Icon(Icons.music_note, color: Colors.green))),
                const SizedBox(height: 15),
                TextFormField(controller: _youtubeCtrl, decoration: const InputDecoration(labelText: "YouTube Link", border: OutlineInputBorder(), prefixIcon: Icon(Icons.play_circle, color: Colors.red))),
                const SizedBox(height: 15),
                TextFormField(controller: _descCtrl, decoration: const InputDecoration(labelText: "Description", border: OutlineInputBorder()), maxLines: 4),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
        ElevatedButton(
          onPressed: _submit, 
          style: ElevatedButton.styleFrom(backgroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15)),
          child: const Text("Save Artist", style: TextStyle(color: Colors.white))
        ),
      ],
    );
  }
}