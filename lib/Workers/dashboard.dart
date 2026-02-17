import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../CustomerPages/AddCustomerScreen.dart';
import '../CustomerPages/BillListPage.dart';
import '../CustomerPages/CreateQuotationScreen.dart';
import '../CustomerPages/QuotationsListScreen.dart';
import '../Models/customer_model.dart';

class WorkerDashboard extends StatefulWidget {
  const WorkerDashboard({super.key});

  @override
  State<WorkerDashboard> createState() => _WorkerDashboardState();
}

class _WorkerDashboardState extends State<WorkerDashboard>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _usersRef =
  FirebaseDatabase.instance.ref().child('users');
  final DatabaseReference _teamsRef =
  FirebaseDatabase.instance.ref().child('teams');
  final DatabaseReference _customersRef =
  FirebaseDatabase.instance.ref().child('customers');
  final DatabaseReference _tasksRef =
  FirebaseDatabase.instance.ref().child('tasks');

  Map<String, dynamic> _workerData = {};
  Map<String, dynamic>? _myTeamInfo;
  List<Map<String, dynamic>> _teamMembers = [];
  List<CustomerModel> _myCustomers = [];
  List<Map<String, dynamic>> _myTasks = [];
  Map<String, dynamic>? _selectedCustomer;

  bool _isLoading = true;
  bool _isLoadingCustomers = true;
  int _selectedIndex = 0;

  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  // Premium color palette - Matching Manager Dashboard
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
  static const Color _violet = Color(0xFF8B5CF6);
  static const Color _pink = Color(0xFFEC4899);

  // Worker colors - softer, more approachable palette
  final List<Color> _workerGradients = [
    const Color(0xFF38BDF8), // Sky Blue
    const Color(0xFF10B981), // Emerald Green
    const Color(0xFFF59E0B), // Amber
    const Color(0xFF8B5CF6), // Violet
    const Color(0xFFEC4899), // Pink
    const Color(0xFF6B4EFF), // Deep Purple
  ];

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
    _loadWorkerData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadWorkerData() async {
    setState(() => _isLoading = true);

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Load worker's own data
      DatabaseEvent userEvent = await _usersRef.child(user.uid).once();
      if (userEvent.snapshot.value != null) {
        _workerData =
        Map<String, dynamic>.from(userEvent.snapshot.value as Map);

        // Load worker's team if assigned
        if (_workerData['teamId'] != null) {
          await _loadMyTeam(_workerData['teamId']);
        }
      }

      // Load worker's customers
      await _loadMyCustomers();

      // Load worker's tasks
      await _loadMyTasks();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadMyTeam(String teamId) async {
    DatabaseEvent teamEvent = await _teamsRef.child(teamId).once();
    if (teamEvent.snapshot.value != null) {
      _myTeamInfo = Map<String, dynamic>.from(teamEvent.snapshot.value as Map);
      _myTeamInfo?['id'] = teamId;

      // Load team members
      await _loadTeamMembers(teamId);
    }
  }

  Future<void> _loadTeamMembers(String teamId) async {
    _teamMembers.clear();

    DatabaseEvent teamEvent =
    await _teamsRef.child(teamId).child('members').once();
    if (teamEvent.snapshot.value != null) {
      Map<dynamic, dynamic> membersMap =
      teamEvent.snapshot.value as Map<dynamic, dynamic>;

      for (String memberId in membersMap.keys) {
        DatabaseEvent userEvent = await _usersRef.child(memberId).once();
        if (userEvent.snapshot.value != null) {
          Map<String, dynamic> member =
          Map<String, dynamic>.from(userEvent.snapshot.value as Map);
          member['uid'] = memberId;
          _teamMembers.add(member);
        }
      }
    }
  }

  Future<void> _loadMyCustomers() async {
    setState(() => _isLoadingCustomers = true);
    _myCustomers.clear();

    User? user = FirebaseAuth.instance.currentUser;

    DatabaseEvent customersEvent = await _customersRef.once();
    if (customersEvent.snapshot.value != null) {
      Map<dynamic, dynamic> customersMap =
      customersEvent.snapshot.value as Map<dynamic, dynamic>;

      customersMap.forEach((customerId, customerData) {
        Map<String, dynamic> customer =
        Map<String, dynamic>.from(customerData as Map);

        // Workers see customers assigned to them OR created by them
        if (customer['assignedTo'] == user?.uid ||
            customer['createdBy'] == user?.uid) {
          _myCustomers.add(CustomerModel.fromMap(customerId, customer));
        }
      });
    }

    setState(() => _isLoadingCustomers = false);
  }

  Future<void> _loadMyTasks() async {
    User? user = FirebaseAuth.instance.currentUser;
    _myTasks.clear();

    DatabaseEvent tasksEvent = await _tasksRef.once();
    if (tasksEvent.snapshot.value != null) {
      Map<dynamic, dynamic> tasksMap =
      tasksEvent.snapshot.value as Map<dynamic, dynamic>;

      tasksMap.forEach((taskId, taskData) {
        Map<String, dynamic> task =
        Map<String, dynamic>.from(taskData as Map);
        if (task['assignedTo'] == user?.uid) {
          task['id'] = taskId;
          _myTasks.add(task);
        }
      });
    }

    // Sort tasks by due date
    _myTasks.sort((a, b) {
      DateTime aDate = DateTime.parse(a['dueDate'] ?? DateTime.now().toIso8601String());
      DateTime bDate = DateTime.parse(b['dueDate'] ?? DateTime.now().toIso8601String());
      return aDate.compareTo(bDate);
    });
  }

  Future<void> _updateTaskStatus(String taskId, String status) async {
    await _tasksRef.child(taskId).update({
      'status': status,
      'updatedAt': DateTime.now().toIso8601String(),
    });
    await _loadMyTasks();
    if (mounted) {
      _showSuccessSnackBar('✅ Task marked as $status');
    }
  }

  void _navigateToAddCustomer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCustomerScreen(
          teamId: _workerData['teamId'],
          teamName: _myTeamInfo?['name'],
          assignedTo: FirebaseAuth.instance.currentUser?.uid,
          assignedToName: _workerData['name'],
        ),
      ),
    ).then((refresh) {
      if (refresh == true) {
        _loadMyCustomers();
      }
    });
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
        duration: const Duration(seconds: 3),
      ),
    );
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
        duration: const Duration(seconds: 3),
      ),
    );
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

  Color _getPriorityColor(String priority) {
    switch (priority) {
      case 'High':
        return _crimsonRed;
      case 'Medium':
        return _amberGlow;
      case 'Low':
        return _emeraldGreen;
      default:
        return _steelGray;
    }
  }

  String _formatDate(String dateString) {
    try {
      DateTime date = DateTime.parse(dateString);
      return '${date.day}/${date.month}/${date.year}';
    } catch (e) {
      return dateString;
    }
  }

  String _getTimeRemaining(DateTime dueDate) {
    final now = DateTime.now();
    final difference = dueDate.difference(now).inDays;

    if (difference < 0) {
      return 'Overdue';
    } else if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Tomorrow';
    } else {
      return '$difference days left';
    }
  }

  @override
  Widget build(BuildContext context) {
    Color workerColor = _workerGradients[
    (_workerData['name']?.length ?? 0) % _workerGradients.length];

    return Scaffold(
      backgroundColor: _darkNavy,
      appBar: AppBar(
        backgroundColor: _charcoalBlue,
        elevation: 0,
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [workerColor, workerColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: workerColor.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                backgroundColor: Colors.transparent,
                child: Text(
                  _workerData['name']?[0].toUpperCase() ?? 'W',
                  style: const TextStyle(
                    color: _pearlWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _workerData['name'] ?? 'Worker',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _pearlWhite,
                    letterSpacing: 0.3,
                  ),
                ),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: _myTeamInfo != null
                        ? workerColor.withOpacity(0.2)
                        : _crimsonRed.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _myTeamInfo != null
                          ? workerColor.withOpacity(0.3)
                          : _crimsonRed.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    _myTeamInfo != null
                        ? _myTeamInfo!['name'] ?? 'No Team'
                        : 'No Team',
                    style: TextStyle(
                      fontSize: 11,
                      color: _myTeamInfo != null
                          ? workerColor.withOpacity(0.9)
                          : _crimsonRed,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _slateGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.refresh_rounded,
                color: _pearlWhite,
                size: 22,
              ),
              onPressed: _loadWorkerData,
              tooltip: 'Refresh',
            ),
          ),
          Container(
            margin: const EdgeInsets.only(right: 8),
            decoration: BoxDecoration(
              color: _slateGray,
              borderRadius: BorderRadius.circular(12),
            ),
            child: IconButton(
              icon: const Icon(
                Icons.logout_rounded,
                color: _pearlWhite,
                size: 22,
              ),
              onPressed: _logout,
              tooltip: 'Logout',
            ),
          ),
        ],
      ),
      body: _isLoading
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [workerColor, workerColor.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: const Center(
                child: CircularProgressIndicator(
                  color: _pearlWhite,
                  strokeWidth: 3,
                ),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Loading your workspace...',
              style: TextStyle(
                color: _pearlWhite.withOpacity(0.7),
                fontSize: 14,
              ),
            ),
          ],
        ),
      )
          : FadeTransition(
        opacity: _fadeAnimation,
        child: SlideTransition(
          position: _slideAnimation,
          child: IndexedStack(
            index: _selectedIndex,
            children: [
              _buildOverviewTab(workerColor),
              _buildCustomersTab(workerColor),
              _buildTeamTab(workerColor),
              _buildTasksTab(workerColor),
            ],
          ),
        ),
      ),
      bottomNavigationBar: Container(
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
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
          child: BottomNavigationBar(
            backgroundColor: _charcoalBlue,
            selectedItemColor: workerColor,
            unselectedItemColor: _pearlWhite.withOpacity(0.5),
            currentIndex: _selectedIndex,
            onTap: (index) {
              setState(() => _selectedIndex = index);
            },
            items: [
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 0
                        ? workerColor.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.dashboard_rounded),
                ),
                label: 'Overview',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 1
                        ? _emeraldGreen.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.people_rounded),
                ),
                label: 'Customers',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 2
                        ? _deepPurple.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.groups_rounded),
                ),
                label: 'Team',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 3
                        ? _amberGlow.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.task_alt_rounded),
                ),
                label: 'Tasks',
              ),
            ],
            type: BottomNavigationBarType.fixed,
            elevation: 0,
          ),
        ),
      ),
      floatingActionButton: _selectedIndex == 1
          ? Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [_emeraldGreen, workerColor],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _emeraldGreen.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _navigateToAddCustomer,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(
            Icons.add_rounded,
            color: _pearlWhite,
          ),
          label: const Text(
            'Add Customer',
            style: TextStyle(
              color: _pearlWhite,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.5,
            ),
          ),
        ),
      )
          : null,
    );
  }

  // ============= OVERVIEW TAB =============
  Widget _buildOverviewTab(Color workerColor) {
    int activeCustomers = _myCustomers.where((c) => c.status == 'Active').length;
    int pendingTasks = _myTasks.where((t) => t['status'] != 'Completed').length;
    int overdueTasks = _myTasks.where((t) {
      if (t['status'] == 'Completed') return false;
      try {
        DateTime dueDate = DateTime.parse(t['dueDate']);
        return dueDate.isBefore(DateTime.now());
      } catch (e) {
        return false;
      }
    }).length;

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      child: Column(
        children: [
          // Welcome Header
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _charcoalBlue,
                  _charcoalBlue.withOpacity(0.8),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(32),
                bottomRight: Radius.circular(32),
              ),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      width: 70,
                      height: 70,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [workerColor, workerColor.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: workerColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          (_workerData['name'] ?? 'W')[0].toUpperCase(),
                          style: const TextStyle(
                            color: _pearlWhite,
                            fontSize: 32,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 20),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Good ${_getTimeOfDay()},',
                            style: TextStyle(
                              color: _pearlWhite.withOpacity(0.7),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _workerData['name']?.split(' ')[0] ?? 'Worker',
                            style: const TextStyle(
                              color: _pearlWhite,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: BoxDecoration(
                                  color: _workerData['isActive'] == true
                                      ? _emeraldGreen
                                      : _crimsonRed,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                _workerData['isActive'] == true
                                    ? 'Active Now'
                                    : 'Offline',
                                style: TextStyle(
                                  color: _workerData['isActive'] == true
                                      ? _emeraldGreen
                                      : _crimsonRed,
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Stats Cards
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _buildGlassStatCard(
                        title: 'My Customers',
                        value: _myCustomers.length.toString(),
                        icon: Icons.people_rounded,
                        color: _emeraldGreen,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildGlassStatCard(
                        title: 'Active',
                        value: activeCustomers.toString(),
                        icon: Icons.check_circle_rounded,
                        color: workerColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: _buildGlassStatCard(
                        title: 'Pending Tasks',
                        value: pendingTasks.toString(),
                        icon: Icons.pending_actions_rounded,
                        color: _amberGlow,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _buildGlassStatCard(
                        title: 'Overdue',
                        value: overdueTasks.toString(),
                        icon: Icons.warning_rounded,
                        color: _crimsonRed,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Quick Actions Grid
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: workerColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        Icons.flash_on_rounded,
                        color: workerColor,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Quick Actions',
                      style: TextStyle(
                        color: _pearlWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                GridView.count(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  crossAxisCount: 4,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.9,
                  children: [
                    _buildQuickActionButton(
                      icon: Icons.person_add_alt_1_rounded,
                      label: 'Add Customer',
                      color: _emeraldGreen,
                      onTap: _navigateToAddCustomer,
                    ),
                    _buildQuickActionButton(
                      icon: Icons.task_alt_rounded,
                      label: 'New Task',
                      color: _amberGlow,
                      onTap: () {
                        _showCreateTaskDialog();
                      },
                    ),
                    _buildQuickActionButton(
                      icon: Icons.message_rounded,
                      label: 'Team Chat',
                      color: workerColor,
                      onTap: () {
                        _showComingSoonSnackBar('Team Chat');
                      },
                    ),
                    _buildQuickActionButton(
                      icon: Icons.calendar_month_rounded,
                      label: 'Schedule',
                      color: _deepPurple,
                      onTap: () {
                        _showComingSoonSnackBar('Schedule');
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Upcoming Tasks
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _amberGlow.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.task_alt_rounded,
                            color: _amberGlow,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Upcoming Tasks',
                          style: TextStyle(
                            color: _pearlWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedIndex = 3);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: workerColor,
                      ),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _myTasks.isEmpty
                    ? _buildEmptyState(
                  icon: Icons.task_alt_rounded,
                  title: 'No Tasks',
                  message: 'You have no tasks assigned',
                  color: _amberGlow,
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _myTasks.length > 3 ? 3 : _myTasks.length,
                  itemBuilder: (context, index) {
                    var task = _myTasks[index];
                    return _buildCompactTaskCard(task, workerColor);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Recent Customers
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: _emeraldGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: const Icon(
                            Icons.history_rounded,
                            color: _emeraldGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'Recent Customers',
                          style: TextStyle(
                            color: _pearlWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    TextButton(
                      onPressed: () {
                        setState(() => _selectedIndex = 1);
                      },
                      style: TextButton.styleFrom(
                        foregroundColor: workerColor,
                      ),
                      child: const Text('View All'),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                _myCustomers.isEmpty
                    ? _buildEmptyState(
                  icon: Icons.people_outline_rounded,
                  title: 'No Customers',
                  message: 'Add your first customer to get started',
                  color: _emeraldGreen,
                  action: _navigateToAddCustomer,
                  actionLabel: 'Add Customer',
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _myCustomers.length > 3 ? 3 : _myCustomers.length,
                  itemBuilder: (context, index) {
                    var customer = _myCustomers[index];
                    return _buildCompactCustomerCard(customer, workerColor);
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Performance Summary
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.analytics_rounded,
                        color: _deepPurple,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Text(
                      'Your Performance',
                      style: TextStyle(
                        color: _pearlWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        _charcoalBlue,
                        _charcoalBlue.withOpacity(0.8),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: workerColor.withOpacity(0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildPerformanceMetric(
                            label: 'Tasks Done',
                            value: _myTasks
                                .where((t) => t['status'] == 'Completed')
                                .length
                                .toString(),
                            icon: Icons.check_circle_rounded,
                            color: _emeraldGreen,
                          ),
                          _buildPerformanceMetric(
                            label: 'Customers',
                            value: _myCustomers.length.toString(),
                            icon: Icons.people_rounded,
                            color: workerColor,
                          ),
                          _buildPerformanceMetric(
                            label: 'Completion',
                            value: _myTasks.isEmpty
                                ? '0%'
                                : '${((_myTasks.where((t) => t['status'] == 'Completed').length / _myTasks.length) * 100).toInt()}%',
                            icon: Icons.percent_rounded,
                            color: _amberGlow,
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      LinearProgressIndicator(
                        value: _myTasks.isEmpty
                            ? 0
                            : _myTasks.where((t) => t['status'] == 'Completed').length /
                            _myTasks.length,
                        backgroundColor: _slateGray,
                        valueColor: AlwaysStoppedAnimation<Color>(_emeraldGreen),
                        minHeight: 8,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Progress',
                            style: TextStyle(
                              color: _pearlWhite.withOpacity(0.6),
                              fontSize: 12,
                            ),
                          ),
                          Text(
                            '${_myTasks.where((t) => t['status'] == 'Completed').length}/${_myTasks.length} tasks',
                            style: TextStyle(
                              color: _pearlWhite.withOpacity(0.8),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
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
        ],
      ),
    );
  }

  Widget _buildGlassStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _charcoalBlue,
            _charcoalBlue.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  icon,
                  color: color,
                  size: 20,
                ),
              ),
              Text(
                value,
                style: TextStyle(
                  color: color,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: _pearlWhite.withOpacity(0.7),
              fontSize: 13,
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
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              _charcoalBlue,
              _charcoalBlue.withOpacity(0.8),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: color.withOpacity(0.3),
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              color: color,
              size: 28,
            ),
            const SizedBox(height: 8),
            Text(
              label,
              style: TextStyle(
                color: color,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceMetric({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            icon,
            color: color,
            size: 20,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            color: color,
            fontSize: 20,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            color: _pearlWhite.withOpacity(0.6),
            fontSize: 11,
          ),
        ),
      ],
    );
  }

  Widget _buildCompactTaskCard(Map<String, dynamic> task, Color workerColor) {
    Color priorityColor = _getPriorityColor(task['priority']);
    bool isCompleted = task['status'] == 'Completed';

    DateTime dueDate = DateTime.parse(task['dueDate'] ?? DateTime.now().toIso8601String());
    String timeRemaining = _getTimeRemaining(dueDate);
    bool isOverdue = dueDate.isBefore(DateTime.now()) && !isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _charcoalBlue,
            _charcoalBlue.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isOverdue
              ? _crimsonRed.withOpacity(0.3)
              : isCompleted
              ? _emeraldGreen.withOpacity(0.2)
              : priorityColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 50,
            decoration: BoxDecoration(
              color: isOverdue
                  ? _crimsonRed
                  : isCompleted
                  ? _emeraldGreen
                  : priorityColor,
              borderRadius: BorderRadius.circular(4),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  task['title'] ?? 'Untitled Task',
                  style: TextStyle(
                    color: isCompleted
                        ? _pearlWhite.withOpacity(0.5)
                        : _pearlWhite,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    decoration: isCompleted ? TextDecoration.lineThrough : null,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: isOverdue
                            ? _crimsonRed.withOpacity(0.1)
                            : isCompleted
                            ? _emeraldGreen.withOpacity(0.1)
                            : priorityColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        isOverdue ? 'Overdue' : timeRemaining,
                        style: TextStyle(
                          color: isOverdue
                              ? _crimsonRed
                              : isCompleted
                              ? _emeraldGreen
                              : priorityColor,
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Icon(
                      Icons.circle_rounded,
                      size: 6,
                      color: _pearlWhite.withOpacity(0.3),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      task['priority'] ?? 'Medium',
                      style: TextStyle(
                        color: priorityColor,
                        fontSize: 11,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Checkbox(
            value: isCompleted,
            onChanged: (value) {
              _updateTaskStatus(
                task['id'],
                value == true ? 'Completed' : 'Pending',
              );
            },
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(6),
            ),
            activeColor: _emeraldGreen,
            checkColor: _pearlWhite,
          ),
        ],
      ),
    );
  }

  Widget _buildCompactCustomerCard(CustomerModel customer, Color workerColor) {
    Color statusColor = _getStatusColor(customer.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _charcoalBlue,
            _charcoalBlue.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 45,
            height: 45,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [statusColor, statusColor.withOpacity(0.7)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Center(
              child: Text(
                customer.name[0].toUpperCase(),
                style: const TextStyle(
                  color: _pearlWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  customer.name,
                  style: const TextStyle(
                    color: _pearlWhite,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  customer.email,
                  style: TextStyle(
                    color: _pearlWhite.withOpacity(0.6),
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 6),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    customer.status,
                    style: TextStyle(
                      color: statusColor,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: _pearlWhite.withOpacity(0.5),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState({
    required IconData icon,
    required String title,
    required String message,
    required Color color,
    VoidCallback? action,
    String? actionLabel,
  }) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: _charcoalBlue,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: Colors.white.withOpacity(0.05),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            size: 48,
            color: _pearlWhite.withOpacity(0.3),
          ),
          const SizedBox(height: 12),
          Text(
            title,
            style: TextStyle(
              color: _pearlWhite.withOpacity(0.8),
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: TextStyle(
              color: _pearlWhite.withOpacity(0.5),
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          if (action != null) ...[
            const SizedBox(height: 16),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color, color.withOpacity(0.7)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(12),
              ),
              child: ElevatedButton.icon(
                onPressed: action,
                icon: const Icon(Icons.add_rounded),
                label: Text(actionLabel ?? 'Add'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: _pearlWhite,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 10,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  String _getTimeOfDay() {
    final hour = DateTime.now().hour;
    if (hour < 12) {
      return 'Morning';
    } else if (hour < 17) {
      return 'Afternoon';
    } else {
      return 'Evening';
    }
  }

  void _showComingSoonSnackBar(String feature) {
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
                Icons.hourglass_empty_rounded,
                color: _amberGlow,
                size: 18,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                '$feature coming soon!',
                style: const TextStyle(
                  color: _pearlWhite,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
        backgroundColor: _amberGlow.withOpacity(0.9),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        margin: const EdgeInsets.all(16),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  void _showCreateTaskDialog() {
    final titleController = TextEditingController();
    final descriptionController = TextEditingController();
    DateTime selectedDate = DateTime.now().add(const Duration(days: 7));
    String selectedPriority = 'Medium';

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) {
          return AlertDialog(
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
                      colors: [_amberGlow, _deepPurple],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.task_alt_rounded,
                    color: _pearlWhite,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Create New Task',
                  style: TextStyle(
                    color: _pearlWhite,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(height: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: _slateGray,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: TextFormField(
                      controller: titleController,
                      style: const TextStyle(color: _pearlWhite),
                      decoration: InputDecoration(
                        labelText: 'Task Title',
                        labelStyle: TextStyle(
                          color: _pearlWhite.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                        hintText: 'e.g., Follow up with client',
                        hintStyle: TextStyle(
                          color: _pearlWhite.withOpacity(0.3),
                        ),
                        prefixIcon: Icon(
                          Icons.title_rounded,
                          color: _amberGlow.withOpacity(0.8),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    decoration: BoxDecoration(
                      color: _slateGray,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: TextFormField(
                      controller: descriptionController,
                      style: const TextStyle(color: _pearlWhite),
                      maxLines: 3,
                      decoration: InputDecoration(
                        labelText: 'Description',
                        labelStyle: TextStyle(
                          color: _pearlWhite.withOpacity(0.7),
                          fontWeight: FontWeight.w500,
                        ),
                        hintText: 'Add task details...',
                        hintStyle: TextStyle(
                          color: _pearlWhite.withOpacity(0.3),
                        ),
                        prefixIcon: Padding(
                          padding: const EdgeInsets.only(bottom: 30),
                          child: Icon(
                            Icons.description_rounded,
                            color: _amberGlow.withOpacity(0.8),
                          ),
                        ),
                        border: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 20,
                          vertical: 16,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: _slateGray,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: Colors.white.withOpacity(0.1),
                            ),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Due Date',
                                style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.5),
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  Icon(
                                    Icons.calendar_today_rounded,
                                    size: 16,
                                    color: _amberGlow.withOpacity(0.8),
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    '${selectedDate.day}/${selectedDate.month}/${selectedDate.year}',
                                    style: const TextStyle(
                                      color: _pearlWhite,
                                      fontSize: 14,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                  const Spacer(),
                                  TextButton(
                                    onPressed: () async {
                                      DateTime? picked = await showDatePicker(
                                        context: context,
                                        initialDate: selectedDate,
                                        firstDate: DateTime.now(),
                                        lastDate: DateTime.now().add(const Duration(days: 365)),
                                        builder: (context, child) {
                                          return Theme(
                                            data: ThemeData.dark().copyWith(
                                              colorScheme: const ColorScheme.dark(
                                                primary: _amberGlow,
                                                onPrimary: _pearlWhite,
                                                surface: _charcoalBlue,
                                                onSurface: _pearlWhite,
                                              ),
                                            ),
                                            child: child!,
                                          );
                                        },
                                      );
                                      if (picked != null) {
                                        setDialogState(() {
                                          selectedDate = picked;
                                        });
                                      }
                                    },
                                    style: TextButton.styleFrom(
                                      foregroundColor: _amberGlow,
                                      minimumSize: Size.zero,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                                    ),
                                    child: const Text('Change'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: _slateGray,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Priority',
                          style: TextStyle(
                            color: _pearlWhite.withOpacity(0.5),
                            fontSize: 12,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Row(
                          children: [
                            _buildPriorityChip(
                              'Low',
                              _emeraldGreen,
                              selectedPriority == 'Low',
                                  () {
                                setDialogState(() {
                                  selectedPriority = 'Low';
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildPriorityChip(
                              'Medium',
                              _amberGlow,
                              selectedPriority == 'Medium',
                                  () {
                                setDialogState(() {
                                  selectedPriority = 'Medium';
                                });
                              },
                            ),
                            const SizedBox(width: 8),
                            _buildPriorityChip(
                              'High',
                              _crimsonRed,
                              selectedPriority == 'High',
                                  () {
                                setDialogState(() {
                                  selectedPriority = 'High';
                                });
                              },
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ],
              ),
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
                    colors: [_amberGlow, _deepPurple],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton(
                  onPressed: () {
                    if (titleController.text.isNotEmpty) {
                      // TODO: Save task to Firebase
                      Navigator.pop(context);
                      _showSuccessSnackBar('✅ Task created successfully');
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: _pearlWhite,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Create Task'),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPriorityChip(String label, Color color, bool isSelected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withOpacity(0.2) : Colors.transparent,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? color : _pearlWhite.withOpacity(0.8),
            fontSize: 13,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
          ),
        ),
      ),
    );
  }

  // ============= CUSTOMERS TAB =============
  Widget _buildCustomersTab(Color workerColor) {
    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _charcoalBlue,
                _charcoalBlue.withOpacity(0.8),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_emeraldGreen, workerColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.people_rounded,
                      color: _pearlWhite,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'My Customers',
                          style: TextStyle(
                            color: _pearlWhite,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_myCustomers.length} total · ${_myCustomers.where((c) => c.status == 'Active').length} active',
                          style: TextStyle(
                            color: _pearlWhite.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_emeraldGreen, workerColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: ElevatedButton.icon(
                      onPressed: _navigateToAddCustomer,
                      icon: const Icon(Icons.add_rounded),
                      label: const Text('Add'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        shadowColor: Colors.transparent,
                        foregroundColor: _pearlWhite,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 10,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // Status Filter Chips
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: [
                    _buildFilterChip('All', _myCustomers.length, null, workerColor),
                    _buildFilterChip(
                      'Active',
                      _myCustomers.where((c) => c.status == 'Active').length,
                      'Active',
                      workerColor,
                    ),
                    _buildFilterChip(
                      'Lead',
                      _myCustomers.where((c) => c.status == 'Lead').length,
                      'Lead',
                      workerColor,
                    ),
                    _buildFilterChip(
                      'Prospect',
                      _myCustomers.where((c) => c.status == 'Prospect').length,
                      'Prospect',
                      workerColor,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _isLoadingCustomers
              ? Center(
            child: CircularProgressIndicator(
              color: workerColor,
            ),
          )
              : _myCustomers.isEmpty
              ? _buildEmptyState(
            icon: Icons.people_outline_rounded,
            title: 'No Customers Yet',
            message: 'Add your first customer to get started',
            color: _emeraldGreen,
            action: _navigateToAddCustomer,
            actionLabel: 'Add Customer',
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: _myCustomers.length,
            itemBuilder: (context, index) {
              var customer = _myCustomers[index];
              return TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + (index * 50)),
                curve: Curves.easeOutCubic,
                builder: (context, double value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: _buildCustomerCard(customer, workerColor),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildFilterChip(String label, int count, String? filterValue, Color workerColor) {
    // In a real implementation, you'd track selected filter
    bool isSelected = false;

    return Container(
      margin: const EdgeInsets.only(right: 8),
      padding: const EdgeInsets.symmetric(
        horizontal: 16,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        gradient: isSelected
            ? LinearGradient(
          colors: [workerColor, workerColor.withOpacity(0.7)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        )
            : null,
        color: isSelected ? null : _slateGray.withOpacity(0.5),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(
          color: isSelected
              ? workerColor
              : Colors.white.withOpacity(0.1),
        ),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              color: isSelected ? _pearlWhite : _pearlWhite.withOpacity(0.9),
              fontSize: 13,
              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
            ),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.all(4),
            decoration: BoxDecoration(
              color: isSelected
                  ? _pearlWhite.withOpacity(0.2)
                  : _pearlWhite.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Text(
              count.toString(),
              style: TextStyle(
                color: isSelected ? _pearlWhite : _pearlWhite.withOpacity(0.9),
                fontSize: 10,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCustomerCard(CustomerModel customer, Color workerColor) {
    Color statusColor = _getStatusColor(customer.status);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _charcoalBlue,
            _charcoalBlue.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: statusColor.withOpacity(0.2),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [statusColor, statusColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Text(
              customer.name[0].toUpperCase(),
              style: const TextStyle(
                color: _pearlWhite,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ),
        title: Text(
          customer.name,
          style: const TextStyle(
            color: _pearlWhite,
            fontWeight: FontWeight.w600,
            fontSize: 16,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Text(
              customer.email,
              style: TextStyle(
                color: _pearlWhite.withOpacity(0.6),
                fontSize: 13,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 10,
                vertical: 4,
              ),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: statusColor.withOpacity(0.3),
                ),
              ),
              child: Text(
                customer.status,
                style: TextStyle(
                  color: statusColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        trailing: const Icon(
          Icons.expand_more_rounded,
          color: _pearlWhite,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _slateGray.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              children: [
                if (customer.company != null && customer.company!.isNotEmpty)
                  _buildCustomerDetailRow(
                    icon: Icons.business_rounded,
                    label: 'Company',
                    value: customer.company!,
                    color: _skyBlue,
                  ),
                if (customer.phone.isNotEmpty)
                  _buildCustomerDetailRow(
                    icon: Icons.phone_rounded,
                    label: 'Phone',
                    value: customer.phone,
                    color: _emeraldGreen,
                  ),
                if (customer.address != null && customer.address!.isNotEmpty)
                  _buildCustomerDetailRow(
                    icon: Icons.location_on_rounded,
                    label: 'Address',
                    value: customer.address!,
                    color: _amberGlow,
                  ),
                if (customer.notes != null && customer.notes!.isNotEmpty)
                  _buildCustomerDetailRow(
                    icon: Icons.note_rounded,
                    label: 'Notes',
                    value: customer.notes!,
                    color: _deepPurple,
                  ),
                _buildCustomerDetailRow(
                  icon: Icons.person_rounded,
                  label: 'Added by',
                  value: customer.createdByName,
                  color: workerColor,
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        _showEditCustomerDialog(customer);
                      },
                      icon: const Icon(Icons.edit_rounded, size: 18),
                      label: const Text('Edit'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _skyBlue,
                        side: BorderSide(color: _skyBlue.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        _showDeleteCustomerDialog(customer.id);
                      },
                      icon: const Icon(Icons.delete_rounded, size: 18),
                      label: const Text('Delete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _crimsonRed,
                        foregroundColor: _pearlWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    // Add this button alongside Edit and Delete
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateQuotationScreen(
                              customer: customer,
                              teamId: _workerData['teamId'],
                              teamName: _myTeamInfo?['name'],
                            ),
                          ),
                        ).then((refresh) {
                          if (refresh == true) {
                            _showSuccessSnackBar('✅ Quotation created successfully!');
                          }
                        });
                      },
                      icon: const Icon(Icons.description_rounded, size: 18),
                      label: const Text('Quote'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _deepPurple,
                        side: BorderSide(color: _deepPurple.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuotationsListScreen(
                              customer: customer,
                              teamId: _workerData['teamId'],
                              teamName: _myTeamInfo?['name'],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.description_rounded, size: 18),
                      label: const Text('Quotes'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _deepPurple,
                        side: BorderSide(color: _deepPurple.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BillsListScreen(
                              teamId: _workerData['teamId'],
                              teamName: _myTeamInfo?['name'],
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.description_rounded, size: 18),
                      label: const Text('Bills'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _deepPurple,
                        side: BorderSide(color: _deepPurple.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
    );
  }

  Widget _buildCustomerDetailRow({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              size: 16,
              color: color,
            ),
          ),
          const SizedBox(width: 12),
          SizedBox(
            width: 70,
            child: Text(
              label,
              style: TextStyle(
                color: _pearlWhite.withOpacity(0.5),
                fontSize: 13,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                color: _pearlWhite,
                fontSize: 13,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _showDeleteCustomerDialog(String customerId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _charcoalBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: _crimsonRed.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.warning_rounded,
                color: _crimsonRed,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Delete Customer',
              style: TextStyle(
                color: _pearlWhite,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
          ],
        ),
        content: const Text(
          'Are you sure you want to delete this customer? This action cannot be undone.',
          style: TextStyle(color: _pearlWhite, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
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
              color: _crimsonRed,
              borderRadius: BorderRadius.circular(12),
            ),
            child: TextButton(
              onPressed: () => Navigator.pop(context, true),
              style: TextButton.styleFrom(
                foregroundColor: _pearlWhite,
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 12,
                ),
              ),
              child: const Text('Delete'),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      await _customersRef.child(customerId).remove();
      await _loadMyCustomers();
      if (mounted) {
        _showSuccessSnackBar('✅ Customer deleted successfully');
      }
    }
  }

  void _showEditCustomerDialog(CustomerModel customer) {
    // TODO: Implement edit customer dialog
    _showComingSoonSnackBar('Edit Customer');
  }

  // ============= TEAM TAB =============
  Widget _buildTeamTab(Color workerColor) {
    if (_myTeamInfo == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _charcoalBlue,
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: workerColor.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.group_off_rounded,
                size: 80,
                color: workerColor.withOpacity(0.5),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Not Assigned to Any Team',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _pearlWhite.withOpacity(0.9),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You will be added to a team by your manager',
              style: TextStyle(
                fontSize: 15,
                color: _pearlWhite.withOpacity(0.6),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 24,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: _slateGray,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: workerColor.withOpacity(0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.hourglass_empty_rounded,
                    color: workerColor,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Waiting for assignment',
                    style: TextStyle(
                      color: workerColor,
                      fontSize: 14,
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

    int memberCount = _teamMembers.length;
    Color teamColor = _workerGradients[
    (_myTeamInfo!['name']?.length ?? 0) % _workerGradients.length];

    return Row(
      children: [
        // Team Info Sidebar
        Container(
          width: 280,
          decoration: BoxDecoration(
            color: _charcoalBlue,
            borderRadius: const BorderRadius.only(
              topRight: Radius.circular(24),
              bottomRight: Radius.circular(24),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.2),
                blurRadius: 10,
                offset: const Offset(2, 0),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      teamColor.withOpacity(0.2),
                      _charcoalBlue,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    topRight: Radius.circular(24),
                  ),
                ),
                child: Column(
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [teamColor, teamColor.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(24),
                        boxShadow: [
                          BoxShadow(
                            color: teamColor.withOpacity(0.3),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          (_myTeamInfo!['name'] ?? 'T')[0].toUpperCase(),
                          style: const TextStyle(
                            color: _pearlWhite,
                            fontSize: 36,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      _myTeamInfo!['name'] ?? 'My Team',
                      style: const TextStyle(
                        color: _pearlWhite,
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                        letterSpacing: -0.5,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: teamColor.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: teamColor.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: teamColor,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Active Team',
                            style: TextStyle(
                              color: teamColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: teamColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.description_rounded,
                            color: teamColor,
                            size: 18,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text(
                          'About',
                          style: TextStyle(
                            color: _pearlWhite,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _myTeamInfo!['description'] ?? 'No description available',
                      style: TextStyle(
                        color: _pearlWhite.withOpacity(0.7),
                        fontSize: 14,
                        height: 1.5,
                      ),
                    ),
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: _slateGray.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Column(
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.people_rounded,
                                size: 20,
                                color: teamColor,
                              ),
                              const SizedBox(width: 12),
                              Text(
                                '$memberCount Members',
                                style: const TextStyle(
                                  color: _pearlWhite,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              Icon(
                                Icons.calendar_today_rounded,
                                size: 16,
                                color: _pearlWhite.withOpacity(0.5),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Created: ${_formatDate(_myTeamInfo!['createdAt'] ?? '')}',
                                style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.6),
                                  fontSize: 12,
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
            ],
          ),
        ),
        // Team Members View
        Expanded(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      teamColor.withOpacity(0.1),
                      _charcoalBlue,
                    ],
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                  ),
                  borderRadius: const BorderRadius.only(
                    bottomLeft: Radius.circular(32),
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: teamColor.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.people_rounded,
                        color: teamColor,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Team Members',
                          style: const TextStyle(
                            color: _pearlWhite,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '$memberCount active members',
                          style: TextStyle(
                            color: _pearlWhite.withOpacity(0.7),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              Expanded(
                child: _teamMembers.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          color: _charcoalBlue,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.people_outline_rounded,
                          size: 60,
                          color: _pearlWhite.withOpacity(0.3),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text(
                        'No team members yet',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: _pearlWhite.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Your team is still being built',
                        style: TextStyle(
                          fontSize: 14,
                          color: _pearlWhite.withOpacity(0.5),
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _teamMembers.length,
                  itemBuilder: (context, index) {
                    var member = _teamMembers[index];
                    bool isYou = member['uid'] ==
                        FirebaseAuth.instance.currentUser?.uid;
                    bool isManager =
                        member['uid'] == _myTeamInfo!['managerId'];

                    return TweenAnimationBuilder(
                      tween: Tween<double>(begin: 0, end: 1),
                      duration: Duration(milliseconds: 300 + (index * 100)),
                      curve: Curves.easeOutCubic,
                      builder: (context, double value, child) {
                        return Opacity(
                          opacity: value,
                          child: Transform.translate(
                            offset: Offset(0, 20 * (1 - value)),
                            child: child,
                          ),
                        );
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              _charcoalBlue,
                              _charcoalBlue.withOpacity(0.8),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          ),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isManager
                                ? teamColor.withOpacity(0.3)
                                : isYou
                                ? workerColor.withOpacity(0.3)
                                : Colors.white.withOpacity(0.05),
                            width: isManager || isYou ? 2 : 1,
                          ),
                        ),
                        child: ListTile(
                          contentPadding: const EdgeInsets.all(16),
                          leading: Stack(
                            children: [
                              Container(
                                width: 50,
                                height: 50,
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: isManager
                                        ? [teamColor, teamColor.withOpacity(0.7)]
                                        : [_skyBlue, _royalBlue],
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: Center(
                                  child: Text(
                                    (member['name'] ?? 'U')[0].toUpperCase(),
                                    style: const TextStyle(
                                      color: _pearlWhite,
                                      fontSize: 20,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ),
                              if (isManager)
                                Positioned(
                                  bottom: -2,
                                  right: -2,
                                  child: Container(
                                    padding: const EdgeInsets.all(4),
                                    decoration: BoxDecoration(
                                      color: _amberGlow,
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: _charcoalBlue,
                                        width: 2,
                                      ),
                                    ),
                                    child: const Icon(
                                      Icons.star_rounded,
                                      size: 12,
                                      color: _pearlWhite,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          title: Row(
                            children: [
                              Text(
                                member['name'] ?? 'Unknown',
                                style: const TextStyle(
                                  color: _pearlWhite,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 16,
                                ),
                              ),
                              if (isYou) ...[
                                const SizedBox(width: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 8,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: workerColor.withOpacity(0.2),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    'You',
                                    style: TextStyle(
                                      color: workerColor,
                                      fontSize: 11,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ),
                              ],
                            ],
                          ),
                          subtitle: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const SizedBox(height: 4),
                              Text(
                                member['email'] ?? '',
                                style: TextStyle(
                                  color: _pearlWhite.withOpacity(0.6),
                                  fontSize: 13,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  if (member['phone'] != null) ...[
                                    Icon(
                                      Icons.phone_rounded,
                                      size: 12,
                                      color: _pearlWhite.withOpacity(0.4),
                                    ),
                                    const SizedBox(width: 4),
                                    Text(
                                      member['phone'],
                                      style: TextStyle(
                                        color: _pearlWhite.withOpacity(0.5),
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                  ],
                                  Container(
                                    width: 4,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: member['isActive'] == true
                                          ? _emeraldGreen
                                          : _crimsonRed,
                                      shape: BoxShape.circle,
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Text(
                                    member['isActive'] == true
                                        ? 'Active'
                                        : 'Inactive',
                                    style: TextStyle(
                                      color: member['isActive'] == true
                                          ? _emeraldGreen
                                          : _crimsonRed,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  // ============= TASKS TAB =============
  Widget _buildTasksTab(Color workerColor) {
    int pendingTasks = _myTasks.where((t) => t['status'] != 'Completed').length;
    int completedTasks = _myTasks.where((t) => t['status'] == 'Completed').length;
    int overdueTasks = _myTasks.where((t) {
      if (t['status'] == 'Completed') return false;
      try {
        DateTime dueDate = DateTime.parse(t['dueDate']);
        return dueDate.isBefore(DateTime.now());
      } catch (e) {
        return false;
      }
    }).length;

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                _charcoalBlue,
                _charcoalBlue.withOpacity(0.8),
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
            borderRadius: const BorderRadius.only(
              bottomLeft: Radius.circular(32),
              bottomRight: Radius.circular(32),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [_amberGlow, workerColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Icon(
                      Icons.task_alt_rounded,
                      color: _pearlWhite,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'My Tasks',
                        style: TextStyle(
                          color: _pearlWhite,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '$pendingTasks pending · $completedTasks completed',
                        style: TextStyle(
                          color: _pearlWhite.withOpacity(0.7),
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: _buildTaskStatCard(
                      title: 'Pending',
                      value: pendingTasks.toString(),
                      icon: Icons.pending_actions_rounded,
                      color: _amberGlow,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTaskStatCard(
                      title: 'Completed',
                      value: completedTasks.toString(),
                      icon: Icons.check_circle_rounded,
                      color: _emeraldGreen,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _buildTaskStatCard(
                      title: 'Overdue',
                      value: overdueTasks.toString(),
                      icon: Icons.warning_rounded,
                      color: _crimsonRed,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: _amberGlow.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.task_alt_rounded,
                      color: _amberGlow,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  const Text(
                    'All Tasks',
                    style: TextStyle(
                      color: _pearlWhite,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [_amberGlow, workerColor],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: ElevatedButton.icon(
                  onPressed: _showCreateTaskDialog,
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('New Task'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: _pearlWhite,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: _myTasks.isEmpty
              ? _buildEmptyState(
            icon: Icons.task_alt_rounded,
            title: 'No Tasks',
            message: 'You have no tasks assigned yet',
            color: _amberGlow,
            action: _showCreateTaskDialog,
            actionLabel: 'Create Task',
          )
              : ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _myTasks.length,
            itemBuilder: (context, index) {
              var task = _myTasks[index];
              return TweenAnimationBuilder(
                tween: Tween<double>(begin: 0, end: 1),
                duration: Duration(milliseconds: 300 + (index * 50)),
                curve: Curves.easeOutCubic,
                builder: (context, double value, child) {
                  return Opacity(
                    opacity: value,
                    child: Transform.translate(
                      offset: Offset(0, 20 * (1 - value)),
                      child: child,
                    ),
                  );
                },
                child: _buildTaskCard(task, workerColor),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTaskStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _slateGray.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: color.withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Icon(
            icon,
            color: color,
            size: 20,
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(
              color: color,
              fontSize: 20,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            title,
            style: TextStyle(
              color: _pearlWhite.withOpacity(0.6),
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTaskCard(Map<String, dynamic> task, Color workerColor) {
    Color priorityColor = _getPriorityColor(task['priority']);
    bool isCompleted = task['status'] == 'Completed';

    DateTime dueDate = DateTime.parse(task['dueDate'] ?? DateTime.now().toIso8601String());
    String timeRemaining = _getTimeRemaining(dueDate);
    bool isOverdue = dueDate.isBefore(DateTime.now()) && !isCompleted;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            _charcoalBlue,
            _charcoalBlue.withOpacity(0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isOverdue
              ? _crimsonRed.withOpacity(0.3)
              : isCompleted
              ? _emeraldGreen.withOpacity(0.2)
              : priorityColor.withOpacity(0.2),
        ),
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.all(16),
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: isOverdue
                  ? [_crimsonRed, _crimsonRed.withOpacity(0.7)]
                  : isCompleted
                  ? [_emeraldGreen, _emeraldGreen.withOpacity(0.7)]
                  : [priorityColor, priorityColor.withOpacity(0.7)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Center(
            child: Icon(
              isCompleted
                  ? Icons.check_circle_rounded
                  : isOverdue
                  ? Icons.warning_rounded
                  : Icons.task_alt_rounded,
              color: _pearlWhite,
              size: 24,
            ),
          ),
        ),
        title: Text(
          task['title'] ?? 'Untitled Task',
          style: TextStyle(
            color: isCompleted
                ? _pearlWhite.withOpacity(0.5)
                : _pearlWhite,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            decoration: isCompleted ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: isOverdue
                        ? _crimsonRed.withOpacity(0.1)
                        : isCompleted
                        ? _emeraldGreen.withOpacity(0.1)
                        : priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    isOverdue ? 'Overdue' : timeRemaining,
                    style: TextStyle(
                      color: isOverdue
                          ? _crimsonRed
                          : isCompleted
                          ? _emeraldGreen
                          : priorityColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: priorityColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    task['priority'] ?? 'Medium',
                    style: TextStyle(
                      color: priorityColor,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Checkbox(
              value: isCompleted,
              onChanged: (value) {
                _updateTaskStatus(
                  task['id'],
                  value == true ? 'Completed' : 'Pending',
                );
              },
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(6),
              ),
              activeColor: _emeraldGreen,
              checkColor: _pearlWhite,
            ),
            const Icon(
              Icons.expand_more_rounded,
              color: _pearlWhite,
            ),
          ],
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: _slateGray.withOpacity(0.3),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(20),
                bottomRight: Radius.circular(20),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (task['description'] != null && task['description'].isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.description_rounded,
                              size: 16,
                              color: _pearlWhite.withOpacity(0.5),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              'Description',
                              style: TextStyle(
                                color: _pearlWhite.withOpacity(0.7),
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          task['description'],
                          style: TextStyle(
                            color: _pearlWhite.withOpacity(0.8),
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_rounded,
                      size: 14,
                      color: _pearlWhite.withOpacity(0.5),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Due: ${_formatDate(task['dueDate'])}',
                      style: TextStyle(
                        color: isOverdue
                            ? _crimsonRed
                            : _pearlWhite.withOpacity(0.8),
                        fontSize: 13,
                        fontWeight: isOverdue ? FontWeight.w600 : FontWeight.normal,
                      ),
                    ),
                  ],
                ),
                if (task['createdAt'] != null) ...[
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: 14,
                        color: _pearlWhite.withOpacity(0.5),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        'Created: ${_formatDate(task['createdAt'])}',
                        style: TextStyle(
                          color: _pearlWhite.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        _updateTaskStatus(task['id'], 'In Progress');
                      },
                      icon: const Icon(Icons.play_arrow_rounded, size: 18),
                      label: const Text('Start'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: _skyBlue,
                        side: BorderSide(color: _skyBlue.withOpacity(0.5)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: () {
                        _updateTaskStatus(task['id'], 'Completed');
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Complete'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: _emeraldGreen,
                        foregroundColor: _pearlWhite,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
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
    );
  }
}