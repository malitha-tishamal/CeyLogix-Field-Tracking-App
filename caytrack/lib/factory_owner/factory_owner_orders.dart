// factory_owner_orders.dart - FINAL VERSION WITH STATIC HEADER & FOOTER
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'factory_owner_drawer.dart';

// Reusing AppColors locally
class AppColors {
  static const Color background = Color(0xFFEEEBFF);
  static const Color darkText = Color(0xFF2C2A3A);
  static const Color primaryBlue = Color(0xFF2764E7);
  static const Color accentRed = Color(0xFFE53935);
  static const Color accentTeal = Color(0xFF00BFA5);
  static const Color successGreen = Color(0xFF4CAF50);
  static const Color warningOrange = Color(0xFFFF9800);
  static const Color cardBackground = Colors.white;
  static const Color secondaryText = Color(0xFF6A798A);
  static const Color secondaryColor = Color(0xFF6AD96A);
  static const Color purpleAccent = Color(0xFF9C27B0);
  static const Color amberAccent = Color(0xFFFFC107);
  static const Color info = Color(0xFF2196F3);
  static const Color textTertiary = Color(0xFF999999);
  static const Color hover = Color(0xFFF5F7FA);
  static const Color border = Color(0xFFE1E5E9);
  
  // Custom colors based on the image's gradient header
  static const Color headerGradientStart = Color(0xFF869AEC);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);  
  static const Color headerTextDark = Color(0xFF333333);
}

class FactoryOwnerOrdersPage extends StatefulWidget {
  final User? currentUser;

  const FactoryOwnerOrdersPage({
    super.key,
    this.currentUser,
  });

  // Factory constructor for drawer navigation
  factory FactoryOwnerOrdersPage.fromContext(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    return FactoryOwnerOrdersPage(
      currentUser: user,
    );
  }

  @override
  State<FactoryOwnerOrdersPage> createState() => _FactoryOwnerOrdersPageState();
}

class _FactoryOwnerOrdersPageState extends State<FactoryOwnerOrdersPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  List<Map<String, dynamic>> _allOrders = [];
  List<Map<String, dynamic>> _filteredOrders = [];
  bool _isLoading = true;
  String? _errorMessage;
  
  // User data
  String _loggedInUserName = 'Loading...';
  String? _profileImageUrl;
  String _userRole = 'Factory Owner';
  String _factoryID = 'F-ID';
  String _factoryName = 'Loading...';
  
  // Filter variables
  String _searchQuery = '';
  String _statusFilter = 'All'; // All, Pending, Factory Received, Delivered, etc.
  DateTimeRange? _dateRangeFilter;
  String _cropTypeFilter = 'All'; // All, Tea, Cinnamon, Both
  
  // Controller for search
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _initializeUserData();
    _fetchOrders();
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _initializeUserData() async {
    final user = widget.currentUser ?? FirebaseAuth.instance.currentUser;
    if (user == null) return;

    setState(() {
      _factoryID = user.uid.substring(0, 8);
    });

    try {
      // Fetch user details
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner Name Missing';
          _userRole = userData?['role'] ?? 'Factory Owner';
          _profileImageUrl = userData?['profileImageUrl'];
        });
      }
      
      // Fetch factory details
      final factoryDoc = await _firestore.collection('factories').doc(user.uid).get();
      if (factoryDoc.exists) {
        setState(() {
          _factoryName = factoryDoc.data()?['factoryName'] ?? 'Factory Name Missing';
        });
      }
    } catch (e) {
      debugPrint("Error fetching user data: $e");
    }
  }

  Future<void> _fetchOrders() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final user = widget.currentUser ?? FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _errorMessage = "User not logged in";
          _isLoading = false;
        });
        return;
      }

      final factoryId = user.uid;
      
      final ordersQuery = await _firestore
          .collection('land_orders')
          .where('factoryId', isEqualTo: factoryId)
          .get();

      if (ordersQuery.docs.isEmpty) {
        setState(() {
          _allOrders = [];
          _filteredOrders = [];
          _isLoading = false;
        });
        return;
      }

      final orders = ordersQuery.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          ...data,
          'orderDate': (data['orderDate'] as Timestamp?)?.toDate(),
          'createdAt': data['createdAt'],
          'updatedAt': data['updatedAt'],
          'orderPhotos': List<String>.from(data['orderPhotos'] ?? []),
        };
      }).toList();

      // Sort by orderDate descending (newest first)
      orders.sort((a, b) {
        final aDate = a['orderDate'] as DateTime?;
        final bDate = b['orderDate'] as DateTime?;
        if (aDate == null || bDate == null) return 0;
        return bDate.compareTo(aDate);
      });

      setState(() {
        _allOrders = orders;
        _filteredOrders = List.from(orders);
        _isLoading = false;
      });
    } catch (e) {
      debugPrint("Error fetching orders: $e");
      setState(() {
        _errorMessage = "Failed to load orders. Please try again.";
        _isLoading = false;
      });
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allOrders);
    
    // Apply search filter
    if (_searchQuery.isNotEmpty) {
      filtered = filtered.where((order) {
        final landOwnerName = (order['landOwnerName'] ?? '').toString().toLowerCase();
        final cropType = (order['cropType'] ?? '').toString().toLowerCase();
        final description = (order['description'] ?? '').toString().toLowerCase();
        
        return landOwnerName.contains(_searchQuery.toLowerCase()) ||
               cropType.contains(_searchQuery.toLowerCase()) ||
               description.contains(_searchQuery.toLowerCase());
      }).toList();
    }
    
    // Apply status filter
    if (_statusFilter != 'All') {
      filtered = filtered.where((order) {
        final status = (order['status'] ?? '').toString().toLowerCase();
        final filterStatus = _statusFilter.toLowerCase();
        
        if (filterStatus == 'pending') {
          return status == 'pending';
        } else if (filterStatus == 'factory received') {
          return status.contains('factory recived') || 
                 status.contains('received factory') || 
                 status.contains('factory received');
        } else if (filterStatus == 'delivered') {
          return status.contains('delivered') || 
                 status.contains('completed') || 
                 status.contains('accepted');
        } else if (filterStatus == 'cancelled') {
          return status.contains('cancelled') || 
                 status.contains('rejected');
        }
        return true;
      }).toList();
    }
    
    // Apply date range filter
    if (_dateRangeFilter != null) {
      filtered = filtered.where((order) {
        final orderDate = order['orderDate'] as DateTime?;
        if (orderDate == null) return false;
        
        return orderDate.isAfter(_dateRangeFilter!.start) && 
               orderDate.isBefore(_dateRangeFilter!.end.add(Duration(days: 1)));
      }).toList();
    }
    
    // Apply crop type filter
    if (_cropTypeFilter != 'All') {
      filtered = filtered.where((order) {
        final cropType = (order['cropType'] ?? '').toString();
        return cropType == _cropTypeFilter;
      }).toList();
    }
    
    setState(() {
      _filteredOrders = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _searchQuery = '';
      _searchController.clear();
      _statusFilter = 'All';
      _dateRangeFilter = null;
      _cropTypeFilter = 'All';
      _filteredOrders = List.from(_allOrders);
    });
  }

  void _onSearchChanged() {
    setState(() {
      _searchQuery = _searchController.text;
    });
    _applyFilters();
  }

  Future<void> _selectDateRange(BuildContext context) async {
    final DateTimeRange? picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020),
      lastDate: DateTime.now().add(Duration(days: 365)),
      currentDate: DateTime.now(),
      saveText: 'Apply',
      helpText: 'Select Date Range',
      confirmText: 'Apply',
      cancelText: 'Cancel',
      fieldStartLabelText: 'Start date',
      fieldEndLabelText: 'End date',
    );
    
    if (picked != null && picked != _dateRangeFilter) {
      setState(() {
        _dateRangeFilter = picked;
      });
      _applyFilters();
    }
  }

  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => _buildFilterBottomSheet(context),
    );
  }

  Widget _buildFilterBottomSheet(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filter Orders',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.darkText,
                ),
              ),
              IconButton(
                icon: Icon(Icons.close),
                onPressed: () => Navigator.pop(context),
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Status Filter
          Text(
            'Status',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildFilterChip('All', _statusFilter == 'All'),
              _buildFilterChip('Pending', _statusFilter == 'Pending'),
              _buildFilterChip('Factory Received', _statusFilter == 'Factory Received'),
              _buildFilterChip('Delivered', _statusFilter == 'Delivered'),
              _buildFilterChip('Cancelled', _statusFilter == 'Cancelled'),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Crop Type Filter
          Text(
            'Crop Type',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _buildCropFilterChip('All', _cropTypeFilter == 'All'),
              _buildCropFilterChip('Tea', _cropTypeFilter == 'Tea'),
              _buildCropFilterChip('Cinnamon', _cropTypeFilter == 'Cinnamon'),
              _buildCropFilterChip('Both', _cropTypeFilter == 'Both'),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Date Range Filter
          Text(
            'Date Range',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          SizedBox(height: 10),
          ElevatedButton.icon(
            onPressed: () => _selectDateRange(context),
            icon: Icon(Icons.calendar_today),
            label: Text(
              _dateRangeFilter == null
                  ? 'Select Date Range'
                  : '${DateFormat('MMM dd, yyyy').format(_dateRangeFilter!.start)} - ${DateFormat('MMM dd, yyyy').format(_dateRangeFilter!.end)}',
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
              foregroundColor: AppColors.primaryBlue,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
          ),
          
          SizedBox(height: 30),
          
          // Action Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _clearFilters,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    side: BorderSide(color: AppColors.accentRed),
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Clear All Filters'),
                ),
              ),
              SizedBox(width: 10),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    _applyFilters();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(vertical: 15),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: Text('Apply Filters'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected) {
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (bool value) {
        setState(() {
          _statusFilter = value ? label : 'All';
        });
      },
      backgroundColor: selected ? AppColors.primaryBlue : AppColors.hover,
      selectedColor: AppColors.primaryBlue,
      labelStyle: TextStyle(
        color: selected ? Colors.white : AppColors.darkText,
      ),
      checkmarkColor: Colors.white,
    );
  }

  Widget _buildCropFilterChip(String label, bool selected) {
    Color chipColor;
    switch (label) {
      case 'Tea':
        chipColor = AppColors.successGreen;
        break;
      case 'Cinnamon':
        chipColor = AppColors.warningOrange;
        break;
      case 'Both':
        chipColor = AppColors.accentTeal;
        break;
      default:
        chipColor = AppColors.primaryBlue;
    }
    
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (bool value) {
        setState(() {
          _cropTypeFilter = value ? label : 'All';
        });
      },
      backgroundColor: selected ? chipColor : chipColor.withOpacity(0.1),
      selectedColor: chipColor,
      labelStyle: TextStyle(
        color: selected ? Colors.white : chipColor,
        fontWeight: FontWeight.w600,
      ),
      checkmarkColor: Colors.white,
    );
  }

  Future<void> _updateOrderStatus(String orderId, String status) async {
    try {
      await _firestore.collection('land_orders').doc(orderId).update({
        'status': status,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Refresh orders
      _fetchOrders();

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Order status updated to "$status"'),
          backgroundColor: AppColors.successGreen,
        ),
      );
    } catch (e) {
      debugPrint("Error updating order status: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to update order status: $e'),
          backgroundColor: AppColors.accentRed,
        ),
      );
    }
  }

  void _showOrderDetailsModal(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => FactoryOrderDetailsModal(
        order: order,
        onStatusUpdate: (orderId) => _updateOrderStatus(orderId, 'Factory Received'),
      ),
    );
  }

  Color _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warningOrange;
      case 'factory recived':
      case 'received factory':
      case 'factory received':
        return AppColors.info;
      case 'delivered':
      case 'completed':
      case 'accepted':
        return AppColors.successGreen;
      case 'cancelled':
      case 'rejected':
        return AppColors.accentRed;
      default:
        return AppColors.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      
      drawer: FactoryOwnerDrawer(
        onLogout: () {
          Navigator.pop(context);
        },
        onNavigate: (routeName) {
          Navigator.pop(context);
        },
      ),

      body: SafeArea(
        child: Column(
          children: [
            // STATIC HEADER - Doesn't scroll
            _buildHeader(context, screenWidth),
            
            // STATIC SEARCH & FILTER - Doesn't scroll
            _buildSearchFilterSection(context, screenWidth),
            
            // SCROLLABLE CONTENT AREA (Statistics + Orders)
            Expanded(
              child: _isLoading
                  ? _buildLoading()
                  : _errorMessage != null
                      ? _buildError()
                      : _buildScrollableContent(screenWidth, screenHeight),
            ),
            
            // STATIC FOOTER - Doesn't scroll
            Container(
  width: double.infinity, // <-- makes it full width
  padding: EdgeInsets.symmetric(
    horizontal: screenWidth * 0.04,
    vertical: screenHeight * 0.015,
  ),
  decoration: BoxDecoration(
    
    border: Border(
      top: BorderSide(
        color: AppColors.border,
        width: 1,
      ),
    ),
  ),
  child: Text(
    'Developed By Malitha Tishamal',
    textAlign: TextAlign.center,
    style: TextStyle(
      color: AppColors.darkText.withOpacity(0.7),
      fontSize: screenWidth * 0.03,
    ),
  ),
),

          ],
        ),
      ),
    );
  }

  Widget _buildScrollableContent(double screenWidth, double screenHeight) {
    return RefreshIndicator(
      color: AppColors.primaryBlue,
      onRefresh: _fetchOrders,
      child: _filteredOrders.isEmpty
          ? _buildEmpty()
          : SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Column(
                children: [
                  // Statistics Section
                  _buildStatisticsSection(screenWidth, screenHeight),
                  
                  // Orders List
                  ..._filteredOrders.map((order) {
                    return _buildOrderCard(order, context, screenWidth, screenHeight);
                  }).toList(),
                  
                  // Add some bottom padding
                  SizedBox(height: 20),
                ],
              ),
            ),
    );
  }

  /// STATIC HEADER - Fixed at the top
  Widget _buildHeader(BuildContext context, double screenWidth) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (isSmallScreen ? 8 : isMediumScreen ? 10 : 12),
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
        bottom: isSmallScreen ? 16 : isMediumScreen ? 18 : 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF869AEC), AppColors.headerGradientEnd], 
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30), 
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000), 
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              IconButton(
                icon: Icon(
                  Icons.menu,
                  color: AppColors.headerTextDark,
                  size: isSmallScreen ? 24 : isMediumScreen ? 26 : 28,
                ),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 6 : 8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.9),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.1),
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Text(
                  '${_filteredOrders.length}',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.bold,
                    color: AppColors.primaryBlue,
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 8 : isMediumScreen ? 9 : 10),
          
          Row(
            children: [
              Container(
                width: isSmallScreen ? 60 : isMediumScreen ? 65 : 70,
                height: isSmallScreen ? 60 : isMediumScreen ? 65 : 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _profileImageUrl == null 
                    ? const LinearGradient(
                        colors: [AppColors.primaryBlue, Color(0xFF457AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                  border: Border.all(color: Colors.white, width: isSmallScreen ? 2 : 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.4),
                      blurRadius: isSmallScreen ? 8 : 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  image: _profileImageUrl != null 
                    ? DecorationImage(
                        image: NetworkImage(_profileImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                ),
                child: _profileImageUrl == null
                    ? Icon(
                        Icons.person,
                        size: isSmallScreen ? 32 : isMediumScreen ? 36 : 40,
                        color: Colors.white,
                      )
                    : null,
              ),
              
              SizedBox(width: isSmallScreen ? 12 : isMediumScreen ? 14 : 15),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loggedInUserName,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : isMediumScreen ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headerTextDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 2 : isMediumScreen ? 3 : 4),
                    Text(
                      '$_factoryName\n($_userRole)',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : isMediumScreen ? 12 : 14,
                        color: AppColors.headerTextDark.withOpacity(0.7),
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 15 : isMediumScreen ? 18 : 20),
          
          Text(
            'Orders for Factory ID: $_factoryID',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : isMediumScreen ? 15 : 16,
              fontWeight: FontWeight.w600,
              color: AppColors.headerTextDark,
            ),
          ),
        ],
      ),
    );
  }

  /// STATIC SEARCH & FILTER - Fixed below header
  Widget _buildSearchFilterSection(BuildContext context, double screenWidth) {
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      color: Colors.white,
      child: Column(
        children: [
          // Search Bar
          Container(
            decoration: BoxDecoration(
              color: AppColors.hover,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                SizedBox(width: 12),
                Icon(Icons.search, color: AppColors.secondaryText),
                SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search by land owner, crop type...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(vertical: 14),
                    ),
                    style: TextStyle(fontSize: isSmallScreen ? 14 : 16),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                      _onSearchChanged();
                    },
                  ),
              ],
            ),
          ),
          
          SizedBox(height: 12),
          
          // Filter Chips Row
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Filter Button
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.filter_list, 
                        size: 16, 
                        color: AppColors.primaryBlue
                      ),
                      SizedBox(width: 6),
                      Text(
                        'Filters',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                    ],
                  ),
                ),
                
                SizedBox(width: 8),
                
                // Active Filters
                if (_statusFilter != 'All')
                  _buildActiveFilterChip(
                    label: 'Status: $_statusFilter',
                    onRemove: () {
                      setState(() {
                        _statusFilter = 'All';
                      });
                      _applyFilters();
                    },
                  ),
                
                if (_cropTypeFilter != 'All')
                  _buildActiveFilterChip(
                    label: 'Crop: $_cropTypeFilter',
                    onRemove: () {
                      setState(() {
                        _cropTypeFilter = 'All';
                      });
                      _applyFilters();
                    },
                  ),
                
                if (_dateRangeFilter != null)
                  _buildActiveFilterChip(
                    label: 'Date Range',
                    onRemove: () {
                      setState(() {
                        _dateRangeFilter = null;
                      });
                      _applyFilters();
                    },
                  ),
                
                // Clear All Button
                if (_statusFilter != 'All' || _cropTypeFilter != 'All' || _dateRangeFilter != null)
                  GestureDetector(
                    onTap: _clearFilters,
                    child: Container(
                      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      child: Text(
                        'Clear All',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.accentRed,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActiveFilterChip({required String label, required VoidCallback onRemove}) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.successGreen.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.successGreen.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              color: AppColors.successGreen,
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(width: 4),
          GestureDetector(
            onTap: onRemove,
            child: Icon(
              Icons.close,
              size: 14,
              color: AppColors.successGreen,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatisticsSection(double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    // Calculate statistics
    final now = DateTime.now();
    final startOfToday = DateTime(now.year, now.month, now.day);
    final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
    
    final ordersToday = _filteredOrders.where((order) {
      final orderDate = order['orderDate'] as DateTime?;
      if (orderDate == null) return false;
      return orderDate.isAfter(startOfToday) && orderDate.isBefore(now);
    }).toList();
    
    final ordersThisWeek = _filteredOrders.where((order) {
      final orderDate = order['orderDate'] as DateTime?;
      if (orderDate == null) return false;
      return orderDate.isAfter(startOfWeek) && orderDate.isBefore(now);
    }).toList();
    
    // Calculate crop breakdown for this week
    final teaThisWeek = ordersThisWeek.where((order) {
      final cropType = (order['cropType'] ?? '').toString().toLowerCase();
      return cropType == 'tea';
    }).length;
    
    final cinnamonThisWeek = ordersThisWeek.where((order) {
      final cropType = (order['cropType'] ?? '').toString().toLowerCase();
      return cropType == 'cinnamon';
    }).length;
    
    final bothThisWeek = ordersThisWeek.where((order) {
      final cropType = (order['cropType'] ?? '').toString().toLowerCase();
      return cropType == 'both';
    }).length;
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 
                   isMediumScreen ? 14 : 16,
        vertical: 16,
      ),
      child: Column(
        children: [
          // Row 1: Total, Pending, Received
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12 : 
                    isMediumScreen ? 14 : 16),
            margin: EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.cardBackground,
              borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 14),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildSummaryItem(
                  label: 'Total',
                  value: _filteredOrders.length.toString(),
                  icon: Icons.list_alt,
                  color: AppColors.primaryBlue,
                  screenWidth: screenWidth,
                ),
                _buildSummaryItem(
                  label: 'Pending',
                  value: _filteredOrders.where((order) {
                    final status = (order['status'] ?? '').toString().toLowerCase();
                    return status == 'pending';
                  }).length.toString(),
                  icon: Icons.pending,
                  color: AppColors.warningOrange,
                  screenWidth: screenWidth,
                ),
                _buildSummaryItem(
                  label: 'Received',
                  value: _filteredOrders.where((order) {
                    final status = (order['status'] ?? '').toString().toLowerCase();
                    return status.contains('factory recived') || 
                           status.contains('received factory') || 
                           status.contains('factory received');
                  }).length.toString(),
                  icon: Icons.check_circle,
                  color: AppColors.successGreen,
                  screenWidth: screenWidth,
                ),
              ],
            ),
          ),
          
          // Row 2: Today, This Week
          Row(
            children: [
              // Orders Today Card
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 
                          isMediumScreen ? 14 : 16),
                  margin: EdgeInsets.only(right: 6),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.primaryBlue.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.today,
                              size: isSmallScreen ? 16 : 18,
                              color: AppColors.primaryBlue,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'Today',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkText,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        ordersToday.length.toString(),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'orders received',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 10 : 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // This Week Card
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12 : 
                          isMediumScreen ? 14 : 16),
                  margin: EdgeInsets.only(left: 6),
                  decoration: BoxDecoration(
                    color: AppColors.cardBackground,
                    borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 6,
                        offset: Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(6),
                            decoration: BoxDecoration(
                              color: AppColors.accentTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Icon(
                              Icons.date_range,
                              size: isSmallScreen ? 16 : 18,
                              color: AppColors.accentTeal,
                            ),
                          ),
                          SizedBox(width: 8),
                          Text(
                            'This Week',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12 : 14,
                              fontWeight: FontWeight.w600,
                              color: AppColors.darkText,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 8),
                      Text(
                        ordersThisWeek.length.toString(),
                        style: TextStyle(
                          fontSize: isSmallScreen ? 20 : 24,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accentTeal,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'orders received',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 10 : 12,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          // Row 3: This Week Crop Breakdown
          if (ordersThisWeek.isNotEmpty) ...[
            SizedBox(height: 12),
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 
                      isMediumScreen ? 14 : 16),
              margin: EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 6,
                    offset: Offset(0, 3),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.agriculture,
                        size: isSmallScreen ? 16 : 18,
                        color: AppColors.successGreen,
                      ),
                      SizedBox(width: 8),
                      Text(
                        'This Week Crop Breakdown',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  
                  // Crop Type Breakdown
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceAround,
                    children: [
                      // Tea
                      Column(
                        children: [
                          Container(
                            width: isSmallScreen ? 50 : 60,
                            height: isSmallScreen ? 50 : 60,
                            decoration: BoxDecoration(
                              color: AppColors.successGreen.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.successGreen.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.eco,
                                  color: AppColors.successGreen,
                                  size: isSmallScreen ? 20 : 24,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  teaThisWeek.toString(),
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.successGreen,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Tea',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      
                      // Cinnamon
                      Column(
                        children: [
                          Container(
                            width: isSmallScreen ? 50 : 60,
                            height: isSmallScreen ? 50 : 60,
                            decoration: BoxDecoration(
                              color: AppColors.warningOrange.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.warningOrange.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.forest,
                                  color: AppColors.warningOrange,
                                  size: isSmallScreen ? 20 : 24,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  cinnamonThisWeek.toString(),
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.warningOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Cinnamon',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                      
                      // Both
                      Column(
                        children: [
                          Container(
                            width: isSmallScreen ? 50 : 60,
                            height: isSmallScreen ? 50 : 60,
                            decoration: BoxDecoration(
                              color: AppColors.accentTeal.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.accentTeal.withOpacity(0.3),
                              ),
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.layers,
                                  color: AppColors.accentTeal,
                                  size: isSmallScreen ? 20 : 24,
                                ),
                                SizedBox(height: 4),
                                Text(
                                  bothThisWeek.toString(),
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14 : 16,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.accentTeal,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          SizedBox(height: 6),
                          Text(
                            'Both',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 12,
                              color: AppColors.secondaryText,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                  
                  // Total for this week
                  SizedBox(height: 12),
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: AppColors.primaryBlue.withOpacity(0.2),
                      ),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Total This Week: ',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        Text(
                          ordersThisWeek.length.toString(),
                          style: TextStyle(
                            fontSize: isSmallScreen ? 14 : 16,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                        Text(
                          ' orders',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 14,
                            color: AppColors.secondaryText,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          
          // Orders List Title
          if (_filteredOrders.isNotEmpty) ...[
            SizedBox(height: 8),
            Container(
              margin: EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Icon(
                    Icons.list,
                    size: isSmallScreen ? 18 : 20,
                    color: AppColors.primaryBlue,
                  ),
                  SizedBox(width: 8),
                  Text(
                    'All Orders (${_filteredOrders.length})',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.darkText,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildSummaryItem({
    required String label,
    required String value,
    required IconData icon,
    required Color color,
    required double screenWidth,
  }) {
    final isSmallScreen = screenWidth < 360;
    
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
          ),
          child: Icon(
            icon,
            size: isSmallScreen ? 18 : 22,
            color: color,
          ),
        ),
        SizedBox(height: 8),
        Text(
          value,
          style: TextStyle(
            fontSize: isSmallScreen ? 16 : 18,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: isSmallScreen ? 10 : 12,
            color: AppColors.secondaryText,
          ),
        ),
      ],
    );
  }

  Widget _buildOrderCard(Map<String, dynamic> order, BuildContext context, double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    final landOwnerName = order['landOwnerName'] ?? 'Unknown';
    final status = order['status'] ?? 'Pending';
    final cropType = order['cropType'] ?? 'N/A';
    final totalQuantity = order['totalQuantity'] ?? 0;
    final unit = order['unit'] ?? 'kg';
    final orderDate = order['orderDate'] as DateTime?;
    final description = order['description'] ?? '';
    final orderPhotos = List<String>.from(order['orderPhotos'] ?? []);
    
    final statusColor = _getOrderStatusColor(status);
    final cropColor = _getCropColorFromString(cropType);
    final canMarkAsReceived = status.toLowerCase() == 'pending';

    return Container(
      margin: EdgeInsets.only(
        left: isSmallScreen ? 12 : isMediumScreen ? 14 : 16,
        right: isSmallScreen ? 12 : isMediumScreen ? 14 : 16,
        bottom: isSmallScreen ? 12 : 16,
      ),
      child: Material(
        elevation: 2,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 14),
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 14),
            border: Border.all(color: AppColors.border),
          ),
          child: InkWell(
            onTap: () => _showOrderDetailsModal(order),
            borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 14),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 
                      isMediumScreen ? 14 : 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header row
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Row(
                          children: [
                            Container(
                              padding: EdgeInsets.all(isSmallScreen ? 4 : 
                                      isMediumScreen ? 5 : 6),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
                              ),
                              child: Icon(
                                _getOrderStatusIcon(status),
                                size: isSmallScreen ? 14 : 
                                      isMediumScreen ? 16 : 18,
                                color: statusColor,
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 8 : 
                                    isMediumScreen ? 10 : 12),
                            Expanded(
                              child: Text(
                                landOwnerName,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 
                                          isMediumScreen ? 15 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 8 : 
                                    isMediumScreen ? 9 : 10,
                          vertical: isSmallScreen ? 3 : 
                                    isMediumScreen ? 4 : 5,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 15),
                          border: Border.all(color: statusColor.withOpacity(0.3)),
                        ),
                        child: Text(
                          status,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 
                                    isMediumScreen ? 11 : 12,
                            fontWeight: FontWeight.w600,
                            color: statusColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  SizedBox(height: screenHeight * 0.01),
                  
                  // Order details row
                  Row(
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 6 : 
                                    isMediumScreen ? 7 : 8,
                          vertical: isSmallScreen ? 2 : 
                                    isMediumScreen ? 3 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: cropColor.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
                        ),
                        child: Text(
                          cropType,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 
                                    isMediumScreen ? 11 : 12,
                            fontWeight: FontWeight.w600,
                            color: cropColor,
                          ),
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 8 : 
                              isMediumScreen ? 10 : 12),
                      Icon(
                        Icons.scale,
                        size: isSmallScreen ? 12 : 
                              isMediumScreen ? 14 : 16,
                        color: AppColors.secondaryText,
                      ),
                      SizedBox(width: isSmallScreen ? 2 : 
                              isMediumScreen ? 3 : 4),
                      Text(
                        '$totalQuantity $unit',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 
                                  isMediumScreen ? 13 : 14,
                          color: AppColors.darkText,
                        ),
                      ),
                      Spacer(),
                      if (orderDate != null)
                        Row(
                          children: [
                            Icon(
                              Icons.calendar_today,
                              size: isSmallScreen ? 10 : 
                                    isMediumScreen ? 12 : 14,
                              color: AppColors.textTertiary,
                            ),
                            SizedBox(width: isSmallScreen ? 2 : 
                                    isMediumScreen ? 3 : 4),
                            Text(
                              DateFormat('MMM dd, HH:mm').format(orderDate),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10 : 
                                        isMediumScreen ? 11 : 12,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                  
                  // Description (if available)
                  if (description.isNotEmpty) ...[
                    SizedBox(height: screenHeight * 0.01),
                    Text(
                      description.length > 50 && isSmallScreen
                        ? '${description.substring(0, 50)}...'
                        : description.length > 80
                          ? '${description.substring(0, 80)}...'
                          : description,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 
                                isMediumScreen ? 11 : 12,
                        color: AppColors.secondaryText,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                  
                  // Photos indicator
                  if (orderPhotos.isNotEmpty) ...[
                    SizedBox(height: screenHeight * 0.01),
                    Row(
                      children: [
                        Icon(
                          Icons.photo_camera_outlined,
                          size: isSmallScreen ? 12 : 
                                isMediumScreen ? 14 : 16,
                          color: AppColors.primaryBlue,
                        ),
                        SizedBox(width: isSmallScreen ? 4 : 
                                isMediumScreen ? 5 : 6),
                        Text(
                          '${orderPhotos.length} photo${orderPhotos.length > 1 ? 's' : ''}',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 
                                    isMediumScreen ? 11 : 12,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ],
                  
                  // Action button
                  if (canMarkAsReceived) ...[
                    SizedBox(height: screenHeight * 0.015),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: () => _updateOrderStatus(order['id'], 'Factory Received'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.successGreen,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
                          ),
                          padding: EdgeInsets.symmetric(
                            vertical: isSmallScreen ? 10 : 
                                    isMediumScreen ? 12 : 14,
                          ),
                        ),
                        child: Text(
                          'Mark as Received',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 
                                    isMediumScreen ? 13 : 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoading() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primaryBlue,
            strokeWidth: 2,
          ),
          SizedBox(height: 16),
          Text(
            'Loading orders...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildError() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline,
            size: 64,
            color: AppColors.accentRed,
          ),
          SizedBox(height: 16),
          Text(
            _errorMessage ?? 'An error occurred',
            style: const TextStyle(
              fontSize: 16,
              color: AppColors.darkText,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 16),
          ElevatedButton(
            onPressed: _fetchOrders,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
            ),
            child: const Text('Retry'),
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Center(
      child: SingleChildScrollView(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.inventory_outlined,
              size: 80,
              color: AppColors.textTertiary.withOpacity(0.5),
            ),
            SizedBox(height: 16),
            Text(
              'No Orders Found',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
            SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40),
              child: Text(
                _searchQuery.isNotEmpty || _statusFilter != 'All' || _dateRangeFilter != null
                    ? 'No orders match your filters. Try changing your search criteria.'
                    : 'You have not received any orders yet.\nOrders will appear here when land owners send products.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
            SizedBox(height: 20),
            ElevatedButton.icon(
              onPressed: _clearFilters,
              icon: Icon(Icons.refresh),
              label: Text('Clear Filters'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getCropColorFromString(String cropType) {
    switch (cropType.toLowerCase()) {
      case 'tea':
        return AppColors.successGreen;
      case 'cinnamon':
        return AppColors.warningOrange;
      case 'both':
        return AppColors.accentTeal;
      default:
        return AppColors.primaryBlue;
    }
  }

  IconData _getOrderStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending_outlined;
      case 'factory recived':
      case 'received factory':
      case 'factory received':
        return Icons.factory_rounded;
      case 'delivered':
      case 'completed':
      case 'accepted':
        return Icons.check_circle_outline_rounded;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }
}

// FactoryOrderDetailsModal class (with land and owner details) - Same as before
class FactoryOrderDetailsModal extends StatefulWidget {
  final Map<String, dynamic> order;
  final Function(String orderId) onStatusUpdate;

  const FactoryOrderDetailsModal({
    super.key, 
    required this.order,
    required this.onStatusUpdate,
  });

  @override
  State<FactoryOrderDetailsModal> createState() => _FactoryOrderDetailsModalState();
}

class _FactoryOrderDetailsModalState extends State<FactoryOrderDetailsModal> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  Map<String, dynamic>? _landDetails;
  Map<String, dynamic>? _landOwnerDetails;
  bool _isLoadingLandInfo = false;
  String? _landInfoError;

  @override
  void initState() {
    super.initState();
    _fetchLandAndOwnerDetails();
  }

  Future<void> _fetchLandAndOwnerDetails() async {
    setState(() {
      _isLoadingLandInfo = true;
      _landInfoError = null;
    });

    try {
      final landOwnerId = widget.order['landOwnerId'] as String?;
      if (landOwnerId == null || landOwnerId.isEmpty) {
        setState(() {
          _isLoadingLandInfo = false;
          _landInfoError = 'Land owner ID not found';
        });
        return;
      }

      // Fetch land owner details
      final userDoc = await _firestore.collection('users').doc(landOwnerId).get();
      if (userDoc.exists) {
        setState(() {
          _landOwnerDetails = userDoc.data();
        });
      }

      // Fetch land details
      final landsQuery = await _firestore
          .collection('lands')
          .where('owner', isEqualTo: landOwnerId)
          .limit(1)
          .get();

      if (landsQuery.docs.isNotEmpty) {
        setState(() {
          _landDetails = landsQuery.docs.first.data();
          _landDetails!['id'] = landsQuery.docs.first.id;
        });
      }

      setState(() {
        _isLoadingLandInfo = false;
      });
    } catch (e) {
      debugPrint("Error fetching land/owner details: $e");
      setState(() {
        _isLoadingLandInfo = false;
        _landInfoError = 'Failed to load land information';
      });
    }
  }

  @override
  @override
Widget build(BuildContext context) {
  final screenWidth = MediaQuery.of(context).size.width;
  final screenHeight = MediaQuery.of(context).size.height;
  
  final landOwnerName = widget.order['landOwnerName'] ?? 'Unknown';
  final status = widget.order['status'] ?? 'Pending';
  final cropType = widget.order['cropType'] ?? 'N/A';
  final totalQuantity = widget.order['totalQuantity'] ?? 0;
  final unit = widget.order['unit'] ?? 'kg';
  final orderDate = widget.order['orderDate'] as DateTime?;
  final description = widget.order['description'] ?? '';
  final orderPhotos = List<String>.from(widget.order['orderPhotos'] ?? []);
  
  final statusColor = _getOrderStatusColor(status);
  final canMarkAsReceived = status.toLowerCase() == 'pending';

  // Responsive calculations
  final isSmallScreen = screenWidth < 360;
  final isMediumScreen = screenWidth >= 360 && screenWidth < 600;
  final isLargeScreen = screenWidth >= 600;

  // Calculate dialog width based on screen size
  final double dialogWidth = isSmallScreen
      ? screenWidth * 0.95
      : isMediumScreen
          ? screenWidth * 0.85
          : 500; // Max width for large screens

  // Calculate dialog height based on screen size
  final double dialogHeight = screenHeight * (isSmallScreen ? 0.85 : 0.9);

  // Calculate font sizes based on screen size
  final double titleFontSize = isSmallScreen ? 16 : isMediumScreen ? 18 : 20;
  final double subtitleFontSize = isSmallScreen ? 12 : isMediumScreen ? 14 : 16;
  final double bodyFontSize = isSmallScreen ? 14 : isMediumScreen ? 16 : 18;
  final double detailFontSize = isSmallScreen ? 12 : isMediumScreen ? 14 : 16;
  final double buttonFontSize = isSmallScreen ? 14 : isMediumScreen ? 16 : 18;

  // Calculate padding based on screen size
  final double paddingAll = isSmallScreen ? 12 : isMediumScreen ? 16 : 20;
  final double paddingVertical = isSmallScreen ? 8 : isMediumScreen ? 12 : 16;
  final double paddingHorizontal = isSmallScreen ? 12 : isMediumScreen ? 16 : 20;

  // Calculate icon sizes based on screen size
  final double iconSizeSmall = isSmallScreen ? 16 : isMediumScreen ? 20 : 24;
  final double iconSizeMedium = isSmallScreen ? 20 : isMediumScreen ? 24 : 28;
  final double iconSizeLarge = isSmallScreen ? 24 : isMediumScreen ? 28 : 32;

  // Calculate avatar radius based on screen size
  final double avatarRadius = isSmallScreen ? 20 : isMediumScreen ? 25 : 30;

  // Calculate grid columns based on screen size
  final int gridColumns = isSmallScreen ? 1 : 2;

  // Calculate image sizes based on screen size
  final double landPhotoSize = isSmallScreen ? 60 : isMediumScreen ? 70 : 80;
  final double orderPhotoSize = isSmallScreen ? 80 : isMediumScreen ? 90 : 100;

  return Dialog(
    backgroundColor: Colors.transparent,
    insetPadding: EdgeInsets.symmetric(
      horizontal: isSmallScreen ? 8 : isMediumScreen ? 16 : 24,
      vertical: isSmallScreen ? 8 : 16,
    ),
    child: Container(
      constraints: BoxConstraints(
        maxWidth: dialogWidth,
        maxHeight: dialogHeight,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: isSmallScreen ? 20 : 30,
            spreadRadius: isSmallScreen ? 3 : 5,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(paddingAll),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.1),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(isSmallScreen ? 16 : 20),
                topRight: Radius.circular(isSmallScreen ? 16 : 20),
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 8 : 10),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                  ),
                  child: Icon(
                    _getOrderStatusIcon(status),
                    size: iconSizeMedium,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Order Details',
                        style: TextStyle(
                          fontSize: titleFontSize,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 2 : 4),
                      Text(
                        'From: $landOwnerName',
                        style: TextStyle(
                          fontSize: subtitleFontSize,
                          color: AppColors.secondaryText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 12,
                    vertical: isSmallScreen ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
                    border: Border.all(color: statusColor.withOpacity(0.4)),
                  ),
                  child: Text(
                    status.length > 10 && isSmallScreen
                        ? status.substring(0, 10).toUpperCase()
                        : status.toUpperCase(),
                    style: TextStyle(
                      fontSize: isSmallScreen ? 10 : 12,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              child: Padding(
                padding: EdgeInsets.all(paddingAll),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Order Information
                    Container(
                      padding: EdgeInsets.all(paddingAll),
                      margin: EdgeInsets.only(bottom: paddingVertical),
                      decoration: BoxDecoration(
                        color: AppColors.hover,
                        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'ORDER INFORMATION',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 12,
                              fontWeight: FontWeight.w600,
                              color: AppColors.secondaryText,
                              letterSpacing: 1,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          _buildOrderDetailRow(
                            'Crop Type', 
                            cropType, 
                            screenWidth,
                            fontSize: detailFontSize,
                          ),
                          _buildOrderDetailRow(
                            'Quantity', 
                            '$totalQuantity $unit', 
                            screenWidth,
                            fontSize: detailFontSize,
                          ),
                          if (orderDate != null)
                            _buildOrderDetailRow(
                              'Order Date', 
                              DateFormat('MMM dd, yyyy • HH:mm').format(orderDate), 
                              screenWidth,
                              fontSize: detailFontSize,
                            ),
                          if (widget.order['factoryName'] != null)
                            _buildOrderDetailRow(
                              'To Factory', 
                              widget.order['factoryName'].toString(), 
                              screenWidth,
                              fontSize: detailFontSize,
                            ),
                        ],
                      ),
                    ),

                    SizedBox(height: paddingVertical),

                    // Land Owner Details
                    Container(
                      padding: EdgeInsets.all(paddingAll),
                      margin: EdgeInsets.only(bottom: paddingVertical),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                        border: Border.all(color: AppColors.border),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.person_outline,
                                color: AppColors.primaryBlue,
                                size: iconSizeSmall,
                              ),
                              SizedBox(width: isSmallScreen ? 6 : 8),
                              Text(
                                'LAND OWNER DETAILS',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 10 : 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.secondaryText,
                                  letterSpacing: 1,
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 8 : 12),
                          
                          if (_isLoadingLandInfo)
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(paddingAll),
                                child: CircularProgressIndicator(
                                  color: AppColors.primaryBlue,
                                  strokeWidth: 2,
                                ),
                              ),
                            )
                          else if (_landInfoError != null)
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(paddingAll),
                                child: Column(
                                  children: [
                                    Icon(
                                      Icons.error_outline,
                                      color: AppColors.accentRed,
                                      size: iconSizeLarge,
                                    ),
                                    SizedBox(height: isSmallScreen ? 6 : 8),
                                    Text(
                                      _landInfoError!,
                                      style: TextStyle(
                                        fontSize: detailFontSize,
                                        color: AppColors.secondaryText,
                                      ),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              ),
                            )
                          else if (_landOwnerDetails != null)
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Owner Profile
                                Row(
                                  children: [
                                    CircleAvatar(
                                      radius: avatarRadius,
                                      backgroundImage: _landOwnerDetails!['profileImageUrl'] != null
                                          ? NetworkImage(_landOwnerDetails!['profileImageUrl']!)
                                          : null,
                                      backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                                      child: _landOwnerDetails!['profileImageUrl'] == null
                                          ? Icon(
                                              Icons.person,
                                              color: AppColors.primaryBlue,
                                              size: iconSizeMedium,
                                            )
                                          : null,
                                    ),
                                    SizedBox(width: isSmallScreen ? 10 : 12),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            _landOwnerDetails!['name'] ?? 'N/A',
                                            style: TextStyle(
                                              fontSize: bodyFontSize,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors.darkText,
                                            ),
                                            maxLines: 2,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          SizedBox(height: isSmallScreen ? 2 : 4),
                                          Text(
                                            'Land Owner',
                                            style: TextStyle(
                                              fontSize: detailFontSize,
                                              color: AppColors.primaryBlue,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: isSmallScreen ? 10 : 12),
                                
                                // Owner Details Grid
                                GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: gridColumns,
                                  crossAxisSpacing: isSmallScreen ? 6 : 10,
                                  mainAxisSpacing: isSmallScreen ? 6 : 10,
                                  childAspectRatio: isSmallScreen ? 3.5 : 3,
                                  children: [
                                    _buildOwnerDetailItem(
                                      icon: Icons.email,
                                      label: 'Email',
                                      value: _landOwnerDetails!['email'] ?? 'N/A',
                                      iconSize: iconSizeSmall,
                                      fontSize: detailFontSize,
                                    ),
                                    _buildOwnerDetailItem(
                                      icon: Icons.phone,
                                      label: 'Mobile',
                                      value: _landOwnerDetails!['mobile'] ?? 'N/A',
                                      iconSize: iconSizeSmall,
                                      fontSize: detailFontSize,
                                    ),
                                    _buildOwnerDetailItem(
                                      icon: Icons.badge,
                                      label: 'NIC',
                                      value: _landOwnerDetails!['nic'] ?? 'N/A',
                                      iconSize: iconSizeSmall,
                                      fontSize: detailFontSize,
                                    ),
                                    _buildOwnerDetailItem(
                                      icon: Icons.calendar_today,
                                      label: 'Registered',
                                      value: _landOwnerDetails!['registrationDate'] != null
                                          ? DateFormat('MMM dd, yyyy').format(
                                              (_landOwnerDetails!['registrationDate'] as Timestamp).toDate())
                                          : 'N/A',
                                      iconSize: iconSizeSmall,
                                      fontSize: detailFontSize,
                                    ),
                                  ],
                                ),
                              ],
                            )
                          else
                            Center(
                              child: Padding(
                                padding: EdgeInsets.all(paddingAll),
                                child: Text(
                                  'Land owner details not found',
                                  style: TextStyle(
                                    fontSize: detailFontSize,
                                    color: AppColors.secondaryText,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),

                    // Land Details
                    if (_landDetails != null && !_isLoadingLandInfo)
                      Column(
                        children: [
                          SizedBox(height: paddingVertical),
                          Container(
                            padding: EdgeInsets.all(paddingAll),
                            decoration: BoxDecoration(
                              color: Colors.white,
                              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(
                                      Icons.landscape,
                                      color: AppColors.successGreen,
                                      size: iconSizeSmall,
                                    ),
                                    SizedBox(width: isSmallScreen ? 6 : 8),
                                    Text(
                                      'LAND DETAILS',
                                      style: TextStyle(
                                        fontSize: isSmallScreen ? 10 : 12,
                                        fontWeight: FontWeight.w600,
                                        color: AppColors.secondaryText,
                                        letterSpacing: 1,
                                      ),
                                    ),
                                  ],
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 12),
                                
                                // Land Name and Crop Type
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        _landDetails!['landName'] ?? 'Unknown Land',
                                        style: TextStyle(
                                          fontSize: bodyFontSize,
                                          fontWeight: FontWeight.bold,
                                          color: AppColors.darkText,
                                        ),
                                        maxLines: 2,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ),
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: isSmallScreen ? 6 : 8,
                                        vertical: isSmallScreen ? 3 : 4,
                                      ),
                                      margin: EdgeInsets.only(left: isSmallScreen ? 6 : 8),
                                      decoration: BoxDecoration(
                                        color: _getCropColorFromString(_landDetails!['cropType'] ?? '').withOpacity(0.1),
                                        borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
                                      ),
                                      child: Text(
                                        _landDetails!['cropType'] ?? 'N/A',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 10 : 12,
                                          fontWeight: FontWeight.w600,
                                          color: _getCropColorFromString(_landDetails!['cropType'] ?? ''),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: isSmallScreen ? 8 : 12),
                                
                                // Land Size Details
                                if (_landDetails!['landSizeDetails'] != null && _landDetails!['landSizeDetails'].toString().isNotEmpty)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        'Land Size Breakdown:',
                                        style: TextStyle(
                                          fontSize: detailFontSize,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 4 : 6),
                                      Text(
                                        _landDetails!['landSizeDetails'] ?? '',
                                        style: TextStyle(
                                          fontSize: detailFontSize,
                                          color: AppColors.darkText,
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 8 : 12),
                                    ],
                                  ),
                                
                                // Location Details
                                GridView.count(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  crossAxisCount: gridColumns,
                                  crossAxisSpacing: isSmallScreen ? 6 : 10,
                                  mainAxisSpacing: isSmallScreen ? 6 : 10,
                                  childAspectRatio: isSmallScreen ? 3.5 : 3,
                                  children: [
                                    _buildLandDetailItem(
                                      icon: Icons.location_on,
                                      label: 'Address',
                                      value: _landDetails!['address'] ?? 'N/A',
                                      iconSize: iconSizeSmall,
                                      fontSize: detailFontSize,
                                    ),
                                    _buildLandDetailItem(
                                      icon: Icons.location_city,
                                      label: 'District',
                                      value: _landDetails!['district'] ?? 'N/A',
                                      iconSize: iconSizeSmall,
                                      fontSize: detailFontSize,
                                    ),
                                    _buildLandDetailItem(
                                      icon: Icons.landscape,
                                      label: 'Village',
                                      value: _landDetails!['village'] ?? 'N/A',
                                      iconSize: iconSizeSmall,
                                      fontSize: detailFontSize,
                                    ),
                                    _buildLandDetailItem(
                                      icon: Icons.agriculture,
                                      label: 'A/G Division',
                                      value: _landDetails!['agDivision'] ?? 'N/A',
                                      iconSize: iconSizeSmall,
                                      fontSize: detailFontSize,
                                    ),
                                  ],
                                ),
                                
                                // Land Photos
                                if (_landDetails!['landPhotos'] != null && (_landDetails!['landPhotos'] as List).isNotEmpty)
                                  Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      SizedBox(height: isSmallScreen ? 8 : 12),
                                      Text(
                                        'LAND PHOTOS',
                                        style: TextStyle(
                                          fontSize: isSmallScreen ? 10 : 12,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.secondaryText,
                                        ),
                                      ),
                                      SizedBox(height: isSmallScreen ? 6 : 8),
                                      SizedBox(
                                        height: landPhotoSize,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: (_landDetails!['landPhotos'] as List).length,
                                          itemBuilder: (context, index) {
                                            return Container(
                                              margin: EdgeInsets.only(right: isSmallScreen ? 6 : 8),
                                              width: landPhotoSize,
                                              height: landPhotoSize,
                                              decoration: BoxDecoration(
                                                borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
                                                border: Border.all(color: AppColors.border),
                                              ),
                                              child: ClipRRect(
                                                borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
                                                child: Image.network(
                                                  _landDetails!['landPhotos'][index],
                                                  fit: BoxFit.cover,
                                                  errorBuilder: (context, error, stackTrace) {
                                                    return Container(
                                                      color: AppColors.hover,
                                                      child: Column(
                                                        mainAxisAlignment: MainAxisAlignment.center,
                                                        children: [
                                                          Icon(
                                                            Icons.broken_image,
                                                            color: AppColors.textTertiary,
                                                            size: iconSizeSmall,
                                                          ),
                                                          SizedBox(height: 4),
                                                          Text(
                                                            'Failed',
                                                            style: TextStyle(
                                                              fontSize: isSmallScreen ? 8 : 10,
                                                              color: AppColors.textTertiary,
                                                            ),
                                                          ),
                                                        ],
                                                      ),
                                                    );
                                                  },
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                              ],
                            ),
                          ),
                        ],
                      ),

                    // Order Description
                    if (description.isNotEmpty)
                      Column(
                        children: [
                          SizedBox(height: paddingVertical),
                          Container(
                            padding: EdgeInsets.all(paddingAll),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ORDER DESCRIPTION',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 10 : 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondaryText,
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 6 : 8),
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: detailFontSize,
                                    color: AppColors.darkText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),

                    // Order Photos
                    if (orderPhotos.isNotEmpty)
                      Column(
                        children: [
                          SizedBox(height: paddingVertical),
                          Container(
                            padding: EdgeInsets.all(paddingAll),
                            decoration: BoxDecoration(
                              color: AppColors.cardBackground,
                              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'ORDER PHOTOS (${orderPhotos.length})',
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 10 : 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.secondaryText,
                                    letterSpacing: 1,
                                  ),
                                ),
                                SizedBox(height: isSmallScreen ? 8 : 12),
                                SizedBox(
                                  height: orderPhotoSize,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: orderPhotos.length,
                                    itemBuilder: (context, index) {
                                      return Container(
                                        margin: EdgeInsets.only(right: isSmallScreen ? 8 : 12),
                                        width: orderPhotoSize,
                                        height: orderPhotoSize,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                                          border: Border.all(color: AppColors.border),
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                                          child: Image.network(
                                            orderPhotos[index],
                                            fit: BoxFit.cover,
                                            errorBuilder: (context, error, stackTrace) {
                                              return Container(
                                                color: AppColors.hover,
                                                child: Column(
                                                  mainAxisAlignment: MainAxisAlignment.center,
                                                  children: [
                                                    Icon(
                                                      Icons.broken_image,
                                                      color: AppColors.textTertiary,
                                                      size: iconSizeMedium,
                                                    ),
                                                    SizedBox(height: 4),
                                                    Text(
                                                      'Failed to load',
                                                      style: TextStyle(
                                                        fontSize: isSmallScreen ? 8 : 10,
                                                        color: AppColors.textTertiary,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              );
                                            },
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
                      ),
                    
                    // Add bottom padding
                    SizedBox(height: paddingVertical * 2),
                  ],
                ),
              ),
            ),
          ),

          // Action Buttons
          Container(
            padding: EdgeInsets.all(paddingAll),
            decoration: BoxDecoration(
              border: Border(
                top: BorderSide(
                  color: AppColors.border,
                  width: 1,
                ),
              ),
            ),
            child: Row(
              children: [
                // Close Button
                Expanded(
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.secondaryText,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(
                        vertical: isSmallScreen ? 12 : 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                      ),
                    ),
                    child: Text(
                      'Close',
                      style: TextStyle(
                        fontSize: buttonFontSize,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
                
                if (canMarkAsReceived) SizedBox(width: isSmallScreen ? 8 : 12),
                
                // Mark as Received Button
                if (canMarkAsReceived)
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        widget.onStatusUpdate(widget.order['id']);
                        Navigator.of(context).pop();
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.successGreen,
                        foregroundColor: Colors.white,
                        padding: EdgeInsets.symmetric(
                          vertical: isSmallScreen ? 12 : 14,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                        ),
                      ),
                      child: Text(
                        isSmallScreen ? 'Mark Received' : 'Mark as Received',
                        style: TextStyle(
                          fontSize: buttonFontSize,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

Widget _buildOrderDetailRow(String title, String value, double screenWidth, {double fontSize = 14}) {
  final isSmallScreen = screenWidth < 360;
  
  return Container(
    padding: EdgeInsets.symmetric(vertical: isSmallScreen ? 6 : 8),
    decoration: BoxDecoration(
      border: Border(
        bottom: BorderSide(
          color: AppColors.border,
          width: 1,
        ),
      ),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            title,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w500,
              color: AppColors.secondaryText,
            ),
          ),
        ),
        SizedBox(width: isSmallScreen ? 12 : 16),
        Expanded(
          flex: 2,
          child: Text(
            value,
            style: TextStyle(
              fontSize: fontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
            textAlign: TextAlign.right,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    ),
  );
}

Widget _buildOwnerDetailItem({
  required IconData icon,
  required String label,
  required String value,
  required double iconSize,
  required double fontSize,
}) {
  return Row(
    children: [
      Container(
        padding: EdgeInsets.all(iconSize * 0.375), // 6 for 16px, 7.5 for 20px
        decoration: BoxDecoration(
          color: AppColors.primaryBlue.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: AppColors.primaryBlue,
        ),
      ),
      SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize * 0.833, // 10 for 12px, 11.67 for 14px
                color: AppColors.secondaryText,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ],
  );
}

Widget _buildLandDetailItem({
  required IconData icon,
  required String label,
  required String value,
  required double iconSize,
  required double fontSize,
}) {
  return Row(
    children: [
      Container(
        padding: EdgeInsets.all(iconSize * 0.375),
        decoration: BoxDecoration(
          color: AppColors.successGreen.withOpacity(0.1),
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(
          icon,
          size: iconSize,
          color: AppColors.successGreen,
        ),
      ),
      SizedBox(width: 8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: fontSize * 0.833,
                color: AppColors.secondaryText,
              ),
            ),
            Text(
              value,
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    ],
  );
}


  Color _getOrderStatusColor(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return AppColors.warningOrange;
      case 'factory recived':
      case 'received factory':
      case 'factory received':
        return AppColors.info;
      case 'delivered':
      case 'completed':
      case 'accepted':
        return AppColors.successGreen;
      case 'cancelled':
      case 'rejected':
        return AppColors.accentRed;
      default:
        return AppColors.primaryBlue;
    }
  }

  Color _getCropColorFromString(String cropType) {
    switch (cropType.toLowerCase()) {
      case 'tea':
        return AppColors.successGreen;
      case 'cinnamon':
        return AppColors.warningOrange;
      case 'both':
        return AppColors.accentTeal;
      default:
        return AppColors.primaryBlue;
    }
  }

  IconData _getOrderStatusIcon(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return Icons.pending_outlined;
      case 'factory recived':
      case 'received factory':
      case 'factory received':
        return Icons.factory_rounded;
      case 'delivered':
      case 'completed':
      case 'accepted':
        return Icons.check_circle_outline_rounded;
      case 'cancelled':
      case 'rejected':
        return Icons.cancel_outlined;
      default:
        return Icons.info_outline_rounded;
    }
  }
}