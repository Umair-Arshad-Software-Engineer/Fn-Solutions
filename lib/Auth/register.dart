// Modified RegistrationScreen with role restriction parameter
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';

class RegistrationScreen extends StatefulWidget {
  final bool isAdminRegistration; // true when coming from admin dashboard
  final String? managerId; // optional manager ID if registering workers for specific manager

  const RegistrationScreen({
    super.key,
    this.isAdminRegistration = false,
    this.managerId,
  });

  @override
  State<RegistrationScreen> createState() => _RegistrationScreenState();
}

class _RegistrationScreenState extends State<RegistrationScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String _selectedRole = 'Worker';
  bool _isLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _acceptTerms = false;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Premium color palette
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
  static const Color _pearlWhite = Color(0xFFF8FAFC);

  List<String> get _availableRoles {
    if (widget.isAdminRegistration) {
      return ['Manager', 'Worker'];
    } else {
      return ['Worker']; // Manager dashboard can only register workers
    }
  }

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutCubic,
      ),
    );

    _animationController.forward();

    // Set default role based on available options
    if (!widget.isAdminRegistration) {
      _selectedRole = 'Worker';
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptTerms) {
      _showErrorSnackBar('Please accept the terms and conditions');
      return;
    }

    setState(() => _isLoading = true);

    try {
      // 1. Create user with email & password
      final userCredential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Prepare user data
      Map<String, dynamic> userData = {
        'name': _nameController.text.trim(),
        'email': _emailController.text.trim(),
        'password':_passwordController.text.trim(),
        'phone': _phoneController.text.trim(),
        'role': _selectedRole,
        'createdAt': DateTime.now().toIso8601String(),
        'isActive': true,
        'avatar': '',
        'department': '',
      };

      // 3. If registering a worker from manager dashboard, assign to that manager
      if (!widget.isAdminRegistration && _selectedRole == 'Worker' && widget.managerId != null) {
        userData['managerId'] = widget.managerId;
        // You might want to add team assignment logic here
      }

      // 4. Save user data to Realtime Database
      final userRef = FirebaseDatabase.instance
          .ref()
          .child('users')
          .child(userCredential.user!.uid);

      await userRef.set(userData);

      if (mounted) {
        _showSuccessDialog();
      }
    } on FirebaseAuthException catch (e) {
      String message = 'Registration failed';
      switch (e.code) {
        case 'weak-password':
          message = 'Password is too weak';
          break;
        case 'email-already-in-use':
          message = 'Email is already registered';
          break;
        case 'invalid-email':
          message = 'Invalid email address';
          break;
        case 'network-request-failed':
          message = 'Network error. Please check your connection.';
          break;
        default:
          message = 'Registration failed: ${e.message}';
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

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: _charcoalBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [_deepPurple, _electricIndigo],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            shape: BoxShape.circle,
          ),
          child: const Icon(
            Icons.check_rounded,
            color: _pearlWhite,
            size: 40,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Registration Successful!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: _pearlWhite,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Your account has been created successfully.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: _pearlWhite.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              decoration: BoxDecoration(
                color: _emeraldGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: _emeraldGreen.withOpacity(0.3),
                ),
              ),
              child: Text(
                'Role: $_selectedRole',
                style: const TextStyle(
                  color: _emeraldGreen,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        actions: [
          Container(
            width: double.infinity,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_deepPurple, _electricIndigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () {
                Navigator.pop(context);
                Navigator.pushReplacementNamed(context, '/login');
              },
              style: TextButton.styleFrom(
                foregroundColor: _pearlWhite,
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text(
                'Continue to Login',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline_rounded, color: _pearlWhite),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: _crimsonRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    String title = widget.isAdminRegistration
        ? 'Create Account'
        : 'Register New Worker';

    return Scaffold(
      backgroundColor: _darkNavy,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: _charcoalBlue,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
              ),
            ),
            child: const Icon(
              Icons.arrow_back_rounded,
              color: _pearlWhite,
              size: 20,
            ),
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: _pearlWhite.withOpacity(0.9),
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          physics: const ClampingScrollPhysics(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: SlideTransition(
                position: _slideAnimation,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 20),
                    _buildHeader(),
                    const SizedBox(height: 24),
                    _buildFormCard(),
                    const SizedBox(height: 24),
                    _buildTermsAndConditions(),
                    const SizedBox(height: 24),
                    _buildRegisterButton(),
                    const SizedBox(height: 24),
                    if (!widget.isAdminRegistration) _buildBackToDashboardLink(),
                    const SizedBox(height: 20),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _deepPurple.withOpacity(0.2),
            _electricIndigo.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: _deepPurple.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_deepPurple, _electricIndigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(
              widget.isAdminRegistration
                  ? Icons.admin_panel_settings_rounded
                  : Icons.person_add_alt_1_rounded,
              color: _pearlWhite,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.isAdminRegistration
                      ? 'Admin Registration'
                      : 'Worker Registration',
                  style: const TextStyle(
                    color: _pearlWhite,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  widget.isAdminRegistration
                      ? 'Create manager or worker accounts'
                      : 'Add new workers to your team',
                  style: TextStyle(
                    color: _pearlWhite.withOpacity(0.6),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 6,
            ),
            decoration: BoxDecoration(
              color: _deepPurple.withOpacity(0.2),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _deepPurple.withOpacity(0.3),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 8,
                  height: 8,
                  decoration: const BoxDecoration(
                    color: _deepPurple,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  _availableRoles.join(' · '),
                  style: const TextStyle(
                    color: _deepPurple,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _charcoalBlue,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildNameField(),
            const SizedBox(height: 20),
            _buildEmailField(),
            const SizedBox(height: 20),
            _buildPhoneField(),
            const SizedBox(height: 20),
            if (widget.isAdminRegistration) _buildRoleDropdown(),
            const SizedBox(height: 20),
            _buildPasswordField(),
            const SizedBox(height: 20),
            _buildConfirmPasswordField(),
          ],
        ),
      ),
    );
  }

  Widget _buildNameField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Full Name',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _pearlWhite.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _slateGray,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          child: TextFormField(
            controller: _nameController,
            style: const TextStyle(color: _pearlWhite, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'John Doe',
              hintStyle: TextStyle(
                color: _pearlWhite.withOpacity(0.3),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.person_outline_rounded,
                color: _pearlWhite.withOpacity(0.5),
                size: 22,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Name is required';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildEmailField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Email Address',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _pearlWhite.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _slateGray,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          child: TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            style: const TextStyle(color: _pearlWhite, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'you@company.com',
              hintStyle: TextStyle(
                color: _pearlWhite.withOpacity(0.3),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.mail_outline_rounded,
                color: _pearlWhite.withOpacity(0.5),
                size: 22,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Email is required';
              }
              if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
                return 'Invalid email format';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildPhoneField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Phone Number',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _pearlWhite.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _slateGray,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          child: TextFormField(
            controller: _phoneController,
            keyboardType: TextInputType.phone,
            style: const TextStyle(color: _pearlWhite, fontSize: 15),
            decoration: InputDecoration(
              hintText: '+1 (555) 000-0000',
              hintStyle: TextStyle(
                color: _pearlWhite.withOpacity(0.3),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.phone_outlined,
                color: _pearlWhite.withOpacity(0.5),
                size: 22,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Phone number is required';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildRoleDropdown() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Role',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _pearlWhite.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _slateGray,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          child: DropdownButtonFormField<String>(
            value: _selectedRole,
            dropdownColor: _charcoalBlue,
            icon: Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _pearlWhite.withOpacity(0.5),
            ),
            style: const TextStyle(
              color: _pearlWhite,
              fontSize: 15,
            ),
            decoration: InputDecoration(
              prefixIcon: Icon(
                Icons.work_outline_rounded,
                color: _pearlWhite.withOpacity(0.5),
                size: 22,
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 6,
              ),
            ),
            items: _availableRoles.map((role) {
              return DropdownMenuItem(
                value: role,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: role == 'Manager' ? _amberGlow : _skyBlue,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(role),
                  ],
                ),
              );
            }).toList(),
            onChanged: (value) {
              setState(() => _selectedRole = value!);
            },
          ),
        ),
        const SizedBox(height: 8),
        Text(
          _selectedRole == 'Manager'
              ? 'Managers can create teams and manage workers'
              : 'Workers can be assigned to teams by managers',
          style: TextStyle(
            fontSize: 11,
            color: _pearlWhite.withOpacity(0.4),
          ),
        ),
      ],
    );
  }

  Widget _buildPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Password',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _pearlWhite.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _slateGray,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          child: TextFormField(
            controller: _passwordController,
            obscureText: _obscurePassword,
            style: const TextStyle(color: _pearlWhite, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Create a password',
              hintStyle: TextStyle(
                color: _pearlWhite.withOpacity(0.3),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: _pearlWhite.withOpacity(0.5),
                size: 22,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscurePassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: _pearlWhite.withOpacity(0.5),
                  size: 22,
                ),
                onPressed: () {
                  setState(() => _obscurePassword = !_obscurePassword);
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Password is required';
              }
              if (value.length < 8) {
                return 'Password must be at least 8 characters';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildConfirmPasswordField() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Confirm Password',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: _pearlWhite.withOpacity(0.8),
          ),
        ),
        const SizedBox(height: 6),
        Container(
          decoration: BoxDecoration(
            color: _slateGray,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: Colors.white.withOpacity(0.05),
            ),
          ),
          child: TextFormField(
            controller: _confirmPasswordController,
            obscureText: _obscureConfirmPassword,
            style: const TextStyle(color: _pearlWhite, fontSize: 15),
            decoration: InputDecoration(
              hintText: 'Confirm your password',
              hintStyle: TextStyle(
                color: _pearlWhite.withOpacity(0.3),
                fontSize: 15,
              ),
              prefixIcon: Icon(
                Icons.lock_outline_rounded,
                color: _pearlWhite.withOpacity(0.5),
                size: 22,
              ),
              suffixIcon: IconButton(
                icon: Icon(
                  _obscureConfirmPassword
                      ? Icons.visibility_off_rounded
                      : Icons.visibility_rounded,
                  color: _pearlWhite.withOpacity(0.5),
                  size: 22,
                ),
                onPressed: () {
                  setState(() => _obscureConfirmPassword = !_obscureConfirmPassword);
                },
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'Please confirm your password';
              }
              if (value != _passwordController.text) {
                return 'Passwords do not match';
              }
              return null;
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTermsAndConditions() {
    return Row(
      children: [
        SizedBox(
          width: 24,
          height: 24,
          child: Checkbox(
            value: _acceptTerms,
            onChanged: (value) {
              setState(() => _acceptTerms = value ?? false);
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
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            'I agree to the Terms of Service and Privacy Policy',
            style: TextStyle(
              fontSize: 13,
              color: _pearlWhite.withOpacity(0.7),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterButton() {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: const LinearGradient(
          colors: [_deepPurple, _electricIndigo],
        ),
        boxShadow: [
          BoxShadow(
            color: _deepPurple.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: _isLoading ? null : _register,
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
            : Text(
          widget.isAdminRegistration ? 'Create Account' : 'Register Worker',
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: _pearlWhite,
          ),
        ),
      ),
    );
  }

  Widget _buildBackToDashboardLink() {
    return Center(
      child: TextButton(
        onPressed: () => Navigator.pop(context),
        style: TextButton.styleFrom(
          foregroundColor: _pearlWhite.withOpacity(0.7),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.arrow_back_rounded, size: 18),
            const SizedBox(width: 8),
            const Text('Back to Dashboard'),
          ],
        ),
      ),
    );
  }
}