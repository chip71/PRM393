import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';

class ManageUsersScreen extends StatefulWidget {
  const ManageUsersScreen({super.key});

  @override
  State<ManageUsersScreen> createState() => _ManageUsersScreenState();
}

class _ManageUsersScreenState extends State<ManageUsersScreen> {
  List<dynamic> _users = [];
  List<dynamic> _filteredUsers = [];
  bool _isLoading = true;
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _fetchUsers();
  }

  Future<void> _fetchUsers() async {
    if (!mounted) return;
    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      final res = await http.get(Uri.parse('${auth.apiUrl}/api/admin/users'));
      if (res.statusCode == 200) {
        final data = json.decode(res.body);
        if (mounted) {
          setState(() {
            _users = data;
            _filteredUsers = data;
            _isLoading = false;
          });
        }
      }
    } catch (e) {
      debugPrint("Fetch Users Error: $e");
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _filterUsers(String query) {
    setState(() {
      _searchQuery = query;
      _filteredUsers = _users.where((u) {
        final name = u['name'].toString().toLowerCase();
        final email = u['email'].toString().toLowerCase();
        return name.contains(query.toLowerCase()) || email.contains(query.toLowerCase());
      }).toList();
    });
  }

  Future<void> _deleteUser(String id) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);
    try {
      final res = await http.delete(Uri.parse('${auth.apiUrl}/api/admin/users/$id'));
      if (res.statusCode == 200) {
        _fetchUsers();
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User deleted")));
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
        title: const Text("Manage Users", style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    onChanged: _filterUsers,
                    decoration: InputDecoration(
                      hintText: "Search by name or email...",
                      prefixIcon: const Icon(Icons.search),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                ElevatedButton.icon(
                  onPressed: () => _showUserForm(),
                  icon: const Icon(Icons.person_add),
                  label: const Text("Add New User"),
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
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator(color: Colors.black))
                  : _buildUserTable(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildUserTable() {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(side: BorderSide(color: Colors.grey[200]!), borderRadius: BorderRadius.circular(12)),
      child: SingleChildScrollView(
        child: SizedBox(
          width: double.infinity,
          child: DataTable(
            headingRowColor: WidgetStateProperty.all(Colors.grey[50]),
            columns: const [
              DataColumn(label: Text('Name')),
              DataColumn(label: Text('Email')),
              DataColumn(label: Text('Role')),
              DataColumn(label: Text('Actions')),
            ],
            rows: _filteredUsers.map((user) {
              return DataRow(cells: [
                DataCell(Text(user['name'], style: const TextStyle(fontWeight: FontWeight.bold))),
                DataCell(Text(user['email'])),
                DataCell(Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: user['role'] == 'admin' ? Colors.red.withOpacity(0.1) : Colors.blue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    user['role'].toString().toUpperCase(),
                    style: TextStyle(color: user['role'] == 'admin' ? Colors.red : Colors.blue, fontWeight: FontWeight.bold, fontSize: 11),
                  ),
                )),
                DataCell(Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(icon: const Icon(Icons.edit_outlined, color: Colors.blue), onPressed: () => _showUserForm(user: user)),
                    IconButton(icon: const Icon(Icons.delete_outlined, color: Colors.red), onPressed: () => _confirmDelete(user)),
                  ],
                )),
              ]);
            }).toList(),
          ),
        ),
      ),
    );
  }

  void _showUserForm({Map<String, dynamic>? user}) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => _UserFormDialog(
        user: user,
        onSave: () {
          Navigator.pop(ctx);
          _fetchUsers();
        },
      ),
    );
  }

  void _confirmDelete(dynamic user) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete User"),
        content: Text("Are you sure you want to delete '${user['name']}'?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              _deleteUser(user['_id']);
            },
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );
  }
}

class _UserFormDialog extends StatefulWidget {
  final Map<String, dynamic>? user;
  final VoidCallback onSave;
  const _UserFormDialog({this.user, required this.onSave});

  @override
  State<_UserFormDialog> createState() => _UserFormDialogState();
}

class _UserFormDialogState extends State<_UserFormDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameCtrl, _emailCtrl, _passCtrl;
  String _selectedRole = "customer";
  bool _obscure = true;

  @override
  void initState() {
    super.initState();
    _nameCtrl = TextEditingController(text: widget.user?['name'] ?? "");
    _emailCtrl = TextEditingController(text: widget.user?['email'] ?? "");
    _passCtrl = TextEditingController();
    _selectedRole = widget.user?['role'] ?? "customer";
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    final payload = {
      "name": _nameCtrl.text.trim(),
      "role": _selectedRole,
    };
    
    if (widget.user == null) payload["email"] = _emailCtrl.text.trim();
    if (_passCtrl.text.isNotEmpty) payload["password"] = _passCtrl.text;

    try {
      final String url = widget.user == null 
          ? '${auth.apiUrl}/api/admin/users' 
          : '${auth.apiUrl}/api/admin/users/${widget.user!['_id']}';
      
      final res = await (widget.user == null 
          ? http.post(Uri.parse(url), headers: {"Content-Type": "application/json"}, body: json.encode(payload))
          : http.put(Uri.parse(url), headers: {"Content-Type": "application/json"}, body: json.encode(payload)));

      if (res.statusCode == 200 || res.statusCode == 201) widget.onSave();
    } catch (e) {
      debugPrint("Submit Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.user == null ? "Create New User" : "Edit User Profile"),
      content: SizedBox(
        width: 450,
        child: Form(
          key: _formKey,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextFormField(controller: _nameCtrl, decoration: const InputDecoration(labelText: "Full Name", border: OutlineInputBorder()), validator: (v) => v!.length < 3 ? "Minimum 3 characters" : null),
              const SizedBox(height: 15),
              TextFormField(
                controller: _emailCtrl, 
                decoration: const InputDecoration(labelText: "Email Address", border: OutlineInputBorder()), 
                enabled: widget.user == null,
                validator: (v) => !v!.contains("@") ? "Invalid email" : null
              ),
              const SizedBox(height: 15),
              TextFormField(
                controller: _passCtrl,
                obscureText: _obscure,
                decoration: InputDecoration(
                  labelText: widget.user == null ? "Password" : "New Password (Optional)",
                  border: const OutlineInputBorder(),
                  suffixIcon: IconButton(icon: Icon(_obscure ? Icons.visibility_off : Icons.visibility), onPressed: () => setState(() => _obscure = !_obscure)),
                ),
                validator: (v) => (widget.user == null && v!.length < 8) ? "Minimum 8 characters" : null,
              ),
              const SizedBox(height: 15),
              DropdownButtonFormField<String>(
                value: _selectedRole,
                decoration: const InputDecoration(labelText: "User Role", border: OutlineInputBorder()),
                items: const [
                  DropdownMenuItem(value: "customer", child: Text("Customer")),
                  DropdownMenuItem(value: "admin", child: Text("Admin")),
                ],
                onChanged: (v) => setState(() => _selectedRole = v!),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: _submit, style: ElevatedButton.styleFrom(backgroundColor: Colors.black), child: const Text("Save User", style: TextStyle(color: Colors.white))),
      ],
    );
  }
}