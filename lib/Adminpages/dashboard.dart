import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math' as math;

import '../Auth/register.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  final DatabaseReference _usersRef =
  FirebaseDatabase.instance.ref().child('users');

  Map<String, dynamic> _userData = {};
  List<Map<String, dynamic>> _allUsers = [];
  bool _isLoading = true;
  String _searchQuery = '';
  String _selectedRoleFilter = 'All';
  bool _isGridView = false;
  bool _isSearchExpanded = false;

  late AnimationController _animationController;
  late AnimationController _pulseController;
  late Animation<double> _fadeAnimation;
  late Animation<double> _pulseAnimation;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _scrollController = ScrollController();

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
  static const Color _steelGray = Color(0xFF334155);
  static const Color _pearlWhite = Color(0xFFF8FAFC);

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeOutQuart,
      ),
    );

    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(
        parent: _pulseController,
        curve: Curves.easeInOut,
      ),
    );

    _animationController.forward();
    _loadUserData();
    _loadAllUsers();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadUserData() async {
    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      DatabaseEvent event = await _usersRef.child(user.uid).once();
      if (event.snapshot.value != null) {
        setState(() {
          _userData = Map<String, dynamic>.from(event.snapshot.value as Map);
        });
      }
    }
  }

  Future<void> _loadAllUsers() async {
    setState(() => _isLoading = true);

    DatabaseEvent event = await _usersRef.once();
    List<Map<String, dynamic>> usersList = [];

    if (event.snapshot.value != null) {
      Map<dynamic, dynamic> usersMap =
      event.snapshot.value as Map<dynamic, dynamic>;
      usersMap.forEach((key, value) {
        Map<String, dynamic> user = Map<String, dynamic>.from(value as Map);
        user['uid'] = key;
        usersList.add(user);
      });
    }

    setState(() {
      _allUsers = usersList;
      _isLoading = false;
    });
  }

  Future<void> _toggleUserStatus(String uid, bool currentStatus) async {
    await _usersRef.child(uid).update({
      'isActive': !currentStatus,
    });
    _loadAllUsers();
    if (mounted) {
      _showSuccessSnackBar('User status updated successfully');
    }
  }

  Future<void> _deleteUser(String uid) async {
    bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildDeleteConfirmationSheet(),
    );

    if (confirm == true) {
      await _usersRef.child(uid).remove();
      _loadAllUsers();
      if (mounted) {
        _showSuccessSnackBar('User deleted successfully');
      }
    }
  }

  Widget _buildDeleteConfirmationSheet() {
    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _charcoalBlue,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: _crimsonRed.withOpacity(0.3)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: _steelGray,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _crimsonRed.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.delete_forever_rounded,
              color: _crimsonRed,
              size: 40,
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            'Delete User?',
            style: TextStyle(
              color: _pearlWhite,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'This action cannot be undone. All user data will be permanently removed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _pearlWhite.withOpacity(0.6),
                fontSize: 14,
              ),
            ),
          ),
          const SizedBox(height: 32),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, false),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        color: _slateGray,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: _pearlWhite,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: GestureDetector(
                    onTap: () => Navigator.pop(context, true),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_crimsonRed, Color(0xFFDC2626)],
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                        child: Text(
                          'Delete',
                          style: TextStyle(
                            color: _pearlWhite,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                color: _pearlWhite,
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.check_rounded,
                color: _emeraldGreen,
                size: 16,
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
        backgroundColor: _emeraldGreen,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'Admin':
        return _crimsonRed;
      case 'Manager':
        return _amberGlow;
      case 'Worker':
        return _skyBlue;
      default:
        return _steelGray;
    }
  }

  IconData _getRoleIcon(String role) {
    switch (role) {
      case 'Admin':
        return Icons.admin_panel_settings_rounded;
      case 'Manager':
        return Icons.manage_accounts_rounded;
      case 'Worker':
        return Icons.engineering_rounded;
      default:
        return Icons.person_rounded;
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    return _allUsers.where((user) {
      if (_selectedRoleFilter != 'All' && user['role'] != _selectedRoleFilter) {
        return false;
      }

      if (_searchQuery.isNotEmpty) {
        final name = (user['name'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || email.contains(query);
      }

      return true;
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkNavy,
      body: _isLoading ? _buildLoadingState() : _buildMainContent(),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [
              SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  color: _deepPurple.withOpacity(0.3),
                  strokeWidth: 6,
                  value: 1,
                ),
              ),
              const SizedBox(
                width: 100,
                height: 100,
                child: CircularProgressIndicator(
                  color: _deepPurple,
                  strokeWidth: 6,
                ),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_deepPurple, _electricIndigo],
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.dashboard_rounded,
                  color: _pearlWhite,
                  size: 28,
                ),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text(
            'Loading Dashboard',
            style: TextStyle(
              color: _pearlWhite,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Please wait...',
            style: TextStyle(
              color: _pearlWhite.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: CustomScrollView(
        controller: _scrollController,
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(),
          SliverToBoxAdapter(child: _buildStatsSection()),
          SliverToBoxAdapter(child: _buildQuickActions()),
          SliverToBoxAdapter(child: _buildFilterSection()),
          _buildUsersList(),
          const SliverToBoxAdapter(child: SizedBox(height: 100)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar() {
    return SliverAppBar(
      expandedHeight: 200,
      floating: false,
      pinned: true,
      backgroundColor: _charcoalBlue,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _deepPurple.withOpacity(0.3),
                _charcoalBlue,
              ],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Stack(
            children: [
              // Decorative circles
              Positioned(
                top: -50,
                right: -50,
                child: Container(
                  width: 200,
                  height: 200,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _deepPurple.withOpacity(0.3),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: -30,
                left: -30,
                child: Container(
                  width: 150,
                  height: 150,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _electricIndigo.withOpacity(0.2),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
              // Content
              SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _buildProfileAvatar(),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Welcome back,',
                                  style: TextStyle(
                                    color: _pearlWhite.withOpacity(0.7),
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  _userData['name'] ?? 'Admin',
                                  style: const TextStyle(
                                    color: _pearlWhite,
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          _buildNotificationBell(),
                        ],
                      ),
                      const Spacer(),
                      _buildSearchBar(),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      actions: [
        Container(
          margin: const EdgeInsets.only(right: 8),
          decoration: BoxDecoration(
            color: _slateGray.withOpacity(0.5),
            borderRadius: BorderRadius.circular(12),
          ),
          child: IconButton(
            icon: const Icon(Icons.logout_rounded, color: _pearlWhite),
            onPressed: _logout,
          ),
        ),
      ],
    );
  }

  Widget _buildProfileAvatar() {
    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        return Transform.scale(
          scale: _pulseAnimation.value,
          child: Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [_deepPurple, _electricIndigo],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: _deepPurple.withOpacity(0.5),
                  blurRadius: 20,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Center(
              child: Text(
                (_userData['name'] ?? 'A')[0].toUpperCase(),
                style: const TextStyle(
                  color: _pearlWhite,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildNotificationBell() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _slateGray.withOpacity(0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Stack(
        children: [
          const Icon(
            Icons.notifications_rounded,
            color: _pearlWhite,
            size: 24,
          ),
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                color: _crimsonRed,
                shape: BoxShape.circle,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _slateGray.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _pearlWhite.withOpacity(0.1),
        ),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(color: _pearlWhite),
        decoration: InputDecoration(
          hintText: 'Search users...',
          hintStyle: TextStyle(color: _pearlWhite.withOpacity(0.4)),
          border: InputBorder.none,
          icon: Icon(
            Icons.search_rounded,
            color: _pearlWhite.withOpacity(0.5),
          ),
          suffixIcon: _searchQuery.isNotEmpty
              ? IconButton(
            icon: const Icon(Icons.clear_rounded, color: _pearlWhite),
            onPressed: () {
              _searchController.clear();
              setState(() => _searchQuery = '');
            },
          )
              : null,
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    int adminCount = _allUsers.where((u) => u['role'] == 'Admin').length;
    int managerCount = _allUsers.where((u) => u['role'] == 'Manager').length;
    int workerCount = _allUsers.where((u) => u['role'] == 'Worker').length;
    int activeCount = _allUsers.where((u) => u['isActive'] == true).length;

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Overview',
                style: TextStyle(
                  color: _pearlWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
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
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: const BoxDecoration(
                        color: _emeraldGreen,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      '$activeCount Active',
                      style: const TextStyle(
                        color: _emeraldGreen,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Total Users',
                  _allUsers.length.toString(),
                  Icons.people_alt_rounded,
                  _deepPurple,
                  isMain: true,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _buildStatCard(
                  'Admins',
                  adminCount.toString(),
                  Icons.admin_panel_settings_rounded,
                  _crimsonRed,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Managers',
                  managerCount.toString(),
                  Icons.manage_accounts_rounded,
                  _amberGlow,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _buildStatCard(
                  'Workers',
                  workerCount.toString(),
                  Icons.engineering_rounded,
                  _skyBlue,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(
      String label,
      String value,
      IconData icon,
      Color color, {
        bool isMain = false,
      }) {
    return Container(
      padding: EdgeInsets.all(isMain ? 24 : 16),
      decoration: BoxDecoration(
        gradient: isMain
            ? LinearGradient(
          colors: [color, color.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: isMain ? null : _charcoalBlue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
        boxShadow: isMain
            ? [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ]
            : null,
      ),
      child: Column(
        crossAxisAlignment:
        isMain ? CrossAxisAlignment.start : CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment:
            isMain ? MainAxisAlignment.spaceBetween : MainAxisAlignment.center,
            children: [
              Container(
                padding: EdgeInsets.all(isMain ? 12 : 10),
                decoration: BoxDecoration(
                  color: isMain
                      ? _pearlWhite.withOpacity(0.2)
                      : color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isMain ? 14 : 12),
                ),
                child: Icon(
                  icon,
                  color: isMain ? _pearlWhite : color,
                  size: isMain ? 28 : 22,
                ),
              ),
              if (isMain)
                IconButton(
                  icon: Icon(
                    Icons.refresh_rounded,
                    color: _pearlWhite.withOpacity(0.7),
                  ),
                  onPressed: _loadAllUsers,
                ),
            ],
          ),
          SizedBox(height: isMain ? 16 : 12),
          Text(
            value,
            style: TextStyle(
              color: isMain ? _pearlWhite : color,
              fontSize: isMain ? 36 : 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: isMain
                  ? _pearlWhite.withOpacity(0.8)
                  : _pearlWhite.withOpacity(0.5),
              fontSize: isMain ? 14 : 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActions() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(
            child: _buildQuickActionButton(
              icon: Icons.person_add_alt_1_rounded,
              label: 'Add User',
              color: _deepPurple,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegistrationScreen(
                      isAdminRegistration: true,
                    ),
                  ),
                ).then((_) => _loadAllUsers());
              },
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionButton(
              icon: _isGridView ? Icons.view_list_rounded : Icons.grid_view_rounded,
              label: _isGridView ? 'List View' : 'Grid View',
              color: _skyBlue,
              onTap: () => setState(() => _isGridView = !_isGridView),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildQuickActionButton(
              icon: Icons.download_rounded,
              label: 'Export',
              color: _emeraldGreen,
              onTap: () {},
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuickActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterSection() {
    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Users (${_filteredUsers.length})',
                style: const TextStyle(
                  color: _pearlWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterPill('All', 'All'),
                _buildFilterPill('Admins', 'Admin'),
                _buildFilterPill('Managers', 'Manager'),
                _buildFilterPill('Workers', 'Worker'),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label, String value) {
    bool isSelected = _selectedRoleFilter == value;
    Color pillColor;

    switch (value) {
      case 'Admin':
        pillColor = _crimsonRed;
        break;
      case 'Manager':
        pillColor = _amberGlow;
        break;
      case 'Worker':
        pillColor = _skyBlue;
        break;
      default:
        pillColor = _deepPurple;
    }

    return GestureDetector(
      onTap: () => setState(() => _selectedRoleFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
            colors: [pillColor, pillColor.withOpacity(0.7)],
          )
              : null,
          color: isSelected ? null : _charcoalBlue,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected ? pillColor : _steelGray,
          ),
          boxShadow: isSelected
              ? [
            BoxShadow(
              color: pillColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ]
              : null,
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? _pearlWhite : _pearlWhite.withOpacity(0.7),
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ),
    );
  }

  Widget _buildUsersList() {
    if (_filteredUsers.isEmpty) {
      return SliverToBoxAdapter(child: _buildEmptyState());
    }

    if (_isGridView) {
      return SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverGrid(
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 0.85,
          ),
          delegate: SliverChildBuilderDelegate(
                (context, index) => _buildUserGridCard(_filteredUsers[index], index),
            childCount: _filteredUsers.length,
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) => _buildUserListCard(_filteredUsers[index], index),
          childCount: _filteredUsers.length,
        ),
      ),
    );
  }

  Widget _buildUserListCard(Map<String, dynamic> user, int index) {
    Color roleColor = _getRoleColor(user['role'] ?? 'Worker');
    bool isActive = user['isActive'] == true;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 50)),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(30 * (1 - value), 0),
            child: child,
          ),
        );
      },
      child: Dismissible(
        key: Key(user['uid']),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
            color: _crimsonRed,
            borderRadius: BorderRadius.circular(20),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(
            Icons.delete_rounded,
            color: _pearlWhite,
            size: 28,
          ),
        ),
        confirmDismiss: (direction) async {
          return await showModalBottomSheet<bool>(
            context: context,
            backgroundColor: Colors.transparent,
            isScrollControlled: true,
            builder: (context) => _buildDeleteConfirmationSheet(),
          );
        },
        onDismissed: (direction) {
          _usersRef.child(user['uid']).remove();
          _loadAllUsers();
          _showSuccessSnackBar('User deleted successfully');
        },
        child: GestureDetector(
          onTap: () => _showUserDetailSheet(user),
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _charcoalBlue,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: roleColor.withOpacity(0.2),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [roleColor, roleColor.withOpacity(0.6)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      (user['name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                        color: _pearlWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              user['name'] ?? 'Unknown',
                              style: const TextStyle(
                                color: _pearlWhite,
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isActive ? _emeraldGreen : _crimsonRed,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (isActive ? _emeraldGreen : _crimsonRed)
                                      .withOpacity(0.5),
                                  blurRadius: 6,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        user['email'] ?? '',
                        style: TextStyle(
                          color: _pearlWhite.withOpacity(0.5),
                          fontSize: 13,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildRoleBadge(user['role'] ?? 'Worker', roleColor),
                          const Spacer(),
                          Icon(
                            Icons.chevron_right_rounded,
                            color: _pearlWhite.withOpacity(0.3),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildUserGridCard(Map<String, dynamic> user, int index) {
    Color roleColor = _getRoleColor(user['role'] ?? 'Worker');
    bool isActive = user['isActive'] == true;

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 50)),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.scale(
            scale: 0.8 + (0.2 * value),
            child: child,
          ),
        );
      },
      child: GestureDetector(
        onTap: () => _showUserDetailSheet(user),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _charcoalBlue,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: roleColor.withOpacity(0.2),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [roleColor, roleColor.withOpacity(0.6)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        (user['name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                          color: _pearlWhite,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 0,
                    bottom: 0,
                    child: Container(
                      width: 16,
                      height: 16,
                      decoration: BoxDecoration(
                        color: isActive ? _emeraldGreen : _crimsonRed,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: _charcoalBlue,
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                user['name'] ?? 'Unknown',
                style: const TextStyle(
                  color: _pearlWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 4),
              Text(
                user['email'] ?? '',
                style: TextStyle(
                  color: _pearlWhite.withOpacity(0.5),
                  fontSize: 11,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
              ),
              const Spacer(),
              _buildRoleBadge(user['role'] ?? 'Worker', roleColor),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRoleBadge(String role, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            _getRoleIcon(role),
            color: color,
            size: 14,
          ),
          const SizedBox(width: 6),
          Text(
            role,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  void _showUserDetailSheet(Map<String, dynamic> user) {
    Color roleColor = _getRoleColor(user['role'] ?? 'Worker');
    bool isActive = user['isActive'] == true;

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        minChildSize: 0.5,
        maxChildSize: 0.95,
        builder: (context, scrollController) => Container(
          decoration: BoxDecoration(
            color: _charcoalBlue,
            borderRadius: const BorderRadius.vertical(
              top: Radius.circular(28),
            ),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: _steelGray,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Expanded(
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    children: [
                      Container(
                        width: 100,
                        height: 100,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [roleColor, roleColor.withOpacity(0.6)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                              color: roleColor.withOpacity(0.4),
                              blurRadius: 24,
                              offset: const Offset(0, 12),
                            ),
                          ],
                        ),
                        child: Center(
                          child: Text(
                            (user['name'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                              color: _pearlWhite,
                              fontSize: 40,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        user['name'] ?? 'Unknown',
                        style: const TextStyle(
                          color: _pearlWhite,
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        user['email'] ?? '',
                        style: TextStyle(
                          color: _pearlWhite.withOpacity(0.6),
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildRoleBadge(user['role'] ?? 'Worker', roleColor),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? _emeraldGreen.withOpacity(0.1)
                                  : _crimsonRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: isActive
                                    ? _emeraldGreen.withOpacity(0.3)
                                    : _crimsonRed.withOpacity(0.3),
                              ),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color:
                                    isActive ? _emeraldGreen : _crimsonRed,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  isActive ? 'Active' : 'Inactive',
                                  style: TextStyle(
                                    color:
                                    isActive ? _emeraldGreen : _crimsonRed,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      _buildDetailSection(user),
                      const SizedBox(height: 32),
                      _buildActionButtons(user, isActive),
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

  Widget _buildDetailSection(Map<String, dynamic> user) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _slateGray.withOpacity(0.3),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          _buildDetailItem(
            icon: Icons.phone_rounded,
            label: 'Phone',
            value: user['phone'] ?? 'Not provided',
            color: _skyBlue,
          ),
          _buildDetailItem(
            icon: Icons.calendar_today_rounded,
            label: 'Created',
            value: _formatDate(user['createdAt']),
            color: _amberGlow,
          ),
          if (user['managerId'] != null)
            _buildDetailItem(
              icon: Icons.supervisor_account_rounded,
              label: 'Manager ID',
              value: user['managerId'],
              color: _deepPurple,
            ),
          if (user['teamId'] != null)
            _buildDetailItem(
              icon: Icons.groups_rounded,
              label: 'Team ID',
              value: user['teamId'],
              color: _emeraldGreen,
              isLast: true,
            ),
        ],
      ),
    );
  }

  Widget _buildDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    bool isLast = false,
  }) {
    return Padding(
      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(
                  color: _pearlWhite.withOpacity(0.5),
                  fontSize: 12,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                value,
                style: const TextStyle(
                  color: _pearlWhite,
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionButtons(Map<String, dynamic> user, bool isActive) {
    return Row(
      children: [
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _toggleUserStatus(user['uid'], isActive);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: isActive
                    ? _amberGlow.withOpacity(0.1)
                    : _emeraldGreen.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isActive
                      ? _amberGlow.withOpacity(0.3)
                      : _emeraldGreen.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    isActive
                        ? Icons.pause_circle_outline_rounded
                        : Icons.play_circle_outline_rounded,
                    color: isActive ? _amberGlow : _emeraldGreen,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    isActive ? 'Deactivate' : 'Activate',
                    style: TextStyle(
                      color: isActive ? _amberGlow : _emeraldGreen,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: GestureDetector(
            onTap: () {
              Navigator.pop(context);
              _deleteUser(user['uid']);
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16),
              decoration: BoxDecoration(
                color: _crimsonRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: _crimsonRed.withOpacity(0.3),
                ),
              ),
              child: const Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.delete_outline_rounded,
                    color: _crimsonRed,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'Delete',
                    style: TextStyle(
                      color: _crimsonRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(32),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _deepPurple.withOpacity(0.1),
                  _electricIndigo.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            child: Icon(
              _searchQuery.isNotEmpty || _selectedRoleFilter != 'All'
                  ? Icons.search_off_rounded
                  : Icons.people_outline_rounded,
              size: 64,
              color: _deepPurple.withOpacity(0.5),
            ),
          ),
          const SizedBox(height: 24),
          Text(
            _searchQuery.isNotEmpty || _selectedRoleFilter != 'All'
                ? 'No Results Found'
                : 'No Users Yet',
            style: const TextStyle(
              color: _pearlWhite,
              fontSize: 22,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            _searchQuery.isNotEmpty || _selectedRoleFilter != 'All'
                ? 'Try adjusting your search or filters'
                : 'Add your first user to get started',
            style: TextStyle(
              color: _pearlWhite.withOpacity(0.5),
              fontSize: 15,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          if (_searchQuery.isEmpty && _selectedRoleFilter == 'All')
            GestureDetector(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const RegistrationScreen(
                      isAdminRegistration: true,
                    ),
                  ),
                ).then((_) => _loadAllUsers());
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 32,
                  vertical: 16,
                ),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    colors: [_deepPurple, _electricIndigo],
                  ),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: _deepPurple.withOpacity(0.4),
                      blurRadius: 16,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.person_add_alt_1_rounded,
                      color: _pearlWhite,
                    ),
                    SizedBox(width: 12),
                    Text(
                      'Add First User',
                      style: TextStyle(
                        color: _pearlWhite,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Unknown';
    try {
      DateTime date = DateTime.parse(dateString);
      List<String> months = [
        'Jan',
        'Feb',
        'Mar',
        'Apr',
        'May',
        'Jun',
        'Jul',
        'Aug',
        'Sep',
        'Oct',
        'Nov',
        'Dec'
      ];
      return '${date.day} ${months[date.month - 1]}, ${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }
}