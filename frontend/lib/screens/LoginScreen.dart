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
  
  SMITrigger? _successTrigger, _failTrigger; 

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _emailFocusNode = FocusNode();
  final _passwordFocusNode = FocusNode();

  bool _isLoading = false;
  bool _obscurePassword = true; 
  String? _errorMessage;

  // Design Palette (MUSICX Style)
  final Color bgColor = Colors.white;            
  final Color circleColor = const Color(0xFFF0F0F0); // Xám nhạt hiện đại
  final Color inputBgColor = const Color(0xFFF5F5F5); 
  final Color primaryBlack = Colors.black;       
  final Color accentGreen = const Color(0xFF1DB954); // Spotify Green cho các nút phụ

  @override
  void initState() {
    super.initState();
    _emailFocusNode.addListener(() {
      if (mounted) _isChecking?.value = _emailFocusNode.hasFocus;
    });
    _passwordFocusNode.addListener(_updateBearAnimation);
  }

  void _updateBearAnimation() {
    if (_passwordFocusNode.hasFocus) {
      _isHandsUp?.value = _obscurePassword; 
      _isChecking?.value = !_obscurePassword; 
      if (!_obscurePassword) {
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
      _successTrigger = _controller!.findInput<bool>('successTrigger') as SMITrigger?;
      _failTrigger = _controller!.findInput<bool>('failTrigger') as SMITrigger?;
    }
  }

  Future<void> _handleSubmit() async {
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      setState(() => _errorMessage = "Email and password are required.");
      _failTrigger?.fire();
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
      if (result['success']) {
        _successTrigger?.fire();
        
        // Đợi hoạt ảnh thành công kết thúc rồi mới điều hướng
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            setState(() => _isLoading = false);
            // ✅ Đẩy về '/' để Route Guard tự quyết định đích đến (Dashboard hoặc Explore)
            Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
          }
        });
      } else {
        _failTrigger?.fire();
        setState(() {
          _isLoading = false;
          _errorMessage = result['message'];
        });
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
              const Text(
                "MUSICX",
                style: TextStyle(color: Colors.black, fontSize: 42, fontWeight: FontWeight.w900, letterSpacing: 1.5),
              ),
              const Text("Welcome Back", style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: Colors.grey)),
              const SizedBox(height: 30),

              // Rive Bear Animation
              Center(
                child: Container(
                  height: 200, width: 200,
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
                  child: Text(_errorMessage!, style: const TextStyle(color: Colors.redAccent, fontSize: 14, fontWeight: FontWeight.w500)),
                ),

              const SizedBox(height: 40),

              ElevatedButton(
                onPressed: _isLoading ? null : _handleSubmit,
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryBlack,
                  minimumSize: const Size(double.infinity, 60),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                  elevation: 0,
                ),
                child: _isLoading 
                  ? const SizedBox(height: 24, width: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : const Text("Sign In", style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ),

              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("No account?", style: TextStyle(color: Colors.grey)),
                  TextButton(
                    onPressed: () => Navigator.pushNamed(context, '/register'),
                    child: Text("Sign Up Now", style: TextStyle(color: accentGreen, fontWeight: FontWeight.bold)),
                  ),
                ],
              ),
              TextButton(
                onPressed: () {},
                child: const Text("Forgot Password?", style: TextStyle(color: Colors.grey, fontSize: 13)),
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
        style: const TextStyle(color: Colors.black, fontWeight: FontWeight.w500),
        decoration: InputDecoration(
          hintText: hint,
          prefixIcon: Icon(icon, color: Colors.black54),
          suffixIcon: suffixIcon,
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 20, horizontal: 20),
        ),
      ),
    );
  }
}