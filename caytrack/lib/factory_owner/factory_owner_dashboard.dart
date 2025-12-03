import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'factory_owner_drawer.dart';
import 'land_details.dart'; // Import the LandDetailsPage

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
  
  // Custom colors based on the image's gradient header
  static const Color headerGradientStart = Color(0xFF869AEC);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);  
  static const Color headerTextDark = Color(0xFF333333);
}

// -----------------------------------------------------------------------------
// --- 1. MAIN SCREEN (FactoryOwnerDashboard) ---
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

  @override
  void initState() {
    super.initState();
    _fetchHeaderData();
    _fetchAssociatedLands();
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

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isLargeScreen = screenWidth > 400;
    
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
  // --- 2. MODULARIZED WIDGETS (Header & Dashboard Content) ---
  // -----------------------------------------------------------------

  /// 🌟 HEADER - Custom Header Widget matching FactoryDetails style
  Widget _buildDashboardHeader(BuildContext context, double screenWidth) {
    final isSmallScreen = screenWidth < 360;
    
    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(context).padding.top + (isSmallScreen ? 8 : 12),
        left: screenWidth * 0.05,
        right: screenWidth * 0.05,
        bottom: isSmallScreen ? 16 : 20,
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
                  size: isSmallScreen ? 24 : 28,
                ),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 8 : 10),
          
          Row(
            children: [
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
                  border: Border.all(color: Colors.white, width: isSmallScreen ? 2 : 3),
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
                    ? Icon(
                        Icons.person,
                        size: isSmallScreen ? 32 : 40,
                        color: Colors.white,
                      )
                    : null,
              ),
              
              SizedBox(width: isSmallScreen ? 12 : 15),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _loggedInUserName,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 16 : 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headerTextDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: isSmallScreen ? 2 : 4),
                    Text(
                      'Factory Name: $_factoryName\n($_userRole)',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11 : 14,
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
          
          SizedBox(height: isSmallScreen ? 15 : 20),
          
          Text(
            'Operational Overview (ID: $_factoryID)',
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

  // --- Dashboard Content Widgets ---

  Widget _buildSectionTitle(String title, IconData icon, double screenWidth) {
    final isSmallScreen = screenWidth < 360;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 4.0),
      child: Row(
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 5 : 6),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              icon,
              color: AppColors.primaryBlue,
              size: isSmallScreen ? 18 : 20,
            ),
          ),
          SizedBox(width: isSmallScreen ? 6 : 8),
          Text(
            title,
            style: TextStyle(
              fontSize: isSmallScreen ? 16 : 18,
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
    final isMediumScreen = screenWidth < 400;
    
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
    final cardWidth = screenWidth * 0.22;
    
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: cardWidth,
        padding: EdgeInsets.all(isSmallScreen ? 8 : 12),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [color, Color.lerp(color, Colors.black, 0.1)!],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(12),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.3),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: isSmallScreen ? 16 : 18, color: iconColor),
            SizedBox(height: isSmallScreen ? 4 : 6),
            Text(
              value,
              style: TextStyle(
                fontSize: isSmallScreen ? 16 : 18,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: isSmallScreen ? 2 : 4),
            Text(
              title,
              style: TextStyle(
                fontSize: isSmallScreen ? 9 : 10,
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
              size: isSmallScreen ? 16 : 18,
            ),
            label: Text(
              'View All Associated Lands',
              style: TextStyle(
                fontSize: isSmallScreen ? 13 : 14,
              ),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.05,
                vertical: isSmallScreen ? 12 : 14,
              ),
            ),
          ),
        ),

        // ✅ Show only latest 5 associated lands from each category
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
    // ✅ Take only latest 5 lands (already sorted newest first)
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
                  padding: EdgeInsets.all(isSmallScreen ? 5 : 6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    icon,
                    size: isSmallScreen ? 18 : 20,
                    color: color,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8 : 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: isSmallScreen ? 14 : 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.darkText,
                  ),
                ),
              ],
            ),
            Container(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 8 : 10,
                vertical: isSmallScreen ? 3 : 4,
              ),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
              ),
              child: Text(
                '$totalLands lands',
                style: TextStyle(
                  fontSize: isSmallScreen ? 10 : 12,
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
            // ✅ Display only latest 5 associated lands
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
            
            // ✅ Show "View All" button if there are more than 5 lands
            if (hasMoreLands)
              Container(
                margin: EdgeInsets.only(top: screenHeight * 0.01),
                child: TextButton.icon(
                  onPressed: () {
                    _navigateToCategoryDetails(
                      categoryTitle: title,
                      lands: lands, // Pass ALL lands (already sorted newest first)
                      categoryType: _getCategoryTypeFromTitle(title),
                      icon: icon,
                      color: color,
                    );
                  },
                  icon: Icon(
                    Icons.arrow_forward,
                    size: isSmallScreen ? 14 : 16,
                    color: color,
                  ),
                  label: Text(
                    'View All ${lands.length} Lands',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12 : 14,
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
          borderRadius: BorderRadius.circular(12),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: mainColor.withOpacity(0.1)),
            ),
            child: Padding(
              padding: EdgeInsets.all(isSmallScreen ? 12 : 16),
              child: Row(
                children: [
                  Container(
                    width: isSmallScreen ? 40 : 50,
                    height: isSmallScreen ? 40 : 50,
                    decoration: BoxDecoration(
                      color: mainColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Center(
                      child: Text(
                        '${index + 1}',
                        style: TextStyle(
                          fontSize: isSmallScreen ? 16 : 18,
                          fontWeight: FontWeight.bold,
                          color: mainColor,
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
                                color: mainColor.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(15),
                                border: Border.all(color: mainColor.withOpacity(0.3)),
                              ),
                              child: Text(
                                cropType,
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 10 : 11,
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
                            fontSize: isSmallScreen ? 12 : 13,
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
                              size: isSmallScreen ? 12 : 14,
                              color: mainColor,
                            ),
                            SizedBox(width: isSmallScreen ? 3 : 4),
                            Text(
                              '$landSize $landSizeUnit',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 12 : 13,
                                color: AppColors.darkText,
                              ),
                            ),
                            SizedBox(width: isSmallScreen ? 8 : 12),
                            Icon(
                              Icons.location_on,
                              size: isSmallScreen ? 12 : 14,
                              color: mainColor,
                            ),
                            SizedBox(width: isSmallScreen ? 3 : 4),
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

  Widget _buildLoadingLands(double screenWidth, double screenHeight) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.08),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
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
    );
  }

  Widget _buildErrorLands(double screenWidth) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.05),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.accentRed.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.error_outline,
            size: screenWidth * 0.09,
            color: AppColors.accentRed,
          ),
          SizedBox(height: screenWidth * 0.03),
          Text(
            _errorMessage ?? 'Unable to load land data',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: screenWidth * 0.04,
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
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoLandsCard(double screenWidth) {
    return Container(
      padding: EdgeInsets.all(screenWidth * 0.06),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.landscape,
            size: screenWidth * 0.12,
            color: AppColors.primaryBlue,
          ),
          SizedBox(height: screenWidth * 0.04),
          Text(
            'No Associated Lands',
            style: TextStyle(
              fontSize: screenWidth * 0.045,
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
              fontSize: screenWidth * 0.035,
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
                    borderRadius: BorderRadius.circular(12),
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
                    screenHeight: screenHeight,
                  ),
                  
                  SizedBox(height: screenHeight * 0.02),
                  
                  _buildDetailSection(
                    title: 'Land Information',
                    icon: Icons.info_outline,
                    children: [
                      _buildDetailRow('Land Name', landName, screenWidth),
                      _buildDetailRow('Crop Type', cropType, screenWidth),
                      _buildDetailRow('Total Land Size', '$landSize $landSizeUnit', screenWidth),
                      if (cropType == 'Both' || cropType == 'Tea')
                        _buildDetailRow('Tea Land Size', '$teaLandSize $landSizeUnit', screenWidth),
                      if (cropType == 'Both' || cropType == 'Cinnamon')
                        _buildDetailRow('Cinnamon Land Size', '$cinnamonLandSize $landSizeUnit', screenWidth),
                    ],
                    screenWidth: screenWidth,
                  ),
                  
                  SizedBox(height: screenHeight * 0.02),
                  
                  _buildDetailSection(
                    title: 'Location Details',
                    icon: Icons.location_on,
                    children: [
                      if (address.isNotEmpty) _buildDetailRow('Address', address, screenWidth),
                      if (village.isNotEmpty) _buildDetailRow('Village/Town', village, screenWidth),
                      if (district.isNotEmpty) _buildDetailRow('District', district, screenWidth),
                      if (province.isNotEmpty) _buildDetailRow('Province', province, screenWidth),
                      if (agDivision.isNotEmpty) _buildDetailRow('A/G Division', agDivision, screenWidth),
                      if (gnDivision.isNotEmpty) _buildDetailRow('G/N Division', gnDivision, screenWidth),
                      _buildDetailRow('Country', country, screenWidth),
                    ],
                    screenWidth: screenWidth,
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
                        ),
                        SizedBox(height: screenHeight * 0.02),
                      ],
                    ),
                  
                  _buildDetailSection(
                    title: 'Land Identification',
                    icon: Icons.fingerprint,
                    children: [
                      _buildDetailRow('Land ID', land['id']?.toString() ?? 'N/A', screenWidth),
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
                            SizedBox(width: isSmallScreen ? 8 : 10),
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
                  ),
                  
                  SizedBox(height: screenHeight * 0.03),
                ],
              ),
            ),
          ),
        ],
      ),
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
    required double screenHeight,
  }) {
    final isSmallScreen = screenWidth < 360;
    
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
                SizedBox(width: isSmallScreen ? 8 : 10),
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
            
            SizedBox(height: screenHeight * 0.015),
            
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Owner Profile Picture
                Container(
                  width: isSmallScreen ? 60 : 70,
                  height: isSmallScreen ? 60 : 70,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: mainColor.withOpacity(0.3), width: 2),
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
                          size: isSmallScreen ? 24 : 28,
                          color: mainColor,
                        ),
                      )
                    : null,
                ),
                
                SizedBox(width: isSmallScreen ? 12 : 16),
                
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
                      
                      SizedBox(height: screenHeight * 0.006),
                      
                      // Contact Number
                      if (ownerMobile.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.phone,
                              size: isSmallScreen ? 14 : 16,
                              color: mainColor,
                            ),
                            SizedBox(width: isSmallScreen ? 6 : 8),
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
                      
                      SizedBox(height: screenHeight * 0.004),
                      
                      // Email
                      if (ownerEmail.isNotEmpty)
                        Row(
                          children: [
                            Icon(
                              Icons.email,
                              size: isSmallScreen ? 14 : 16,
                              color: mainColor,
                            ),
                            SizedBox(width: isSmallScreen ? 6 : 8),
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
                      
                      SizedBox(height: screenHeight * 0.006),
                      
                      // Status Badge
                    /*  Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 8 : 10,
                          vertical: isSmallScreen ? 2 : 4,
                        ),
                        decoration: BoxDecoration(
                          color: _getStatusColor(ownerStatus).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(15),
                          border: Border.all(color: _getStatusColor(ownerStatus).withOpacity(0.3)),
                        ),
                        child: Text(
                          ownerStatus,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 10 : 11,
                            fontWeight: FontWeight.w600,
                            color: _getStatusColor(ownerStatus),
                          ),
                        ),
                      ),*/
                    ],
                  ),
                ),
              ],
            ),
            
            SizedBox(height: screenHeight * 0.015),
            
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
  }) {
    final isSmallScreen = screenWidth < 360;
    
    return Padding(
      padding: EdgeInsets.symmetric(vertical: screenWidth * 0.015),
      child: Row(
        children: [
          Icon(
            icon,
            size: isSmallScreen ? 16 : 18,
            color: AppColors.primaryBlue,
          ),
          SizedBox(width: isSmallScreen ? 8 : 10),
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
                SizedBox(height: screenWidth * 0.005),
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
  }) {
    final isSmallScreen = screenWidth < 360;
    
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
            SizedBox(width: isSmallScreen ? 8 : 10),
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

  Widget _buildDetailRow(String label, String value, double screenWidth) {
    final isSmallScreen = screenWidth < 360;
    
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
                fontSize: isSmallScreen ? 12 : 14,
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
                fontSize: isSmallScreen ? 12 : 14,
                color: AppColors.darkText,
              ),
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
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

  // Helper method to get status color
  Color _getStatusColor(String status) {
    switch (status) {
      case 'Verified':
        return AppColors.successGreen;
      case 'Pending Verification':
        return AppColors.warningOrange;
      case 'Rejected':
        return AppColors.accentRed;
      default:
        return AppColors.secondaryText;
    }
  }
}