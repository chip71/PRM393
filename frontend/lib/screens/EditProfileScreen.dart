import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  // --- Rive Controllers ---
  StateMachineController? _controller;
  SMIInput<bool>? _isChecking;
  SMIInput<double>? _numLook;
  SMITrigger? _successTrigger, _failTrigger; 

  late TextEditingController _nameController;
  final _nameFocusNode = FocusNode();
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    // Đảm bảo lấy đúng Key từ Map của AuthProvider
    _nameController = TextEditingController(text: auth.user?['name'] ?? '');
    
    // Gấu liếc nhìn khi người dùng nhấn vào ô nhập tên
    _nameFocusNode.addListener(() {
      if (mounted) _isChecking?.value = _nameFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _nameFocusNode.dispose();
    super.dispose();
  }

  void _onRiveInit(Artboard artboard) {
    _controller = StateMachineController.fromArtboard(artboard, 'Login Machine');
    if (_controller != null) {
      artboard.addController(_controller!);
      _isChecking = _controller!.findInput<bool>('isChecking');
      _numLook = _controller!.findInput<double>('numLook');
      _successTrigger = _controller!.findInput<bool>('successTrigger') as SMITrigger?;
      _failTrigger = _controller!.findInput<bool>('failTrigger') as SMITrigger?;
    }
  }

  Future<void> _handleUpdate() async {
    final newName = _nameController.text.trim();
    
    if (newName.isEmpty) {
      _failTrigger?.fire(); // Gấu báo lỗi nếu để trống tên
      return;
    }

    setState(() => _isLoading = true);
    final auth = Provider.of<AuthProvider>(context, listen: false);
    
    // Gọi API cập nhật thông qua Route /users/profile đã được tối ưu
    final success = await auth.updateProfile(newName);

    if (mounted) {
      setState(() => _isLoading = false);
      if (success) {
        // Gấu gật đầu xác nhận lưu thành công
        _successTrigger?.fire(); 
        
        // Đợi gấu diễn hoạt xong rồi mới quay lại trang Profile
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        // Gấu lắc đầu nếu Backend trả về lỗi (như 404 hoặc 500)
        _failTrigger?.fire(); 
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text("Edit Profile", 
          style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        backgroundColor: Colors.white,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.black),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // --- 1. Bear UI ---
              Center(
                child: Container(
                  height: 160, width: 160,
                  decoration: const BoxDecoration(
                    color: Color(0xFFE8F5E9), 
                    shape: BoxShape.circle
                  ),
                  child: ClipOval(
                    child: RiveAnimation.asset(
                      'assets/animations/login_bear.riv',
                      onInit: _onRiveInit,
                      fit: BoxFit.cover,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 30),

              // --- 2. Ô nhập tên ---
              _buildInput(
                controller: _nameController,
                focusNode: _nameFocusNode,
                hint: "Full Name",
                icon: Icons.person_outline,
                onChanged: (v) => _numLook?.value = v.length.toDouble() * 1.5,
              ),
              const SizedBox(height: 16),

              // --- 3. Ô Email (Read Only) ---
              _buildInput(
                controller: TextEditingController(text: auth.user?['email'] ?? ''),
                focusNode: FocusNode(),
                hint: "Email",
                icon: Icons.mail_outline,
                readOnly: true,
              ),

              const SizedBox(height: 32),

              // --- 4. Nút Save Changes ---
              ElevatedButton(
                onPressed: _isLoading ? null : _handleUpdate,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(15)
                  ),
                  elevation: 0,
                ),
                child: _isLoading
                    ? const SizedBox(
                        height: 20, 
                        width: 20, 
                        child: CircularProgressIndicator(
                          color: Colors.white, 
                          strokeWidth: 2
                        )
                      )
                    : const Text("Save Changes", 
                        style: TextStyle(
                          color: Colors.white, 
                          fontSize: 18, 
                          fontWeight: FontWeight.bold
                        )
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    bool readOnly = false,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: readOnly ? const Color(0xFFE0E0E0) : const Color(0xFFF5F5F5),
        borderRadius: BorderRadius.circular(15),
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        readOnly: readOnly,
        onChanged: onChanged,
        style: TextStyle(
          color: readOnly ? Colors.grey[600] : Colors.black,
          fontWeight: readOnly ? FontWeight.w500 : FontWeight.normal
        ),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }
}