import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'dart:math' as math;

import '../Auth/register.dart';
import '../CustomerPages/AddCustomerScreen.dart';
import '../CustomerPages/BillListPage.dart';
import '../CustomerPages/CreateQuotationScreen.dart';
import '../CustomerPages/QuotationsListScreen.dart';
import '../Models/customer_model.dart';
import '../items/ItemslistPage.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with TickerProviderStateMixin {
  final DatabaseReference _usersRef =
  FirebaseDatabase.instance.ref().child('users');
  final DatabaseReference _teamsRef =
  FirebaseDatabase.instance.ref().child('teams');
  final DatabaseReference _customersRef =
  FirebaseDatabase.instance.ref().child('customers');

  Map<String, dynamic> _userData = {};
  List<Map<String, dynamic>> _allUsers = [];
  List<Map<String, dynamic>> _allTeams = [];
  Map<String, List<Map<String, dynamic>>> _teamMembersMap = {};
  List<CustomerModel> _allCustomers = [];

  bool _isLoading = true;
  bool _isLoadingTeams = false;
  bool _isLoadingCustomers = false;

  String _searchQuery = '';
  String _selectedRoleFilter = 'All';
  String _selectedCustomerFilter = 'All';
  bool _isGridView = false;

  // Bottom nav index: 0=Users, 1=Teams, 2=Customers, 3=Items
  int _selectedNavIndex = 0;

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

  final List<Color> _teamGradients = [
    const Color(0xFF6B4EFF),
    const Color(0xFF2563EB),
    const Color(0xFF38BDF8),
    const Color(0xFF10B981),
    const Color(0xFFF59E0B),
    const Color(0xFFEF4444),
    const Color(0xFF8B5CF6),
    const Color(0xFFEC4899),
  ];

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
      CurvedAnimation(parent: _animationController, curve: Curves.easeOutQuart),
    );
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _animationController.forward();
    _loadUserData();
    _loadAllUsers();
    _loadAllTeams();
    _loadAllCustomers();
  }

  @override
  void dispose() {
    _animationController.dispose();
    _pulseController.dispose();
    _searchController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // ─────────────────────────────────────────────
  //  DATA LOADERS
  // ─────────────────────────────────────────────

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

  Future<void> _loadAllTeams() async {
    setState(() => _isLoadingTeams = true);
    DatabaseEvent event = await _teamsRef.once();
    List<Map<String, dynamic>> teamsList = [];

    if (event.snapshot.value != null) {
      Map<dynamic, dynamic> teamsMap =
      event.snapshot.value as Map<dynamic, dynamic>;
      teamsMap.forEach((key, value) {
        Map<String, dynamic> team = Map<String, dynamic>.from(value as Map);
        team['id'] = key;
        teamsList.add(team);
      });
    }

    setState(() {
      _allTeams = teamsList;
      _isLoadingTeams = false;
    });

    // load members for each team
    for (var team in teamsList) {
      await _loadTeamMembers(team['id']);
    }
  }

  Future<void> _loadTeamMembers(String teamId) async {
    DatabaseEvent event =
    await _teamsRef.child(teamId).child('members').once();
    List<Map<String, dynamic>> members = [];

    if (event.snapshot.value != null) {
      Map<dynamic, dynamic> membersMap =
      event.snapshot.value as Map<dynamic, dynamic>;
      for (String memberId in membersMap.keys) {
        DatabaseEvent userEvent = await _usersRef.child(memberId).once();
        if (userEvent.snapshot.value != null) {
          Map<String, dynamic> member =
          Map<String, dynamic>.from(userEvent.snapshot.value as Map);
          member['uid'] = memberId;
          members.add(member);
        }
      }
    }

    setState(() {
      _teamMembersMap[teamId] = members;
    });
  }

  Future<void> _loadAllCustomers() async {
    setState(() => _isLoadingCustomers = true);
    _allCustomers.clear();
    DatabaseEvent event = await _customersRef.once();

    if (event.snapshot.value != null) {
      Map<dynamic, dynamic> customersMap =
      event.snapshot.value as Map<dynamic, dynamic>;
      customersMap.forEach((id, data) {
        Map<String, dynamic> customer = Map<String, dynamic>.from(data as Map);
        _allCustomers.add(CustomerModel.fromMap(id, customer));
      });
    }

    setState(() => _isLoadingCustomers = false);
  }

  // ─────────────────────────────────────────────
  //  ACTIONS
  // ─────────────────────────────────────────────

  Future<void> _toggleUserStatus(String uid, bool currentStatus) async {
    await _usersRef.child(uid).update({'isActive': !currentStatus});
    _loadAllUsers();
    if (mounted) _showSuccessSnackBar('User status updated successfully');
  }

  Future<void> _deleteUser(String uid) async {
    bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildDeleteConfirmationSheet('user'),
    );
    if (confirm == true) {
      await _usersRef.child(uid).remove();
      _loadAllUsers();
      if (mounted) _showSuccessSnackBar('User deleted successfully');
    }
  }

  Future<void> _deleteTeam(String teamId) async {
    bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildDeleteConfirmationSheet('team'),
    );
    if (confirm == true) {
      // Unassign all members
      List<Map<String, dynamic>> members = _teamMembersMap[teamId] ?? [];
      for (var member in members) {
        await _usersRef
            .child(member['uid'])
            .update({'managerId': null, 'teamId': null});
      }
      await _teamsRef.child(teamId).remove();
      _loadAllTeams();
      if (mounted) _showSuccessSnackBar('Team deleted successfully');
    }
  }

  Future<void> _deleteCustomer(String customerId) async {
    bool? confirm = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => _buildDeleteConfirmationSheet('customer'),
    );
    if (confirm == true) {
      await _customersRef.child(customerId).remove();
      _loadAllCustomers();
      if (mounted) _showSuccessSnackBar('Customer deleted successfully');
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) Navigator.pushReplacementNamed(context, '/login');
  }

  // ─────────────────────────────────────────────
  //  HELPERS / UTILITIES
  // ─────────────────────────────────────────────

  void _showSuccessSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: const BoxDecoration(
                  color: _pearlWhite, shape: BoxShape.circle),
              child: const Icon(Icons.check_rounded,
                  color: _emeraldGreen, size: 16),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(message,
                  style: const TextStyle(
                      color: _pearlWhite, fontWeight: FontWeight.w500)),
            ),
          ],
        ),
        backgroundColor: _emeraldGreen,
        behavior: SnackBarBehavior.floating,
        shape:
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
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

  Color _getStatusColor(String status) {
    switch (status) {
      case 'Lead':
        return _skyBlue;
      case 'Prospect':
        return _amberGlow;
      case 'Active':
        return _emeraldGreen;
      case 'Inactive':
        return _steelGray;
      default:
        return _steelGray;
    }
  }

  String _formatDate(String? dateString) {
    if (dateString == null || dateString.isEmpty) return 'Unknown';
    try {
      DateTime date = DateTime.parse(dateString);
      const months = [
        'Jan','Feb','Mar','Apr','May','Jun',
        'Jul','Aug','Sep','Oct','Nov','Dec'
      ];
      return '${date.day} ${months[date.month - 1]}, ${date.year}';
    } catch (e) {
      return 'Unknown';
    }
  }

  List<Map<String, dynamic>> get _filteredUsers {
    return _allUsers.where((user) {
      if (_selectedRoleFilter != 'All' &&
          user['role'] != _selectedRoleFilter) return false;
      if (_searchQuery.isNotEmpty) {
        final name = (user['name'] ?? '').toString().toLowerCase();
        final email = (user['email'] ?? '').toString().toLowerCase();
        final query = _searchQuery.toLowerCase();
        return name.contains(query) || email.contains(query);
      }
      return true;
    }).toList();
  }

  List<CustomerModel> get _filteredCustomers {
    if (_selectedCustomerFilter == 'All') return _allCustomers;
    return _allCustomers
        .where((c) => c.status == _selectedCustomerFilter)
        .toList();
  }

  // ─────────────────────────────────────────────
  //  BUILD
  // ─────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkNavy,
      body: _isLoading ? _buildLoadingState() : _buildMainContent(),
      bottomNavigationBar: _buildBottomNavBar(),
    );
  }

  Widget _buildBottomNavBar() {
    return Container(
      decoration: BoxDecoration(
        color: _charcoalBlue,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, -5))
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
        ),
        child: BottomNavigationBar(
          backgroundColor: _charcoalBlue,
          selectedItemColor: _deepPurple,
          unselectedItemColor: _pearlWhite.withOpacity(0.5),
          currentIndex: _selectedNavIndex,
          onTap: (index) => setState(() => _selectedNavIndex = index),
          type: BottomNavigationBarType.fixed,
          elevation: 0,
          items: [
            _navItem(Icons.people_alt_rounded, 'Users', 0),
            _navItem(Icons.groups_rounded, 'Teams', 1),
            _navItem(Icons.person_search_rounded, 'Customers', 2),
            _navItem(Icons.inventory_2_rounded, 'Items', 3),
          ],
        ),
      ),
    );
  }

  BottomNavigationBarItem _navItem(IconData icon, String label, int index) {
    final selected = _selectedNavIndex == index;
    return BottomNavigationBarItem(
      icon: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
          color: selected ? _deepPurple.withOpacity(0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon),
      ),
      label: label,
    );
  }

  Widget _buildMainContent() {
    return FadeTransition(
      opacity: _fadeAnimation,
      child: IndexedStack(
        index: _selectedNavIndex,
        children: [
          _buildUsersTab(),
          _buildTeamsTab(),
          _buildCustomersTab(),
          ItemsListPage(),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  LOADING STATE
  // ─────────────────────────────────────────────

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
                    color: _deepPurple, strokeWidth: 6),
              ),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                      colors: [_deepPurple, _electricIndigo]),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(Icons.dashboard_rounded,
                    color: _pearlWhite, size: 28),
              ),
            ],
          ),
          const SizedBox(height: 32),
          const Text('Loading Dashboard',
              style: TextStyle(
                  color: _pearlWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 8),
          Text('Please wait...',
              style: TextStyle(
                  color: _pearlWhite.withOpacity(0.5), fontSize: 14)),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  SHARED HEADER
  // ─────────────────────────────────────────────

  Widget _buildPageHeader({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    Widget? trailing,
    Widget? searchBar,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.15), _charcoalBlue],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Profile avatar
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) => Transform.scale(
                  scale: _pulseAnimation.value,
                  child: Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      gradient:
                      const LinearGradient(colors: [_deepPurple, _electricIndigo]),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                            color: _deepPurple.withOpacity(0.4),
                            blurRadius: 16,
                            offset: const Offset(0, 6))
                      ],
                    ),
                    child: Center(
                      child: Text(
                        (_userData['name'] ?? 'A')[0].toUpperCase(),
                        style: const TextStyle(
                            color: _pearlWhite,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                            color: _pearlWhite,
                            fontSize: 22,
                            fontWeight: FontWeight.bold)),
                    Text(subtitle,
                        style: TextStyle(
                            color: _pearlWhite.withOpacity(0.6),
                            fontSize: 13)),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: _slateGray.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  icon: const Icon(Icons.logout_rounded, color: _pearlWhite),
                  onPressed: _logout,
                  tooltip: 'Logout',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ),
            ],
          ),
          if (trailing != null) ...[const SizedBox(height: 16), trailing],
          if (searchBar != null) ...[const SizedBox(height: 16), searchBar],
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  USERS TAB
  // ─────────────────────────────────────────────

  Widget _buildUsersTab() {
    int adminCount = _allUsers.where((u) => u['role'] == 'Admin').length;
    int managerCount = _allUsers.where((u) => u['role'] == 'Manager').length;
    int workerCount = _allUsers.where((u) => u['role'] == 'Worker').length;
    int activeCount = _allUsers.where((u) => u['isActive'] == true).length;

    return CustomScrollView(
      controller: _scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _buildPageHeader(
            title: _userData['name'] ?? 'Admin',
            subtitle: 'Admin Dashboard',
            icon: Icons.dashboard_rounded,
            color: _deepPurple,
            searchBar: _buildSearchBar(),
          ),
        ),
        // Stats
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Overview',
                        style: TextStyle(
                            color: _pearlWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: _emeraldGreen.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                            color: _emeraldGreen.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(
                                  color: _emeraldGreen,
                                  shape: BoxShape.circle)),
                          const SizedBox(width: 6),
                          Text('$activeCount Active',
                              style: const TextStyle(
                                  color: _emeraldGreen,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                        child: _buildStatCard('Total Users',
                            _allUsers.length.toString(),
                            Icons.people_alt_rounded, _deepPurple,
                            isMain: true)),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                        child: _buildStatCard('Admins',
                            adminCount.toString(),
                            Icons.admin_panel_settings_rounded, _crimsonRed)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildStatCard('Managers',
                            managerCount.toString(),
                            Icons.manage_accounts_rounded, _amberGlow)),
                    const SizedBox(width: 12),
                    Expanded(
                        child: _buildStatCard('Workers',
                            workerCount.toString(),
                            Icons.engineering_rounded, _skyBlue)),
                  ],
                ),
              ],
            ),
          ),
        ),
        // Quick actions
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Add User',
                      color: _deepPurple,
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const RegistrationScreen(
                              isAdminRegistration: true),
                        ),
                      ).then((_) => _loadAllUsers()),
                    )),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildQuickActionButton(
                      icon: _isGridView
                          ? Icons.view_list_rounded
                          : Icons.grid_view_rounded,
                      label: _isGridView ? 'List View' : 'Grid View',
                      color: _skyBlue,
                      onTap: () => setState(() => _isGridView = !_isGridView),
                    )),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildQuickActionButton(
                      icon: Icons.refresh_rounded,
                      label: 'Refresh',
                      color: _emeraldGreen,
                      onTap: _loadAllUsers,
                    )),
              ],
            ),
          ),
        ),
        // Filter pills
        SliverToBoxAdapter(child: _buildFilterSection()),
        // Users list
        _buildUsersList(),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildSearchBar() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: _slateGray.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _pearlWhite.withOpacity(0.1)),
      ),
      child: TextField(
        controller: _searchController,
        onChanged: (value) => setState(() => _searchQuery = value),
        style: const TextStyle(color: _pearlWhite),
        decoration: InputDecoration(
          hintText: 'Search users...',
          hintStyle: TextStyle(color: _pearlWhite.withOpacity(0.4)),
          border: InputBorder.none,
          icon: Icon(Icons.search_rounded, color: _pearlWhite.withOpacity(0.5)),
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

  Widget _buildStatCard(String label, String value, IconData icon, Color color,
      {bool isMain = false}) {
    return Container(
      padding: EdgeInsets.all(isMain ? 24 : 16),
      decoration: BoxDecoration(
        gradient: isMain
            ? LinearGradient(
            colors: [color, color.withOpacity(0.7)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight)
            : null,
        color: isMain ? null : _charcoalBlue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
        boxShadow: isMain
            ? [BoxShadow(color: color.withOpacity(0.3), blurRadius: 20, offset: const Offset(0, 8))]
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
                child: Icon(icon,
                    color: isMain ? _pearlWhite : color,
                    size: isMain ? 28 : 22),
              ),
              if (isMain)
                IconButton(
                  icon: Icon(Icons.refresh_rounded,
                      color: _pearlWhite.withOpacity(0.7)),
                  onPressed: _loadAllUsers,
                ),
            ],
          ),
          SizedBox(height: isMain ? 16 : 12),
          Text(value,
              style: TextStyle(
                  color: isMain ? _pearlWhite : color,
                  fontSize: isMain ? 36 : 24,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: isMain
                      ? _pearlWhite.withOpacity(0.8)
                      : _pearlWhite.withOpacity(0.5),
                  fontSize: isMain ? 14 : 11)),
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
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 24),
            const SizedBox(height: 8),
            Text(label,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w600)),
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
          Text('Users (${_filteredUsers.length})',
              style: const TextStyle(
                  color: _pearlWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 16),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterPill('All', 'All', _deepPurple),
                _buildFilterPill('Admins', 'Admin', _crimsonRed),
                _buildFilterPill('Managers', 'Manager', _amberGlow),
                _buildFilterPill('Workers', 'Worker', _skyBlue),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterPill(String label, String value, Color pillColor) {
    bool isSelected = _selectedRoleFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedRoleFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(
              colors: [pillColor, pillColor.withOpacity(0.7)])
              : null,
          color: isSelected ? null : _charcoalBlue,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(color: isSelected ? pillColor : _steelGray),
          boxShadow: isSelected
              ? [BoxShadow(
              color: pillColor.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 4))]
              : null,
        ),
        child: Text(label,
            style: TextStyle(
                color: isSelected ? _pearlWhite : _pearlWhite.withOpacity(0.7),
                fontWeight:
                isSelected ? FontWeight.bold : FontWeight.w500)),
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
                (context, index) =>
                _buildUserGridCard(_filteredUsers[index], index),
            childCount: _filteredUsers.length,
          ),
        ),
      );
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList(
        delegate: SliverChildBuilderDelegate(
              (context, index) =>
              _buildUserListCard(_filteredUsers[index], index),
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
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(offset: Offset(30 * (1 - value), 0), child: child),
      ),
      child: Dismissible(
        key: Key(user['uid']),
        direction: DismissDirection.endToStart,
        background: Container(
          margin: const EdgeInsets.only(bottom: 12),
          decoration: BoxDecoration(
              color: _crimsonRed, borderRadius: BorderRadius.circular(20)),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          child: const Icon(Icons.delete_rounded, color: _pearlWhite, size: 28),
        ),
        confirmDismiss: (direction) => showModalBottomSheet<bool>(
          context: context,
          backgroundColor: Colors.transparent,
          isScrollControlled: true,
          builder: (context) => _buildDeleteConfirmationSheet('user'),
        ),
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
              border: Border.all(color: roleColor.withOpacity(0.2)),
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
                        end: Alignment.bottomRight),
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Center(
                    child: Text(
                      (user['name'] ?? 'U')[0].toUpperCase(),
                      style: const TextStyle(
                          color: _pearlWhite,
                          fontSize: 22,
                          fontWeight: FontWeight.bold),
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
                            child: Text(user['name'] ?? 'Unknown',
                                style: const TextStyle(
                                    color: _pearlWhite,
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis),
                          ),
                          Container(
                            width: 10,
                            height: 10,
                            decoration: BoxDecoration(
                              color: isActive ? _emeraldGreen : _crimsonRed,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: (isActive ? _emeraldGreen : _crimsonRed).withOpacity(0.5),
                                  blurRadius: 6,
                                )
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(user['email'] ?? '',
                          style: TextStyle(
                              color: _pearlWhite.withOpacity(0.5),
                              fontSize: 13),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          _buildRoleBadge(user['role'] ?? 'Worker', roleColor),
                          const Spacer(),
                          Icon(Icons.chevron_right_rounded,
                              color: _pearlWhite.withOpacity(0.3)),
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
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.scale(scale: 0.8 + (0.2 * value), child: child),
      ),
      child: GestureDetector(
        onTap: () => _showUserDetailSheet(user),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: _charcoalBlue,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: roleColor.withOpacity(0.2)),
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
                          end: Alignment.bottomRight),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Center(
                      child: Text(
                        (user['name'] ?? 'U')[0].toUpperCase(),
                        style: const TextStyle(
                            color: _pearlWhite,
                            fontSize: 26,
                            fontWeight: FontWeight.bold),
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
                        border: Border.all(color: _charcoalBlue, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(user['name'] ?? 'Unknown',
                  style: const TextStyle(
                      color: _pearlWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center),
              const SizedBox(height: 4),
              Text(user['email'] ?? '',
                  style: TextStyle(
                      color: _pearlWhite.withOpacity(0.5), fontSize: 11),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center),
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
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(_getRoleIcon(role), color: color, size: 14),
          const SizedBox(width: 6),
          Text(role,
              style: TextStyle(
                  color: color, fontSize: 12, fontWeight: FontWeight.w600)),
        ],
      ),
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
              gradient: LinearGradient(colors: [
                _deepPurple.withOpacity(0.1),
                _electricIndigo.withOpacity(0.05)
              ]),
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
                color: _pearlWhite, fontSize: 22, fontWeight: FontWeight.bold),
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
            borderRadius:
            const BorderRadius.vertical(top: Radius.circular(28)),
          ),
          child: Column(
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                    color: _steelGray,
                    borderRadius: BorderRadius.circular(2)),
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
                              end: Alignment.bottomRight),
                          borderRadius: BorderRadius.circular(28),
                          boxShadow: [
                            BoxShadow(
                                color: roleColor.withOpacity(0.4),
                                blurRadius: 24,
                                offset: const Offset(0, 12))
                          ],
                        ),
                        child: Center(
                          child: Text(
                            (user['name'] ?? 'U')[0].toUpperCase(),
                            style: const TextStyle(
                                color: _pearlWhite,
                                fontSize: 40,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(user['name'] ?? 'Unknown',
                          style: const TextStyle(
                              color: _pearlWhite,
                              fontSize: 24,
                              fontWeight: FontWeight.bold)),
                      const SizedBox(height: 8),
                      Text(user['email'] ?? '',
                          style: TextStyle(
                              color: _pearlWhite.withOpacity(0.6),
                              fontSize: 16)),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _buildRoleBadge(user['role'] ?? 'Worker', roleColor),
                          const SizedBox(width: 12),
                          Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 6),
                            decoration: BoxDecoration(
                              color: isActive
                                  ? _emeraldGreen.withOpacity(0.1)
                                  : _crimsonRed.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                  color: isActive
                                      ? _emeraldGreen.withOpacity(0.3)
                                      : _crimsonRed.withOpacity(0.3)),
                            ),
                            child: Row(
                              children: [
                                Container(
                                    width: 8,
                                    height: 8,
                                    decoration: BoxDecoration(
                                        color: isActive
                                            ? _emeraldGreen
                                            : _crimsonRed,
                                        shape: BoxShape.circle)),
                                const SizedBox(width: 6),
                                Text(isActive ? 'Active' : 'Inactive',
                                    style: TextStyle(
                                        color: isActive
                                            ? _emeraldGreen
                                            : _crimsonRed,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w600)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 32),
                      Container(
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
                                color: _skyBlue),
                            _buildDetailItem(
                                icon: Icons.calendar_today_rounded,
                                label: 'Created',
                                value: _formatDate(user['createdAt']),
                                color: _amberGlow),
                            if (user['managerId'] != null)
                              _buildDetailItem(
                                  icon: Icons.supervisor_account_rounded,
                                  label: 'Manager ID',
                                  value: user['managerId'],
                                  color: _deepPurple),
                            if (user['teamId'] != null)
                              _buildDetailItem(
                                  icon: Icons.groups_rounded,
                                  label: 'Team ID',
                                  value: user['teamId'],
                                  color: _emeraldGreen,
                                  isLast: true),
                          ],
                        ),
                      ),
                      const SizedBox(height: 32),
                      Row(
                        children: [
                          Expanded(
                            child: GestureDetector(
                              onTap: () {
                                Navigator.pop(context);
                                _toggleUserStatus(user['uid'], isActive);
                              },
                              child: Container(
                                padding:
                                const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: isActive
                                      ? _amberGlow.withOpacity(0.1)
                                      : _emeraldGreen.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: isActive
                                          ? _amberGlow.withOpacity(0.3)
                                          : _emeraldGreen.withOpacity(0.3)),
                                ),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      isActive
                                          ? Icons.pause_circle_outline_rounded
                                          : Icons.play_circle_outline_rounded,
                                      color: isActive
                                          ? _amberGlow
                                          : _emeraldGreen,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      isActive ? 'Deactivate' : 'Activate',
                                      style: TextStyle(
                                          color: isActive
                                              ? _amberGlow
                                              : _emeraldGreen,
                                          fontWeight: FontWeight.w600),
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
                                padding:
                                const EdgeInsets.symmetric(vertical: 16),
                                decoration: BoxDecoration(
                                  color: _crimsonRed.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                      color: _crimsonRed.withOpacity(0.3)),
                                ),
                                child: const Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.delete_outline_rounded,
                                        color: _crimsonRed),
                                    SizedBox(width: 8),
                                    Text('Delete',
                                        style: TextStyle(
                                            color: _crimsonRed,
                                            fontWeight: FontWeight.w600)),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
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
                borderRadius: BorderRadius.circular(12)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 16),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label,
                  style: TextStyle(
                      color: _pearlWhite.withOpacity(0.5), fontSize: 12)),
              const SizedBox(height: 2),
              Text(value,
                  style: const TextStyle(
                      color: _pearlWhite,
                      fontSize: 15,
                      fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDeleteConfirmationSheet(String itemType) {
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
                  color: _steelGray, borderRadius: BorderRadius.circular(2))),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
                color: _crimsonRed.withOpacity(0.1), shape: BoxShape.circle),
            child: const Icon(Icons.delete_forever_rounded,
                color: _crimsonRed, size: 40),
          ),
          const SizedBox(height: 20),
          Text('Delete ${itemType[0].toUpperCase()}${itemType.substring(1)}?',
              style: const TextStyle(
                  color: _pearlWhite,
                  fontSize: 22,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'This action cannot be undone. All data will be permanently removed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: _pearlWhite.withOpacity(0.6), fontSize: 14),
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
                          borderRadius: BorderRadius.circular(16)),
                      child: const Center(
                          child: Text('Cancel',
                              style: TextStyle(
                                  color: _pearlWhite,
                                  fontWeight: FontWeight.w600))),
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
                            colors: [_crimsonRed, Color(0xFFDC2626)]),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: const Center(
                          child: Text('Delete',
                              style: TextStyle(
                                  color: _pearlWhite,
                                  fontWeight: FontWeight.w600))),
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

  // ─────────────────────────────────────────────
  //  TEAMS TAB
  // ─────────────────────────────────────────────

  Widget _buildTeamsTab() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _buildPageHeader(
            title: 'All Teams',
            subtitle: '${_allTeams.length} teams across the organisation',
            icon: Icons.groups_rounded,
            color: _royalBlue,
          ),
        ),
        // Summary row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(
                    child: _buildSmallStatCard(
                        'Total Teams',
                        _allTeams.length.toString(),
                        Icons.groups_rounded,
                        _royalBlue)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildSmallStatCard(
                        'Total Members',
                        _allTeams
                            .fold<int>(
                            0,
                                (sum, t) =>
                            sum +
                                (_teamMembersMap[t['id']]?.length ?? 0))
                            .toString(),
                        Icons.people_rounded,
                        _emeraldGreen)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildSmallStatCard(
                        'Managers',
                        _allUsers
                            .where((u) => u['role'] == 'Manager')
                            .length
                            .toString(),
                        Icons.manage_accounts_rounded,
                        _amberGlow)),
              ],
            ),
          ),
        ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('Teams (${_allTeams.length})',
                    style: const TextStyle(
                        color: _pearlWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                GestureDetector(
                  onTap: _loadAllTeams,
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                        color: _slateGray,
                        borderRadius: BorderRadius.circular(10)),
                    child: const Icon(Icons.refresh_rounded,
                        color: _pearlWhite, size: 20),
                  ),
                ),
              ],
            ),
          ),
        ),
        _isLoadingTeams
            ? const SliverToBoxAdapter(
            child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: _royalBlue),
                )))
            : _allTeams.isEmpty
            ? SliverToBoxAdapter(
            child: _buildGenericEmptyState(
                icon: Icons.groups_outlined,
                title: 'No Teams Yet',
                message:
                'Teams are created by managers. None found.',
                color: _royalBlue))
            : SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                  _buildTeamCard(_allTeams[index], index),
              childCount: _allTeams.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildSmallStatCard(
      String label, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _charcoalBlue,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(height: 8),
          Text(value,
              style: TextStyle(
                  color: color, fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(label,
              style: TextStyle(
                  color: _pearlWhite.withOpacity(0.5), fontSize: 11),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }

  Widget _buildTeamCard(Map<String, dynamic> team, int index) {
    Color teamColor = _teamGradients[index % _teamGradients.length];
    List<Map<String, dynamic>> members =
        _teamMembersMap[team['id']] ?? [];

    // Find manager name
    String managerName = team['managerName'] ?? 'Unknown';

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 400 + (index * 60)),
      curve: Curves.easeOutQuart,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child:
        Transform.translate(offset: Offset(0, 20 * (1 - value)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          color: _charcoalBlue,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: teamColor.withOpacity(0.2)),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          leading: Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [teamColor, teamColor.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                (team['name'] ?? 'T')[0].toUpperCase(),
                style: const TextStyle(
                    color: _pearlWhite,
                    fontSize: 22,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          title: Text(team['name'] ?? 'Unnamed Team',
              style: const TextStyle(
                  color: _pearlWhite,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(team['description'] ?? 'No description',
                  style: TextStyle(
                      color: _pearlWhite.withOpacity(0.5), fontSize: 12),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildTeamBadge(
                      Icons.star_rounded, managerName, _amberGlow),
                  const SizedBox(width: 8),
                  _buildTeamBadge(Icons.people_rounded,
                      '${members.length} members', teamColor),
                ],
              ),
            ],
          ),
          trailing: const Icon(Icons.expand_more_rounded, color: _pearlWhite),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _slateGray.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Team details
                  _buildDetailItemRow(
                      icon: Icons.calendar_today_rounded,
                      label: 'Created',
                      value: _formatDate(team['createdAt']),
                      color: _skyBlue),
                  _buildDetailItemRow(
                      icon: Icons.manage_accounts_rounded,
                      label: 'Manager',
                      value: managerName,
                      color: _amberGlow),
                  const SizedBox(height: 16),
                  // Members list
                  if (members.isNotEmpty) ...[
                    Text('Members',
                        style: TextStyle(
                            color: _pearlWhite.withOpacity(0.7),
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 10),
                    ...members.map((member) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        children: [
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: teamColor.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Center(
                              child: Text(
                                (member['name'] ?? 'U')[0].toUpperCase(),
                                style: TextStyle(
                                    color: teamColor,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 14),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(member['name'] ?? 'Unknown',
                                    style: const TextStyle(
                                        color: _pearlWhite,
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500)),
                                Text(member['email'] ?? '',
                                    style: TextStyle(
                                        color: _pearlWhite.withOpacity(0.5),
                                        fontSize: 11),
                                    overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: member['isActive'] == true
                                  ? _emeraldGreen
                                  : _crimsonRed,
                              shape: BoxShape.circle,
                            ),
                          ),
                        ],
                      ),
                    )),
                  ] else
                    Text('No members in this team yet.',
                        style: TextStyle(
                            color: _pearlWhite.withOpacity(0.4),
                            fontSize: 13)),
                  const SizedBox(height: 16),
                  // Delete button (admin power)
                  Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      GestureDetector(
                        onTap: () => _deleteTeam(team['id']),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 20, vertical: 10),
                          decoration: BoxDecoration(
                            color: _crimsonRed.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                                color: _crimsonRed.withOpacity(0.3)),
                          ),
                          child: const Row(
                            children: [
                              Icon(Icons.delete_outline_rounded,
                                  color: _crimsonRed, size: 18),
                              SizedBox(width: 6),
                              Text('Delete Team',
                                  style: TextStyle(
                                      color: _crimsonRed,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTeamBadge(IconData icon, String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 12),
          const SizedBox(width: 4),
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600),
              overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }

  Widget _buildDetailItemRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8)),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(label,
                style: TextStyle(
                    color: _pearlWhite.withOpacity(0.5), fontSize: 13)),
          ),
          Expanded(
            child: Text(value,
                style: const TextStyle(color: _pearlWhite, fontSize: 13)),
          ),
        ],
      ),
    );
  }

  // ─────────────────────────────────────────────
  //  CUSTOMERS TAB
  // ─────────────────────────────────────────────

  Widget _buildCustomersTab() {
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverToBoxAdapter(
          child: _buildPageHeader(
            title: 'All Customers',
            subtitle: '${_allCustomers.length} customers in the system',
            icon: Icons.person_search_rounded,
            color: _emeraldGreen,
          ),
        ),
        // Stats row
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
            child: Row(
              children: [
                Expanded(
                    child: _buildSmallStatCard(
                        'Total',
                        _allCustomers.length.toString(),
                        Icons.people_alt_rounded,
                        _emeraldGreen)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildSmallStatCard(
                        'Active',
                        _allCustomers
                            .where((c) => c.status == 'Active')
                            .length
                            .toString(),
                        Icons.check_circle_rounded,
                        _skyBlue)),
                const SizedBox(width: 12),
                Expanded(
                    child: _buildSmallStatCard(
                        'Leads',
                        _allCustomers
                            .where((c) => c.status == 'Lead')
                            .length
                            .toString(),
                        Icons.trending_up_rounded,
                        _amberGlow)),
              ],
            ),
          ),
        ),
        // Filter chips
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Customers (${_filteredCustomers.length})',
                        style: const TextStyle(
                            color: _pearlWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold)),
                    GestureDetector(
                      onTap: _loadAllCustomers,
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                            color: _slateGray,
                            borderRadius: BorderRadius.circular(10)),
                        child: const Icon(Icons.refresh_rounded,
                            color: _pearlWhite, size: 20),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildCustomerFilterPill('All', 'All'),
                      _buildCustomerFilterPill('Active', 'Active'),
                      _buildCustomerFilterPill('Lead', 'Lead'),
                      _buildCustomerFilterPill('Prospect', 'Prospect'),
                      _buildCustomerFilterPill('Inactive', 'Inactive'),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        _isLoadingCustomers
            ? const SliverToBoxAdapter(
            child: Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: _emeraldGreen),
                )))
            : _filteredCustomers.isEmpty
            ? SliverToBoxAdapter(
            child: _buildGenericEmptyState(
                icon: Icons.people_outline_rounded,
                title: 'No Customers Found',
                message: 'No customers match the current filter.',
                color: _emeraldGreen))
            : SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildBuilderDelegate(
                  (context, index) =>
                  _buildCustomerCard(_filteredCustomers[index], index),
              childCount: _filteredCustomers.length,
            ),
          ),
        ),
        const SliverToBoxAdapter(child: SizedBox(height: 100)),
      ],
    );
  }

  Widget _buildCustomerFilterPill(String label, String value) {
    bool isSelected = _selectedCustomerFilter == value;
    return GestureDetector(
      onTap: () => setState(() => _selectedCustomerFilter = value),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(right: 10),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
              colors: [_emeraldGreen, Color(0xFF059669)])
              : null,
          color: isSelected ? null : _charcoalBlue,
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
              color: isSelected ? _emeraldGreen : _steelGray),
          boxShadow: isSelected
              ? [
            BoxShadow(
                color: _emeraldGreen.withOpacity(0.3),
                blurRadius: 10,
                offset: const Offset(0, 4))
          ]
              : null,
        ),
        child: Text(label,
            style: TextStyle(
                color:
                isSelected ? _pearlWhite : _pearlWhite.withOpacity(0.7),
                fontWeight:
                isSelected ? FontWeight.bold : FontWeight.w500,
                fontSize: 13)),
      ),
    );
  }

  Widget _buildCustomerCard(CustomerModel customer, int index) {
    Color statusColor = _getStatusColor(customer.status);

    // Find which team name
    String? teamName;
    if (customer.teamId != null) {
      final team = _allTeams.firstWhere(
            (t) => t['id'] == customer.teamId,
        orElse: () => {},
      );
      if (team.isNotEmpty) teamName = team['name'];
    }

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: Curves.easeOutCubic,
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)), child: child),
      ),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          color: _charcoalBlue,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: statusColor.withOpacity(0.2)),
        ),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.all(16),
          leading: Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                  colors: [statusColor, statusColor.withOpacity(0.6)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                customer.name[0].toUpperCase(),
                style: const TextStyle(
                    color: _pearlWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold),
              ),
            ),
          ),
          title: Text(customer.name,
              style: const TextStyle(
                  color: _pearlWhite,
                  fontWeight: FontWeight.w600,
                  fontSize: 16)),
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 4),
              Text(customer.email,
                  style: TextStyle(
                      color: _pearlWhite.withOpacity(0.6), fontSize: 13),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              const SizedBox(height: 8),
              Row(
                children: [
                  _buildStatusBadge(customer.status, statusColor),
                  if (teamName != null) ...[
                    const SizedBox(width: 8),
                    _buildStatusBadge(teamName, _deepPurple,
                        icon: Icons.groups_rounded),
                  ],
                ],
              ),
            ],
          ),
          trailing: const Icon(Icons.expand_more_rounded, color: _pearlWhite),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: _slateGray.withOpacity(0.3),
                borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(20),
                    bottomRight: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  if (customer.company != null &&
                      customer.company!.isNotEmpty)
                    _buildDetailItemRow(
                        icon: Icons.business_rounded,
                        label: 'Company',
                        value: customer.company!,
                        color: _skyBlue),
                  if (customer.phone.isNotEmpty)
                    _buildDetailItemRow(
                        icon: Icons.phone_rounded,
                        label: 'Phone',
                        value: customer.phone,
                        color: _emeraldGreen),
                  if (customer.address != null &&
                      customer.address!.isNotEmpty)
                    _buildDetailItemRow(
                        icon: Icons.location_on_rounded,
                        label: 'Address',
                        value: customer.address!,
                        color: _amberGlow),
                  _buildDetailItemRow(
                      icon: Icons.person_rounded,
                      label: 'Created by',
                      value: customer.createdByName,
                      color: _electricIndigo),
                  if (customer.assignedToName != null &&
                      customer.assignedToName!.isNotEmpty)
                    _buildDetailItemRow(
                        icon: Icons.assignment_ind_rounded,
                        label: 'Assigned to',
                        value: customer.assignedToName!,
                        color: _royalBlue),
                  if (teamName != null)
                    _buildDetailItemRow(
                        icon: Icons.groups_rounded,
                        label: 'Team',
                        value: teamName,
                        color: _deepPurple),
                  const SizedBox(height: 16),
                  // Action buttons
                  Row(
                    children: [
                      Expanded(
                        child: _buildCustomerActionButton(
                          icon: Icons.description_rounded,
                          label: 'Create Quote',
                          color: _deepPurple,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => CreateQuotationScreen(
                                  customer: customer,
                                  teamId: customer.teamId ??
                                      (_allTeams.isNotEmpty
                                          ? _allTeams.first['id']
                                          : ''),
                                  teamName: teamName ??
                                      (_allTeams.isNotEmpty
                                          ? _allTeams.first['name']
                                          : ''),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCustomerActionButton(
                          icon: Icons.format_list_bulleted_rounded,
                          label: 'View Quotes',
                          color: _amberGlow,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => QuotationsListScreen(
                                  customer: customer,
                                  teamId: customer.teamId ??
                                      (_allTeams.isNotEmpty
                                          ? _allTeams.first['id']
                                          : ''),
                                  teamName: teamName ??
                                      (_allTeams.isNotEmpty
                                          ? _allTeams.first['name']
                                          : ''),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCustomerActionButton(
                          icon: Icons.receipt_rounded,
                          label: 'Bills',
                          color: _skyBlue,
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => BillsListScreen(
                                  teamId: customer.teamId ??
                                      (_allTeams.isNotEmpty
                                          ? _allTeams.first['id']
                                          : ''),
                                  teamName: teamName ??
                                      (_allTeams.isNotEmpty
                                          ? _allTeams.first['name']
                                          : ''),
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: _buildCustomerActionButton(
                          icon: Icons.delete_outline_rounded,
                          label: 'Delete',
                          color: _crimsonRed,
                          onTap: () => _deleteCustomer(customer.id),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusBadge(String label, Color color, {IconData? icon}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 11, color: color),
            const SizedBox(width: 4),
          ],
          Text(label,
              style: TextStyle(
                  color: color, fontSize: 11, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }

  Widget _buildCustomerActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            Icon(icon, color: color, size: 18),
            const SizedBox(height: 4),
            Text(label,
                style: TextStyle(
                    color: color,
                    fontSize: 10,
                    fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  Widget _buildGenericEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(28),
            decoration: BoxDecoration(
              color: color.withOpacity(0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 56, color: color.withOpacity(0.5)),
          ),
          const SizedBox(height: 20),
          Text(title,
              style: const TextStyle(
                  color: _pearlWhite,
                  fontSize: 20,
                  fontWeight: FontWeight.bold)),
          const SizedBox(height: 8),
          Text(message,
              style:
              TextStyle(color: _pearlWhite.withOpacity(0.5), fontSize: 14),
              textAlign: TextAlign.center),
        ],
      ),
    );
  }
}