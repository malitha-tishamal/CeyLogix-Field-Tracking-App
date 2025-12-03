import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'factory_owner_drawer.dart'; // Import the external drawer

// Reusing AppColors
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
  
  // Custom colors based on the image's gradient header
  static const Color headerGradientStart = Color(0xFF869AEC);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);  
  static const Color headerTextDark = Color(0xFF333333);
}

class LandDetailsPage extends StatefulWidget {
  final User? currentUser;
  final String? categoryTitle;
  final List<Map<String, dynamic>>? lands;
  final String? categoryType;
  final IconData? icon;
  final Color? color;
  
  const LandDetailsPage({
    super.key,
    required this.currentUser,
    this.categoryTitle,
    this.lands,
    this.categoryType,
    this.icon,
    this.color,
  });

  @override
  State<LandDetailsPage> createState() => _LandDetailsPageState();
}

class _LandDetailsPageState extends State<LandDetailsPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // State variables to hold fetched data
  String _loggedInUserName = 'Loading...';
  String _factoryName = 'Loading...';
  String _userRole = 'Factory Owner';
  String? _profileImageUrl;

  // State variables for all associated lands
  List<Map<String, dynamic>> _allAssociatedLands = [];
  List<Map<String, dynamic>> _teaLands = [];
  List<Map<String, dynamic>> _cinnamonLands = [];
  List<Map<String, dynamic>> _multiCropLands = [];
  List<Map<String, dynamic>> _filteredLands = [];
  bool _isLoadingLands = true;
  String? _errorMessage;

  // Filter states
  String? _selectedCropType;
  String? _selectedProvince;
  String? _selectedDistrict;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  bool _showFilters = false;

  // Province and District data
  final Map<String, List<String>> _provinceDistricts = {
    'Western Province': ['Colombo District', 'Gampaha District', 'Kalutara District'],
    'Central Province': ['Kandy District', 'Matale District', 'Nuwara Eliya District'],
    'Southern Province': ['Galle District', 'Matara District', 'Hambantota District'],
    'Eastern Province': ['Trincomalee District', 'Batticaloa District', 'Ampara District'],
    'Northern Province': ['Jaffna District', 'Vavuniya District', 'Kilinochchi District', 'Mannar District', 'Mullaitivu District'],
    'North Western Province': ['Kurunegala District', 'Puttalam District'],
    'North Central Province': ['Anuradhapura District', 'Polonnaruwa District'],
    'Uva Province': ['Badulla District', 'Monaragala District'],
    'Sabaragamuwa Province': ['Ratnapura District', 'Kegalle District'],
  };

  // Check if this is a category-specific view
  bool get _isCategoryView => widget.lands != null;

  @override
  void initState() {
    super.initState();
    _fetchHeaderData();
    
    if (_isCategoryView) {
      _loadCategoryLands();
    } else {
      _fetchAllAssociatedLands();
    }
    
    _searchController.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadCategoryLands() {
    final lands = widget.lands ?? [];
    if (lands.isEmpty) {
      setState(() {
        _allAssociatedLands = [];
        _filteredLands = [];
        _isLoadingLands = false;
      });
      return;
    }

    _categorizeLands(lands);
  }

  void _fetchHeaderData() async {
    final user = widget.currentUser;
    if (user == null) {
      return;
    }

    final String uid = user.uid;

    try {
      // Fetch User Name and Role from 'users' collection
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner Name Missing';
          _userRole = userData?['role'] ?? 'Factory Owner';
          _profileImageUrl = userData?['profileImageUrl'];
        });
      }
      
      // Fetch Factory Name from 'factories' collection
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

  void _fetchAllAssociatedLands() async {
    final user = widget.currentUser;
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
          _filteredLands = [];
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

  void _categorizeLands(List<Map<String, dynamic>> lands) {
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
      _filteredLands = List.from(lands);
      _teaLands = teaLands;
      _cinnamonLands = cinnamonLands;
      _multiCropLands = multiLands;
      _isLoadingLands = false;
    });
  }

  void _onSearchChanged() {
    if (_searchController.text.isEmpty) {
      setState(() {
        _isSearching = false;
        _applyFilters();
      });
    } else {
      setState(() {
        _isSearching = true;
        _applyFilters();
      });
    }
  }

  void _applyFilters() {
    List<Map<String, dynamic>> filtered = List.from(_allAssociatedLands);

    // Apply search filter
    if (_searchController.text.isNotEmpty) {
      final searchLower = _searchController.text.toLowerCase();
      filtered = filtered.where((land) {
        final landName = land['landName']?.toString().toLowerCase() ?? '';
        final ownerName = land['ownerName']?.toString().toLowerCase() ?? '';
        final district = land['district']?.toString().toLowerCase() ?? '';
        return landName.contains(searchLower) ||
               ownerName.contains(searchLower) ||
               district.contains(searchLower);
      }).toList();
    }

    // Apply crop type filter
    if (_selectedCropType != null && _selectedCropType != 'All') {
      filtered = filtered.where((land) {
        final cropType = land['cropType'] ?? 'N/A';
        return cropType == _selectedCropType;
      }).toList();
    }

    // Apply province filter
    if (_selectedProvince != null) {
      final districtsInProvince = _provinceDistricts[_selectedProvince] ?? [];
      filtered = filtered.where((land) {
        final district = land['district'] ?? '';
        return districtsInProvince.any((d) => district.contains(d.replaceAll(' District', '')));
      }).toList();
    }

    // Apply district filter
    if (_selectedDistrict != null) {
      filtered = filtered.where((land) {
        final district = land['district'] ?? '';
        return district.contains(_selectedDistrict!.replaceAll(' District', ''));
      }).toList();
    }

    setState(() {
      _filteredLands = filtered;
    });
  }

  void _clearFilters() {
    setState(() {
      _selectedCropType = null;
      _selectedProvince = null;
      _selectedDistrict = null;
      _searchController.clear();
      _showFilters = false;
      _filteredLands = List.from(_allAssociatedLands);
    });
  }

  void _showLandDetailsModal(Map<String, dynamic> land) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => FactoryOwnerLandDetailsModal(land: land),
    );
  }

  void _handleDrawerNavigate(String routeName) {
    Navigator.pop(context); // Close drawer
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    
    if (widget.currentUser == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "Error: User not logged in.",
            style: TextStyle(fontSize: screenWidth * 0.04),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      // Link the external drawer exactly like in UserDetails page
      drawer: FactoryOwnerDrawer(
        onLogout: () {
          FirebaseAuth.instance.signOut();
          Navigator.pop(context);
        },
        onNavigate: _handleDrawerNavigate,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Header
            _buildDashboardHeader(context, screenWidth, screenHeight),
            
            // Main Content with Footer
            Expanded(
              child: Column(
                children: [
                  // Filters Section
                  _buildFilterSection(screenWidth, screenHeight, isSmallScreen),
                  
                  // Lands List or Loading/Error States with Scrollable Content
                  Expanded(
                    child: SingleChildScrollView(
                      child: _buildContent(screenWidth, screenHeight, isSmallScreen),
                    ),
                  ),
                  
                  // Footer (Fixed at bottom of content area)
                  Container(
                    padding: EdgeInsets.all(screenWidth * 0.04),
                    child: Text(
                      'Developed by Malitha Tishamal',
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

  Widget _buildDashboardHeader(BuildContext context, double screenWidth, double screenHeight) {
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (isSmallScreen ? 8 : 10),
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
        bottom: isSmallScreen ? 16 : 20,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
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
                  size: isSmallScreen ? 24 : 28,
                ),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ],
          ),
          
          SizedBox(height: screenHeight * 0.01),
          
          Row(
            children: [
              // Profile Picture with Firebase image
              Container(
                width: isSmallScreen ? 60 : 70,
                height: isSmallScreen ? 60 : 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _profileImageUrl == null 
                    ? const LinearGradient(
                        colors: [AppColors.primaryBlue, Color(0xFF457AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                  border: Border.all(
                    color: Colors.white,
                    width: isSmallScreen ? 2.5 : 3.0,
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.4),
                      blurRadius: 10.0,
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
                        size: isSmallScreen ? 32 : 40,
                        color: Colors.white,
                      )
                    : null,
              ),
              
              SizedBox(width: screenWidth * 0.04),
              
              // User Info Display from Firebase
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loggedInUserName, 
                      style: TextStyle(
                        fontSize: isSmallScreen ? 18 : 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headerTextDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenHeight * 0.004),
                    Text(
                      'Factory Name: $_factoryName \n($_userRole)',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12 : 14,
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
          
          SizedBox(height: screenHeight * 0.02),
          
          // Page Title
          Text(
            _isCategoryView ? (widget.categoryTitle ?? 'Land Details') : 'All Associated Lands',
            style: TextStyle(
              fontSize: isSmallScreen ? 14 : 16,
              fontWeight: FontWeight.w600,
              color: AppColors.headerTextDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection(double screenWidth, double screenHeight, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
      margin: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12 : 16,
        vertical: isSmallScreen ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(isSmallScreen ? 12 : 16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        children: [
          // Search Bar
          Container(
            padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 10 : 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.search,
                  color: AppColors.primaryBlue,
                  size: isSmallScreen ? 18 : 20,
                ),
                SizedBox(width: screenWidth * 0.02),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: InputDecoration(
                      hintText: 'Search lands, owners, districts...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: AppColors.secondaryText,
                        fontSize: isSmallScreen ? 13 : 14,
                      ),
                    ),
                    style: TextStyle(
                      color: AppColors.darkText,
                      fontSize: isSmallScreen ? 13 : 14,
                    ),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.clear,
                      size: isSmallScreen ? 18 : 20,
                    ),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
              ],
            ),
          ),
          
          SizedBox(height: screenHeight * 0.012),
          
          // Filter Toggle Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14 : 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              IconButton(
                icon: Icon(
                  _showFilters ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.primaryBlue,
                  size: isSmallScreen ? 20 : 24,
                ),
                onPressed: () {
                  setState(() {
                    _showFilters = !_showFilters;
                  });
                },
              ),
            ],
          ),
          
          // Filters (Collapsible)
          if (_showFilters) ...[
            SizedBox(height: screenHeight * 0.012),
            
            // Crop Type Filter
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crop Type',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkText,
                  ),
                ),
                SizedBox(height: screenHeight * 0.008),
                Wrap(
                  spacing: isSmallScreen ? 6 : 8,
                  runSpacing: isSmallScreen ? 6 : 8,
                  children: [
                    _buildFilterChip('All', _selectedCropType == null || _selectedCropType == 'All', 
                      () {
                        setState(() {
                          _selectedCropType = 'All';
                          _applyFilters();
                        });
                      }, isSmallScreen),
                    _buildFilterChip('Tea', _selectedCropType == 'Tea', 
                      () {
                        setState(() {
                          _selectedCropType = 'Tea';
                          _applyFilters();
                        });
                      }, isSmallScreen, AppColors.successGreen),
                    _buildFilterChip('Cinnamon', _selectedCropType == 'Cinnamon', 
                      () {
                        setState(() {
                          _selectedCropType = 'Cinnamon';
                          _applyFilters();
                        });
                      }, isSmallScreen, AppColors.warningOrange),
                    _buildFilterChip('Both', _selectedCropType == 'Both', 
                      () {
                        setState(() {
                          _selectedCropType = 'Both';
                          _applyFilters();
                        });
                      }, isSmallScreen, AppColors.accentTeal),
                  ],
                ),
              ],
            ),
            
            SizedBox(height: screenHeight * 0.016),
            
            // Province Filter
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Province',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkText,
                  ),
                ),
                SizedBox(height: screenHeight * 0.008),
                DropdownButtonFormField<String>(
                  value: _selectedProvince,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: isSmallScreen ? 10 : 12,
                    ),
                  ),
                  items: [
                    DropdownMenuItem(
                      value: null,
                      child: Text(
                        'All Provinces',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 13 : 14,
                        ),
                      ),
                    ),
                    ..._provinceDistricts.keys.map((province) {
                      return DropdownMenuItem(
                        value: province,
                        child: Text(
                          province,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                  onChanged: (value) {
                    setState(() {
                      _selectedProvince = value;
                      _selectedDistrict = null; // Reset district when province changes
                      _applyFilters();
                    });
                  },
                ),
              ],
            ),
            
            SizedBox(height: screenHeight * 0.016),
            
            // District Filter
            if (_selectedProvince != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'District',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 13 : 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.darkText,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.008),
                  DropdownButtonFormField<String>(
                    value: _selectedDistrict,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: isSmallScreen ? 12 : 16,
                        vertical: isSmallScreen ? 10 : 12,
                      ),
                    ),
                    items: [
                      DropdownMenuItem(
                        value: null,
                        child: Text(
                          'All Districts',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13 : 14,
                          ),
                        ),
                      ),
                      ...(_provinceDistricts[_selectedProvince] ?? []).map((district) {
                        return DropdownMenuItem(
                          value: district,
                          child: Text(
                            district,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 13 : 14,
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                    onChanged: (value) {
                      setState(() {
                        _selectedDistrict = value;
                        _applyFilters();
                      });
                    },
                  ),
                ],
              ),
            
            SizedBox(height: screenHeight * 0.016),
            
            // Clear Filters Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: Icon(
                    Icons.clear_all,
                    size: isSmallScreen ? 14 : 16,
                  ),
                  label: Text(
                    'Clear Filters',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 13 : 14,
                    ),
                  ),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    side: BorderSide(color: AppColors.accentRed.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                    ),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 12 : 16,
                      vertical: isSmallScreen ? 8 : 10,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap, bool isSmallScreen, [Color? color]) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : (color ?? AppColors.primaryBlue),
          fontWeight: FontWeight.w500,
          fontSize: isSmallScreen ? 12 : 13,
        ),
      ),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.white,
      selectedColor: color ?? AppColors.primaryBlue,
      checkmarkColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: selected ? (color ?? AppColors.primaryBlue) : AppColors.primaryBlue.withOpacity(0.3),
          width: 1,
        ),
      ),
    );
  }

  Widget _buildLandCard(Map<String, dynamic> land, Color color, int index, double screenWidth, bool isSmallScreen) {
    final landName = land['landName'] ?? 'Unknown Land';
    final ownerName = land['ownerName'] ?? 'N/A';
    final cropType = land['cropType'] ?? 'N/A';
    final landSize = land['landSize'] ?? 'N/A';
    final landSizeUnit = land['landSizeUnit'] ?? 'ha';
    final district = land['district'] ?? 'N/A';

    return GestureDetector(
      onTap: () {
        _showLandDetailsModal(land);
      },
      child: Container(
        margin: EdgeInsets.only(bottom: screenWidth * 0.03),
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Row(
                children: [
                  Container(
                    width: isSmallScreen ? 40 : 50,
                    height: isSmallScreen ? 40 : 50,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 8 : 10),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(width: isSmallScreen ? 10 : 12),
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
                                  fontSize: isSmallScreen ? 14 : 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkText,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: isSmallScreen ? 6 : 8,
                                vertical: isSmallScreen ? 1 : 2,
                              ),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: color.withOpacity(0.3)),
                              ),
                              child: Text(
                                cropType,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 10 : 11,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        SizedBox(height: screenWidth * 0.008),
                        Text(
                          'Owner: $ownerName',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 12 : 13,
                            color: AppColors.secondaryText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: screenWidth * 0.008),
                        Row(
                          children: [
                            Icon(
                              Icons.square_foot,
                              size: isSmallScreen ? 12 : 14,
                              color: color,
                            ),
                            SizedBox(width: screenWidth * 0.01),
                            Text(
                              '$landSize $landSizeUnit',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 13,
                                color: AppColors.darkText,
                              ),
                            ),
                            SizedBox(width: screenWidth * 0.025),
                            Icon(
                              Icons.location_on,
                              size: isSmallScreen ? 12 : 14,
                              color: color,
                            ),
                            SizedBox(width: screenWidth * 0.01),
                            Expanded(
                              child: Text(
                                district,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 13,
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

  Widget _buildContent(double screenWidth, double screenHeight, bool isSmallScreen) {
    if (_isLoadingLands) {
      return Container(
        height: screenHeight * 0.3,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primaryBlue),
              SizedBox(height: screenHeight * 0.02),
              Text(
                'Loading land data...',
                style: TextStyle(
                  fontSize: screenWidth * 0.04,
                  color: AppColors.darkText,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_errorMessage != null) {
      return Container(
        padding: EdgeInsets.all(screenWidth * 0.05),
        margin: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentRed.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: screenWidth * 0.12,
              color: AppColors.accentRed,
            ),
            SizedBox(height: screenHeight * 0.02),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: screenWidth * 0.04,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
            SizedBox(height: screenHeight * 0.02),
            ElevatedButton.icon(
              onPressed: _fetchAllAssociatedLands,
              icon: Icon(
                Icons.refresh,
                size: screenWidth * 0.04,
              ),
              label: Text(
                'Retry',
                style: TextStyle(fontSize: screenWidth * 0.035),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: EdgeInsets.symmetric(
                  horizontal: screenWidth * 0.05,
                  vertical: screenHeight * 0.012,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    // Determine which lands to display
    final List<Map<String, dynamic>> displayLands = _filteredLands;

    if (displayLands.isEmpty) {
      return Container(
        padding: EdgeInsets.all(screenWidth * 0.06),
        margin: EdgeInsets.all(screenWidth * 0.04),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _isSearching || _selectedCropType != null || _selectedProvince != null
                ? Icons.search_off
                : Icons.landscape,
              size: screenWidth * 0.15,
              color: AppColors.primaryBlue,
            ),
            SizedBox(height: screenHeight * 0.02),
            Text(
              _isSearching || _selectedCropType != null || _selectedProvince != null
                ? 'No Matching Lands Found'
                : (_isCategoryView ? 'No Lands in this Category' : 'No Associated Lands'),
              style: TextStyle(
                fontSize: screenWidth * 0.045,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
              textAlign: TextAlign.center,
            ),
            SizedBox(height: screenHeight * 0.015),
            Text(
              _isSearching || _selectedCropType != null || _selectedProvince != null
                ? 'Try adjusting your search or filters to find what you\'re looking for.'
                : (_isCategoryView 
                    ? 'There are no lands in this category.'
                    : 'You are not currently associated with any lands. Lands will appear here once they add your factory.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: screenWidth * 0.035,
              ),
            ),
            if (_isSearching || _selectedCropType != null || _selectedProvince != null)
              SizedBox(height: screenHeight * 0.02),
            if (_isSearching || _selectedCropType != null || _selectedProvince != null)
              ElevatedButton.icon(
                onPressed: _clearFilters,
                icon: Icon(
                  Icons.clear_all,
                  size: screenWidth * 0.04,
                ),
                label: Text(
                  'Clear Filters',
                  style: TextStyle(fontSize: screenWidth * 0.035),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  padding: EdgeInsets.symmetric(
                    horizontal: screenWidth * 0.06,
                    vertical: screenHeight * 0.014,
                  ),
                ),
              ),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Results Count
        Padding(
          padding: EdgeInsets.symmetric(
            horizontal: isSmallScreen ? 12 : 16,
            vertical: isSmallScreen ? 6 : 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${displayLands.length} of ${_allAssociatedLands.length} lands',
                style: TextStyle(
                  fontSize: isSmallScreen ? 13 : 14,
                  color: AppColors.secondaryText,
                ),
              ),
              if (_isSearching || _selectedCropType != null || _selectedProvince != null)
                GestureDetector(
                  onTap: _clearFilters,
                  child: Text(
                    'Clear all',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 13 : 14,
                      color: AppColors.primaryBlue,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
            ],
          ),
        ),

        // Lands List
        Padding(
          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12 : 16),
          child: Column(
            children: displayLands.asMap().entries.map((entry) {
              final index = entry.key;
              final land = entry.value;
              final color = _isCategoryView ? widget.color! : _getCategoryColor(land['cropType'] ?? 'N/A');
              return _buildLandCard(land, color, index, screenWidth, isSmallScreen);
            }).toList(),
          ),
        ),
        
        SizedBox(height: screenHeight * 0.03),
      ],
    );
  }

  Color _getCategoryColor(String cropType) {
    switch (cropType) {
      case 'Cinnamon':
        return AppColors.warningOrange;
      case 'Tea':
        return AppColors.successGreen;
      case 'Both':
        return AppColors.accentTeal;
      default:
        return AppColors.primaryBlue;
    }
  }
}

// -----------------------------------------------------------------
// --- FACTORY OWNER LAND DETAILS MODAL WIDGET ---
// -----------------------------------------------------------------

class FactoryOwnerLandDetailsModal extends StatelessWidget {
  final Map<String, dynamic> land;

  const FactoryOwnerLandDetailsModal({super.key, required this.land});

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    
    final landName = land['landName'] ?? 'Unknown Land';
    final ownerName = land['ownerName'] ?? 'N/A';
    final cropType = land['cropType'] ?? 'N/A';
    final landSize = land['landSize'] ?? 'N/A';
    final landSizeUnit = land['landSizeUnit'] ?? 'ha';
    final address = land['address'] ?? 'N/A';
    final district = land['district'] ?? 'N/A';
    final agDivision = land['agDivision'] ?? 'N/A';
    final gnDivision = land['gnDivision'] ?? 'N/A';
    final village = land['village'] ?? 'N/A';
    final province = land['province'] ?? 'N/A';
    final country = land['country'] ?? 'Sri Lanka';
    final cinnamonLandSize = land['cinnamonLandSize'] ?? 'N/A';
    final teaLandSize = land['teaLandSize'] ?? 'N/A';
    final landPhotos = List<String>.from(land['landPhotos'] ?? []);
    final ownerUid = land['owner'] ?? '';
    final ownerEmail = land['ownerEmail'] ?? '';
    final ownerMobile = land['ownerMobile'] ?? '';
    final ownerNic = land['ownerNic'] ?? '';
    final ownerProfileImageUrl = land['ownerProfileImageUrl'] ?? '';
    final ownerRegistrationDate = land['ownerRegistrationDate'];
    final ownerStatus = land['ownerStatus'] ?? 'N/A';

    final Map<String, Color> cropColors = {
      'Cinnamon': AppColors.warningOrange,
      'Tea': AppColors.successGreen,
      'Both': AppColors.accentTeal,
    };

    final mainColor = cropColors[cropType] ?? AppColors.primaryBlue;

    return Container(
      height: screenHeight * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(30),
          topRight: Radius.circular(30),
        ),
      ),
      child: Column(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  mainColor.withOpacity(0.1),
                  mainColor.withOpacity(0.05),
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(30),
                topRight: Radius.circular(30),
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: isSmallScreen ? 40 : 50,
                  height: isSmallScreen ? 40 : 50,
                  decoration: BoxDecoration(
                    color: mainColor,
                    borderRadius: BorderRadius.circular(isSmallScreen ? 10 : 12),
                  ),
                  child: Icon(
                    _getCropIcon(cropType),
                    color: Colors.white,
                    size: isSmallScreen ? 22 : 28,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12 : 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        landName,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: screenHeight * 0.004),
                      Text(
                        '$cropType Land',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 12 : 14,
                          color: mainColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(
                    Icons.close,
                    color: AppColors.secondaryText,
                    size: isSmallScreen ? 20 : 24,
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: EdgeInsets.all(isSmallScreen ? 16 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // OWNER DETAILS SECTION
                  _buildOwnerDetailsSection(
                    ownerName: ownerName,
                    ownerProfileImageUrl: ownerProfileImageUrl,
                    ownerMobile: ownerMobile,
                    ownerEmail: ownerEmail,
                    ownerNic: ownerNic,
                    ownerStatus: ownerStatus,
                    mainColor: mainColor,
                    screenWidth: screenWidth,
                    isSmallScreen: isSmallScreen,
                  ),
                  
                  SizedBox(height: screenHeight * 0.02),
                  
                  _buildDetailSection(
                    title: 'Land Information',
                    icon: Icons.info_outline,
                    children: [
                      _buildDetailRow('Land Name', landName, screenWidth, isSmallScreen),
                      _buildDetailRow('Crop Type', cropType, screenWidth, isSmallScreen),
                      _buildDetailRow('Total Land Size', '$landSize $landSizeUnit', screenWidth, isSmallScreen),
                      if (cropType == 'Both' || cropType == 'Tea')
                        _buildDetailRow('Tea Land Size', '$teaLandSize $landSizeUnit', screenWidth, isSmallScreen),
                      if (cropType == 'Both' || cropType == 'Cinnamon')
                        _buildDetailRow('Cinnamon Land Size', '$cinnamonLandSize $landSizeUnit', screenWidth, isSmallScreen),
                    ],
                    screenWidth: screenWidth,
                    isSmallScreen: isSmallScreen,
                  ),
                  
                  SizedBox(height: screenHeight * 0.02),
                  
                  _buildDetailSection(
                    title: 'Location Details',
                    icon: Icons.location_on,
                    children: [
                      if (address.isNotEmpty) _buildDetailRow('Address', address, screenWidth, isSmallScreen),
                      if (village.isNotEmpty) _buildDetailRow('Village/Town', village, screenWidth, isSmallScreen),
                      if (district.isNotEmpty) _buildDetailRow('District', district, screenWidth, isSmallScreen),
                      if (province.isNotEmpty) _buildDetailRow('Province', province, screenWidth, isSmallScreen),
                      if (agDivision.isNotEmpty) _buildDetailRow('A/G Division', agDivision, screenWidth, isSmallScreen),
                      if (gnDivision.isNotEmpty) _buildDetailRow('G/N Division', gnDivision, screenWidth, isSmallScreen),
                      _buildDetailRow('Country', country, screenWidth, isSmallScreen),
                    ],
                    screenWidth: screenWidth,
                    isSmallScreen: isSmallScreen,
                  ),
                  
                  SizedBox(height: screenHeight * 0.02),
                  
                  if (landPhotos.isNotEmpty)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildDetailSection(
                          title: 'Land Photos',
                          icon: Icons.photo_camera,
                          children: [
                            GridView.builder(
                              shrinkWrap: true,
                              physics: const NeverScrollableScrollPhysics(),
                              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: isSmallScreen ? 2 : 2,
                                crossAxisSpacing: isSmallScreen ? 6 : 8,
                                mainAxisSpacing: isSmallScreen ? 6 : 8,
                                childAspectRatio: 1,
                              ),
                              itemCount: landPhotos.length,
                              itemBuilder: (context, index) {
                                return ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: Image.network(
                                    landPhotos[index],
                                    fit: BoxFit.cover,
                                    loadingBuilder: (context, child, loadingProgress) {
                                      if (loadingProgress == null) return child;
                                      return Center(
                                        child: CircularProgressIndicator(
                                          value: loadingProgress.expectedTotalBytes != null
                                              ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                              : null,
                                          color: mainColor,
                                        ),
                                      );
                                    },
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        color: Colors.grey[200],
                                        child: Icon(
                                          Icons.broken_image,
                                          color: Colors.grey,
                                          size: screenWidth * 0.1,
                                        ),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                          screenWidth: screenWidth,
                          isSmallScreen: isSmallScreen,
                        ),
                        SizedBox(height: screenHeight * 0.02),
                      ],
                    ),
                  
                  _buildDetailSection(
                    title: 'Land Identification',
                    icon: Icons.fingerprint,
                    children: [
                      _buildDetailRow('Land ID', land['id']?.toString() ?? 'N/A', screenWidth, isSmallScreen),
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: mainColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.shield,
                              color: mainColor,
                              size: isSmallScreen ? 18 : 20,
                            ),
                            SizedBox(width: screenWidth * 0.025),
                            Expanded(
                              child: Text(
                                'Associated with your factory',
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 14,
                                  color: AppColors.darkText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    screenWidth: screenWidth,
                    isSmallScreen: isSmallScreen,
                  ),
                  
                  SizedBox(height: screenHeight * 0.03),
                ],
              ),
            ),
          ),
        ],
      )
    );
  }

  Widget _buildOwnerDetailsSection({
    required String ownerName,
    required String ownerProfileImageUrl,
    required String ownerMobile,
    required String ownerEmail,
    required String ownerNic,
    required String ownerStatus,
    required Color mainColor,
    required double screenWidth,
    required bool isSmallScreen,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: mainColor.withOpacity(0.1)),
      ),
      child: Padding(
        padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 5 : 6),
                  decoration: BoxDecoration(
                    color: mainColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.person,
                    size: isSmallScreen ? 16 : 18,
                    color: mainColor,
                  ),
                ),
                SizedBox(width: screenWidth * 0.025),
                Text(
                  'Land Owner Details',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
            
            SizedBox(height: screenWidth * 0.04),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Owner Profile Picture
                Container(
                  width: isSmallScreen ? 55 : 70,
                  height: isSmallScreen ? 55 : 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: mainColor.withOpacity(0.3),
                      width: isSmallScreen ? 1.5 : 2.0,
                    ),
                    image: ownerProfileImageUrl.isNotEmpty
                      ? DecorationImage(
                          image: NetworkImage(ownerProfileImageUrl),
                          fit: BoxFit.cover,
                        )
                      : null,
                    color: ownerProfileImageUrl.isEmpty ? mainColor.withOpacity(0.1) : null,
                  ),
                  child: ownerProfileImageUrl.isEmpty
                    ? Center(
                        child: Icon(
                          Icons.person,
                          size: isSmallScreen ? 22 : 28,
                          color: mainColor,
                        ),
                      )
                    : null,
                ),
                
                SizedBox(width: screenWidth * 0.04),
                
                // Owner Details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ownerName,
                        style: TextStyle(
                          fontSize: isSmallScreen ? 15 : 17,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                      
                      SizedBox(height: screenWidth * 0.015),
                      
                      // Contact Number
                      if (ownerMobile.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: isSmallScreen ? 14 : 16,
                              color: mainColor,
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Expanded(
                              child: Text(
                                ownerMobile,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 13 : 14,
                                  color: AppColors.darkText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      
                      SizedBox(height: screenWidth * 0.008),
                      
                      // Email
                      if (ownerEmail.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.email,
                              size: isSmallScreen ? 14 : 16,
                              color: mainColor,
                            ),
                            SizedBox(width: screenWidth * 0.02),
                            Expanded(
                              child: Text(
                                ownerEmail,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 12 : 13,
                                  color: AppColors.secondaryText,
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
            
            SizedBox(height: screenWidth * 0.04),
            
            // Additional Owner Info
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 10 : 12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.background),
              ),
              child: Column(
                children: [
                  if (ownerNic.isNotEmpty)
                    _buildOwnerDetailRow(
                      label: 'NIC Number:',
                      value: ownerNic,
                      icon: Icons.badge,
                      screenWidth: screenWidth,
                      isSmallScreen: isSmallScreen,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOwnerDetailRow({
    required String label,
    required String value,
    required IconData icon,
    required double screenWidth,
    required bool isSmallScreen,
  }) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
      child: Row(
        children: [
          Icon(
            icon,
            size: isSmallScreen ? 16 : 18,
            color: AppColors.primaryBlue,
          ),
          SizedBox(width: screenWidth * 0.025),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 11 : 12,
                    color: AppColors.secondaryText,
                  ),
                ),
                SizedBox(height: screenWidth * 0.008),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 13 : 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDetailSection({
    required String title,
    required IconData icon,
    required List<Widget> children,
    required double screenWidth,
    required bool isSmallScreen,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 5 : 6),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                icon,
                size: isSmallScreen ? 16 : 18,
                color: AppColors.primaryBlue,
              ),
            ),
            SizedBox(width: screenWidth * 0.025),
            Text(
              title,
              style: TextStyle(
                fontSize: isSmallScreen ? 14 : 16,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
          ],
        ),
        SizedBox(height: screenWidth * 0.03),
        Container(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Column(
            children: children,
          ),
        ),
      ],
    );
  }

  Widget _buildDetailRow(String label, String value, double screenWidth, bool isSmallScreen) {
    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.02),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: screenWidth * (isSmallScreen ? 0.35 : 0.4),
            child: Text(
              '$label:',
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          SizedBox(width: screenWidth * 0.02),
          Expanded(
            child: Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
                color: AppColors.darkText,
              ),
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
}