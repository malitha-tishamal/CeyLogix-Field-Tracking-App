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
          // Fetch land owner details
          String? ownerUid = landData['owner'] ?? landDoc.id;
          String ownerName = 'Unknown Owner';
          
          if (ownerUid != null && ownerUid.isNotEmpty) {
            try {
              final userDoc = await _firestore
                  .collection('users')
                  .doc(ownerUid)
                  .get();
              
              if (userDoc.exists) {
                final userData = userDoc.data() as Map<String, dynamic>;
                ownerName = userData['name'] ?? 'Unknown Owner';
              }
            } catch (e) {
              debugPrint("Error fetching owner info for $ownerUid: $e");
            }
          }
          
          associatedLands.add({
            'id': landDoc.id,
            ...landData,
            'ownerName': ownerName,
          });
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
      builder: (context) => LandDetailsModal(land: land),
    );
  }

  void _handleDrawerNavigate(String routeName) {
    Navigator.pop(context); // Close drawer
    // You can add navigation logic here based on routeName
  }

  @override
  Widget build(BuildContext context) {
    if (widget.currentUser == null) {
      return const Scaffold(body: Center(child: Text("Error: User not logged in.")));
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
      body: Column(
        children: [
          // Header
          _buildDashboardHeader(context),
          
          // Main Content with Footer
          Expanded(
            child: Column(
              children: [
                // Filters Section
                _buildFilterSection(),
                
                // Lands List or Loading/Error States with Scrollable Content
                Expanded(
                  child: SingleChildScrollView(
                    child: _buildContent(),
                  ),
                ),
                
                // Footer (Fixed at bottom of content area) - Same as UserDetails
                Container(
                  padding: const EdgeInsets.all(16.0),
                  child: Text(
                    'Developed by Malitha Tishamal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.darkText.withOpacity(0.7),
                      fontSize: 12,
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

  Widget _buildDashboardHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
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
                icon: const Icon(Icons.menu, color: AppColors.headerTextDark, size: 28),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          Row(
            children: [
              // Profile Picture with Firebase image
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _profileImageUrl == null 
                    ? const LinearGradient(
                        colors: [AppColors.primaryBlue, Color(0xFF457AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.4),
                      blurRadius: 10,
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
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
              
              const SizedBox(width: 15),
              
              // User Info Display from Firebase
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loggedInUserName, 
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headerTextDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      'Factory Name: $_factoryName \n($_userRole)', 
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.headerTextDark.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 25), 
          
          // Page Title
          Text(
            _isCategoryView ? (widget.categoryTitle ?? 'Land Details') : 'All Associated Lands',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.headerTextDark,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterSection() {
    return Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
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
            padding: const EdgeInsets.symmetric(horizontal: 12),
            decoration: BoxDecoration(
              color: AppColors.background,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.search, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _searchController,
                    decoration: const InputDecoration(
                      hintText: 'Search lands, owners, districts...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(color: AppColors.secondaryText),
                    ),
                    style: const TextStyle(color: AppColors.darkText),
                  ),
                ),
                if (_searchController.text.isNotEmpty)
                  IconButton(
                    icon: const Icon(Icons.clear, size: 20),
                    onPressed: () {
                      _searchController.clear();
                    },
                  ),
              ],
            ),
          ),
          
          const SizedBox(height: 12),
          
          // Filter Toggle Button
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Filters',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.darkText,
                ),
              ),
              IconButton(
                icon: Icon(
                  _showFilters ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.primaryBlue,
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
            const SizedBox(height: 12),
            
            // Crop Type Filter
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Crop Type',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _buildFilterChip('All', _selectedCropType == null || _selectedCropType == 'All', 
                      () {
                        setState(() {
                          _selectedCropType = 'All';
                          _applyFilters();
                        });
                      }),
                    _buildFilterChip('Tea', _selectedCropType == 'Tea', 
                      () {
                        setState(() {
                          _selectedCropType = 'Tea';
                          _applyFilters();
                        });
                      }, AppColors.successGreen),
                    _buildFilterChip('Cinnamon', _selectedCropType == 'Cinnamon', 
                      () {
                        setState(() {
                          _selectedCropType = 'Cinnamon';
                          _applyFilters();
                        });
                      }, AppColors.warningOrange),
                    _buildFilterChip('Both', _selectedCropType == 'Both', 
                      () {
                        setState(() {
                          _selectedCropType = 'Both';
                          _applyFilters();
                        });
                      }, AppColors.accentTeal),
                  ],
                ),
              ],
            ),
            
            const SizedBox(height: 16),
            
            // Province Filter
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Province',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 8),
                DropdownButtonFormField<String>(
                  value: _selectedProvince,
                  decoration: InputDecoration(
                    filled: true,
                    fillColor: AppColors.background,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  ),
                  items: [
                    const DropdownMenuItem(
                      value: null,
                      child: Text('All Provinces'),
                    ),
                    ..._provinceDistricts.keys.map((province) {
                      return DropdownMenuItem(
                        value: province,
                        child: Text(province),
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
            
            const SizedBox(height: 16),
            
            // District Filter
            if (_selectedProvince != null)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'District',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.darkText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _selectedDistrict,
                    decoration: InputDecoration(
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide.none,
                      ),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: null,
                        child: Text('All Districts'),
                      ),
                      ...(_provinceDistricts[_selectedProvince] ?? []).map((district) {
                        return DropdownMenuItem(
                          value: district,
                          child: Text(district),
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
            
            const SizedBox(height: 16),
            
            // Clear Filters Button
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                OutlinedButton.icon(
                  onPressed: _clearFilters,
                  icon: const Icon(Icons.clear_all, size: 16),
                  label: const Text('Clear Filters'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.accentRed,
                    side: BorderSide(color: AppColors.accentRed.withOpacity(0.3)),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
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

  Widget _buildFilterChip(String label, bool selected, VoidCallback onTap, [Color? color]) {
    return FilterChip(
      label: Text(
        label,
        style: TextStyle(
          color: selected ? Colors.white : (color ?? AppColors.primaryBlue),
          fontWeight: FontWeight.w500,
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

  Widget _buildLandCard(Map<String, dynamic> land, Color color, int index) {
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
        margin: const EdgeInsets.only(bottom: 12),
        child: Material(
          elevation: 2,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Container(
                    width: 50,
                    height: 50,
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: color,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
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
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.darkText,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: color.withOpacity(0.3)),
                              ),
                              child: Text(
                                cropType,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w600,
                                  color: color,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Owner: $ownerName',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.secondaryText,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.square_foot, size: 14, color: color),
                            const SizedBox(width: 4),
                            Text(
                              '$landSize $landSizeUnit',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.darkText,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Icon(Icons.location_on, size: 14, color: color),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                district,
                                style: TextStyle(
                                  fontSize: 13,
                                  color: AppColors.darkText,
                                ),
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

  Widget _buildContent() {
    if (_isLoadingLands) {
      return Container(
        height: 200,
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(color: AppColors.primaryBlue),
              const SizedBox(height: 16),
              const Text(
                'Loading land data...',
                style: TextStyle(
                  fontSize: 14,
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
        padding: const EdgeInsets.all(20),
        margin: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.accentRed.withOpacity(0.2)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline, size: 48, color: AppColors.accentRed),
            const SizedBox(height: 16),
            Text(
              _errorMessage!,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _fetchAllAssociatedLands,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primaryBlue,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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
        padding: const EdgeInsets.all(24),
        margin: const EdgeInsets.all(20),
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
              size: 64,
              color: AppColors.primaryBlue,
            ),
            const SizedBox(height: 16),
            Text(
              _isSearching || _selectedCropType != null || _selectedProvince != null
                ? 'No Matching Lands Found'
                : (_isCategoryView ? 'No Lands in this Category' : 'No Associated Lands'),
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              _isSearching || _selectedCropType != null || _selectedProvince != null
                ? 'Try adjusting your search or filters to find what you\'re looking for.'
                : (_isCategoryView 
                    ? 'There are no lands in this category.'
                    : 'You are not currently associated with any lands. Lands will appear here once they add your factory.'),
              textAlign: TextAlign.center,
              style: TextStyle(
                color: AppColors.secondaryText,
                fontSize: 14,
              ),
            ),
            if (_isSearching || _selectedCropType != null || _selectedProvince != null)
              const SizedBox(height: 16),
            if (_isSearching || _selectedCropType != null || _selectedProvince != null)
              ElevatedButton.icon(
                onPressed: _clearFilters,
                icon: const Icon(Icons.clear_all, size: 16),
                label: const Text('Clear Filters'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
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
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Showing ${displayLands.length} of ${_allAssociatedLands.length} lands',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.secondaryText,
                ),
              ),
              if (_isSearching || _selectedCropType != null || _selectedProvince != null)
                GestureDetector(
                  onTap: _clearFilters,
                  child: Text(
                    'Clear all',
                    style: TextStyle(
                      fontSize: 14,
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
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: displayLands.asMap().entries.map((entry) {
              final index = entry.key;
              final land = entry.value;
              final color = _isCategoryView ? widget.color! : _getCategoryColor(land['cropType'] ?? 'N/A');
              return _buildLandCard(land, color, index);
            }).toList(),
          ),
        ),
        
        const SizedBox(height: 30),
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

// LandDetailsModal widget (keep the same as before)
class LandDetailsModal extends StatelessWidget {
  final Map<String, dynamic> land;

  const LandDetailsModal({super.key, required this.land});

  @override
  Widget build(BuildContext context) {
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

    final Map<String, Color> cropColors = {
      'Cinnamon': AppColors.warningOrange,
      'Tea': AppColors.successGreen,
      'Both': AppColors.accentTeal,
    };

    final mainColor = cropColors[cropType] ?? AppColors.primaryBlue;

    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
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
            padding: const EdgeInsets.all(20),
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
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    color: mainColor,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    _getCropIcon(cropType),
                    color: Colors.white,
                    size: 28,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        landName,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: AppColors.darkText,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '$cropType Land',
                        style: TextStyle(
                          fontSize: 14,
                          color: mainColor,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: const Icon(Icons.close, color: AppColors.secondaryText),
                ),
              ],
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailSection(
                    title: 'Basic Information',
                    icon: Icons.info_outline,
                    children: [
                      _buildDetailRow('Land Name', landName),
                      _buildDetailRow('Owner Name', ownerName),
                      _buildDetailRow('Crop Type', cropType),
                      _buildDetailRow('Total Land Size', '$landSize $landSizeUnit'),
                      if (cropType == 'Both' || cropType == 'Tea')
                        _buildDetailRow('Tea Land Size', '$teaLandSize $landSizeUnit'),
                      if (cropType == 'Both' || cropType == 'Cinnamon')
                        _buildDetailRow('Cinnamon Land Size', '$cinnamonLandSize $landSizeUnit'),
                    ],
                  ),
                  const SizedBox(height: 24),
                  _buildDetailSection(
                    title: 'Location Details',
                    icon: Icons.location_on,
                    children: [
                      if (address.isNotEmpty) _buildDetailRow('Address', address),
                      if (village.isNotEmpty) _buildDetailRow('Village/Town', village),
                      if (district.isNotEmpty) _buildDetailRow('District', district),
                      if (province.isNotEmpty) _buildDetailRow('Province', province),
                      if (agDivision.isNotEmpty) _buildDetailRow('A/G Division', agDivision),
                      if (gnDivision.isNotEmpty) _buildDetailRow('G/N Division', gnDivision),
                      _buildDetailRow('Country', country),
                    ],
                  ),
                  const SizedBox(height: 24),
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
                              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                                crossAxisCount: 2,
                                crossAxisSpacing: 8,
                                mainAxisSpacing: 8,
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
                                        child: const Icon(Icons.broken_image, color: Colors.grey),
                                      );
                                    },
                                  ),
                                );
                              },
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                      ],
                    ),
                  _buildDetailSection(
                    title: 'Land Identification',
                    icon: Icons.fingerprint,
                    children: [
                      _buildDetailRow('Land ID', land['id']?.toString() ?? 'N/A'),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.background,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: mainColor.withOpacity(0.2)),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.shield, color: mainColor, size: 20),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'Associated with your factory',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.darkText,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 30),
                ],
              ),
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: AppColors.primaryBlue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(icon, size: 18, color: AppColors.primaryBlue),
            ),
            const SizedBox(width: 10),
            Text(
              title,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.darkText,
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.all(16),
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

  Widget _buildDetailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              '$label:',
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.secondaryText,
              ),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.darkText,
              ),
            ),
          ),
        ],
      )
    );
  }

  // Helper method to get crop icon for modal
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