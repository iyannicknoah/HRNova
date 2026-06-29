import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:intl/intl.dart';
import 'dart:async';
import '../../auth/providers/auth_provider.dart';
import '../../../../shared/widgets/hrnova_button.dart';
import '../../../../shared/widgets/hrnova_text_field.dart';
import '../../../../shared/widgets/success_dialog_box.dart';
import '../../../../shared/widgets/status_badge.dart';
import '../../../../shared/widgets/hrnova_sidebar.dart';
import '../../../../shared/widgets/loading_widget.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/services/api_service.dart';

class SuperAdminScreen extends ConsumerStatefulWidget {
  const SuperAdminScreen({super.key});

  @override
  ConsumerState<SuperAdminScreen> createState() => _SuperAdminScreenState();
}

class _SuperAdminScreenState extends ConsumerState<SuperAdminScreen> {
  String _statusFilter = 'All'; // 'All', 'Active', 'Suspended'
  String _priceSort = 'Default'; // 'Default', 'High to Low', 'Low to High'

  // Panel state
  bool _isPanelOpen = false;
  DocumentSnapshot? _editingCompany;
  
  // Details state
  bool _isDetailsOpen = false;
  DocumentSnapshot? _detailsCompany;

  final _formKey = GlobalKey<FormState>();

  // Form controllers
  final _nameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _employeesController = TextEditingController();
  final _priceController = TextEditingController();
  final _passwordController = TextEditingController();

  String _selectedIndustry = 'Factory';
  bool _isSaving = false;

  final List<String> _industries = [
    'Factory',
    'School',
    'Clinic',
    'NGO',
    'Hotel',
    'Other'
  ];

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() {
      if (!_phoneController.text.startsWith('+250')) {
        _phoneController.value = TextEditingValue(
          text: '+250',
          selection: const TextSelection.collapsed(offset: 4),
        );
      }
    });
  }

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _contactController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _employeesController.dispose();
    _priceController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _openAddPanel() {
    setState(() {
      _isPanelOpen = true;
      _isDetailsOpen = false;
      _editingCompany = null;
      _nameController.clear();
      _addressController.clear();
      _contactController.clear();
      _emailController.clear();
      _phoneController.text = '+250';
      _employeesController.clear();
      _priceController.clear();
      _passwordController.clear();
      _selectedIndustry = 'Factory';
    });
  }

  void _openEditPanel(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    setState(() {
      _isPanelOpen = true;
      _isDetailsOpen = false;
      _editingCompany = doc;
      _nameController.text = data['name']?.toString() ?? '';
      _addressController.text = data['address']?.toString() ?? '';
      _contactController.text = data['contactPerson']?.toString() ?? '';
      _emailController.text = data['hrAdminEmail']?.toString() ?? '';
      final phone = data['hrAdminPhone']?.toString() ?? '';
      _phoneController.text = phone.startsWith('+250') ? phone : (phone.isEmpty ? '+250' : '+250$phone');
      _employeesController.text = data['employeeCount']?.toString() ?? '';
      _priceController.text = data['monthlyPrice']?.toString() ?? '';
      _passwordController.clear();
      _selectedIndustry = data['industry']?.toString() ?? 'Factory';
      if (!_industries.contains(_selectedIndustry)) {
        _selectedIndustry = 'Other';
      }
    });
  }

  void _openDetailsPanel(DocumentSnapshot doc) {
    setState(() {
      _isDetailsOpen = true;
      _detailsCompany = doc;
      _isPanelOpen = false;
    });
  }

  void _closePanel() {
    setState(() {
      _isPanelOpen = false;
      _editingCompany = null;
    });
  }

  void _closeDetailsPanel() {
    setState(() {
      _isDetailsOpen = false;
      _detailsCompany = null;
    });
  }

  Future<void> _handleSave() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSaving = true;
    });

    try {
      final name = _nameController.text.trim();
      final address = _addressController.text.trim();
      final contactPerson = _contactController.text.trim();
      final hrAdminEmail = _emailController.text.trim();
      final hrAdminPhone = _phoneController.text.trim();
      final employeeCount = int.tryParse(_employeesController.text) ?? 0;
      final monthlyPrice = int.tryParse(_priceController.text) ?? 0;
      final password = _passwordController.text;

      final db = FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default');

      if (_editingCompany == null) {
        // Create Flow
        // 1. Generate local company doc ID
        final companyRef = db.collection('companies').doc();
        final newId = companyRef.id;

        // 2. Call backend /api/auth/create-user to provision BOTH the company document and the user account
        final api = ref.read(apiServiceProvider);
        await api.post(
          '/api/auth/create-user',
          data: {
            'email': hrAdminEmail,
            'password': password,
            'role': 'hr_admin',
            'companyId': newId,
            'displayName': contactPerson,
            'companyName': name,
            'industry': _selectedIndustry,
            'address': address,
            'hrAdminPhone': hrAdminPhone,
            'employeeCount': employeeCount,
            'monthlyPrice': monthlyPrice,
          },
        ).timeout(const Duration(seconds: 12));

        setState(() {
          _isSaving = false;
        });
        _closePanel();
        
        // 3. Show success dialog exactly like FlutterFlow design
        if (mounted) {
          showDialog(
            context: context,
            barrierDismissible: false,
            builder: (context) => const SuccessDialogBoxWidget(
              message: 'Company has been registered successfully',
            ),
          );
        }
      } else {
        // Edit Flow
        final docId = _editingCompany!.id;
        final updateFuture = db.collection('companies').doc(docId).update({
          'name': name,
          'industry': _selectedIndustry,
          'address': address,
          'contactPerson': contactPerson,
          'hrAdminEmail': hrAdminEmail,
          'hrAdminPhone': hrAdminPhone,
          'employeeCount': employeeCount,
          'monthlyPrice': monthlyPrice,
        });

        // Tolerant timeout: Wait at most 2 seconds for server acknowledgment.
        // If it takes longer, it is queued locally and we proceed to close the panel.
        try {
          await updateFuture.timeout(const Duration(seconds: 2));
        } on TimeoutException {
          debugPrint('Firestore company update queued locally.');
        }
        
        setState(() {
          _isSaving = false;
        });
        _closePanel();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Company details updated successfully.')),
          );
        }
      }
    } catch (e) {
      setState(() {
        _isSaving = false;
      });
      if (mounted) {
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppColors.cardNavy,
            title: const Text('Registration Failed', style: TextStyle(color: Colors.white)),
            content: Text(e.toString(), style: const TextStyle(color: Colors.white70)),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('OK', style: TextStyle(color: AppColors.errorRed)),
              ),
            ],
          ),
        );
      }
    }
  }

  Future<void> _toggleSuspension(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final currentStatus = data['status']?.toString() ?? 'active';
    final newStatus = currentStatus == 'active' ? 'suspended' : 'active';
    final actionName = newStatus == 'suspended' ? 'Suspend' : 'Activate';

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardNavy,
        title: Text('$actionName Company?', style: const TextStyle(color: Colors.white)),
        content: Text(
          newStatus == 'suspended'
              ? 'Are you sure you want to suspend "${data['name']}"? Their admins and managers will be locked out immediately.'
              : 'Are you sure you want to reactivate "${data['name']}"? Their system access will be restored.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              actionName,
              style: TextStyle(
                color: newStatus == 'suspended' ? const Color(0xFF94A3B8) : AppColors.lightGreen,
              ),
            ),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default').collection('companies').doc(doc.id).update({
          'status': newStatus,
        }).timeout(const Duration(seconds: 5));
        
        // Refresh details doc if currently opened
        if (_isDetailsOpen && _detailsCompany?.id == doc.id) {
          final refreshed = await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default').collection('companies').doc(doc.id).get();
          setState(() {
            _detailsCompany = refreshed;
          });
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Company status changed to $newStatus.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to change status: $e')),
          );
        }
      }
    }
  }

  Future<void> _deleteCompany(DocumentSnapshot doc) async {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardNavy,
        title: const Text('Delete Company?', style: TextStyle(color: Colors.white)),
        content: Text(
          'Are you sure you want to permanently delete "${data['name']}"? All company configurations and system data will be removed. This cannot be undone.',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Color(0xFF94A3B8))), // soft grey
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default')
            .collection('companies')
            .doc(doc.id)
            .delete()
            .timeout(const Duration(seconds: 5));
        
        _closeDetailsPanel();
        
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Company successfully deleted.')),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete company: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.darkNavy,
      body: Stack(
        children: [
          Row(
            children: [
              // Sidebar configuration
              HRNovaSidebar(
                currentRoute: '/super-admin',
                companyName: 'HRNova HQ',
                userName: 'Super Admin',
                userRole: 'super_admin',
                onItemTapped: (route) async {
                  if (route == 'sign_out_action') {
                    await ref.read(authNotifierProvider.notifier).signOut();
                  } else if (route == 'add_company_action') {
                    _openAddPanel();
                  }
                },
                customItems: const [
                  SidebarItem(icon: Icons.business, label: 'Companies', route: '/super-admin'),
                  SidebarItem(icon: Icons.add_business, label: 'Add Company', route: 'add_company_action'),
                ],
              ),

              // Main content area
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(28.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Header Row
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'Companies Registry',
                            style: TextStyle(
                              fontSize: 26,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          HRNovaButton(
                            label: 'Add Company',
                            onPressed: _openAddPanel,
                          ),
                        ],
                      ),
                      const SizedBox(height: 24),

                      // Firestore Stream connection for statistics and grid list
                      StreamBuilder<QuerySnapshot>(
                        stream: FirebaseFirestore.instanceFor(app: Firebase.app(), databaseId: 'default').collection('companies').snapshots(),
                        builder: (context, snapshot) {
                          if (snapshot.connectionState == ConnectionState.waiting) {
                            return const Expanded(
                              child: Center(
                                child: LoadingWidget(message: 'Loading companies...'),
                              ),
                            );
                          }

                          if (snapshot.hasError) {
                            return Expanded(
                              child: Center(
                                child: Text(
                                  'Error loading registry: ${snapshot.error}',
                                  style: const TextStyle(color: AppColors.errorRed),
                                ),
                              ),
                            );
                          }

                          final docs = snapshot.data?.docs ?? [];
                          final totalCompanies = docs.length;
                          final activeCount = docs.where((d) => (d.data() as Map)['status'] == 'active').length;
                          
                          int monthlyRevenue = 0;
                          for (final d in docs) {
                            final data = d.data() as Map<String, dynamic>;
                            if (data['status'] == 'active') {
                              monthlyRevenue += (data['monthlyPrice'] as num? ?? 0).toInt();
                            }
                          }

                          final formatter = NumberFormat('#,###', 'en_US');

                          // Apply status and sort filters locally
                          List<DocumentSnapshot> filteredDocs = List.from(docs);

                          if (_statusFilter == 'Active') {
                            filteredDocs = filteredDocs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>? ?? {};
                              return data['status'] == 'active';
                            }).toList();
                          } else if (_statusFilter == 'Suspended') {
                            filteredDocs = filteredDocs.where((doc) {
                              final data = doc.data() as Map<String, dynamic>? ?? {};
                              return data['status'] == 'suspended';
                            }).toList();
                          }

                          if (_priceSort == 'High to Low') {
                            filteredDocs.sort((a, b) {
                              final priceA = (a.data() as Map<String, dynamic>? ?? {})['monthlyPrice'] as num? ?? 0;
                              final priceB = (b.data() as Map<String, dynamic>? ?? {})['monthlyPrice'] as num? ?? 0;
                              return priceB.compareTo(priceA);
                            });
                          } else if (_priceSort == 'Low to High') {
                            filteredDocs.sort((a, b) {
                              final priceA = (a.data() as Map<String, dynamic>? ?? {})['monthlyPrice'] as num? ?? 0;
                              final priceB = (b.data() as Map<String, dynamic>? ?? {})['monthlyPrice'] as num? ?? 0;
                              return priceA.compareTo(priceB);
                            });
                          }

                          return Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Summary Cards row (KPIs have no border and 24px border radius)
                                Row(
                                  children: [
                                    _buildSummaryCard('Total Companies', totalCompanies.toString(), Icons.business_center),
                                    const SizedBox(width: 20),
                                    _buildSummaryCard('Active Clients', activeCount.toString(), Icons.check_circle_outline, color: AppColors.lightGreen),
                                    const SizedBox(width: 20),
                                    _buildSummaryCard('Monthly Revenue', '${formatter.format(monthlyRevenue)} RWF', Icons.monetization_on, color: AppColors.lightGreen),
                                  ],
                                ),
                                const SizedBox(height: 28),

                                // Filter and Sort Control Row
                                Row(
                                  children: [
                                    const Text(
                                      'Filters: ',
                                      style: TextStyle(
                                        color: Colors.white54,
                                        fontSize: 13,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(width: 12),
                                    // Status Filter Dropdown
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: AppColors.cardNavy,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0x13FFFFFF)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _statusFilter,
                                          dropdownColor: AppColors.cardNavy,
                                          style: const TextStyle(color: Colors.white, fontSize: 13),
                                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() {
                                                _statusFilter = val;
                                              });
                                            }
                                          },
                                          items: const [
                                            DropdownMenuItem(value: 'All', child: Text('All Statuses')),
                                            DropdownMenuItem(value: 'Active', child: Text('Active Only')),
                                            DropdownMenuItem(value: 'Suspended', child: Text('Suspended Only')),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    // Price Sort Dropdown
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 16),
                                      decoration: BoxDecoration(
                                        color: AppColors.cardNavy,
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(color: const Color(0x13FFFFFF)),
                                      ),
                                      child: DropdownButtonHideUnderline(
                                        child: DropdownButton<String>(
                                          value: _priceSort,
                                          dropdownColor: AppColors.cardNavy,
                                          style: const TextStyle(color: Colors.white, fontSize: 13),
                                          icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(() {
                                                _priceSort = val;
                                              });
                                            }
                                          },
                                          items: const [
                                            DropdownMenuItem(value: 'Default', child: Text('Default Sort')),
                                            DropdownMenuItem(value: 'High to Low', child: Text('Price: High to Low')),
                                            DropdownMenuItem(value: 'Low to High', child: Text('Price: Low to High')),
                                          ],
                                        ),
                                      ),
                                    ),
                                    const Spacer(),
                                    Text(
                                      'Showing ${filteredDocs.length} companies',
                                      style: const TextStyle(
                                        color: Colors.white38,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 18),

                                // Registry Table List
                                Expanded(
                                  child: Container(
                                    decoration: BoxDecoration(
                                      color: AppColors.cardNavy,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(color: const Color(0x13FFFFFF)),
                                    ),
                                    clipBehavior: Clip.antiAlias,
                                    child: SingleChildScrollView(
                                      child: Table(
                                        columnWidths: const {
                                          0: FlexColumnWidth(2.5),
                                          1: FlexColumnWidth(1.5),
                                          2: FlexColumnWidth(1.2),
                                          3: FlexColumnWidth(1.5),
                                          4: FlexColumnWidth(1.5),
                                          5: FlexColumnWidth(2.0),
                                        },
                                        children: [
                                          // Table Header
                                          TableRow(
                                            decoration: const BoxDecoration(
                                              color: Color(0x0AFFFFFF),
                                              border: Border(bottom: BorderSide(color: Color(0x13FFFFFF))),
                                            ),
                                            children: [
                                              _buildTableHeader('Company Name'),
                                              _buildTableHeader('Industry'),
                                              _buildTableHeader('Status'),
                                              _buildTableHeader('Price (RWF)'),
                                              _buildTableHeader('Created Date'),
                                              _buildTableHeader('Actions'),
                                            ],
                                          ),

                                          // Table Rows (clicking row content opens the Details Panel)
                                          ...filteredDocs.map((doc) {
                                            final data = doc.data() as Map<String, dynamic>;
                                            final name = data['name'] ?? 'N/A';
                                            final industry = data['industry'] ?? 'N/A';
                                            final status = data['status'] ?? 'active';
                                            final monthlyPrice = (data['monthlyPrice'] as num? ?? 0).toInt();
                                            
                                            String createdDateStr = 'N/A';
                                            if (data['createdAt'] != null) {
                                              final createdTime = (data['createdAt'] as Timestamp).toDate();
                                              createdDateStr = DateFormat('yyyy-MM-dd').format(createdTime);
                                            }

                                            return TableRow(
                                              decoration: const BoxDecoration(
                                                border: Border(bottom: BorderSide(color: Color(0x06FFFFFF))),
                                              ),
                                              children: [
                                                _buildTableCellText(name, isBold: true, onTap: () => _openDetailsPanel(doc)),
                                                _buildTableCellText(industry, onTap: () => _openDetailsPanel(doc)),
                                                TableCell(
                                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                                  child: InkWell(
                                                    onTap: () => _openDetailsPanel(doc),
                                                    child: Padding(
                                                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                                      child: Align(
                                                        alignment: Alignment.centerLeft,
                                                        child: StatusBadge(
                                                          text: status.toString().toUpperCase(),
                                                          type: status == 'active' ? 'active' : 'suspended',
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                _buildTableCellText(formatter.format(monthlyPrice), onTap: () => _openDetailsPanel(doc)),
                                                _buildTableCellText(createdDateStr, onTap: () => _openDetailsPanel(doc)),
                                                TableCell(
                                                  verticalAlignment: TableCellVerticalAlignment.middle,
                                                  child: Padding(
                                                    padding: const EdgeInsets.symmetric(horizontal: 16),
                                                    child: Row(
                                                      children: [
                                                        IconButton(
                                                          icon: const Icon(Icons.edit_outlined, color: Colors.white70, size: 20),
                                                          tooltip: 'Edit details',
                                                          onPressed: () => _openEditPanel(doc),
                                                        ),
                                                        const SizedBox(width: 8),
                                                        IconButton(
                                                          icon: Icon(
                                                            status == 'active' ? Icons.block : Icons.check_circle_outline,
                                                            color: status == 'active' ? AppColors.errorRed : AppColors.lightGreen,
                                                            size: 20,
                                                          ),
                                                          tooltip: status == 'active' ? 'Suspend client' : 'Activate client',
                                                          onPressed: () => _toggleSuspension(doc),
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                ),
                                              ],
                                            );
                                          }),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),

          // Slide-out Drawer Panel overlay backdrop
          if (_isPanelOpen || _isDetailsOpen)
            GestureDetector(
              onTap: () {
                _closePanel();
                _closeDetailsPanel();
              },
              child: Container(
                color: Colors.black45,
                width: double.infinity,
                height: double.infinity,
              ),
            ),
          
          // Panel 1: Add/Edit Company Form Drawer
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            right: _isPanelOpen ? 0 : -490,
            child: Container(
              width: 480,
              decoration: const BoxDecoration(
                color: AppColors.cardNavy,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 15,
                    offset: Offset(-5, 0),
                  ),
                ],
              ),
              child: _buildPanelContent(),
            ),
          ),

          // Panel 2: Detailed Company Profile Drawer
          AnimatedPositioned(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
            top: 0,
            bottom: 0,
            right: _isDetailsOpen ? 0 : -490,
            child: Container(
              width: 480,
              decoration: const BoxDecoration(
                color: AppColors.cardNavy,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black54,
                    blurRadius: 15,
                    offset: Offset(-5, 0),
                  ),
                ],
              ),
              child: _buildDetailsPanelContent(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryCard(String title, String value, IconData icon, {Color color = Colors.white70}) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppColors.cardNavy,
          borderRadius: BorderRadius.circular(24), // Rounded 24px per requirements
          // No border color/line
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, color: color, size: 28),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontSize: 12, color: Colors.white54)),
                  const SizedBox(height: 4),
                  Text(value, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTableHeader(String text) {
    return TableCell(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
          text,
          style: const TextStyle(
            color: Colors.white60,
            fontWeight: FontWeight.bold,
            fontSize: 13,
          ),
        ),
      ),
    );
  }

  Widget _buildTableCellText(String text, {bool isBold = false, VoidCallback? onTap}) {
    return TableCell(
      verticalAlignment: TableCellVerticalAlignment.middle,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(
              text,
              style: TextStyle(
                color: Colors.white,
                fontWeight: isBold ? FontWeight.bold : FontWeight.normal,
                fontSize: 13,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildPanelContent() {
    final isEdit = _editingCompany != null;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Panel Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    isEdit ? 'Edit Company Details' : 'Register New Company',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white70),
                    onPressed: _closePanel,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Divider(color: Color(0x13FFFFFF)),
              const SizedBox(height: 20),

              // Scrollable Form content
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      HRNovaTextField(
                        label: 'Company Name',
                        hint: 'e.g. Inyange Industries',
                        controller: _nameController,
                      ),
                      const SizedBox(height: 18),

                      // Industry Selection Dropdown
                      const Text(
                        'Industry',
                        style: TextStyle(color: Colors.white70, fontSize: 13, fontWeight: FontWeight.w500),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: AppColors.darkNavy,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: const Color(0x1AFFFFFF)),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            dropdownColor: AppColors.cardNavy,
                            value: _selectedIndustry,
                            isExpanded: true,
                            icon: const Icon(Icons.arrow_drop_down, color: Colors.white54),
                            style: const TextStyle(color: Colors.white, fontSize: 14),
                            onChanged: (val) {
                              if (val != null) {
                                setState(() {
                                  _selectedIndustry = val;
                                });
                              }
                            },
                            items: _industries.map((ind) {
                              return DropdownMenuItem<String>(
                                value: ind,
                                child: Text(ind),
                              );
                            }).toList(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      HRNovaTextField(
                        label: 'Company Address',
                        hint: 'e.g. Kigali, Kicukiro District',
                        controller: _addressController,
                      ),
                      const SizedBox(height: 18),

                      HRNovaTextField(
                        label: 'Contact Person Name',
                        hint: 'e.g. Alice Mutoni',
                        controller: _contactController,
                      ),
                      const SizedBox(height: 18),

                      HRNovaTextField(
                        label: 'HR Admin Email',
                        hint: 'e.g. admin@inyange.rw',
                        controller: _emailController,
                        keyboardType: TextInputType.emailAddress,
                      ),
                      const SizedBox(height: 18),

                      HRNovaTextField(
                        label: 'HR Admin Phone',
                        hint: 'e.g. +250788123456',
                        controller: _phoneController,
                        keyboardType: TextInputType.phone,
                      ),
                      const SizedBox(height: 18),

                      HRNovaTextField(
                        label: 'Expected Employee Count',
                        hint: 'e.g. 50',
                        controller: _employeesController,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 18),

                      HRNovaTextField(
                        label: 'Monthly Price (RWF)',
                        hint: 'e.g. 150000',
                        controller: _priceController,
                        keyboardType: TextInputType.number,
                      ),
                      const SizedBox(height: 18),

                      // Temp Password (Create flow only)
                      if (!isEdit) ...[
                        HRNovaTextField(
                          label: 'Temporary Password for HR Admin',
                          hint: 'Min. 8 characters',
                          controller: _passwordController,
                          obscureText: true,
                        ),
                        const SizedBox(height: 24),
                      ],
                    ],
                  ),
                ),
              ),

              const Divider(color: Color(0x13FFFFFF)),
              const SizedBox(height: 16),

              // Action Buttons Row
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _closePanel,
                    child: const Text('Cancel', style: TextStyle(color: Colors.white54)),
                  ),
                  const SizedBox(width: 16),
                  HRNovaButton(
                    label: isEdit ? 'Save Changes' : 'Create Company',
                    onPressed: _handleSave,
                    isLoading: _isSaving,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDetailsPanelContent() {
    if (_detailsCompany == null) return const SizedBox.shrink();

    final data = _detailsCompany!.data() as Map<String, dynamic>? ?? {};
    final name = data['name'] ?? 'N/A';
    final industry = data['industry'] ?? 'N/A';
    final address = data['address'] ?? 'N/A';
    final contactPerson = data['contactPerson'] ?? 'N/A';
    final hrAdminEmail = data['hrAdminEmail'] ?? 'N/A';
    final hrAdminPhone = data['hrAdminPhone'] ?? 'N/A';
    final employeeCount = data['employeeCount'] ?? 0;
    final monthlyPrice = data['monthlyPrice'] ?? 0;
    final status = data['status'] ?? 'active';

    String createdDateStr = 'N/A';
    if (data['createdAt'] != null) {
      final createdTime = (data['createdAt'] as Timestamp).toDate();
      createdDateStr = DateFormat('yyyy-MM-dd HH:mm').format(createdTime);
    }

    final formatter = NumberFormat('#,###', 'en_US');

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(28.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Details Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Company Profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white70),
                  onPressed: _closeDetailsPanel,
                ),
              ],
            ),
            const SizedBox(height: 8),
            const Divider(color: Color(0x13FFFFFF)),
            const SizedBox(height: 20),

            // Scrollable Content details
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Status Badge row
                    Row(
                      children: [
                        const Text('System Access: ', style: TextStyle(color: Colors.white54, fontSize: 13)),
                        const SizedBox(width: 8),
                        StatusBadge(
                          text: status.toString().toUpperCase(),
                          type: status == 'active' ? 'active' : 'suspended',
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),

                    // Information sections
                    _buildDetailItem('Company Name', name, isTitle: true),
                    _buildDetailItem('Industry Sector', industry),
                    _buildDetailItem('Full Address', address),
                    _buildDetailItem('Created Date', createdDateStr),
                    _buildDetailItem('Monthly Charge Rate', '${formatter.format(monthlyPrice)} RWF'),
                    _buildDetailItem('Estimated Employees', employeeCount.toString()),
                    
                    const SizedBox(height: 12),
                    const Divider(color: Color(0x13FFFFFF)),
                    const SizedBox(height: 20),

                    const Text(
                      'Primary Contact & Admin Details',
                      style: TextStyle(
                        color: AppColors.lightGreen,
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _buildDetailItem('Contact Representative', contactPerson),
                    _buildDetailItem('HR Admin Email', hrAdminEmail),
                    _buildDetailItem('HR Admin Contact Phone', hrAdminPhone),
                  ],
                ),
              ),
            ),

            const Divider(color: Color(0x13FFFFFF)),
            const SizedBox(height: 16),

            // Control Actions Row (Edit, Suspend/Activate, Delete)
            Row(
              children: [
                // Delete Action (Soft Muted Slate Grey, no red/orange/yellow)
                HRNovaButton(
                  label: 'Delete',
                  backgroundColor: AppColors.errorRed, // Slate gray
                  textColor: Colors.white,
                  onPressed: () => _deleteCompany(_detailsCompany!),
                ),
                const Spacer(),
                
                // Suspend / Reactivate Action (Muted gray or soft light green)
                HRNovaButton(
                  label: status == 'active' ? 'Deactivate' : 'Bring to Life',
                  backgroundColor: status == 'active' ? const Color(0x1CFFFFFF) : AppColors.primaryGreen,
                  textColor: Colors.white,
                  onPressed: () => _toggleTransition(_detailsCompany!),
                ),
                const SizedBox(width: 12),

                // Edit action triggers Edit Form
                HRNovaButton(
                  label: 'Edit',
                  onPressed: () => _openEditPanel(_detailsCompany!),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailItem(String title, String value, {bool isTitle = false}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(color: Colors.white54, fontSize: 11),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: Colors.white,
              fontSize: isTitle ? 18 : 13,
              fontWeight: isTitle ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleTransition(DocumentSnapshot doc) async {
    // Standard transition triggers confirmation before updating status
    await _toggleSuspension(doc);
  }
}
