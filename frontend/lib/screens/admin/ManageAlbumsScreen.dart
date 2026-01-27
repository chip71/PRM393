import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ManageAlbumsScreen extends StatefulWidget {
  const ManageAlbumsScreen({super.key});

  @override
  State<ManageAlbumsScreen> createState() => _ManageAlbumsScreenState();
}

class _ManageAlbumsScreenState extends State<ManageAlbumsScreen> {
  List<dynamic> _albums = [];
  List<dynamic> _filteredAlbums = [];
  List<dynamic> _artists = [];
  List<dynamic> _genres = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchData();
  }

  Future<void> _fetchData() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    final String baseApi = "${auth.apiUrl}/api";

    try {
      final results = await Future.wait([
        http.get(Uri.parse('$baseApi/albums')),
        http.get(Uri.parse('$baseApi/artists')),
        http.get(Uri.parse('$baseApi/genres')),
      ]);

      if (mounted) {
        setState(() {
          _albums = json.decode(results[0].body);
          _filteredAlbums = _albums;
          _artists = json.decode(results[1].body);
          _genres = json.decode(results[2].body);
          _isLoading = false;
        });
      }
    } catch (e) {
      debugPrint("Fetch Data Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterAlbums(String query) {
    setState(() {
      _filteredAlbums = _albums
          .where(
            (a) => a['name'].toString().toLowerCase().contains(
              query.toLowerCase(),
            ),
          )
          .toList();
    });
  }

  Future<void> _deleteAlbum(String id) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.delete(Uri.parse('${auth.apiUrl}/api/albums/$id'));
      if (res.statusCode == 200) {
        _fetchData();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Album deleted successfully")),
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
        title: const Text(
          "Manage Albums",
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
        ),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
        actions: [
          IconButton(onPressed: _fetchData, icon: const Icon(Icons.refresh)),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: _filterAlbums,
                    decoration: InputDecoration(
                      hintText: "Search albums by name...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showAlbumForm(),
                  icon: const Icon(Icons.add),
                  label: const Text("Add New Album"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 20,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Colors.black),
                    )
                  : _buildAlbumTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAlbumTable() {
    final currency = NumberFormat("#,###", "vi_VN");
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
            DataColumn(label: Text('Image')),
            DataColumn(label: Text('Album Name')),
            DataColumn(label: Text('Artist • Genre')),
            DataColumn(label: Text('Price')),
            DataColumn(label: Text('Stock')),
            DataColumn(label: Text('Actions')),
          ],
          rows: _filteredAlbums.map((album) {
            return DataRow(
              cells: [
                DataCell(
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: Image.network(
                      album['image'] ?? '',
                      width: 40,
                      height: 40,
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) =>
                          const Icon(Icons.album, size: 40, color: Colors.grey),
                    ),
                  ),
                ),
                DataCell(
                  Text(
                    album['name'],
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                DataCell(
                  Text(
                    "${album['artistID']?['name'] ?? 'N/A'} • ${album['genreID']?['name'] ?? 'N/A'}",
                  ),
                ),
                DataCell(Text("${currency.format(album['price'])}₫")),
                DataCell(Text(album['stock'].toString())),
                DataCell(
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: const Icon(
                          Icons.edit_outlined,
                          color: Colors.blue,
                        ),
                        onPressed: () => _showAlbumForm(album: album),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.delete_outlined,
                          color: Colors.red,
                        ),
                        onPressed: () => _confirmDelete(album),
                      ),
                    ],
                  ),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  void _showAlbumForm({Map<String, dynamic>? album}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _AlbumFormDialog(
        album: album,
        artists: _artists,
        genres: _genres,
        onSave: () {
          Navigator.pop(ctx);
          _fetchData();
        },
      ),
    );
  }

  void _confirmDelete(dynamic album) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: Text("Are you sure you want to delete '${album['name']}'?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteAlbum(album['_id']);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _AlbumFormDialog extends StatefulWidget {
  final Map<String, dynamic>? album;
  final List<dynamic> artists;
  final List<dynamic> genres;
  final VoidCallback onSave;

  const _AlbumFormDialog({
    this.album,
    required this.artists,
    required this.genres,
    required this.onSave,
  });

  @override
  State<_AlbumFormDialog> createState() => _AlbumFormDialogState();
}

class _AlbumFormDialogState extends State<_AlbumFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl,
      _priceCtrl,
      _stockCtrl,
      _imgCtrl,
      _descCtrl,
      _skuCtrl;
  String? _selectedArtist;
  String? _selectedGenre;
  String _selectedFormat = "CD";

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.album?['name'] ?? "");
    _priceCtrl = TextEditingController(
      text: widget.album?['price']?.toString() ?? "",
    );
    _stockCtrl = TextEditingController(
      text: widget.album?['stock']?.toString() ?? "",
    );
    _imgCtrl = TextEditingController(text: widget.album?['image'] ?? "");
    _descCtrl = TextEditingController(text: widget.album?['description'] ?? "");
    _skuCtrl = TextEditingController(text: widget.album?['sku'] ?? "");

    // FIX: Explicitly cast as String? to resolve assignment errors
    _selectedArtist = (widget.album?['artistID'] is Map)
        ? widget.album!['artistID']['_id']?.toString()
        : widget.album?['artistID']?.toString();

    _selectedGenre = (widget.album?['genreID'] is Map)
        ? widget.album!['genreID']['_id']?.toString()
        : widget.album?['genreID']?.toString();

    _selectedFormat = widget.album?['format'] ?? "CD";
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = Provider.of<AuthProvider>(context, listen: false);

    // FIX: Parse String to int safely
    final payload = {
      "name": _nameCtrl.text.trim(),
      "price": int.tryParse(_priceCtrl.text) ?? 0,
      "stock": int.tryParse(_stockCtrl.text) ?? 0,
      "image": _imgCtrl.text.trim(),
      "description": _descCtrl.text.trim(),
      "sku": _skuCtrl.text.trim(),
      "artistID": _selectedArtist,
      "genreID": _selectedGenre,
      "format": _selectedFormat,
    };

    try {
      final String url = widget.album == null
          ? '${auth.apiUrl}/api/albums'
          : '${auth.apiUrl}/api/albums/${widget.album!['_id']}';

      final response = await (widget.album == null
          ? http.post(
              Uri.parse(url),
              headers: {"Content-Type": "application/json"},
              body: json.encode(payload),
            )
          : http.put(
              Uri.parse(url),
              headers: {"Content-Type": "application/json"},
              body: json.encode(payload),
            ));

      if (response.statusCode == 200 || response.statusCode == 201) {
        widget.onSave();
      } else {
        final error = json.decode(response.body);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(error['message'] ?? "Save failed")),
          );
        }
      }
    } catch (e) {
      debugPrint("Submit Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.album == null ? "Add New Album" : "Edit Album"),
      content: SizedBox(
        width: 700,
        child: Form(
          key: _formKey,
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildFieldTitle("Basic Information"),
                TextFormField(
                  controller: _nameCtrl,
                  decoration: const InputDecoration(
                    labelText: "Album Name",
                    border: OutlineInputBorder(),
                  ),
                  validator: (v) =>
                      (v == null || v.isEmpty) ? "Required" : null,
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedArtist,
                        decoration: const InputDecoration(
                          labelText: "Artist",
                          border: OutlineInputBorder(),
                        ),
                        items: widget.artists
                            .map(
                              (a) => DropdownMenuItem<String>(
                                value: a['_id'] as String?,
                                child: Text(a['name']),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedArtist = v),
                        validator: (v) => v == null ? "Required" : null,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedGenre,
                        decoration: const InputDecoration(
                          labelText: "Genre",
                          border: OutlineInputBorder(),
                        ),
                        items: widget.genres
                            .map(
                              (g) => DropdownMenuItem<String>(
                                value: g['_id'] as String?,
                                child: Text(g['name']),
                              ),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedGenre = v),
                        validator: (v) => v == null ? "Required" : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 15),
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _priceCtrl,
                        decoration: const InputDecoration(
                          labelText: "Price (VND)",
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => int.tryParse(v ?? '') == null
                            ? "Must be a number"
                            : null,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: TextFormField(
                        controller: _stockCtrl,
                        decoration: const InputDecoration(
                          labelText: "Stock Quantity",
                          border: OutlineInputBorder(),
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) => int.tryParse(v ?? '') == null
                            ? "Must be a number"
                            : null,
                      ),
                    ),
                    const SizedBox(width: 15),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedFormat,
                        decoration: const InputDecoration(
                          labelText: "Format",
                          border: OutlineInputBorder(),
                        ),
                        items: ["CD", "Vinyl", "Digital"]
                            .map(
                              (f) => DropdownMenuItem(value: f, child: Text(f)),
                            )
                            .toList(),
                        onChanged: (v) => setState(() => _selectedFormat = v!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 25),
                _buildFieldTitle("Media & Metadata"),
                TextFormField(
                  controller: _imgCtrl,
                  decoration: const InputDecoration(
                    labelText: "Image URL",
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (v) => setState(() {}),
                ),
                const SizedBox(height: 10),
                // FIX: Used .isNotEmpty for the boolean check
                if (_imgCtrl.text.isNotEmpty)
                  Center(
                    child: Container(
                      height: 150,
                      width: 150,
                      margin: const EdgeInsets.only(bottom: 15),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.grey[300]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          _imgCtrl.text,
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) =>
                              const Icon(Icons.broken_image),
                        ),
                      ),
                    ),
                  ),
                TextFormField(
                  controller: _skuCtrl,
                  decoration: const InputDecoration(
                    labelText: "SKU (Optional)",
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 15),
                TextFormField(
                  controller: _descCtrl,
                  decoration: const InputDecoration(
                    labelText: "Description",
                    border: OutlineInputBorder(),
                  ),
                  maxLines: 4,
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
        ),
        ElevatedButton(
          onPressed: _submit,
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.black,
            padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
          ),
          child: const Text(
            "Save Changes",
            style: TextStyle(color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildFieldTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        title,
        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
      ),
    );
  }
}
