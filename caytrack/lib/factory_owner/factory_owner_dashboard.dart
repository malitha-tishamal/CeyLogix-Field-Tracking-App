// factory_owner_dashboard.dart - COMPLETE UPDATED VERSION WITH TEA & CINNAMON QUANTITIES
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'factory_owner_drawer.dart';
import 'land_details.dart';
import 'factory_owner_orders.dart'; // Import FactoryOrderDetailsModal from orders page

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

// -----------------------------------------------------------------------------
// --- MAIN SCREEN (FactoryOwnerDashboard) ---
// -----------------------------------------------------------------------------
class FactoryOwnerDashboard extends StatefulWidget {
  const FactoryOwnerDashboard({super.key});

  @override
  State<FactoryOwnerDashboard> createState() => _FactoryOwnerDashboardState();
}

class _FactoryOwnerDashboardState extends State<FactoryOwnerDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // State variables to hold fetched data
  String _loggedInUserName = 'Loading User...';
  String _factoryName = 'Loading Factory...';
  String _userRole = 'Factory Owner';
  String _factoryID = 'F-ID';
  String? _profileImageUrl;

  // State variables for associated lands
  List<Map<String, dynamic>> _allAssociatedLands = [];
  List<Map<String, dynamic>> _teaLands = [];
  List<Map<String, dynamic>> _cinnamonLands = [];
  List<Map<String, dynamic>> _multiCropLands = [];
  bool _isLoadingLands = true;
  String? _errorMessage;

  // State variables for orders statistics
  Map<String, dynamic> _ordersStatistics = {
    'totalOrders': 0,
    'totalQuantity': 0.0,
    'teaQuantity': 0.0,
    'cinnamonQuantity': 0.0,
    'pendingOrders': 0,
    'deliveredOrders': 0,
    'todayOrders': 0,
    'weekOrders': 0,
    'recentOrders': [],
  };
  bool _isLoadingOrders = true;

  @override
  void initState() {
    super.initState();
    _fetchHeaderData();
    _fetchAssociatedLands();
    _fetchOrdersStatistics();
  }

  // --- DATA FETCHING FUNCTION ---
  void _fetchHeaderData() async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    
    final String uid = user.uid;
    setState(() {
      _factoryID = uid.substring(0, 8); 
    });

    try {
      // 1. Fetch User Name and Role from 'users' collection
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner Name Missing';
          _userRole = userData?['role'] ?? 'Factory Owner';
          _profileImageUrl = userData?['profileImageUrl'];
        });
      }
      
      // 2. Fetch Factory Name from 'factories' collection
      final factoryDoc = await FirebaseFirestore.instance.collection('factories').doc(uid).get();
      if (factoryDoc.exists) {
        setState(() {
          _factoryName = factoryDoc.data()?['factoryName'] ?? 'Factory Name Missing';
        });
      }

    } catch (e) {
      debugPrint("Error fetching header data: $e");
      setState(() {
        _loggedInUserName = 'Data Error';
        _factoryName = 'Data Error';
      });
    }
  }

  // Fetch associated lands for this factory
  void _fetchAssociatedLands() async {
    final user = currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingLands = true;
      _errorMessage = null;
    });

    try {
      // Get all lands and filter those that have this factory in their factoryIds array
      final landsQuery = await _firestore.collection('lands').get();
      
      if (landsQuery.docs.isEmpty) {
        setState(() {
          _allAssociatedLands = [];
          _teaLands = [];
          _cinnamonLands = [];
          _multiCropLands = [];
          _isLoadingLands = false;
        });
        return;
      }

      List<Map<String, dynamic>> associatedLands = [];
      final factoryId = user.uid; // Current factory's ID

      for (var landDoc in landsQuery.docs) {
        final landData = landDoc.data() as Map<String, dynamic>;
        final factoryIds = List<String>.from(landData['factoryIds'] ?? []);
        
        // Check if this factory is in the land's factoryIds array
        if (factoryIds.contains(factoryId)) {
          // Fetch land owner details with ALL owner information
          String? ownerUid = landData['owner'] ?? landDoc.id;
          
          if (ownerUid != null && ownerUid.isNotEmpty) {
            try {
              final userDoc = await _firestore
                  .collection('users')
                  .doc(ownerUid)
                  .get();
              
              if (userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>;
                
                associatedLands.add({
                  'id': landDoc.id,
                  ...landData,
                  'ownerName': userData['name'] ?? 'Unknown Owner',
                  'ownerEmail': userData['email'] ?? '',
                  'ownerMobile': userData['mobile'] ?? '',
                  'ownerNic': userData['nic'] ?? '',
                  'ownerProfileImageUrl': userData['profileImageUrl'] ?? '',
                  'ownerRegistrationDate': userData['registrationDate'],
                  'ownerStatus': userData['status'] ?? 'N/A',
                });
              } else {
                // If user document doesn't exist
                associatedLands.add({
                  'id': landDoc.id,
                  ...landData,
                  'ownerName': 'Unknown Owner',
                  'ownerEmail': '',
                  'ownerMobile': '',
                  'ownerNic': '',
                  'ownerProfileImageUrl': '',
                  'ownerRegistrationDate': null,
                  'ownerStatus': 'N/A',
                });
              }
            } catch (e) {
              debugPrint("Error fetching owner info for $ownerUid: $e");
              associatedLands.add({
                'id': landDoc.id,
                ...landData,
                'ownerName': 'Error Loading Owner',
                'ownerEmail': '',
                'ownerMobile': '',
                'ownerNic': '',
                'ownerProfileImageUrl': '',
                'ownerRegistrationDate': null,
                'ownerStatus': 'N/A',
              });
            }
          } else {
            // If ownerUid is null or empty
            associatedLands.add({
              'id': landDoc.id,
              ...landData,
              'ownerName': 'Unknown Owner',
              'ownerEmail': '',
              'ownerMobile': '',
              'ownerNic': '',
              'ownerProfileImageUrl': '',
              'ownerRegistrationDate': null,
              'ownerStatus': 'N/A',
            });
          }
        }
      }

      _categorizeLands(associatedLands);
    } catch (e) {
      debugPrint("Error fetching associated lands: $e");
      setState(() {
        _errorMessage = "Failed to load land data";
        _isLoadingLands = false;
      });
    }
  }

  // Fetch orders statistics for this factory
  void _fetchOrdersStatistics() async {
    final user = currentUser;
    if (user == null) return;

    setState(() {
      _isLoadingOrders = true;
    });

    try {
      final factoryId = user.uid;
      
      // Query orders where factoryId matches current factory
      final ordersQuery = await _firestore
          .collection('land_orders')
          .where('factoryId', isEqualTo: factoryId)
          .get();

      final orders = ordersQuery.docs;
      
      double totalQuantity = 0.0;
      double teaQuantity = 0.0;
      double cinnamonQuantity = 0.0;
      int pendingOrders = 0;
      int deliveredOrders = 0;
      int todayOrders = 0;
      int weekOrders = 0;
      
      final now = DateTime.now();
      final todayStart = DateTime(now.year, now.month, now.day);
      final weekStart = now.subtract(const Duration(days: 7));
      
      final List<Map<String, dynamic>> recentOrders = [];

      for (var orderDoc in orders) {
        final orderData = orderDoc.data();
        final orderId = orderDoc.id;
        final status = (orderData['status'] ?? '').toString().toLowerCase();
        final cropType = orderData['cropType'] ?? '';
        final totalQty = _getQuantity(orderData['totalQuantity']);
        final teaQty = _getQuantity(orderData['teaQuantity']);
        final cinnamonQty = _getQuantity(orderData['cinnamonQuantity']);
        final orderDate = (orderData['orderDate'] as Timestamp?)?.toDate();
        final factoryName = orderData['factoryName'] ?? '';
        final landOwnerName = orderData['landOwnerName'] ?? '';
        final description = orderData['description'] ?? '';
        final unit = orderData['unit'] ?? 'kg';
        final orderPhotos = List<String>.from(orderData['orderPhotos'] ?? []);
        final createdAt = orderData['createdAt'];
        final updatedAt = orderData['updatedAt'];
        final landOwnerId = orderData['landOwnerId'] ?? '';

        totalQuantity += totalQty;
        
        if (cropType == 'Tea') {
          teaQuantity += teaQty > 0 ? teaQty : totalQty;
        } else if (cropType == 'Cinnamon') {
          cinnamonQuantity += cinnamonQty > 0 ? cinnamonQty : totalQty;
        } else if (cropType == 'Both') {
          teaQuantity += teaQty;
          cinnamonQuantity += cinnamonQty;
        }

        if (status == 'pending' || status.contains('pending')) {
          pendingOrders++;
        } else if (status.contains('delivered') || 
                   status.contains('completed') || 
                   status.contains('accepted') ||
                   status.contains('factory received') ||
                   status.contains('received factory')) {
          deliveredOrders++;
        }

        if (orderDate != null) {
          if (orderDate.isAfter(todayStart)) {
            todayOrders++;
          }
          if (orderDate.isAfter(weekStart)) {
            weekOrders++;
          }
        }

        // Add to recent orders (last 5 orders sorted by date)
        recentOrders.add({
          'id': orderId,
          'landOwnerName': landOwnerName,
          'factoryName': factoryName,
          'status': orderData['status'] ?? 'Pending',
          'cropType': cropType,
          'totalQuantity': totalQty,
          'teaQuantity': teaQty,
          'cinnamonQuantity': cinnamonQty,
          'unit': unit,
          'description': description,
          'orderDate': orderDate,
          'orderPhotos': orderPhotos,
          'createdAt': createdAt,
          'updatedAt': updatedAt,
          'landOwnerId': landOwnerId,
          'factoryId': factoryId,
        });
      }

      // Sort recent orders by date (newest first) and take latest 5
      recentOrders.sort((a, b) {
        final aDate = a['orderDate'] as DateTime? ?? DateTime(0);
        final bDate = b['orderDate'] as DateTime? ?? DateTime(0);
        return bDate.compareTo(aDate);
      });

      final latestOrders = recentOrders.take(5).toList();

      setState(() {
        _ordersStatistics = {
          'totalOrders': orders.length,
          'totalQuantity': totalQuantity,
          'teaQuantity': teaQuantity,
          'cinnamonQuantity': cinnamonQuantity,
          'pendingOrders': pendingOrders,
          'deliveredOrders': deliveredOrders,
          'todayOrders': todayOrders,
          'weekOrders': weekOrders,
          'recentOrders': latestOrders,
        };
        _isLoadingOrders = false;
      });
    } catch (e) {
      debugPrint("Error fetching orders statistics: $e");
      setState(() {
        _isLoadingOrders = false;
      });
    }
  }

  double _getQuantity(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Categorize lands by crop type and sort by association time
  void _categorizeLands(List<Map<String, dynamic>> lands) {
    // Sort lands by association time (newest first)
    // Use associationTimestamp if available, otherwise use createdAt or timestamp
    lands.sort((a, b) {
      Timestamp? aTime = a['associationTimestamp'] ?? a['createdAt'] ?? a['timestamp'];
      Timestamp? bTime = b['associationTimestamp'] ?? b['createdAt'] ?? b['timestamp'];
      
      if (aTime == null || bTime == null) {
        // If no timestamp, keep original order
        return 0;
      }
      return bTime.compareTo(aTime); // Newest first
    });

    List<Map<String, dynamic>> teaLands = [];
    List<Map<String, dynamic>> cinnamonLands = [];
    List<Map<String, dynamic>> multiLands = [];

    for (var land in lands) {
      final cropType = land['cropType'] ?? 'N/A';
      if (cropType == 'Tea') {
        teaLands.add(land);
      } else if (cropType == 'Cinnamon') {
        cinnamonLands.add(land);
      } else if (cropType == 'Both') {
        multiLands.add(land);
      }
    }

    setState(() {
      _allAssociatedLands = lands;
      _teaLands = teaLands;
      _cinnamonLands = cinnamonLands;
      _multiCropLands = multiLands;
      _isLoadingLands = false;
    });
  }

  // Show land details modal
  void _showLandDetailsModal(Map<String, dynamic> land) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FactoryOwnerLandDetailsModal(land: land),
    );
  }

  // Show order details modal using the COMPLETE FactoryOrderDetailsModal from factory_owner_orders.dart
  void _showOrderDetailsModal(Map<String, dynamic> order) {
    showDialog(
      context: context,
      builder: (context) => FactoryOrderDetailsModal(
        order: order,
        onStatusUpdate: (orderId) => _updateOrderStatus(orderId),
      ),
    );
  }

  // Update order status to "Factory Received"
  Future<void> _updateOrderStatus(String orderId) async {
    try {
      await _firestore.collection('land_orders').doc(orderId).update({
        'status': 'Factory Received',
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Refresh orders statistics
      _fetchOrdersStatistics();

      // Show success message
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Order status updated to "Factory Received"'),
            backgroundColor: AppColors.successGreen,
          ),
        );
      }
    } catch (e) {
      debugPrint("Error updating order status: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update order status: $e'),
            backgroundColor: AppColors.accentRed,
          ),
        );
      }
    }
  }

  // Navigate to LandDetailsPage with category lands
  void _navigateToCategoryDetails({
    required String categoryTitle,
    required List<Map<String, dynamic>> lands,
    required String categoryType,
    required IconData icon,
    required Color color,
  }) {
    if (lands.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No lands found in $categoryTitle category'),
          backgroundColor: AppColors.accentRed,
        ),
      );
      return;
    }

    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LandDetailsPage(
          currentUser: currentUser,
          categoryTitle: categoryTitle,
          lands: lands,
          categoryType: categoryType,
          icon: icon,
          color: color,
        ),
      ),
    );
  }

  // Navigate to all lands
  void _navigateToAllLands() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => LandDetailsPage(
          currentUser: currentUser,
          categoryTitle: 'All Associated Lands',
          lands: _allAssociatedLands,
          categoryType: 'All',
          icon: Icons.landscape,
          color: AppColors.primaryBlue,
        ),
      ),
    );
  }

  // Navigate to all orders page
  void _navigateToAllOrders() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FactoryOwnerOrdersPage(
          currentUser: currentUser,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    
    void handleDrawerNavigate(String routeName) {
      Navigator.pop(context);
    }
    
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      
      drawer: FactoryOwnerDrawer(
        onLogout: () {
          Navigator.pop(context);
        },
        onNavigate: handleDrawerNavigate,
      ),

      body: SafeArea(
        child: Column(
          children: [
            _buildDashboardHeader(context, screenWidth),
            
            Expanded(
              child: Column(
                children: [
                  Expanded(
                    child: SingleChildScrollView(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.04,
                        vertical: screenHeight * 0.02,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Received Orders Summary Section
                          _buildReceivedOrdersSummary(screenWidth, screenHeight),
                          SizedBox(height: screenHeight * 0.03),
                          
                          _buildSectionTitle('Associated Lands', Icons.landscape_rounded, screenWidth),
                          SizedBox(height: screenHeight * 0.01),
                          _buildAssociatedLandsSection(screenWidth, screenHeight),
                          SizedBox(height: screenHeight * 0.04),
                        ],
                      ),
                    ),
                  ),
                  
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.04,
                      vertical: screenHeight * 0.015,
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
          ],
        ),
      ),
    );
  }

  // -----------------------------------------------------------------
  // --- MODULARIZED WIDGETS (Header & Dashboard Content) ---
  // -----------------------------------------------------------------

  /// 🌟 HEADER - Custom Header Widget matching FactoryDetails style
  Widget _buildDashboardHeader(BuildContext context, double screenWidth) {
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
                      'Factory Name: $_factoryName\n($_userRole)',
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
            'Operational Overview (ID: $_factoryID)',
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

  // --- Received Orders Summary Section ---
  Widget _buildReceivedOrdersSummary(double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    final isLargeScreen = screenWidth >= 400;
    
    return Container(
      margin: EdgeInsets.only(bottom: screenHeight * 0.015),
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 
                   isMediumScreen ? 14 : 16,
        vertical: isSmallScreen ? 12 : 
                  isMediumScreen ? 14 : 16,
      ),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 14 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: isSmallScreen ? 8 : 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header Row
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 5 : 
                                isMediumScreen ? 6 : 7),
                      decoration: BoxDecoration(
                        color: AppColors.primaryBlue.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(isSmallScreen ? 7 : 8),
                      ),
                      child: Icon(
                        Icons.inventory_outlined,
                        color: AppColors.primaryBlue,
                        size: isSmallScreen ? 16 : 
                              isMediumScreen ? 18 : 20,
                      ),
                    ),
                    SizedBox(width: isSmallScreen ? 8 : 
                            isMediumScreen ? 10 : 12),
                    Flexible(
                      child: Text(
                        'Recent Received',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 13 : 
                                  isMediumScreen ? 14 : 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.darkText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(width: isSmallScreen ? 6 : 8),
              GestureDetector(
                onTap: _navigateToAllOrders,
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 8 : 
                              isMediumScreen ? 10 : 12,
                    vertical: isSmallScreen ? 3 : 
                              isMediumScreen ? 4 : 5,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isSmallScreen ? 16 : 20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'View All',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 9 : 
                                  isMediumScreen ? 10 : 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryBlue,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 2 : 
                              isMediumScreen ? 3 : 4),
                      Icon(
                        Icons.arrow_forward,
                        size: isSmallScreen ? 10 : 
                              isMediumScreen ? 12 : 14,
                        color: AppColors.primaryBlue,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          
          SizedBox(height: screenHeight * 0.012),
          
          // Content
          if (_isLoadingOrders)
            _buildOrdersLoading(screenWidth, screenHeight)
          else if (_ordersStatistics['totalOrders'] == 0)
            _buildNoOrdersCard(screenWidth, screenHeight)
          else
            _buildOrdersContent(screenWidth, screenHeight),
        ],
      ),
    );
  }

  Widget _buildOrdersContent(double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;

    return Column(
      children: [
        // Stats Row - Responsive layout
        _buildResponsiveStatsRow(screenWidth, screenHeight),

        SizedBox(
          height: isSmallScreen ? 4 : 
                  isMediumScreen ? 6 : 8,
        ),

        // Crop Breakdown with actual quantities
        if (_ordersStatistics['teaQuantity'] > 0 || _ordersStatistics['cinnamonQuantity'] > 0)
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 10 : 
                    isMediumScreen ? 11 : 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crop Breakdown',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 
                            isMediumScreen ? 12 : 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 6 : 
                        isMediumScreen ? 7 : 8),
                if (_ordersStatistics['teaQuantity'] > 0)
                  _buildCropQuantityItem(
                    label: 'Tea',
                    quantity: _ordersStatistics['teaQuantity'],
                    unit: 'kg',
                    color: AppColors.successGreen,
                    screenWidth: screenWidth,
                  ),
                if (_ordersStatistics['cinnamonQuantity'] > 0)
                  _buildCropQuantityItem(
                    label: 'Cinnamon',
                    quantity: _ordersStatistics['cinnamonQuantity'],
                    unit: 'kg',
                    color: AppColors.warningOrange,
                    screenWidth: screenWidth,
                  ),
                if (_ordersStatistics['teaQuantity'] > 0 && _ordersStatistics['cinnamonQuantity'] > 0)
                  Container(
                    margin: EdgeInsets.only(top: isSmallScreen ? 4 : 
                            isMediumScreen ? 5 : 6),
                    padding: EdgeInsets.all(isSmallScreen ? 6 : 
                            isMediumScreen ? 7 : 8),
                    decoration: BoxDecoration(
                      color: AppColors.primaryBlue.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Total Received:',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 
                                    isMediumScreen ? 11 : 12,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        Text(
                          '${(_ordersStatistics['teaQuantity'] + _ordersStatistics['cinnamonQuantity']).toStringAsFixed(1)} kg',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11 : 
                                    isMediumScreen ? 12 : 13,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryBlue,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),

        SizedBox(
          height: isSmallScreen ? 10 : 
                  isMediumScreen ? 12 : 15,
        ),

        // Recent Orders
        if (_ordersStatistics['recentOrders'].isNotEmpty) ...[
          Text(
            'Recent (Latest 5)',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 
                      isMediumScreen ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          SizedBox(
            height: isSmallScreen ? 6 : 
                    isMediumScreen ? 7 : 8,
          ),
          ..._ordersStatistics['recentOrders']
              .map((order) => _buildOrderPreviewItem(order, screenWidth, screenHeight))
              .toList(),
        ],
      ],
    );
  }

  Widget _buildCropQuantityItem({
    required String label,
    required double quantity,
    required String unit,
    required Color color,
    required double screenWidth,
  }) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    return Padding(
      padding: EdgeInsets.only(bottom: isSmallScreen ? 6 : 
              isMediumScreen ? 7 : 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              Icon(
                label == 'Tea' ? Icons.eco : Icons.forest,
                size: isSmallScreen ? 12 : 
                      isMediumScreen ? 14 : 16,
                color: color,
              ),
              SizedBox(width: isSmallScreen ? 4 : 
                      isMediumScreen ? 5 : 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: isSmallScreen ? 10 : 
                          isMediumScreen ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
          Text(
            '${quantity.toStringAsFixed(1)} $unit',
            style: TextStyle(
              fontSize: isSmallScreen ? 10 : 
                      isMediumScreen ? 11 : 12,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildResponsiveStatsRow(double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    final horizontalSpacing = isSmallScreen ? 6.0 : isMediumScreen ? 8.0 : 12.0;
    final verticalSpacing = isSmallScreen ? 6.0 : isMediumScreen ? 8.0 : 12.0;

    return Padding(
      padding: EdgeInsets.only(
        bottom: isSmallScreen ? 10 : isMediumScreen ? 12 : 16,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // --- Top Row ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Overall Orders",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
          ),
          // --- Top Row ---
          Row(
            children: [
              Expanded(
                child: _buildOrderStatCard(
                  title: 'Total Orders',
                  value: _ordersStatistics['totalOrders'].toString(),
                  icon: Icons.shopping_cart_checkout,
                  color: AppColors.primaryBlue,
                  screenWidth: screenWidth,
                ),
              ),
              SizedBox(width: horizontalSpacing),
              Expanded(
                child: _buildOrderStatCard(
                  title: 'Received Completed',
                  value: _ordersStatistics['deliveredOrders'].toString(),
                  icon: Icons.check_circle,
                  color: AppColors.successGreen,
                  screenWidth: screenWidth,
                ),
              ),
            ],
          ),

          SizedBox(height: verticalSpacing),

          // --- Centered Single Card Row ---
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                width: screenWidth / 3 - horizontalSpacing / 3,
                child: _buildOrderStatCard(
                  title: 'Pending',
                  value: _ordersStatistics['pendingOrders'].toString(),
                  icon: Icons.pending,
                  color: const Color.fromARGB(255, 255, 8, 0),
                  screenWidth: screenWidth,
                ),
              ),
            ],
          ),

          SizedBox(height: verticalSpacing),

          // --- Bottom Row ---
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0),
            child: Text(
              "Recent",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: _buildOrderStatCard(
                  title: 'Today Received',
                  value: _ordersStatistics['todayOrders'].toString(),
                  icon: Icons.today,
                  color: AppColors.accentTeal,
                  screenWidth: screenWidth,
                ),
              ),
              SizedBox(width: horizontalSpacing),
              Expanded(
                child: _buildOrderStatCard(
                  title: 'This Week',
                  value: _ordersStatistics['weekOrders'].toString(),
                  icon: Icons.calendar_today,
                  color: AppColors.purpleAccent,
                  screenWidth: screenWidth,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildOrderStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required double screenWidth,
  }) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;

    final cardWidth = isSmallScreen ? screenWidth * 0.42 : 
                    isMediumScreen ? screenWidth * 0.20 : screenWidth * 0.18;
    final cardHeight = isSmallScreen ? screenWidth * 0.18 : 
                     isMediumScreen ? screenWidth * 0.22 : screenWidth * 0.20;

    return Container(
      width: cardWidth,
      height: cardHeight,
      padding: EdgeInsets.fromLTRB(
        isSmallScreen ? 8 : isMediumScreen ? 10 : 8,
        isSmallScreen ? 8 : isMediumScreen ? 6 : 2,
        isSmallScreen ? 8 : isMediumScreen ? 10 : 12,
        isSmallScreen ? 12 : isMediumScreen ? 4 : 0,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 4 : isMediumScreen ? 5 : 6),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isSmallScreen ? 6 : 8),
            ),
            child: Icon(
              icon, 
              size: isSmallScreen ? 14 : isMediumScreen ? 16 : 18, 
              color: color
            ),
          ),
          SizedBox(height: isSmallScreen ? 4 : isMediumScreen ? 5 : 6),
          Text(
            value,
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : isMediumScreen ? 14 : 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(height: isSmallScreen ? 2 : isMediumScreen ? 3 : 4),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallScreen ? 7 : isMediumScreen ? 8 : 9,
              color: AppColors.secondaryText,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildOrderPreviewItem(Map<String, dynamic> order, double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    final landOwnerName = order['landOwnerName'] ?? 'Unknown Land Owner';
    final status = order['status'] ?? 'Pending';
    final totalQuantity = order['totalQuantity']?.toStringAsFixed(1) ?? '0';
    final cropType = order['cropType'] ?? 'N/A';
    final orderDate = order['orderDate'] as DateTime?;
    final unit = order['unit'] ?? 'kg';
    
    // Get tea and cinnamon quantities
    final teaQuantity = order['teaQuantity'] ?? 0;
    final cinnamonQuantity = order['cinnamonQuantity'] ?? 0;

    final statusColor = _getOrderStatusColor(status);
    
    return GestureDetector(
      onTap: () => _showOrderDetailsModal(order),
      child: Container(
        margin: EdgeInsets.only(bottom: isSmallScreen ? 6 : 
                isMediumScreen ? 7 : 8),
        padding: EdgeInsets.all(isSmallScreen ? 8 : 
                isMediumScreen ? 10 : 12),
        decoration: BoxDecoration(
          color: AppColors.hover,
          borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
          border: Border.all(color: AppColors.border),
        ),
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
                          size: isSmallScreen ? 12 : 
                                isMediumScreen ? 14 : 16,
                          color: statusColor,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 6 : 
                              isMediumScreen ? 8 : 12),
                      Expanded(
                        child: Text(
                          landOwnerName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11 : 
                                    isMediumScreen ? 12 : 14,
                            fontWeight: FontWeight.w600,
                            color: AppColors.darkText,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 6 : 
                              isMediumScreen ? 7 : 8,
                    vertical: isSmallScreen ? 2 : 
                              isMediumScreen ? 3 : 4,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                  ),
                  child: Text(
                    status.length > 8 && isSmallScreen 
                      ? status.substring(0, 8)
                      : status,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 7 : 
                              isMediumScreen ? 8 : 9,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: isSmallScreen ? 4 : 
                    isMediumScreen ? 5 : 6),
            
            // Crop type and quantities row
            Row(
              children: [
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 4 : 6,
                    vertical: isSmallScreen ? 1 : 2,
                  ),
                  decoration: BoxDecoration(
                    color: _getCropColorFromString(cropType).withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isSmallScreen ? 3 : 4),
                  ),
                  child: Text(
                    cropType.length > 6 && isSmallScreen 
                      ? cropType.substring(0, 6) 
                      : cropType,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 7 : 
                              isMediumScreen ? 8 : 9,
                      fontWeight: FontWeight.w600,
                      color: _getCropColorFromString(cropType),
                    ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 4 : 
                        isMediumScreen ? 5 : 6),
                
                // Tea quantity (if applicable)
                if ((cropType.toLowerCase() == 'tea' || cropType.toLowerCase() == 'both') && teaQuantity > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.eco,
                        size: isSmallScreen ? 8 : 10,
                        color: AppColors.successGreen,
                      ),
                      SizedBox(width: 2),
                      Text(
                        '$teaQuantity',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 9 : 
                                  isMediumScreen ? 10 : 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.successGreen,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 2 : 
                              isMediumScreen ? 3 : 4),
                    ],
                  ),
                
                // Cinnamon quantity (if applicable)
                if ((cropType.toLowerCase() == 'cinnamon' || cropType.toLowerCase() == 'both') && cinnamonQuantity > 0)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.forest,
                        size: isSmallScreen ? 8 : 10,
                        color: AppColors.warningOrange,
                      ),
                      SizedBox(width: 2),
                      Text(
                        '$cinnamonQuantity',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 9 : 
                                  isMediumScreen ? 10 : 11,
                          fontWeight: FontWeight.w600,
                          color: AppColors.warningOrange,
                        ),
                      ),
                    ],
                  ),
                
                Spacer(),
                
                // Total quantity
                Text(
                  '$totalQuantity $unit',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 9 : 
                            isMediumScreen ? 10 : 11,
                    color: AppColors.secondaryText,
                  ),
                ),
              ],
            ),
            
            // Date row
            if (orderDate != null)
              Padding(
                padding: EdgeInsets.only(top: isSmallScreen ? 2 : 
                        isMediumScreen ? 3 : 4),
                child: Text(
                  DateFormat('MMM dd, HH:mm').format(orderDate),
                  style: TextStyle(
                    fontSize: isSmallScreen ? 8 : 
                            isMediumScreen ? 9 : 10,
                    color: AppColors.textTertiary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrdersLoading(double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: screenHeight * (isSmallScreen ? 0.03 : 0.04),
      ),
      child: Column(
        children: [
          Center(
            child: CircularProgressIndicator(
              color: AppColors.primaryBlue,
              strokeWidth: isSmallScreen ? 1.5 : 2,
            ),
          ),
          SizedBox(height: screenHeight * (isSmallScreen ? 0.01 : 0.015)),
          Text(
            'Loading orders...',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 14,
              color: AppColors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoOrdersCard(double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    return Container(
      padding: EdgeInsets.symmetric(
        vertical: isSmallScreen ? 12 : 
                  isMediumScreen ? 14 : 16,
        horizontal: isSmallScreen ? 10 : 
                    isMediumScreen ? 12 : 14,
      ),
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: isSmallScreen ? 32 : 
                  isMediumScreen ? 36 : 40,
            color: AppColors.textTertiary.withOpacity(0.3),
          ),
          SizedBox(height: isSmallScreen ? 6 : 
                  isMediumScreen ? 8 : 10),
          Text(
            'No Orders Received',
            style: TextStyle(
              fontSize: isSmallScreen ? 12 : 
                      isMediumScreen ? 13 : 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          SizedBox(height: isSmallScreen ? 3 : 
                  isMediumScreen ? 4 : 5),
          Text(
            'Orders will appear here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 9 : 
                      isMediumScreen ? 10 : 11,
              color: AppColors.textTertiary,
            ),
          ),
        ],
      ),
    );
  }

  // --- Dashboard Content Widgets ---

  Widget _buildSectionTitle(String title, IconData icon, double screenWidth) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 5 : 
                    isMediumScreen ? 6 : 7),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(isSmallScreen ? 7 : 8),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryBlue,
              size: isSmallScreen ? 16 : 
                    isMediumScreen ? 18 : 20,
            ),
          ),
          SizedBox(width: isSmallScreen ? 6 : 
                  isMediumScreen ? 8 : 10),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 
                      isMediumScreen ? 16 : 18,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssociatedLandsSection(double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (_allAssociatedLands.isNotEmpty)
          Container(
            margin: EdgeInsets.only(bottom: screenHeight * 0.015),
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _buildLandStatCard(
                    title: 'Total Lands',
                    value: _allAssociatedLands.length.toString(),
                    icon: Icons.landscape,
                    color: AppColors.primaryBlue,
                    iconColor: Colors.white,
                    onTap: _navigateToAllLands,
                    screenWidth: screenWidth,
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  _buildLandStatCard(
                    title: 'Tea',
                    value: _teaLands.length.toString(),
                    icon: Icons.agriculture,
                    color: AppColors.successGreen,
                    iconColor: Colors.white,
                    onTap: () => _navigateToCategoryDetails(
                      categoryTitle: 'Tea Lands',
                      lands: _teaLands,
                      categoryType: 'Tea',
                      icon: Icons.agriculture,
                      color: AppColors.successGreen,
                    ),
                    screenWidth: screenWidth,
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  _buildLandStatCard(
                    title: 'Cinnamon',
                    value: _cinnamonLands.length.toString(),
                    icon: Icons.spa,
                    color: AppColors.warningOrange,
                    iconColor: Colors.white,
                    onTap: () => _navigateToCategoryDetails(
                      categoryTitle: 'Cinnamon Lands',
                      lands: _cinnamonLands,
                      categoryType: 'Cinnamon',
                      icon: Icons.spa,
                      color: AppColors.warningOrange,
                    ),
                    screenWidth: screenWidth,
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  _buildLandStatCard(
                    title: 'Multi-Crop',
                    value: _multiCropLands.length.toString(),
                    icon: Icons.all_inclusive,
                    color: AppColors.accentTeal,
                    iconColor: Colors.white,
                    onTap: () => _navigateToCategoryDetails(
                      categoryTitle: 'Multi-Crop Lands',
                      lands: _multiCropLands,
                      categoryType: 'Both',
                      icon: Icons.all_inclusive,
                      color: AppColors.accentTeal,
                    ),
                    screenWidth: screenWidth,
                  ),
                ],
              ),
            ),
          ),

        if (_isLoadingLands)
          _buildLoadingLands(screenWidth, screenHeight)
        else if (_errorMessage != null)
          _buildErrorLands(screenWidth)
        else if (_allAssociatedLands.isEmpty)
          _buildNoLandsCard(screenWidth)
        else
          _buildLandsByCategory(screenWidth, screenHeight),
      ],
    );
  }

  Widget _buildLandStatCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required Color iconColor,
    required VoidCallback onTap,
    required double screenWidth,
  }) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    final cardWidth = screenWidth * (isSmallScreen ? 0.22 : 
                     isMediumScreen ? 0.24 : 0.22);
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        padding: EdgeInsets.all(isSmallScreen ? 8 : 
                isMediumScreen ? 10 : 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.black, 0.1)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: isSmallScreen ? 6 : 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isSmallScreen ? 14 : 
                 isMediumScreen ? 16 : 18, color: iconColor),
            SizedBox(height: isSmallScreen ? 4 : 
                    isMediumScreen ? 5 : 6),
            Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 
                        isMediumScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: isSmallScreen ? 2 : 
                    isMediumScreen ? 3 : 4),
            Text(
              title,
              style: TextStyle(
                fontSize: isSmallScreen ? 9 : 
                        isMediumScreen ? 10 : 11,
                color: Colors.white.withOpacity(0.9),
              ),
              textAlign: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLandsByCategory(double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // View All Lands Button
        Container(
          margin: EdgeInsets.only(bottom: screenHeight * 0.02),
          child: ElevatedButton.icon(
            onPressed: _navigateToAllLands,
            icon: Icon(
              Icons.grid_view,
              size: isSmallScreen ? 14 : 
                    isMediumScreen ? 16 : 18,
            ),
            label: Text(
              'View All Associated Lands',
              style: TextStyle(
                fontSize: isSmallScreen ? 12 : 
                        isMediumScreen ? 13 : 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: isSmallScreen ? 10 : 
                        isMediumScreen ? 12 : 14,
              ),
            ),
          ),
        ),

        // Show only latest 5 associated lands from each category
        if (_cinnamonLands.isNotEmpty)
          _buildLandCategorySection(
            title: 'Cinnamon Lands',
            icon: Icons.spa,
            color: AppColors.warningOrange,
            lands: _cinnamonLands,
            totalLands: _cinnamonLands.length,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),
        if (_teaLands.isNotEmpty)
          _buildLandCategorySection(
            title: 'Tea Lands',
            icon: Icons.agriculture,
            color: AppColors.successGreen,
            lands: _teaLands,
            totalLands: _teaLands.length,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),
        if (_multiCropLands.isNotEmpty)
          _buildLandCategorySection(
            title: 'Multi-Crop Lands',
            icon: Icons.all_inclusive,
            color: AppColors.accentTeal,
            lands: _multiCropLands,
            totalLands: _multiCropLands.length,
            screenWidth: screenWidth,
            screenHeight: screenHeight,
          ),
      ],
    );
  }

  Widget _buildLandCategorySection({
    required String title,
    required IconData icon,
    required Color color,
    required List<Map<String, dynamic>> lands,
    required int totalLands,
    required double screenWidth,
    required double screenHeight,
  }) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    final latestLands = lands.length > 5 ? lands.sublist(0, 5) : lands;
    final hasMoreLands = lands.length > 5;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(height: screenHeight * 0.02),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 5 : 
                          isMediumScreen ? 6 : 7),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(isSmallScreen ? 7 : 8),
                  ),
                  child: Icon(
                    icon,
                    size: isSmallScreen ? 16 : 
                          isMediumScreen ? 18 : 20,
                    color: color,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 
                        isMediumScreen ? 10 : 12),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 
                            isMediumScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 8 : 
                          isMediumScreen ? 9 : 10,
                vertical: isSmallScreen ? 3 : 
                          isMediumScreen ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 15),
              ),
              child: Text(
                '$totalLands lands',
                style: TextStyle(
                  fontSize: isSmallScreen ? 10 : 
                          isMediumScreen ? 11 : 12,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: screenHeight * 0.01),
        Column(
          children: [
            // Display only latest 5 associated lands
            ...latestLands.asMap().entries.map((entry) {
              final index = entry.key;
              final land = entry.value;
              return _buildLandCard(
                land,
                index,
                color,
                screenWidth,
                screenHeight,
              );
            }).toList(),
            
            // Show "View All" button if there are more than 5 lands
            if (hasMoreLands)
              Container(
                margin: EdgeInsets.only(top: screenHeight * 0.01),
                child: TextButton.icon(
                  onPressed: () {
                    _navigateToCategoryDetails(
                      categoryTitle: title,
                      lands: lands,
                      categoryType: _getCategoryTypeFromTitle(title),
                      icon: icon,
                      color: color,
                    );
                  },
                  icon: Icon(
                    Icons.arrow_forward,
                    size: isSmallScreen ? 12 : 
                          isMediumScreen ? 14 : 16,
                    color: color,
                  ),
                  label: Text(
                    'View All ${lands.length} Lands',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 11 : 
                              isMediumScreen ? 12 : 14,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  String _getCategoryTypeFromTitle(String title) {
    if (title.contains('Tea')) return 'Tea';
    if (title.contains('Cinnamon')) return 'Cinnamon';
    if (title.contains('Multi')) return 'Both';
    return 'All';
  }

  Widget _buildLandCard(
    Map<String, dynamic> land,
    int index,
    Color categoryColor,
    double screenWidth,
    double screenHeight,
  ) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    final landName = land['landName'] ?? 'Unknown Land';
    final ownerName = land['ownerName'] ?? 'N/A';
    final cropType = land['cropType'] ?? 'N/A';
    final landSize = land['landSize'] ?? 'N/A';
    final landSizeUnit = land['landSizeUnit'] ?? 'ha';
    final address = land['address'] ?? 'N/A';
    final district = land['district'] ?? 'N/A';

    final mainColor = categoryColor;
    final icon = _getCropIcon(cropType);

    return GestureDetector(
      onTap: () {
        _showLandDetailsModal(land);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: screenHeight * 0.012),
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
              border: Border.all(color: mainColor.withOpacity(0.1)),
            ),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 
                      isMediumScreen ? 14 : 16),
              child: Row(
                children: [
                  Container(
                    width: isSmallScreen ? 40 : 
                          isMediumScreen ? 45 : 50,
                    height: isSmallScreen ? 40 : 
                          isMediumScreen ? 45 : 50,
                    decoration: BoxDecoration(
                      color: mainColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 14 : 
                                  isMediumScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: mainColor,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 10 : 
                          isMediumScreen ? 11 : 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Text(
                                landName,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 
                                          isMediumScreen ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 6 : 
                                          isMediumScreen ? 7 : 8,
                                vertical: isSmallScreen ? 1 : 
                                          isMediumScreen ? 1 : 2,
                              ),
                              decoration: BoxDecoration(
                                color: mainColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 15),
                                border: Border.all(color: mainColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                cropType,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 9 : 
                                          isMediumScreen ? 10 : 11,
                                  fontWeight: FontWeight.w600,
                                  color: mainColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: screenHeight * 0.004),
                        Text(
                          'Owner: $ownerName',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 11 : 
                                    isMediumScreen ? 12 : 13,
                            color: AppColors.secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: screenHeight * 0.004),
                        Row(
                          children: [
                            Icon(
                              Icons.square_foot,
                              size: isSmallScreen ? 12 : 
                                    isMediumScreen ? 13 : 14,
                              color: mainColor,
                            ),
                            SizedBox(width: isSmallScreen ? 3 : 
                                    isMediumScreen ? 3 : 4),
                            Text(
                              '$landSize $landSizeUnit',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11 : 
                                        isMediumScreen ? 12 : 13,
                                color: AppColors.darkText,
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 8 : 
                                    isMediumScreen ? 10 : 12),
                            Icon(
                              Icons.location_on,
                              size: isSmallScreen ? 12 : 
                                    isMediumScreen ? 13 : 14,
                              color: mainColor,
                            ),
                            SizedBox(width: isSmallScreen ? 3 : 
                                    isMediumScreen ? 3 : 4),
                            Expanded(
                              child: Text(
                                district,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 11 : 
                                          isMediumScreen ? 12 : 13,
                                  color: AppColors.darkText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
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
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingLands(double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.08),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
      ),
      child: Column(
        children: [
          CircularProgressIndicator(color: AppColors.primaryBlue),
          SizedBox(height: screenHeight * 0.02),
          Text(
            'Loading land data...',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              color: AppColors.darkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorLands(double screenWidth) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
        border: Border.all(color: AppColors.accentRed.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: screenWidth * (isSmallScreen ? 0.08 : 
                 isMediumScreen ? 0.09 : 0.1),
            color: AppColors.accentRed,
          ),
          SizedBox(height: screenWidth * 0.03),
          Text(
            _errorMessage ?? 'Unable to load land data',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 
                      isMediumScreen ? 15 : 16,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          SizedBox(height: screenWidth * 0.02),
          ElevatedButton.icon(
            onPressed: _fetchAssociatedLands,
            icon: Icon(Icons.refresh, size: screenWidth * 0.04),
            label: Text(
              'Retry',
              style: TextStyle(fontSize: screenWidth * 0.035),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: screenWidth * 0.025,
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLandsCard(double screenWidth) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.06),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.landscape,
            size: screenWidth * (isSmallScreen ? 0.12 : 
                 isMediumScreen ? 0.13 : 0.14),
            color: AppColors.primaryBlue,
          ),
          SizedBox(height: screenWidth * 0.04),
          Text(
            'No Associated Lands',
            style: TextStyle(
              fontSize: isSmallScreen ? 15 : 
                      isMediumScreen ? 16 : 17,
              fontWeight: FontWeight.w700,
              color: AppColors.darkText,
            ),
          ),
          SizedBox(height: screenWidth * 0.02),
          Text(
            'You are not currently associated with any lands. Lands will appear here once they add your factory.',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.secondaryText,
              fontSize: isSmallScreen ? 12 : 
                      isMediumScreen ? 13 : 14,
            ),
          ),
        ],
      ),
    );
  }

  // Helper method to get crop icon
  IconData _getCropIcon(String cropType) {
    switch (cropType) {
      case 'Cinnamon':
        return Icons.spa;
      case 'Tea':
        return Icons.agriculture;
      case 'Both':
        return Icons.all_inclusive;
      default:
        return Icons.landscape;
    }
  }

  // Helper functions for order status
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
}

// Factory Owner Land Details Modal (Keep this if you need it for land details)
class FactoryOwnerLandDetailsModal extends StatelessWidget {
  final Map<String, dynamic> land;

  const FactoryOwnerLandDetailsModal({super.key, required this.land});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    
    // Extract land details
    final landName = land['landName'] ?? 'Unknown Land';
    final ownerName = land['ownerName'] ?? 'Unknown Owner';
    final cropType = land['cropType'] ?? 'N/A';
    final landSize = land['landSize'] ?? 'N/A';
    final landSizeUnit = land['landSizeUnit'] ?? 'ha';
    final address = land['address'] ?? 'N/A';
    final district = land['district'] ?? 'N/A';
    final village = land['village'] ?? 'N/A';
    final agDivision = land['agDivision'] ?? 'N/A';
    final landPhotos = List<String>.from(land['landPhotos'] ?? []);
    final ownerMobile = land['ownerMobile'] ?? 'N/A';
    final ownerEmail = land['ownerEmail'] ?? 'N/A';
    final ownerNic = land['ownerNic'] ?? 'N/A';
    final ownerProfileImageUrl = land['ownerProfileImageUrl'];

    final cropColor = _getCropColorFromString(cropType);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(20),
          topRight: Radius.circular(20),
        ),
      ),
      constraints: BoxConstraints(
        maxHeight: screenHeight * 0.9,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.all(screenWidth * 0.05),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      'Land Details',
                      style: TextStyle(
                        fontSize: screenWidth * 0.06,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close, size: screenWidth * 0.06),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),

              SizedBox(height: screenHeight * 0.02),

              // Land Name
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.04,
                  vertical: screenHeight * 0.015,
                ),
                decoration: BoxDecoration(
                  color: cropColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: cropColor.withOpacity(0.3)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.landscape,
                      color: cropColor,
                      size: screenWidth * 0.06,
                    ),
                    SizedBox(width: screenWidth * 0.03),
                    Expanded(
                      child: Text(
                        landName,
                        style: TextStyle(
                          fontSize: screenWidth * 0.055,
                          fontWeight: FontWeight.bold,
                          color: cropColor,
                        ),
                      ),
                    ),
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: screenWidth * 0.04,
                        vertical: screenHeight * 0.008,
                      ),
                      decoration: BoxDecoration(
                        color: cropColor,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        cropType,
                        style: TextStyle(
                          fontSize: screenWidth * 0.04,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              SizedBox(height: screenHeight * 0.02),

              // Owner Details
              _buildOwnerDetailsSection(screenWidth, screenHeight),

              SizedBox(height: screenHeight * 0.02),

              // Land Details
              _buildLandDetailsSection(screenWidth, screenHeight),

              SizedBox(height: screenHeight * 0.02),

              // Land Photos
              if (landPhotos.isNotEmpty)
                _buildLandPhotosSection(screenWidth, screenHeight, landPhotos),

              SizedBox(height: screenHeight * 0.02),

              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Close',
                    style: TextStyle(fontSize: screenWidth * 0.045),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primaryBlue,
                    foregroundColor: Colors.white,
                    padding: EdgeInsets.symmetric(
                      vertical: screenHeight * 0.02,
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
      ),
    );
  }

  Widget _buildOwnerDetailsSection(double screenWidth, double screenHeight) {
    final ownerName = land['ownerName'] ?? 'Unknown Owner';
    final ownerMobile = land['ownerMobile'] ?? 'N/A';
    final ownerEmail = land['ownerEmail'] ?? 'N/A';
    final ownerNic = land['ownerNic'] ?? 'N/A';
    final ownerProfileImageUrl = land['ownerProfileImageUrl'];

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.person_outline,
                color: AppColors.primaryBlue,
                size: screenWidth * 0.055,
              ),
              SizedBox(width: screenWidth * 0.03),
              Text(
                'LAND OWNER',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.015),
          Row(
            children: [
              CircleAvatar(
                radius: screenWidth * 0.06,
                backgroundImage: ownerProfileImageUrl != null && ownerProfileImageUrl.isNotEmpty
                    ? NetworkImage(ownerProfileImageUrl)
                    : null,
                backgroundColor: AppColors.primaryBlue.withOpacity(0.1),
                child: ownerProfileImageUrl == null || ownerProfileImageUrl.isEmpty
                    ? Icon(
                        Icons.person,
                        color: AppColors.primaryBlue,
                        size: screenWidth * 0.06,
                      )
                    : null,
              ),
              SizedBox(width: screenWidth * 0.04),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      ownerName,
                      style: TextStyle(
                        fontSize: screenWidth * 0.045,
                        fontWeight: FontWeight.bold,
                        color: AppColors.darkText,
                      ),
                    ),
                    SizedBox(height: screenHeight * 0.005),
                    if (ownerMobile != 'N/A')
                      Text(
                        '📱 $ownerMobile',
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: AppColors.secondaryText,
                        ),
                      ),
                    if (ownerEmail != 'N/A')
                      Text(
                        '📧 $ownerEmail',
                        style: TextStyle(
                          fontSize: screenWidth * 0.035,
                          color: AppColors.secondaryText,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          if (ownerNic != 'N/A')
            Padding(
              padding: EdgeInsets.only(top: screenHeight * 0.01),
              child: Text(
                'NIC: $ownerNic',
                style: TextStyle(
                  fontSize: screenWidth * 0.035,
                  color: AppColors.secondaryText,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildLandDetailsSection(double screenWidth, double screenHeight) {
    final landSize = land['landSize'] ?? 'N/A';
    final landSizeUnit = land['landSizeUnit'] ?? 'ha';
    final address = land['address'] ?? 'N/A';
    final district = land['district'] ?? 'N/A';
    final village = land['village'] ?? 'N/A';
    final agDivision = land['agDivision'] ?? 'N/A';

    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.info_outline,
                color: AppColors.successGreen,
                size: screenWidth * 0.055,
              ),
              SizedBox(width: screenWidth * 0.03),
              Text(
                'LAND INFORMATION',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.015),
          _buildLandDetailItem(
            icon: Icons.square_foot,
            label: 'Land Size',
            value: '$landSize $landSizeUnit',
            screenWidth: screenWidth,
          ),
          _buildLandDetailItem(
            icon: Icons.location_on,
            label: 'Address',
            value: address,
            screenWidth: screenWidth,
          ),
          _buildLandDetailItem(
            icon: Icons.location_city,
            label: 'District',
            value: district,
            screenWidth: screenWidth,
          ),
          _buildLandDetailItem(
            icon: Icons.house,
            label: 'Village',
            value: village,
            screenWidth: screenWidth,
          ),
          _buildLandDetailItem(
            icon: Icons.agriculture,
            label: 'A/G Division',
            value: agDivision,
            screenWidth: screenWidth,
          ),
        ],
      ),
    );
  }

  Widget _buildLandDetailItem({
    required IconData icon,
    required String label,
    required String value,
    required double screenWidth,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.015),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(screenWidth * 0.025),
            decoration: BoxDecoration(
              color: AppColors.successGreen.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, size: screenWidth * 0.045, color: AppColors.successGreen),
          ),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: screenWidth * 0.035,
                    color: AppColors.secondaryText,
                  ),
                ),
                SizedBox(height: 2),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: screenWidth * 0.04,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLandPhotosSection(double screenWidth, double screenHeight, List<String> landPhotos) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.04),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(15),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.photo_camera_back,
                color: AppColors.purpleAccent,
                size: screenWidth * 0.055,
              ),
              SizedBox(width: screenWidth * 0.03),
              Text(
                'LAND PHOTOS (${landPhotos.length})',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  fontWeight: FontWeight.w600,
                  color: AppColors.secondaryText,
                  letterSpacing: 1,
                ),
              ),
            ],
          ),
          SizedBox(height: screenHeight * 0.015),
          SizedBox(
            height: screenHeight * 0.2,
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              itemCount: landPhotos.length,
              itemBuilder: (context, index) {
                return Container(
                  margin: EdgeInsets.only(right: screenWidth * 0.03),
                  width: screenWidth * 0.35,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(10),
                    image: DecorationImage(
                      image: NetworkImage(landPhotos[index]),
                      fit: BoxFit.cover,
                    ),
                  ),
                );
              },
            ),
          ),
        ],
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
}