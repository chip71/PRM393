import 'package:flutter/material.dart';
import 'package:rive/rive.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  StateMachineController? _controller;
  SMIInput<bool>? _isHandsUp, _isChecking;
  SMIInput<double>? _numLook;
  
  // Đồng bộ tên Trigger với hệ thống mới
  SMITrigger? _successTrigger, _failTrigger; 

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true; 
  String? _errorMessage;

  final Color bgColor = Colors.white;            
  final Color circleColor = const Color(0xFFE8F5E9); 
  final Color inputBgColor = const Color(0xFFF5F5F5); 
  final Color primaryBlack = Colors.black;       
  final Color accentGreen = const Color(0xFF4CAF50); 

  @override
  void initState() {
    super.initState();
    // Gấu liếc nhìn khi nhập Email
    _emailFocusNode.addListener(() {
      if (mounted) _isChecking?.value = _emailFocusNode.hasFocus;
    });
    // Gấu phản ứng thông minh với ô mật khẩu
    _passwordFocusNode.addListener(_updateBearAnimation);
  }

  // Logic: Che mắt khi ẩn mật khẩu, liếc nhìn khi hiện mật khẩu
  void _updateBearAnimation() {
    if (_passwordFocusNode.hasFocus) {
      _isHandsUp?.value = _obscurePassword; 
      _isChecking?.value = !_obscurePassword; 
      if (!_obscurePassword) {
        // Cập nhật vị trí liếc nhìn ngay khi hiện mật khẩu
        _numLook?.value = _passwordController.text.length.toDouble() * 1.5;
      }
    } else {
      _isHandsUp?.value = false;
      _isChecking?.value = false;
    }
  }

  void _togglePasswordVisibility() {
    setState(() {
      _obscurePassword = !_obscurePassword;
      _updateBearAnimation(); 
    });
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
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
      
      // Lấy các Trigger phản hồi theo tên mới
      _successTrigger = _controller!.findInput<bool>('successTrigger') as SMITrigger?;
      _failTrigger = _controller!.findInput<bool>('failTrigger') as SMITrigger?;
    }
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Email and password are required.");
      _failTrigger?.fire(); // Gấu biểu cảm lỗi
      return;
    }

    _emailFocusNode.unfocus();
    _passwordFocusNode.unfocus();

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);
    final result = await auth.login(email, password);

    if (mounted) {
      setState(() => _isLoading = false);
      if (result['success']) {
        _successTrigger?.fire(); // Gấu biểu cảm thành công
        
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            Navigator.pushNamedAndRemoveUntil(context, auth.isAdmin ? '/admin-dashboard' : '/', (r) => false);
          }
        });
      } else {
        _failTrigger?.fire(); // Gấu biểu cảm lỗi khi đăng nhập sai
        setState(() => _errorMessage = result['message']);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 30.0),
          child: Column(
            children: [
              const SizedBox(height: 40),
              Text(
                "MUSICX",
                style: TextStyle(color: primaryBlack, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
              const Text("Welcome Back", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),

              // Vòng tròn gấu xanh lá
              Center(
                child: Container(
                  height: 180, width: 180,
                  decoration: BoxDecoration(color: circleColor, shape: BoxShape.circle),
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

              _buildInput(
                controller: _emailController,
                focusNode: _emailFocusNode,
                hint: "Email",
                icon: Icons.mail_outline,
                onChanged: (v) => _numLook?.value = v.length.toDouble() * 1.5,
              ),
              const SizedBox(height: 16),

              _buildInput(
                controller: _passwordController,
                focusNode: _passwordFocusNode,
                hint: "Password",
                icon: Icons.lock_outline,
                obscureText: _obscurePassword,
                onChanged: (v) {
                  // Chỉ liếc nhìn khi mật khẩu đang hiển thị
                  if (!_obscurePassword) _numLook?.value = v.length.toDouble() * 1.5;
                },
                suffixIcon: IconButton(
                  icon: Icon(_obscurePassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                  onPressed: _togglePasswordVisibility,
                ),
              ),

              if (_errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: 15),
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                ),

              const SizedBox(height: 30),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlack,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Sign In", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 20),
              TextButton(
                onPressed: () {},
                child: Text("Forgot Password?", style: TextStyle(color: accentGreen)),
              ),
              
              const SizedBox(height: 20),
              const Text("No account?", style: TextStyle(color: Colors.grey, fontSize: 14)),
              TextButton(
                onPressed: () => Navigator.pushNamed(context, '/register'),
                child: Text(
                  "Sign Up Now", 
                  style: TextStyle(color: accentGreen, fontWeight: FontWeight.bold, fontSize: 15),
                ),
              ),
              const SizedBox(height: 20), 
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
    bool obscureText = false,
    Widget? suffixIcon,
    Function(String)? onChanged,
  }) {
    return Container(
      decoration: BoxDecoration(color: inputBgColor, borderRadius: BorderRadius.circular(15)),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        obscureText: obscureText,
        onChanged: onChanged,
        style: const TextStyle(color: Colors.black),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.grey),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 18, horizontal: 20),
        ),
      ),
    );
  }
}