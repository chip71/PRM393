import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key});

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final _currentPasswordController = TextEditingController();
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  final _currentFocusNode = FocusNode();
  final _newPasswordFocusNode = FocusNode();
  final _confirmPasswordFocusNode = FocusNode();

  // Trạng thái ẩn/hiện mật khẩu cho 3 ô
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _obscureConfirm = true;

  bool _isLoading = false;
  String? _errorMessage;

  // Rive Controllers
  StateMachineController? _controller;
  SMIInput<bool>? _isHandsUp; // Gấu che mắt
  SMIInput<bool>? _isChecking; // Gấu liếc nhìn
  SMIInput<double>? _numLook; // Vị trí liếc nhìn
  SMITrigger? _successTrigger, _failTrigger;

  @override
  void initState() {
    super.initState();
    
    // Thiết lập lắng nghe Focus để gấu liếc nhìn hoặc che mắt
    _setupFocusListeners();
  }

  void _setupFocusListeners() {
    _currentFocusNode.addListener(() {
      if (mounted) _isChecking?.value = _currentFocusNode.hasFocus;
    });
    _newPasswordFocusNode.addListener(() {
      if (mounted) _isChecking?.value = _newPasswordFocusNode.hasFocus;
    });
    _confirmPasswordFocusNode.addListener(() {
      if (mounted) _isChecking?.value = _confirmPasswordFocusNode.hasFocus;
    });
  }

  @override
  void dispose() {
    _currentPasswordController.dispose();
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    _currentFocusNode.dispose();
    _newPasswordFocusNode.dispose();
    _confirmPasswordFocusNode.dispose();
    super.dispose();
  }

  void _onRiveInit(Artboard artboard) {
    _controller = StateMachineController.fromArtboard(artboard, 'Login Machine');
    if (_controller != null) {
      artboard.addController(_controller!);
      _isHandsUp = _controller!.findInput<bool>('isHandsUp');
      _isChecking = _controller!.findInput<bool>('isChecking');
      _numLook = _controller!.findInput<double>('numLook');
      _successTrigger = _controller!.findInput<bool>('successTrigger') as SMITrigger?;
      _failTrigger = _controller!.findInput<bool>('failTrigger') as SMITrigger?;
    }
  }

  // Cập nhật vị trí liếc nhìn của gấu dựa trên độ dài text
  void _updateNumLook(String value) {
    _numLook?.value = value.length.toDouble() * 1.5;
  }

  bool _isStrongPassword(String password) {
    return password.length >= 8 &&
        RegExp(r'[A-Z]').hasMatch(password) &&
        RegExp(r'[a-z]').hasMatch(password) &&
        RegExp(r'[0-9]').hasMatch(password) &&
        RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(password);
  }

  Future<void> _handleUpdate() async {
    final currentPw = _currentPasswordController.text;
    final newPw = _newPasswordController.text;
    final confirmPw = _confirmPasswordController.text;

    if (currentPw.isEmpty || newPw.isEmpty) {
      setState(() => _errorMessage = "Please fill all fields");
      _failTrigger?.fire();
      return;
    }

    if (!_isStrongPassword(newPw)) {
      setState(() => _errorMessage = "Password too weak");
      _failTrigger?.fire();
      return;
    }

    if (newPw != confirmPw) {
      setState(() => _errorMessage = "Passwords do not match");
      _failTrigger?.fire();
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await auth.changePassword(currentPw, newPw);

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success']) {
        _successTrigger?.fire();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Password updated successfully!")),
        );
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) Navigator.pop(context);
        });
      } else {
        setState(() => _errorMessage = result['message']);
        _failTrigger?.fire();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white, 
        elevation: 0, 
        iconTheme: const IconThemeData(color: Colors.black),
        title: const Text("Security", style: TextStyle(color: Colors.black)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          children: [
            const Text("Change Password", style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold)),
            const SizedBox(height: 20),
            
            // Bear Animation
            SizedBox(
              height: 180,
              child: RiveAnimation.asset(
                'assets/animations/login_bear.riv', 
                onInit: _onRiveInit,
                fit: BoxFit.contain,
              ),
            ),
            
            const SizedBox(height: 20),
            if (_errorMessage != null)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: Colors.red[50], borderRadius: BorderRadius.circular(10)),
                child: Text(_errorMessage!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 10),

            // Ô nhập Mật khẩu hiện tại
            _buildPasswordField(
              controller: _currentPasswordController,
              focusNode: _currentFocusNode,
              hint: "Current Password",
              icon: Icons.lock_outline,
              isObscure: _obscureCurrent,
              onToggle: () => setState(() => _obscureCurrent = !_obscureCurrent),
            ),
            const SizedBox(height: 15),

            // Ô nhập Mật khẩu mới
            _buildPasswordField(
              controller: _newPasswordController,
              focusNode: _newPasswordFocusNode,
              hint: "New Password",
              icon: Icons.lock_reset_outlined,
              isObscure: _obscureNew,
              onToggle: () => setState(() => _obscureNew = !_obscureNew),
            ),
            const SizedBox(height: 15),

            // Ô xác nhận Mật khẩu mới
            _buildPasswordField(
              controller: _confirmPasswordController,
              focusNode: _confirmPasswordFocusNode,
              hint: "Confirm New Password",
              icon: Icons.lock_clock_outlined,
              isObscure: _obscureConfirm,
              onToggle: () => setState(() => _obscureConfirm = !_obscureConfirm),
            ),
            
            const SizedBox(height: 32),
            
            ElevatedButton(
              onPressed: _isLoading ? null : _handleUpdate,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                elevation: 0,
              ),
              child: _isLoading 
                ? const CircularProgressIndicator(color: Colors.white) 
                : const Text("Update Password", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required FocusNode focusNode,
    required String hint,
    required IconData icon,
    required bool isObscure,
    required VoidCallback onToggle,
  }) {
    return Container(
      decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: isObscure,
        onChanged: (value) {
          _updateNumLook(value);
          // Gấu che mắt nếu đang ẩn mật khẩu, bỏ tay nếu đang hiện mật khẩu
          _isHandsUp?.value = isObscure; 
        },
        onTap: () {
          // Khi nhấn vào ô, cập nhật ngay trạng thái che mắt dựa trên obscureText
          _isHandsUp?.value = isObscure;
        },
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey),
          suffixIcon: IconButton(
            icon: Icon(
              isObscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
              color: Colors.grey,
            ),
            onPressed: () {
              onToggle();
              // Nếu sau khi nhấn mà chuyển sang hiện mật khẩu (isObscure thành false) 
              // thì gấu bỏ tay xuống và ngược lại
              _isHandsUp?.value = !isObscure; 
            },
          ),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
        ),
      ),
    );
  }
}