class CustomerModel {
  final String id;
  final String name;
  final String email;
  final String phone;
  final String? address;
  final String? company;
  final String status;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String createdBy;
  final String createdByName;
  final String createdByRole;
  final String? assignedTo;
  final String? assignedToName;
  final String? teamId;
  final String? teamName;

  CustomerModel({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    this.address,
    this.company,
    this.status = 'Lead',
    this.notes,
    required this.createdAt,
    required this.updatedAt,
    required this.createdBy,
    required this.createdByName,
    required this.createdByRole,
    this.assignedTo,
    this.assignedToName,
    this.teamId,
    this.teamName,
  });

  // Convert CustomerModel to Map for Firebase
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'company': company,
      'status': status,
      'notes': notes,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
      'createdBy': createdBy,
      'createdByName': createdByName,
      'createdByRole': createdByRole,
      'assignedTo': assignedTo,
      'assignedToName': assignedToName,
      'teamId': teamId,
      'teamName': teamName,
    };
  }

  // Create CustomerModel from Firebase Map
  factory CustomerModel.fromMap(String id, Map<String, dynamic> map) {
    return CustomerModel(
      id: id,
      name: map['name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address']?.toString(),
      company: map['company']?.toString(),
      status: map['status'] ?? 'Lead',
      notes: map['notes']?.toString(),
      createdAt: map['createdAt'] != null
          ? DateTime.parse(map['createdAt'].toString())
          : DateTime.now(),
      updatedAt: map['updatedAt'] != null
          ? DateTime.parse(map['updatedAt'].toString())
          : DateTime.now(),
      createdBy: map['createdBy'] ?? '',
      createdByName: map['createdByName'] ?? '',
      createdByRole: map['createdByRole'] ?? '',
      assignedTo: map['assignedTo']?.toString(),
      assignedToName: map['assignedToName']?.toString(),
      teamId: map['teamId']?.toString(),
      teamName: map['teamName']?.toString(),
    );
  }

  // Create a copy of CustomerModel with updated fields
  CustomerModel copyWith({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? company,
    String? status,
    String? notes,
    DateTime? updatedAt,
    String? assignedTo,
    String? assignedToName,
    String? teamId,
    String? teamName,
  }) {
    return CustomerModel(
      id: this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      company: company ?? this.company,
      status: status ?? this.status,
      notes: notes ?? this.notes,
      createdAt: this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      createdBy: this.createdBy,
      createdByName: this.createdByName,
      createdByRole: this.createdByRole,
      assignedTo: assignedTo ?? this.assignedTo,
      assignedToName: assignedToName ?? this.assignedToName,
      teamId: teamId ?? this.teamId,
      teamName: teamName ?? this.teamName,
    );
  }

  // Helper getters for safe access
  String get displayAddress => address ?? '';
  String get displayCompany => company ?? '';
  String get displayNotes => notes ?? '';
  String get displayAssignedToName => assignedToName ?? '';
  String get displayTeamName => teamName ?? '';
}