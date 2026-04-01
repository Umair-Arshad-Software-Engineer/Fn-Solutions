import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import '../Auth/register.dart';
import '../CustomerPages/AddCustomerScreen.dart';
import '../CustomerPages/BillListPage.dart';
import '../CustomerPages/CreateQuotationScreen.dart';
import '../CustomerPages/QuotationsListScreen.dart';
import '../Models/customer_model.dart';
import '../items/ItemslistPage.dart';

class ManagerDashboard extends StatefulWidget {
  const ManagerDashboard({super.key});

  @override
  State<ManagerDashboard> createState() => _ManagerDashboardState();
}

class _ManagerDashboardState extends State<ManagerDashboard>
    with SingleTickerProviderStateMixin {
  final DatabaseReference _usersRef =
  FirebaseDatabase.instance.ref().child('users');
  final DatabaseReference _teamsRef =
  FirebaseDatabase.instance.ref().child('teams');

  Map<String, dynamic> _managerData = {};
  List<Map<String, dynamic>> _myTeams = []; // Multiple teams
  Map<String, List<Map<String, dynamic>>> _teamMembers = {}; // Members per team
  List<Map<String, dynamic>> _availableWorkers = [];
  Map<String, dynamic>? _selectedTeam; // Currently selected team
  bool _isLoading = true;
  int _selectedIndex = 0;

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
  static const Color _steelGray = Color(0xFF334155);
  static const Color _pearlWhite = Color(0xFFF8FAFC);


  // Add these with other DatabaseReference declarations
  final DatabaseReference _customersRef =
  FirebaseDatabase.instance.ref().child('customers');
  final DatabaseReference _quotationsRef =
  FirebaseDatabase.instance.ref().child('quotations');
  final DatabaseReference _billsRef =
  FirebaseDatabase.instance.ref().child('bills');

  List<CustomerModel> _allCustomers = [];
  bool _isLoadingCustomers = false;
  Map<String, dynamic>? _selectedCustomer;
  String _selectedCustomerFilter = 'All';

  final List<Color> _teamGradients = [
    const Color(0xFF6B4EFF), // Deep Purple
    const Color(0xFF2563EB), // Royal Blue
    const Color(0xFF38BDF8), // Sky Blue
    const Color(0xFF10B981), // Emerald Green
    const Color(0xFFF59E0B), // Amber
    const Color(0xFFEF4444), // Red
    const Color(0xFF8B5CF6), // Violet
    const Color(0xFFEC4899), // Pink
  ];

  Widget _buildManagerCustomersTab() {
    if (_myTeams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _charcoalBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 80,
                color: _amberGlow.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'Create Teams First',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _pearlWhite.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create teams to manage customers',
              style: TextStyle(
                fontSize: 15,
                color: _pearlWhite.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_deepPurple, _electricIndigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                  _showCreateTeamDialog();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create a Team'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: _pearlWhite,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

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
                      gradient: const LinearGradient(
                        colors: [_emeraldGreen, _deepPurple],
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
                          'All Customers',
                          style: TextStyle(
                            color: _pearlWhite,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${_allCustomers.length} total · ${_allCustomers.where((c) => c.status == 'Active').length} active',
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
                      gradient: const LinearGradient(
                        colors: [_emeraldGreen, _deepPurple],
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
                    _buildFilterChip('All', _allCustomers.length, 'All'),
                    _buildFilterChip(
                      'Active',
                      _allCustomers.where((c) => c.status == 'Active').length,
                      'Active',
                    ),
                    _buildFilterChip(
                      'Lead',
                      _allCustomers.where((c) => c.status == 'Lead').length,
                      'Lead',
                    ),
                    _buildFilterChip(
                      'Prospect',
                      _allCustomers.where((c) => c.status == 'Prospect').length,
                      'Prospect',
                    ),
                    _buildFilterChip(
                      'Inactive',
                      _allCustomers.where((c) => c.status == 'Inactive').length,
                      'Inactive',
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
              color: _deepPurple,
            ),
          )
              : _allCustomers.isEmpty
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
            itemCount: _filteredCustomers().length,
            itemBuilder: (context, index) {
              var customer = _filteredCustomers()[index];
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
                child: _buildCustomerCard(customer),
              );
            },
          ),
        ),
      ],
    );
  }

  List<CustomerModel> _filteredCustomers() {
    if (_selectedCustomerFilter == 'All') {
      return _allCustomers;
    }
    return _allCustomers
        .where((c) => c.status == _selectedCustomerFilter)
        .toList();
  }

  Widget _buildFilterChip(String label, int count, String filterValue) {
    bool isSelected = _selectedCustomerFilter == filterValue;

    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedCustomerFilter = filterValue;
        });
      },
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 8,
        ),
        decoration: BoxDecoration(
          gradient: isSelected
              ? const LinearGradient(
            colors: [_deepPurple, _electricIndigo],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          )
              : null,
          color: isSelected ? null : _slateGray.withOpacity(0.5),
          borderRadius: BorderRadius.circular(30),
          border: Border.all(
            color: isSelected
                ? _deepPurple
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
      ),
    );
  }

  Widget _buildCustomerCard(CustomerModel customer) {
    Color statusColor = _getStatusColor(customer.status);

    // Find which team this customer belongs to (if any)
    String? teamName;
    if (customer.teamId != null && _myTeams.isNotEmpty) {
      var team = _myTeams.firstWhere(
            (t) => t['id'] == customer.teamId,
        orElse: () => {},
      );
      if (team.isNotEmpty) {
        teamName = team['name'];
      }
    }

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
            Row(
              children: [
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
                if (teamName != null) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: _deepPurple.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _deepPurple.withOpacity(0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.groups_rounded,
                          size: 12,
                          color: _deepPurple.withOpacity(0.9),
                        ),
                        const SizedBox(width: 4),
                        Text(
                          teamName,
                          style: TextStyle(
                            color: _deepPurple.withOpacity(0.9),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
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
                  label: 'Created by',
                  value: customer.createdByName,
                  color: _electricIndigo,
                ),
                if (customer.assignedToName != null && customer.assignedToName!.isNotEmpty)
                  _buildCustomerDetailRow(
                    icon: Icons.person_rounded,
                    label: 'Assigned to',
                    value: customer.assignedToName!,
                    color: _emeraldGreen,
                  ),
                const SizedBox(height: 16),
                // Team selection dropdown for managers to assign customers
                if (_myTeams.isNotEmpty && customer.teamId == null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Row(
                      children: [
                        Expanded(
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: _slateGray,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: DropdownButtonHideUnderline(
                              child: DropdownButton<String>(
                                value: null,
                                hint: Row(
                                  children: [
                                    Icon(
                                      Icons.group_add_rounded,
                                      size: 16,
                                      color: _deepPurple.withOpacity(0.8),
                                    ),
                                    const SizedBox(width: 8),
                                    Text(
                                      'Assign to Team',
                                      style: TextStyle(
                                        color: _pearlWhite.withOpacity(0.7),
                                        fontSize: 13,
                                      ),
                                    ),
                                  ],
                                ),
                                isExpanded: true,
                                dropdownColor: _charcoalBlue,
                                icon: Icon(
                                  Icons.arrow_drop_down_rounded,
                                  color: _pearlWhite.withOpacity(0.7),
                                ),
                                style: const TextStyle(
                                  color: _pearlWhite,
                                  fontSize: 14,
                                ),
                                items: _myTeams.map((team) {
                                  return DropdownMenuItem<String>(
                                    value: team['id'],
                                    child: Text(team['name'] ?? 'Unnamed Team'),
                                  );
                                }).toList(),
                                onChanged: (teamId) {
                                  if (teamId != null) {
                                    _assignCustomerToTeam(customer.id, teamId);
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showEditCustomerDialog(customer),
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
                      onPressed: () => _deleteCustomer(customer.id),
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
                  ],
                ),
                const SizedBox(height: 12),
                // Quotation and Bill Actions
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _buildActionButton(
                      icon: Icons.description_rounded,
                      label: 'Create Quote',
                      color: _deepPurple,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => CreateQuotationScreen(
                              customer: customer,
                              teamId: customer.teamId ?? _myTeams.first['id'],
                              teamName: teamName ?? _myTeams.first['name'],
                            ),
                          ),
                        ).then((refresh) {
                          if (refresh == true) {
                            _showSuccessSnackBar('✅ Quotation created successfully!');
                          }
                        });
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.format_list_bulleted_rounded,
                      label: 'View Quotes',
                      color: _amberGlow,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => QuotationsListScreen(
                              customer: customer,
                              teamId: customer.teamId ?? _myTeams.first['id'],
                              teamName: teamName ?? _myTeams.first['name'],
                            ),
                          ),
                        );
                      },
                    ),
                    _buildActionButton(
                      icon: Icons.receipt_rounded,
                      label: 'Bills',
                      color: _emeraldGreen,
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => BillsListScreen(
                              teamId: customer.teamId ?? _myTeams.first['id'],
                              teamName: teamName ?? _myTeams.first['name'],
                            ),
                          ),
                        );
                      },
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

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
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
              const SizedBox(height: 4),
              Text(
                label,
                style: TextStyle(
                  color: color,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
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

  Future<void> _assignCustomerToTeam(String customerId, String teamId) async {
    await _customersRef.child(customerId).update({
      'teamId': teamId,
    });
    await _loadAllCustomers();
    if (mounted) {
      _showSuccessSnackBar('✅ Customer assigned to team successfully');
    }
  }

  Future<void> _loadAllCustomers() async {
    setState(() => _isLoadingCustomers = true);
    _allCustomers.clear();

    User? user = FirebaseAuth.instance.currentUser;

    DatabaseEvent customersEvent = await _customersRef.once();
    if (customersEvent.snapshot.value != null) {
      Map<dynamic, dynamic> customersMap =
      customersEvent.snapshot.value as Map<dynamic, dynamic>;

      customersMap.forEach((customerId, customerData) {
        Map<String, dynamic> customer =
        Map<String, dynamic>.from(customerData as Map);

        // Managers can see all customers (or filter by their teams if needed)
        // You can add team-based filtering logic here if required
        _allCustomers.add(CustomerModel.fromMap(customerId, customer));
      });
    }

    setState(() => _isLoadingCustomers = false);
  }

  Future<void> _deleteCustomer(String customerId) async {
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
      await _loadAllCustomers();
      if (mounted) {
        _showSuccessSnackBar('✅ Customer deleted successfully');
      }
    }
  }

  void _showEditCustomerDialog(CustomerModel customer) {
    // You can implement this similar to AddCustomerScreen with pre-filled data
    _showComingSoonSnackBar('Edit Customer');
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
    _loadManagerData();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadManagerData() async {
    setState(() => _isLoading = true);

    User? user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      // Load manager's own data
      DatabaseEvent userEvent = await _usersRef.child(user.uid).once();
      if (userEvent.snapshot.value != null) {
        _managerData =
        Map<String, dynamic>.from(userEvent.snapshot.value as Map);
      }

      // Load manager's teams
      await _loadMyTeams();

      // Load all customers
      await _loadAllCustomers();
    }

    setState(() => _isLoading = false);
  }

  Future<void> _loadMyTeams() async {
    User? user = FirebaseAuth.instance.currentUser;
    _myTeams.clear();
    _teamMembers.clear();

    // Find all teams where this manager is the manager
    DatabaseEvent teamsEvent = await _teamsRef.once();
    if (teamsEvent.snapshot.value != null) {
      Map<dynamic, dynamic> teamsMap =
      teamsEvent.snapshot.value as Map<dynamic, dynamic>;

      teamsMap.forEach((teamId, teamData) {
        Map<String, dynamic> team = Map<String, dynamic>.from(teamData as Map);
        if (team['managerId'] == user?.uid) {
          team['id'] = teamId;
          _myTeams.add(team);

          // Load team members for this team
          _loadTeamMembers(teamId);
        }
      });
    }

    // Select first team by default if available
    if (_myTeams.isNotEmpty && _selectedTeam == null) {
      _selectedTeam = _myTeams.first;
    }

    // Load available workers (not assigned to any manager)
    await _loadAvailableWorkers();
  }

  Future<void> _loadTeamMembers(String teamId) async {
    DatabaseEvent teamEvent =
    await _teamsRef.child(teamId).child('members').once();

    List<Map<String, dynamic>> members = [];

    if (teamEvent.snapshot.value != null) {
      Map<dynamic, dynamic> membersMap =
      teamEvent.snapshot.value as Map<dynamic, dynamic>;

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

    _teamMembers[teamId] = members;
  }

  Future<void> _loadAvailableWorkers() async {
    _availableWorkers.clear();

    DatabaseEvent usersEvent = await _usersRef.once();
    if (usersEvent.snapshot.value != null) {
      Map<dynamic, dynamic> usersMap =
      usersEvent.snapshot.value as Map<dynamic, dynamic>;

      usersMap.forEach((uid, userData) {
        Map<String, dynamic> user = Map<String, dynamic>.from(userData as Map);
        if (user['role'] == 'Worker' &&
            (user['managerId'] == null || user['managerId'] == '') &&
            user['isActive'] == true) {
          user['uid'] = uid;
          _availableWorkers.add(user);
        }
      });
    }
  }

  Future<void> _createTeam(String teamName, String description) async {
    User? user = FirebaseAuth.instance.currentUser;

    String teamId = _teamsRef.push().key ??
        DateTime.now().millisecondsSinceEpoch.toString();

    await _teamsRef.child(teamId).set({
      'name': teamName,
      'description': description,
      'managerId': user?.uid,
      'managerName': _managerData['name'] ?? 'Manager',
      'createdAt': DateTime.now().toIso8601String(),
      'createdBy': user?.uid,
      'memberCount': 0,
      'members': {},
    });

    await _loadManagerData();

    if (mounted) {
      Navigator.pop(context);
      _showSuccessSnackBar('✨ Team "$teamName" created successfully!');
    }
  }

  Future<void> _addToTeam(String workerId) async {
    if (_selectedTeam == null) {
      _showErrorSnackBar('Please select a team first');
      return;
    }

    String teamId = _selectedTeam!['id'];

    // Add worker to team members
    await _teamsRef.child(teamId).child('members').child(workerId).set(true);

    // Update member count
    int currentCount = _selectedTeam!['memberCount'] ?? 0;
    await _teamsRef.child(teamId).child('memberCount').set(currentCount + 1);

    // Update worker's managerId
    await _usersRef.child(workerId).update({
      'managerId': FirebaseAuth.instance.currentUser?.uid,
      'teamId': teamId,
    });

    await _loadManagerData();

    if (mounted) {
      _showSuccessSnackBar('👤 Worker added to ${_selectedTeam!['name']}');
    }
  }

  Future<void> _removeFromTeam(String workerId, String teamId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _charcoalBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Remove Worker',
          style: TextStyle(color: _pearlWhite, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to remove this worker from the team?',
          style: TextStyle(color: _pearlWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _steelGray),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _crimsonRed,
              foregroundColor: _pearlWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Remove'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Remove worker from team members
    await _teamsRef.child(teamId).child('members').child(workerId).remove();

    // Update member count
    int currentCount = _selectedTeam!['memberCount'] ?? 0;
    await _teamsRef.child(teamId).child('memberCount').set(currentCount - 1);

    // Remove worker's managerId and teamId
    await _usersRef.child(workerId).update({
      'managerId': null,
      'teamId': null,
    });

    await _loadManagerData();

    if (mounted) {
      _showSuccessSnackBar('👋 Worker removed from team');
    }
  }

  Future<void> _deleteTeam(String teamId) async {
    bool? confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: _charcoalBlue,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        title: const Text(
          'Delete Team',
          style: TextStyle(color: _pearlWhite, fontWeight: FontWeight.bold),
        ),
        content: const Text(
          'Are you sure you want to delete this team? All members will be unassigned.',
          style: TextStyle(color: _pearlWhite),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(
              'Cancel',
              style: TextStyle(color: _steelGray),
            ),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: _crimsonRed,
              foregroundColor: _pearlWhite,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    // Get all members of this team
    List<Map<String, dynamic>> members = _teamMembers[teamId] ?? [];

    // Remove managerId from all members
    for (var member in members) {
      await _usersRef.child(member['uid']).update({
        'managerId': null,
        'teamId': null,
      });
    }

    // Delete the team
    await _teamsRef.child(teamId).remove();

    await _loadManagerData();

    if (mounted) {
      _showSuccessSnackBar('🗑️ Team deleted successfully');
    }
  }

  void _showCreateTeamDialog() {
    final teamNameController = TextEditingController();
    final descriptionController = TextEditingController();

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
                Icons.group_add_rounded,
                color: _pearlWhite,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            const Text(
              'Create New Team',
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
                controller: teamNameController,
                style: const TextStyle(color: _pearlWhite),
                decoration: InputDecoration(
                  labelText: 'Team Name',
                  labelStyle: TextStyle(
                    color: _pearlWhite.withOpacity(0.7),
                    fontWeight: FontWeight.w500,
                  ),
                  hintText: 'e.g., Innovation Squad',
                  hintStyle: TextStyle(
                    color: _pearlWhite.withOpacity(0.3),
                  ),
                  prefixIcon: Icon(
                    Icons.sports_esports_rounded,
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
                  hintText: 'What will your team focus on?',
                  hintStyle: TextStyle(
                    color: _pearlWhite.withOpacity(0.3),
                  ),
                  prefixIcon: Padding(
                    padding: const EdgeInsets.only(bottom: 30),
                    child: Icon(
                      Icons.description_rounded,
                      color: _deepPurple.withOpacity(0.8),
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
            child: ElevatedButton(
              onPressed: () {
                if (teamNameController.text.isNotEmpty) {
                  _createTeam(
                    teamNameController.text.trim(),
                    descriptionController.text.trim(),
                  );
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
              child: const Text('Create Team'),
            ),
          ),
        ],
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

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  void _navigateToAddCustomer() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AddCustomerScreen(
          teamId: _myTeams.isNotEmpty ? _myTeams.first['id'] : null,
          teamName: _myTeams.isNotEmpty ? _myTeams.first['name'] : null,
          assignedTo: FirebaseAuth.instance.currentUser?.uid,
          assignedToName: _managerData['name'],
        ),
      ),
    ).then((refresh) {
      if (refresh == true) {
        _loadAllCustomers();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _darkNavy,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: _charcoalBlue,
        elevation: 0,
        title: Row(
          children: [
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_deepPurple, _electricIndigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: _deepPurple.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: CircleAvatar(
                backgroundColor: Colors.transparent,
                child: Text(
                  _managerData['name']?[0].toUpperCase() ?? 'M',
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
                  _managerData['name'] ?? 'Manager',
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
                    color: _deepPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: _deepPurple.withOpacity(0.3),
                    ),
                  ),
                  child: Text(
                    '${_myTeams.length} Teams',
                    style: TextStyle(
                      fontSize: 11,
                      color: _deepPurple.withOpacity(0.9),
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
              onPressed: _loadManagerData,
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
          ElevatedButton(
            style: ButtonStyle(
              backgroundColor: MaterialStateProperty.all(Colors.transparent),
            ),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => RegistrationScreen(
                    isAdminRegistration: false,
                    managerId: FirebaseAuth.instance.currentUser?.uid,
                  ),
                ),
              ).then((_) {
                // Refresh available workers after registration
                _loadAvailableWorkers();
              });
            },
            child: Text(
              'Register New Workers',
              style: TextStyle(
                color: _deepPurple,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          )
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
                gradient: const LinearGradient(
                  colors: [_deepPurple, _electricIndigo],
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
              'Loading your dashboard...',
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
              _buildMyTeamsTab(), // Multiple teams view
              _buildAvailableWorkersTab(),
              // _itemsListpage(),
              _buildManagerCustomersTab(),
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
            selectedItemColor: _deepPurple,
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
                        ? _deepPurple.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.groups_rounded),
                ),
                label: 'My Teams',
              ),
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 1
                        ? _deepPurple.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.person_add_alt_1_rounded),
                ),
                label: 'Add Workers',
              ),
              // BottomNavigationBarItem(
              //   icon: Container(
              //     padding: const EdgeInsets.all(6),
              //     decoration: BoxDecoration(
              //       color: _selectedIndex == 2
              //           ? _deepPurple.withOpacity(0.1)
              //           : Colors.transparent,
              //       borderRadius: BorderRadius.circular(10),
              //     ),
              //     child: const Icon(Icons.person_add_alt_1_rounded),
              //   ),
              //   label: 'Item Management',
              // ),//s
              BottomNavigationBarItem(
                icon: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: _selectedIndex == 3
                        ? _emeraldGreen.withOpacity(0.1)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(Icons.people_rounded),
                ),
                label: 'Customers',
              ),
            ],
            type: BottomNavigationBarType.fixed,
            elevation: 0,
          ),
        ),
      ),
      floatingActionButton: _selectedIndex == 0
          ? Container(
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [_deepPurple, _electricIndigo],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(30),
          boxShadow: [
            BoxShadow(
              color: _deepPurple.withOpacity(0.4),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: FloatingActionButton.extended(
          onPressed: _showCreateTeamDialog,
          backgroundColor: Colors.transparent,
          elevation: 0,
          icon: const Icon(
            Icons.add_rounded,
            color: _pearlWhite,
          ),
          label: const Text(
            'Create Team',
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

  Widget _buildMyTeamsTab() {
    if (_myTeams.isEmpty) {
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
                    color: _deepPurple.withOpacity(0.2),
                    blurRadius: 30,
                    spreadRadius: 5,
                  ),
                ],
              ),
              child: Icon(
                Icons.group_add_rounded,
                size: 80,
                color: _deepPurple.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Teams Created Yet',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _pearlWhite.withOpacity(0.9),
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create your first team to start managing workers',
              style: TextStyle(
                fontSize: 15,
                color: _pearlWhite.withOpacity(0.6),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_deepPurple, _electricIndigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: _deepPurple.withOpacity(0.3),
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ],
              ),
              child: ElevatedButton.icon(
                onPressed: _showCreateTeamDialog,
                icon: const Icon(Icons.add_rounded),
                label: const Text(
                  'Create Your First Team',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: _pearlWhite,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Row(
      children: [
        // Teams Sidebar
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
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: _deepPurple.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: const Icon(
                        Icons.groups_rounded,
                        color: _deepPurple,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'My Teams (${_myTeams.length})',
                      style: const TextStyle(
                        color: _pearlWhite,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: _myTeams.length,
                  itemBuilder: (context, index) {
                    var team = _myTeams[index];
                    bool isSelected = _selectedTeam?['id'] == team['id'];
                    Color teamColor = _teamGradients[index % _teamGradients.length];
                    int memberCount = _teamMembers[team['id']]?.length ?? 0;

                    return GestureDetector(
                      onTap: () {
                        setState(() {
                          _selectedTeam = team;
                        });
                      },
                      child: Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          gradient: isSelected
                              ? LinearGradient(
                            colors: [
                              teamColor.withOpacity(0.2),
                              teamColor.withOpacity(0.05),
                            ],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                              : null,
                          color: isSelected ? null : _slateGray.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: isSelected
                                ? teamColor.withOpacity(0.5)
                                : Colors.white.withOpacity(0.05),
                            width: isSelected ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Container(
                                  width: 40,
                                  height: 40,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [teamColor, teamColor.withOpacity(0.7)],
                                      begin: Alignment.topLeft,
                                      end: Alignment.bottomRight,
                                    ),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Center(
                                    child: Text(
                                      (team['name'] ?? 'T')[0].toUpperCase(),
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
                                        team['name'] ?? 'Unnamed Team',
                                        style: TextStyle(
                                          color: _pearlWhite,
                                          fontWeight: isSelected
                                              ? FontWeight.w700
                                              : FontWeight.w600,
                                          fontSize: 15,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Row(
                                        children: [
                                          Icon(
                                            Icons.people_rounded,
                                            size: 12,
                                            color: _pearlWhite.withOpacity(0.5),
                                          ),
                                          const SizedBox(width: 4),
                                          Text(
                                            '$memberCount members',
                                            style: TextStyle(
                                              color: _pearlWhite.withOpacity(0.5),
                                              fontSize: 11,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                            if (team['description'] != null && team['description'].isNotEmpty)
                              Padding(
                                padding: const EdgeInsets.only(top: 12),
                                child: Text(
                                  team['description'],
                                  style: TextStyle(
                                    color: _pearlWhite.withOpacity(0.6),
                                    fontSize: 12,
                                  ),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                            const SizedBox(height: 12),
                            // Team Lead / Manager Badge
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 4,
                              ),
                              decoration: BoxDecoration(
                                color: _deepPurple.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: _deepPurple.withOpacity(0.3),
                                ),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Icon(
                                    Icons.star_rounded,
                                    color: _deepPurple,
                                    size: 14,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    'Team Lead: ${_managerData['name'] ?? 'You'}',
                                    style: const TextStyle(
                                      color: _deepPurple,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ],
                              ),
                            ),
                            if (isSelected) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: [
                                  Expanded(
                                    child: TextButton.icon(
                                      onPressed: () => _deleteTeam(team['id']),
                                      icon: const Icon(
                                        Icons.delete_outline_rounded,
                                        size: 16,
                                        color: _crimsonRed,
                                      ),
                                      label: const Text(
                                        'Delete',
                                        style: TextStyle(
                                          color: _crimsonRed,
                                          fontSize: 12,
                                        ),
                                      ),
                                      style: TextButton.styleFrom(
                                        backgroundColor: _crimsonRed.withOpacity(0.1),
                                        padding: const EdgeInsets.symmetric(
                                          vertical: 8,
                                        ),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
        // Team Members View
        Expanded(
          child: _selectedTeam != null
              ? _buildTeamMembersView(_selectedTeam!)
              : Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.arrow_back_ios_new_rounded,
                  size: 48,
                  color: _pearlWhite.withOpacity(0.2),
                ),
                const SizedBox(height: 16),
                Text(
                  'Select a team to view members',
                  style: TextStyle(
                    fontSize: 16,
                    color: _pearlWhite.withOpacity(0.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildTeamMembersView(Map<String, dynamic> team) {
    String teamId = team['id'];
    List<Map<String, dynamic>> members = _teamMembers[teamId] ?? [];
    Color teamColor = _teamGradients[_myTeams.indexOf(team) % _teamGradients.length];

    return Column(
      children: [
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
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
              bottomLeft: Radius.circular(32),
            ),
          ),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [teamColor, teamColor.withOpacity(0.7)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: teamColor.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.groups_rounded,
                  color: _pearlWhite,
                  size: 32,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            team['name'] ?? 'My Team',
                            style: const TextStyle(
                              color: _pearlWhite,
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              letterSpacing: -0.5,
                            ),
                          ),
                        ),
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
                                'Active',
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
                    const SizedBox(height: 4),
                    Text(
                      team['description'] ?? 'No description',
                      style: TextStyle(
                        color: _pearlWhite.withOpacity(0.7),
                        fontSize: 14,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 16),
                    // Manager/Lead badge
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _deepPurple.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: _deepPurple.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.star_rounded,
                            color: _deepPurple,
                            size: 16,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Team Lead / Manager',
                            style: TextStyle(
                              color: _deepPurple.withOpacity(0.9),
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: _pearlWhite.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              _managerData['name'] ?? 'You',
                              style: TextStyle(
                                color: _pearlWhite.withOpacity(0.9),
                                fontSize: 11,
                              ),
                            ),
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
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: teamColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.people_rounded,
                  color: teamColor,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                'Team Members (${members.length})',
                style: const TextStyle(
                  color: _pearlWhite,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                  letterSpacing: -0.3,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: _slateGray,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  'Team ID: ${teamId.substring(0, 6)}...',
                  style: TextStyle(
                    color: _pearlWhite.withOpacity(0.5),
                    fontSize: 11,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: members.isEmpty
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
                  'Go to "Add Workers" tab to build your team',
                  style: TextStyle(
                    fontSize: 14,
                    color: _pearlWhite.withOpacity(0.5),
                  ),
                ),
                const SizedBox(height: 24),
                Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [teamColor, teamColor.withOpacity(0.7)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: ElevatedButton.icon(
                    onPressed: () {
                      setState(() {
                        _selectedIndex = 1;
                      });
                    },
                    icon: const Icon(Icons.person_add_rounded),
                    label: const Text('Add Workers'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      shadowColor: Colors.transparent,
                      foregroundColor: _pearlWhite,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 20,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          )
              : ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: members.length,
            itemBuilder: (context, index) {
              var worker = members[index];
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
                      color: teamColor.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [teamColor, teamColor.withOpacity(0.7)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: teamColor.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        child: Text(
                          (worker['name'] ?? 'W')[0].toUpperCase(),
                          style: const TextStyle(
                            color: _pearlWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      worker['name'] ?? 'Unknown',
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
                          worker['email'] ?? '',
                          style: TextStyle(
                            color: _pearlWhite.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: _emeraldGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(
                              color: _emeraldGreen.withOpacity(0.3),
                            ),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Container(
                                width: 6,
                                height: 6,
                                decoration: const BoxDecoration(
                                  color: _emeraldGreen,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              const Text(
                                'Active',
                                style: TextStyle(
                                  color: _emeraldGreen,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    trailing: Container(
                      decoration: BoxDecoration(
                        color: _crimsonRed.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: IconButton(
                        icon: const Icon(
                          Icons.remove_circle_outline_rounded,
                          color: _crimsonRed,
                          size: 24,
                        ),
                        onPressed: () => _removeFromTeam(worker['uid'], teamId),
                        tooltip: 'Remove from team',
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAvailableWorkersTab() {
    if (_myTeams.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: _charcoalBlue,
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.warning_amber_rounded,
                size: 80,
                color: _amberGlow.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Teams Available',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: _pearlWhite.withOpacity(0.9),
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Create a team first to add workers',
              style: TextStyle(
                fontSize: 15,
                color: _pearlWhite.withOpacity(0.6),
              ),
            ),
            const SizedBox(height: 32),
            Container(
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [_deepPurple, _electricIndigo],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(16),
              ),
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _selectedIndex = 0;
                  });
                  _showCreateTeamDialog();
                },
                icon: const Icon(Icons.add_rounded),
                label: const Text('Create a Team'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.transparent,
                  shadowColor: Colors.transparent,
                  foregroundColor: _pearlWhite,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 28,
                    vertical: 16,
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        if (_selectedTeam == null)
          Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  _amberGlow.withOpacity(0.1),
                  _amberGlow.withOpacity(0.05),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: _amberGlow.withOpacity(0.3),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _amberGlow.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(
                    Icons.info_rounded,
                    color: _amberGlow,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Select a Team',
                        style: TextStyle(
                          color: _amberGlow,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Choose a team from the sidebar to add workers',
                        style: TextStyle(
                          color: _amberGlow.withOpacity(0.9),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        Padding(
          padding: const EdgeInsets.all(20.0),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: _skyBlue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.person_search_rounded,
                  color: _skyBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Available Workers (${_availableWorkers.length})',
                  style: const TextStyle(
                    color: _pearlWhite,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.3,
                  ),
                ),
              ),
              if (_selectedTeam != null)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: _deepPurple.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.group_rounded,
                        size: 14,
                        color: _deepPurple,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        'Adding to: ${_selectedTeam!['name']}',
                        style: const TextStyle(
                          color: _deepPurple,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      // In _buildAvailableWorkersTab method, update the ElevatedButton:


                    ],
                  ),
                ),
            ],
          ),
        ),
        Expanded(
          child: _availableWorkers.isEmpty
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
                    Icons.person_off_rounded,
                    size: 60,
                    color: _pearlWhite.withOpacity(0.3),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'No available workers',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: _pearlWhite.withOpacity(0.8),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'All workers are assigned to teams',
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
            itemCount: _availableWorkers.length,
            itemBuilder: (context, index) {
              var worker = _availableWorkers[index];
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
                      color: _skyBlue.withOpacity(0.2),
                      width: 1,
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_skyBlue, _royalBlue],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(16),
                        boxShadow: [
                          BoxShadow(
                            color: _skyBlue.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: CircleAvatar(
                        backgroundColor: Colors.transparent,
                        child: Text(
                          (worker['name'] ?? 'W')[0].toUpperCase(),
                          style: const TextStyle(
                            color: _pearlWhite,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                    title: Text(
                      worker['name'] ?? 'Unknown',
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
                          worker['email'] ?? '',
                          style: TextStyle(
                            color: _pearlWhite.withOpacity(0.6),
                            fontSize: 13,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          worker['phone'] ?? '',
                          style: TextStyle(
                            color: _pearlWhite.withOpacity(0.4),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                    trailing: _selectedTeam != null
                        ? Container(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [_deepPurple, _electricIndigo],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(12),
                        boxShadow: [
                          BoxShadow(
                            color: _deepPurple.withOpacity(0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: ElevatedButton.icon(
                        onPressed: () => _addToTeam(worker['uid']),
                        icon: const Icon(
                          Icons.add_rounded,
                          size: 18,
                        ),
                        label: Text(
                          'Add to ${_selectedTeam!['name']}',
                          style: const TextStyle(fontSize: 12),
                        ),
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
                    )
                        : Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: _slateGray,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Select a team',
                        style: TextStyle(
                          color: _pearlWhite,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _itemsListpage(){
    return ItemsListPage();
  }
}