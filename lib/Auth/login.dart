import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _rememberMe = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Premium color palette matching dashboards
  static const Color _deepPurple = Color(0xFF6B4EFF);
  static const Color _electricIndigo = Color(0xFF4A3AFF);
  static const Color _royalBlue = Color(0xFF2563EB);
  static const Color _skyBlue = Color(0xFF38BDF8);
  static const Color _emeraldGreen = Color(0xFF10B981);
  static const Color _amberGlow = Color(0xFFF59E0B);
  static const Color _crimsonRed = Color(0xFFEF4444);
  static const Color _darkNavy = Color(0xFF0B1120);
  static const Color _slateGray = Color(0xFF1E293B);
  static const Color _charcoalBlue = Color(0xFF0F172A);
  static const Color _steelGray = Color(0xFF334155);
  static const Color _pearlWhite = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.2),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      final userCredential = await FirebaseAuth.instance
          .signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      final userRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(userCredential.user!.uid);

      final event = await userRef.once();

      if (event.snapshot.value == null) {
        await FirebaseAuth.instance.signOut();
        throw Exception('User data not found');
      }

      final userData = Map<String, dynamic>.from(
          event.snapshot.value as Map<dynamic, dynamic>);
      final role = userData['role'] ?? 'Worker';
      final isActive = userData['isActive'] ?? true;

      if (!isActive) {
        await FirebaseAuth.instance.signOut();
        if (mounted) {
          _showErrorSnackBar('Your account has been deactivated');
        }
        return;
      }

      if (mounted) {
        switch (role) {
          case 'Admin':
            Navigator.pushReplacementNamed(context, '/admin-dashboard');
            break;
          case 'Manager':
            Navigator.pushReplacementNamed(context, '/manager-dashboard');
            break;
          default:
            Navigator.pushReplacementNamed(context, '/worker-dashboard');
        }
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Authentication failed';
      switch (e.code) {
        case 'user-not-found':
          message = 'No account found with this email';
          break;
        case 'wrong-password':
          message = 'Incorrect password';
          break;
        case 'invalid-email':
          message = 'Invalid email format';
          break;
        case 'user-disabled':
          message = 'This account has been disabled';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your connection.';
          break;
        default:
          message = 'Login failed: ${e.message}';
          break;
      }
      if (mounted) _showErrorSnackBar(message);
    } on FirebaseException catch (e) {
      if (mounted) _showErrorSnackBar('Database error: ${e.message}');
    } catch (e) {
      if (mounted) _showErrorSnackBar('Connection error. Please try again.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _pearlWhite.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.close_rounded,
                color: _crimsonRed,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _pearlWhite,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _crimsonRed.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _pearlWhite.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: _emeraldGreen,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _pearlWhite,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _emeraldGreen.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  void _showForgotPasswordDialog() {
    final emailController = TextEditingController();

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _charcoalBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_deepPurple, _electricIndigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.lock_reset_rounded,
                color: _pearlWhite,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Reset Password',
              style: TextStyle(
                color: _pearlWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Enter your email address to receive a password reset link',
              style: TextStyle(
                color: _pearlWhite.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 20),
            Container(
              decoration: BoxDecoration(
                color: _slateGray,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: Colors.white.withOpacity(0.05),
                ),
              ),
              child: TextFormField(
                controller: emailController,
                style: const TextStyle(color: _pearlWhite),
                decoration: InputDecoration(
                  hintText: 'your@email.com',
                  hintStyle: TextStyle(
                    color: _pearlWhite.withOpacity(0.3),
                  ),
                  prefixIcon: Icon(
                    Icons.email_outlined,
                    color: _deepPurple.withOpacity(0.8),
                  ),
                  border: InputBorder.none,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            style: TextButton.styleFrom(
              foregroundColor: _pearlWhite.withOpacity(0.7),
              padding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 12,
              ),
            ),
            child: const Text('Cancel'),
          ),
          Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_deepPurple, _electricIndigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () async {
                if (emailController.text.isNotEmpty) {
                  try {
                    await FirebaseAuth.instance
                        .sendPasswordResetEmail(email: emailController.text.trim());
                    if (context.mounted) {
                      Navigator.pop(context);
                      _showSuccessSnackBar('Password reset email sent!');
                    }
                  } on FirebaseAuthException catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      _showErrorSnackBar('Error: ${e.message}');
                    }
                  } catch (e) {
                    if (context.mounted) {
                      Navigator.pop(context);
                      _showErrorSnackBar('Failed to send reset email');
                    }
                  }
                }
              },
              style: TextButton.styleFrom(
                foregroundColor: _pearlWhite,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
              child: const Text('Send Reset Link'),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              _darkNavy,
              _charcoalBlue,
              _darkNavy,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            physics: const ClampingScrollPhysics(),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  SizedBox(height: MediaQuery.of(context).size.height * 0.08),
                  FadeTransition(
                    opacity: _fadeAnimation,
                    child: _buildHeader(),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.05),
                  SlideTransition(
                    position: _slideAnimation,
                    child: _buildLoginCard(),
                  ),
                  SizedBox(height: MediaQuery.of(context).size.height * 0.03),
                  _buildFooter(),
                  SizedBox(height: 20),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      children: [
        Container(
          width: 100,
          height: 100,
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_deepPurple, _electricIndigo, _royalBlue],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(
                color: _deepPurple.withOpacity(0.4),
                blurRadius: 25,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: const Icon(
            Icons.work_history_rounded,
            size: 50,
            color: _pearlWhite,
          ),
        ),
        const SizedBox(height: 28),
        const Text(
          'Welcome Back',
          style: TextStyle(
            fontSize: 36,
            fontWeight: FontWeight.w700,
            color: _pearlWhite,
            letterSpacing: -0.5,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Sign in to continue to your dashboard',
          style: TextStyle(
            fontSize: 16,
            color: _pearlWhite.withOpacity(0.6),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildLoginCard() {
    return Container(
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        color: _charcoalBlue,
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.3),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
          BoxShadow(
            color: _deepPurple.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildEmailField(),
            const SizedBox(height: 24),
            _buildPasswordField(),
            const SizedBox(height: 20),
            _buildRememberAndForgot(),
            const SizedBox(height: 32),
            _buildLoginButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _deepPurple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.email_rounded,
                size: 14,
                color: _deepPurple,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Email Address',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _pearlWhite.withOpacity(0.9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _slateGray,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _deepPurple.withOpacity(0.3),
            ),
          ),
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: _pearlWhite, fontSize: 16),
            decoration: InputDecoration(
              hintText: 'your@email.com',
              hintStyle: TextStyle(
                color: _pearlWhite.withOpacity(0.3),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.mail_outline_rounded,
                color: _deepPurple.withOpacity(0.8),
                size: 22,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Email is required';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$')
                  .hasMatch(value)) {
                return 'Enter a valid email';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _deepPurple.withOpacity(0.2),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(
                Icons.lock_rounded,
                size: 14,
                color: _deepPurple,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Password',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _pearlWhite.withOpacity(0.9),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          decoration: BoxDecoration(
            color: _slateGray,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: _deepPurple.withOpacity(0.3),
            ),
          ),
          child: TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: _pearlWhite, fontSize: 16),
            decoration: InputDecoration(
              hintText: '••••••••',
              hintStyle: TextStyle(
                color: _pearlWhite.withOpacity(0.3),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: _deepPurple.withOpacity(0.8),
                size: 22,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: _deepPurple.withOpacity(0.8),
                  size: 22,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 16,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRememberAndForgot() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            SizedBox(
              width: 20,
              height: 20,
              child: Checkbox(
                value: _rememberMe,
                onChanged: (value) {
                  setState(() => _rememberMe = value ?? false);
                },
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(6),
                ),
                side: BorderSide(
                  color: _pearlWhite.withOpacity(0.3),
                  width: 2,
                ),
                activeColor: _deepPurple,
                checkColor: _pearlWhite,
              ),
            ),
            const SizedBox(width: 8),
            Text(
              'Remember me',
              style: TextStyle(
                fontSize: 14,
                color: _pearlWhite.withOpacity(0.7),
              ),
            ),
          ],
        ),
        TextButton(
          onPressed: _showForgotPasswordDialog,
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: Text(
            'Forgot Password?',
            style: TextStyle(
              color: _deepPurple,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildLoginButton() {
    return Container(
      width: double.infinity,
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [_deepPurple, _electricIndigo],
        ),
        boxShadow: [
          BoxShadow(
            color: _deepPurple.withOpacity(0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _login,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: _isLoading
            ? const SizedBox(
          height: 24,
          width: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2.5,
            valueColor: AlwaysStoppedAnimation<Color>(_pearlWhite),
          ),
        )
            : Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            Text(
              'Sign In',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _pearlWhite,
              ),
            ),
            SizedBox(width: 8),
            Icon(
              Icons.arrow_forward_rounded,
              color: _pearlWhite,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFooter() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          "Don't have an account? ",
          style: TextStyle(
            color: _pearlWhite.withOpacity(0.6),
            fontSize: 14,
          ),
        ),
        TextButton(
          onPressed: () {
            // Navigate to registration or contact admin
            _showInfoSnackBar('Please contact your administrator');
          },
          style: TextButton.styleFrom(
            padding: EdgeInsets.zero,
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text(
            'Contact Admin',
            style: TextStyle(
              color: _deepPurple,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
      ],
    );
  }

  void _showInfoSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(4),
              decoration: BoxDecoration(
                color: _pearlWhite.withOpacity(0.2),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.info_rounded,
                color: _skyBlue,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(
                  color: _pearlWhite,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _skyBlue.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }
}