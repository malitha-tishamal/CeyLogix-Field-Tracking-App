import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'land_details.dart'; // Import Land Details page
import 'landowner_dashbord.dart'; // Import the Dashboard page
import 'user_profile.dart'; // Import the User Profile page (Contains UserDetails)
import 'developer_info.dart'; // Import the Developer Info page
import 'land_location.dart';
import '../Auth/login_page.dart'; // Import the Login page

// --- Hardcoded Colors for Simplicity (Replace with AppColors if available) ---
const Color _primaryBlue = Color(0xFF2764E7);
const Color _darkText = Color(0xFF2C2A3A);
const Color _backgroundColor = Color(0xFFEEEBFF);
const Color _cardBackground = Colors.white;

class LandOwnerDrawer extends StatefulWidget {
  final Function(String route) onNavigate;
  final VoidCallback onLogout;

  const LandOwnerDrawer({
    super.key,
    required this.onNavigate,
    required this.onLogout,
  });

  static Map<String, dynamic>? staticCache;

  @override
  State<LandOwnerDrawer> createState() => _LandOwnerDrawerState();
}

class _LandOwnerDrawerState extends State<LandOwnerDrawer> {
  late Future<Map<String, dynamic>?> _userFuture;
  String? _error;
  
  // Responsive variables
  late bool _isPortrait;
  late double _screenWidth;
  late double _screenHeight;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUserData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateScreenDimensions();
  }

  void _updateScreenDimensions() {
    final mediaQuery = MediaQuery.of(context);
    _screenWidth = mediaQuery.size.width;
    _screenHeight = mediaQuery.size.height;
    _isPortrait = mediaQuery.orientation == Orientation.portrait;
  }

  Future<Map<String, dynamic>?> _loadUserData() async {
    if (LandOwnerDrawer.staticCache != null) {
      return LandOwnerDrawer.staticCache;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _error = "User not logged in";
        return null;
      }
      String uid = user.uid;

      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        LandOwnerDrawer.staticCache = data;
        return data;
      } else {
        _error = "User data not found";
        return null;
      }
    } catch (e) {
      _error = "Failed to load user data: $e";
      return null;
    }
  }

  // New method to handle logout
  Future<void> _handleLogout() async {
    try {
      // Close the drawer first
      Navigator.of(context).pop();
      
      // Show loading indicator
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (BuildContext context) {
          return AlertDialog(
            content: Row(
              children: [
                CircularProgressIndicator(color: _primaryBlue),
                SizedBox(width: _screenWidth * 0.04),
                Text(
                  "Logging out...",
                  style: TextStyle(
                    fontSize: _screenWidth < 360 ? 13 : 14,
                  ),
                ),
              ],
            ),
          );
        },
      );

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      
      // Clear the static cache
      LandOwnerDrawer.staticCache = null;
      
      // Navigate to login page and remove all previous routes
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (context) => const LoginPage()),
        (Route<dynamic> route) => false,
      );
    } catch (e) {
      // Close loading dialog
      Navigator.of(context).pop();
      
      // Show error message
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            "Logout failed: ${e.toString()}",
            style: TextStyle(fontSize: _screenWidth < 360 ? 12 : 14),
          ),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  // Method to handle location selection
  void _handleLocationSelected(Map<String, dynamic> locationData) {
    // You can save this location data to Firestore or use it as needed
    print('Selected Location: $locationData');
    
    // Show success message
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Location selected: ${locationData['address']}',
          style: TextStyle(fontSize: _screenWidth < 360 ? 12 : 14),
        ),
        backgroundColor: Colors.green,
        duration: const Duration(seconds: 2),
      ),
    );
    
    // You can save to Firestore here if needed
    _saveLocationToFirestore(locationData);
  }

  // Method to save location to Firestore
  Future<void> _saveLocationToFirestore(Map<String, dynamic> locationData) async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        await FirebaseFirestore.instance
            .collection('lands')
            .doc(user.uid)
            .set({
          'location': locationData,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
        
        print('Location saved to Firestore');
      }
    } catch (e) {
      print('Error saving location: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateScreenDimensions();
    final isSmallScreen = _screenWidth < 360;
    final isMediumScreen = _screenWidth >= 360 && _screenWidth < 400;
    final drawerWidth = _screenWidth * (_isPortrait ? 0.75 : 0.65);
    
    return Drawer(
      width: drawerWidth,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(20)),
      ),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState(isSmallScreen);
          } else if (snapshot.hasError || !snapshot.hasData || _error != null) {
            return _buildErrorState(isSmallScreen, isMediumScreen);
          } else {
            return _buildDrawerContent(
              snapshot.data!, 
              isSmallScreen, 
              isMediumScreen
            );
          }
        },
      ),
    );
  }

  Widget _buildDrawerContent(
    Map<String, dynamic> user, 
    bool isSmallScreen, 
    bool isMediumScreen
  ) {
    String fullName = user['name'] ?? "User";
    String firstName = fullName.split(" ").first;
    String role = user['role'] ?? "Land Owner";
    String profileUrl = user['profileImageUrl'] ??
        "https://ui-avatars.com/api/?name=$firstName&background=2764E7&color=fff&bold=true&size=150";

    // Responsive sizes
    final logoSize = isSmallScreen ? 50.0 : 
                    isMediumScreen ? 55.0 : 
                    60.0;
    
    final profileSize = isSmallScreen ? 55.0 : 
                       isMediumScreen ? 60.0 : 
                       65.0;
    
    final logoFontSize = isSmallScreen ? 22.0 : 
                        isMediumScreen ? 24.0 : 
                        26.0;
    
    final taglineFontSize = isSmallScreen ? 10.0 : 
                           isMediumScreen ? 10.5 : 
                           11.0;
    
    final nameFontSize = isSmallScreen ? 15.0 : 
                        isMediumScreen ? 16.0 : 
                        17.0;
    
    final roleFontSize = isSmallScreen ? 10.0 : 
                        isMediumScreen ? 10.5 : 
                        11.0;

    return Container(
      color: _backgroundColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: isSmallScreen ? 40.0 : 50.0),

          // Header (Logo/Title section)
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 16.0 : 20.0
            ),
            child: Row(
              children: [
                Container(
                  width: logoSize,
                  height: logoSize,
                  decoration: BoxDecoration(
                    color: _primaryBlue.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(
                      isSmallScreen ? 14.0 : 16.0
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryBlue.withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Image.asset(
                    'assets/logo/logo2.png',
                    width: logoSize,
                    height: logoSize,
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stackTrace) => Icon(
                      Icons.landscape_rounded, 
                      color: _primaryBlue, 
                      size: logoSize * 0.5
                    ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                Flexible(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "CeyLogix",
                        style: TextStyle(
                          fontSize: logoFontSize,
                          fontWeight: FontWeight.w900,
                          color: _primaryBlue,
                          letterSpacing: -0.8,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 1.0 : 2.0),
                      Text(
                        "Land Management",
                        style: TextStyle(
                          fontSize: taglineFontSize,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF666482),
                          letterSpacing: 0.3,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isSmallScreen ? 20.0 : 30.0),

          // Profile Section
          Container(
            margin: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12.0 : 16.0
            ),
            padding: EdgeInsets.all(
              isSmallScreen ? 14.0 : 
              isMediumScreen ? 16.0 : 
              18.0
            ),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [Colors.white, Color(0xFFF8FAFF)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(
                isSmallScreen ? 16.0 : 20.0
              ),
              boxShadow: [
                BoxShadow(
                  color: _primaryBlue.withOpacity(0.08),
                  blurRadius: 20,
                  offset: const Offset(0, 6),
                ),
              ],
              border: Border.all(
                color: Colors.white.withOpacity(0.9), 
                width: 1.5
              ),
            ),
            child: Row(
              children: [
                Container(
                  width: profileSize,
                  height: profileSize,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _primaryBlue, 
                      width: isSmallScreen ? 2.0 : 2.5
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _primaryBlue.withOpacity(0.2),
                        blurRadius: 12,
                        offset: const Offset(0, 4)
                      )
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      profileUrl,
                      fit: BoxFit.cover,
                      errorBuilder: (context, error, stackTrace) => Container(
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: LinearGradient(
                            colors: [_primaryBlue, Color(0xFF457AED)]
                          ),
                        ),
                        child: Icon(
                          Icons.person_rounded,
                          color: Colors.white,
                          size: profileSize * 0.4,
                        ),
                      ),
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: SizedBox(
                            width: profileSize * 0.3,
                            height: profileSize * 0.3,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: const AlwaysStoppedAnimation<Color>(
                                Colors.white
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        firstName,
                        style: TextStyle(
                          fontSize: nameFontSize,
                          fontWeight: FontWeight.w800,
                          color: _darkText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 3.0 : 4.0),
                      Container(
                        padding: EdgeInsets.symmetric(
                          horizontal: isSmallScreen ? 8.0 : 10.0,
                          vertical: isSmallScreen ? 3.0 : 4.0,
                        ),
                        decoration: BoxDecoration(
                          color: _primaryBlue.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(
                            isSmallScreen ? 6.0 : 8.0
                          ),
                          border: Border.all(
                            color: _primaryBlue.withOpacity(0.3)
                          ),
                        ),
                        child: Text(
                          role.toUpperCase(),
                          style: TextStyle(
                            fontSize: roleFontSize,
                            fontWeight: FontWeight.w700,
                            color: _primaryBlue,
                            letterSpacing: 0.8,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(height: isSmallScreen ? 20.0 : 25.0),
          
          _buildSectionDivider(isSmallScreen, isMediumScreen),
          SizedBox(height: isSmallScreen ? 6.0 : 8.0),

          // Menu Items
          Expanded(
            child: ListView(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 8.0 : 12.0,
                vertical: isSmallScreen ? 8.0 : 12.0,
              ),
              physics: const BouncingScrollPhysics(),
              children: [
                // 1. Dashboard 
                _buildModernDrawerItem(
                  icon: Icons.dashboard_rounded,
                  label: "Dashboard",
                  description: "Overview & Analytics",
                  isActive: true,
                  isSmallScreen: isSmallScreen,
                  isMediumScreen: isMediumScreen,
                  onTap: () {
                    Navigator.of(context).pop(); 
                    Navigator.of(context).pushReplacement( 
                      MaterialPageRoute(
                        builder: (context) => const LandOwnerDashboard()
                      ), 
                    );
                  },
                ),
                
                // 2. Land Details
                _buildModernDrawerItem(
                  icon: Icons.landscape_rounded,
                  label: "Land Details",
                  description: "Update land information",
                  isSmallScreen: isSmallScreen,
                  isMediumScreen: isMediumScreen,
                  onTap: () {
                    Navigator.of(context).pop(); 
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const LandDetails()
                      ),
                    );
                  },
                ),
                
                // 3. My Profile
                _buildModernDrawerItem(
                  icon: Icons.person_rounded,
                  label: "My Profile",
                  description: "Personal settings",
                  isSmallScreen: isSmallScreen,
                  isMediumScreen: isMediumScreen,
                  onTap: () {
                    Navigator.of(context).pop(); 
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const UserDetails()
                      ),
                    );
                  },
                ),
                
                // 4. Land Location
                _buildModernDrawerItem(
                  icon: Icons.location_on_rounded,
                  label: "Land Location",
                  description: "Set land location on map",
                  isSmallScreen: isSmallScreen,
                  isMediumScreen: isMediumScreen,
                  onTap: () {
                    Navigator.of(context).pop(); 
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => LocationSelectionPage(
                          onLocationSelected: _handleLocationSelected,
                        ),
                      ),
                    );
                  },
                ),
                
                // 5. Developer Info
                _buildModernDrawerItem(
                  icon: Icons.code_rounded, 
                  label: "Developer Info", 
                  description: "About the application", 
                  isSmallScreen: isSmallScreen,
                  isMediumScreen: isMediumScreen,
                  onTap: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => const DeveloperInfoPage()
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          // Updated Logout Button
          Container(
            margin: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.red.shade50,
                  Colors.red.shade100.withOpacity(0.8)
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight
              ),
              borderRadius: BorderRadius.circular(
                isSmallScreen ? 16.0 : 18.0
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.red.withOpacity(0.1),
                  blurRadius: 15,
                  offset: const Offset(0, 4),
                ),
              ],
              border: Border.all(
                color: Colors.red.withOpacity(0.2), 
                width: 1.5
              ),
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: _handleLogout,
                borderRadius: BorderRadius.circular(
                  isSmallScreen ? 16.0 : 18.0
                ),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 14.0 : 16.0,
                    vertical: isSmallScreen ? 12.0 : 14.0,
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: EdgeInsets.all(
                          isSmallScreen ? 8.0 : 10.0
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.logout_rounded,
                          color: Colors.red,
                          size: isSmallScreen ? 18.0 : 20.0,
                        ),
                      ),
                      SizedBox(width: isSmallScreen ? 12.0 : 14.0),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              "Logout",
                              style: TextStyle(
                                fontSize: isSmallScreen ? 14.0 : 15.0,
                                fontWeight: FontWeight.w700,
                                color: Colors.red,
                              ),
                            ),
                            SizedBox(height: isSmallScreen ? 1.0 : 2.0),
                            Text(
                              "Secure sign out",
                              style: TextStyle(
                                fontSize: isSmallScreen ? 10.0 : 11.0,
                                color: Colors.red.withOpacity(0.8),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: EdgeInsets.all(
                          isSmallScreen ? 5.0 : 6.0
                        ),
                        decoration: BoxDecoration(
                          color: Colors.red.withOpacity(0.1),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios_rounded,
                          color: Colors.red.withOpacity(0.7),
                          size: isSmallScreen ? 11.0 : 12.0,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // Footer
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            child: Column(
              children: [
                Text(
                  "v2.1.0",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 9.0 : 10.0,
                    fontWeight: FontWeight.w600,
                    color: _darkText.withOpacity(0.4),
                    letterSpacing: 0.5,
                  ),
                ),
                SizedBox(height: isSmallScreen ? 3.0 : 4.0),
                Text(
                  "CeyLogix © 2024",
                  style: TextStyle(
                    fontSize: isSmallScreen ? 9.0 : 10.0,
                    color: _darkText.withOpacity(0.3),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- Helper Widgets ---
  Widget _buildModernDrawerItem({
    required IconData icon,
    required String label,
    required String description,
    required bool isSmallScreen,
    required bool isMediumScreen,
    bool isActive = false,
    required VoidCallback onTap,
  }) {
    final itemFontSize = isSmallScreen ? 13.0 : 14.0;
    final descFontSize = isSmallScreen ? 10.0 : 11.0;
    final iconSize = isSmallScreen ? 16.0 : 18.0;
    final arrowSize = isSmallScreen ? 12.0 : 14.0;
    final padding = isSmallScreen ? 12.0 : 14.0;
    final borderRadius = isSmallScreen ? 14.0 : 16.0;
    final iconPadding = isSmallScreen ? 6.0 : 8.0;

    return Container(
      margin: EdgeInsets.only(bottom: isSmallScreen ? 5.0 : 6.0),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(borderRadius),
          child: Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              gradient: isActive
                  ? const LinearGradient(
                      colors: [_primaryBlue, Color(0xFF457AED)],
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                    )
                  : LinearGradient(
                      colors: [
                        Colors.white.withOpacity(0.7),
                        Colors.white.withOpacity(0.4),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
              borderRadius: BorderRadius.circular(borderRadius),
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: _primaryBlue.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ]
                  : [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.03),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
              border: Border.all(
                color: isActive
                    ? _primaryBlue.withOpacity(0.3)
                    : Colors.white.withOpacity(0.8),
                width: 1.2,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: EdgeInsets.all(iconPadding),
                  decoration: BoxDecoration(
                    color: isActive
                        ? Colors.white.withOpacity(0.2)
                        : _primaryBlue.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    color: isActive ? Colors.white : _primaryBlue,
                    size: iconSize,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12.0 : 14.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: itemFontSize,
                          fontWeight: FontWeight.w600,
                          color: isActive ? Colors.white : _darkText,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: isSmallScreen ? 1.0 : 2.0),
                      Text(
                        description,
                        style: TextStyle(
                          fontSize: descFontSize,
                          color: isActive 
                              ? Colors.white.withOpacity(0.8) 
                              : _darkText.withOpacity(0.5),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                SizedBox(width: isSmallScreen ? 8.0 : 10.0),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  color: isActive 
                      ? Colors.white.withOpacity(0.7) 
                      : _primaryBlue.withOpacity(0.4),
                  size: arrowSize,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionDivider(bool isSmallScreen, bool isMediumScreen) {
    final fontSize = isSmallScreen ? 9.0 : 10.0;
    final horizontalPadding = isSmallScreen ? 16.0 : 20.0;
    final textPadding = isSmallScreen ? 10.0 : 12.0;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: _primaryBlue.withOpacity(0.2),
              height: 1,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: textPadding),
            child: Text(
              "MENU",
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: _primaryBlue.withOpacity(0.5),
                letterSpacing: 1.5,
              ),
            ),
          ),
          Expanded(
            child: Divider(
              color: _primaryBlue.withOpacity(0.2),
              height: 1,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState(bool isSmallScreen) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: isSmallScreen ? 32.0 : 40.0,
            height: isSmallScreen ? 32.0 : 40.0,
            child: CircularProgressIndicator(
              strokeWidth: isSmallScreen ? 2.5 : 3.0,
              valueColor: const AlwaysStoppedAnimation<Color>(_primaryBlue),
            ),
          ),
          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
          Text(
            "Loading...",
            style: TextStyle(
              fontSize: isSmallScreen ? 13.0 : 14.0,
              fontWeight: FontWeight.w600,
              color: _darkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(bool isSmallScreen, bool isMediumScreen) {
    final iconSize = isSmallScreen ? 40.0 : 48.0;
    final titleFontSize = isSmallScreen ? 14.0 : 16.0;
    final errorFontSize = isSmallScreen ? 11.0 : 12.0;
    final buttonFontSize = isSmallScreen ? 13.0 : 14.0;

    return Container(
      color: _backgroundColor,
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 20.0 : 24.0),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: _primaryBlue,
            size: iconSize,
          ),
          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
          Text(
            "Unable to load",
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w700,
              color: _darkText,
            ),
            textAlign: TextAlign.center,
          ),
          if (_error != null) 
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 8.0 : 0,
                vertical: isSmallScreen ? 6.0 : 8.0,
              ),
              child: Text(
                _error!,
                style: TextStyle(
                  fontSize: errorFontSize,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          SizedBox(height: isSmallScreen ? 10.0 : 12.0),
          ElevatedButton(
            onPressed: () {
              setState(() {
                _userFuture = _loadUserData();
                _error = null;
              });
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: _primaryBlue,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: isSmallScreen ? 20.0 : 24.0,
                vertical: isSmallScreen ? 10.0 : 12.0,
              ),
              textStyle: TextStyle(
                fontSize: buttonFontSize,
                fontWeight: FontWeight.w600,
              ),
            ),
            child: const Text("Retry"),
          ),
        ],
      ),
    );
  }
}