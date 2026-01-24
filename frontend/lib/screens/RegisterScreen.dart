import 'package:flutter/material.dart';
import 'package:rive/rive.dart'; 
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  // --- Rive Controllers ---
  StateMachineController? _controller;
  SMIInput<bool>? _isHandsUp, _isChecking;
  SMIInput<double>? _numLook;
  
  // Cập nhật tên Trigger đúng theo hình ảnh của bạn
  SMITrigger? _successTrigger, _failTrigger; 

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  
  final _nameFocusNode = FocusNode();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _showPassword = false;

  String? _nameError, _emailError, _passwordError;

  @override
  void initState() {
    super.initState();
    _nameFocusNode.addListener(() => _isChecking?.value = _nameFocusNode.hasFocus);
    _emailFocusNode.addListener(() => _isChecking?.value = _emailFocusNode.hasFocus);
    _passwordFocusNode.addListener(_updateBearAnimation);
  }

  void _updateBearAnimation() {
    if (_passwordFocusNode.hasFocus) {
      _isHandsUp?.value = !_showPassword; 
      _isChecking?.value = _showPassword; 
    } else {
      _isHandsUp?.value = false;
      _isChecking?.value = false;
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _showPassword = !_showPassword;
      _updateBearAnimation(); 
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _nameFocusNode.dispose();
    _emailFocusNode.dispose();
    _passwordFocusNode.dispose();
    super.dispose();
  }

  void _onRiveInit(Artboard artboard) {
    _controller = StateMachineController.fromArtboard(artboard, 'Login Machine');
    if (_controller != null) {
      artboard.addController(_controller!);
      _isHandsUp = _controller!.findInput<bool>('isHandsUp'); 
      _isChecking = _controller!.findInput<bool>('isChecking');
      _numLook = _controller!.findInput<double>('numLook');
      
      // Khởi tạo các trigger theo tên mới
      _successTrigger = _controller!.findInput<bool>('successTrigger') as SMITrigger?;
      _failTrigger = _controller!.findInput<bool>('failTrigger') as SMITrigger?;
    }
  }

  bool _validate() {
    bool isValid = true;
    if (_nameController.text.trim().isEmpty) {
      setState(() => _nameError = 'Full name is required.');
      _failTrigger?.fire(); // Gấu biểu cảm thất bại
      isValid = false;
    } else { setState(() => _nameError = null); }

    final emailRegex = RegExp(r'\S+@\S+\.\S+');
    if (_emailController.text.trim().isEmpty || !emailRegex.hasMatch(_emailController.text)) {
      setState(() => _emailError = 'Valid email is required.');
      _failTrigger?.fire();
      isValid = false;
    } else { setState(() => _emailError = null); }

    if (_passwordController.text.length < 8) {
      setState(() => _passwordError = 'At least 8 characters.');
      _failTrigger?.fire();
      isValid = false;
    } else { setState(() => _passwordError = null); }

    return isValid;
  }

  Future<void> _handleSubmit() async {
    if (!_validate()) return;
    setState(() => _isLoading = true);

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await auth.register(
      _nameController.text.trim(),
      _emailController.text.trim(),
      _passwordController.text,
    );

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success']) {
        // ĐÃ BỎ: Thông báo SnackBar thành công theo yêu cầu
        _successTrigger?.fire(); // Chỉ để gấu biểu cảm gật đầu
        
        // Đợi gấu gật đầu xong rồi mới chuyển trang
        Future.delayed(const Duration(milliseconds: 1500), () => Navigator.pop(context));
      } else {
        _failTrigger?.fire(); // Gấu biểu cảm khi có lỗi từ server
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('❌ ${result['message']}'), backgroundColor: Colors.red),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24.0),
          child: Column(
            children: [
              const SizedBox(height: 20),
              const Text("MUSICX", style: TextStyle(fontSize: 40, fontWeight: FontWeight.w900)),
              const Text("Create Account", style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
              const SizedBox(height: 20),
              Center(
                child: Container(
                  height: 150, width: 150,
                  decoration: const BoxDecoration(color: Color(0xFFE8F5E9), shape: BoxShape.circle),
                  child: ClipOval(
                    child: RiveAnimation.asset('assets/animations/login_bear.riv', onInit: _onRiveInit, fit: BoxFit.cover),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              _buildInput(_nameController, _nameFocusNode, "Full Name", Icons.person_outline,
                error: _nameError, onChanged: (v) => _numLook?.value = v.length.toDouble() * 2),
              const SizedBox(height: 16),
              _buildInput(_emailController, _emailFocusNode, "Email", Icons.mail_outline,
                keyboardType: TextInputType.emailAddress, error: _emailError, onChanged: (v) => _numLook?.value = v.length.toDouble() * 2),
              const SizedBox(height: 16),
              _buildInput(_passwordController, _passwordFocusNode, "Password", Icons.lock_outline,
                obscureText: !_showPassword, error: _passwordError,
                onChanged: (v) { if (_showPassword) _numLook?.value = v.length.toDouble() * 2; },
                suffixIcon: IconButton(
                  icon: Icon(_showPassword ? Icons.visibility : Icons.visibility_off),
                  onPressed: _togglePasswordVisibility,
                ),
              ),
              const SizedBox(height: 30),
              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black, minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                ),
                child: _isLoading
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                    : const Text("Sign Up", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: RichText(
                  text: const TextSpan(
                    style: TextStyle(color: Colors.grey, fontSize: 14),
                    children: [
                      TextSpan(text: "Already have an account? "),
                      TextSpan(text: "Sign In", style: TextStyle(color: Color(0xFF4CAF50), fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInput(TextEditingController controller, FocusNode focusNode, String hint, IconData icon, {
    bool obscureText = false, TextInputType? keyboardType, Widget? suffixIcon, String? error, Function(String)? onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          decoration: BoxDecoration(color: const Color(0xFFF2F2F2), borderRadius: BorderRadius.circular(15)),
          child: TextField(
            controller: controller, focusNode: focusNode, obscureText: obscureText,
            keyboardType: keyboardType, onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint, prefixIcon: Icon(icon, color: Colors.grey),
              suffixIcon: suffixIcon, border: InputBorder.none, contentPadding: const EdgeInsets.symmetric(vertical: 18),
            ),
          ),
        ),
        if (error != null)
          Padding(
            padding: const EdgeInsets.only(top: 4, left: 12),
            child: Text(error, style: const TextStyle(color: Colors.red, fontSize: 12)),
          ),
      ],
    );
  }
}