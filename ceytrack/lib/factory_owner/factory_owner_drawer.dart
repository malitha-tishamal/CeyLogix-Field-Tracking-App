import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'factory_details.dart'; // Import Factory Details page
import 'factory_owner_dashboard.dart'; // Import the Dashboard page
import 'user_profile.dart'; // Import the User Profile page (Contains UserDetails)
import 'developer_info.dart'; // 💡 NEW: Import the Developer Info page
import '../Auth/login_page.dart'; // Import the Login page
import 'land_details.dart';
import 'lands_map.dart';
import 'factory_owner_orders.dart';

// --- Hardcoded Colors for Simplicity (Replace with AppColors if available) ---
const Color _primaryBlue = Color(0xFF2764E7);
const Color _darkText = Color(0xFF2C2A3A);

class FactoryOwnerDrawer extends StatefulWidget {
  final Function(String route) onNavigate;
  final VoidCallback onLogout;

  const FactoryOwnerDrawer({
    super.key,
    required this.onNavigate,
    required this.onLogout,
  });

  static Map<String, dynamic>? staticCache;

  @override
  State<FactoryOwnerDrawer> createState() => _FactoryOwnerDrawerState();
}

class _FactoryOwnerDrawerState extends State<FactoryOwnerDrawer> {
  late Future<Map<String, dynamic>?> _userFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUserData();
  }

  Future<Map<String, dynamic>?> _loadUserData() async {
    if (FactoryOwnerDrawer.staticCache != null) {
      return FactoryOwnerDrawer.staticCache;
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
        FactoryOwnerDrawer.staticCache = data;
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
                SizedBox(width: MediaQuery.of(context).size.width * 0.04),
                const Text("Logging out..."),
              ],
            ),
          );
        },
      );

      // Sign out from Firebase
      await FirebaseAuth.instance.signOut();
      
      // Clear the static cache
      FactoryOwnerDrawer.staticCache = null;
      
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
          content: Text("Logout failed: $e"),
          backgroundColor: Colors.red,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth < 400;
    
    return Drawer(
      width: screenWidth * (isSmallScreen ? 0.75 : 0.65),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
      ),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState(screenWidth);
          } else if (snapshot.hasError || !snapshot.hasData || _error != null) {
            return _buildErrorState(screenWidth);
          } else {
            return _buildDrawerContent(snapshot.data!, screenWidth, screenHeight, isSmallScreen);
          }
        },
      ),
    );
  }

  Widget _buildDrawerContent(
    Map<String, dynamic> user, 
    double screenWidth, 
    double screenHeight,
    bool isSmallScreen,
  ) {
    String fullName = user['name'] ?? "User";
    String firstName = fullName.split(" ").first;
    String role = user['role'] ?? "Factory Owner";
    String profileUrl = user['profileImageUrl'] ??
        "https://ui-avatars.com/api/?name=$firstName&background=2764E7&color=fff&bold=true&size=150";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // STATIC TOP SECTION (Logo + Profile - Will NOT scroll)
        Column(
          children: [
            SizedBox(height: screenHeight * 0.04),

            // Header (Logo/Title section) - FIXED
            Padding(
              padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
              child: Row(
                children: [
                  Container(
                    width: isSmallScreen ? 50 : 60,
                    height: isSmallScreen ? 50 : 60,
                    decoration: BoxDecoration(
                      color: _primaryBlue.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryBlue.withOpacity(0.3),
                          blurRadius: 15,
                          offset: const Offset(0, 5),
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/logo/logo2.png',
                      width: isSmallScreen ? 50 : 60,
                      height: isSmallScreen ? 50 : 60,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) => Icon(
                        Icons.business_rounded,
                        color: _primaryBlue,
                        size: isSmallScreen ? 24 : 30,
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.03),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "CeyLogix",
                        style: TextStyle(
                          fontSize: isSmallScreen ? 22 : 26,
                          fontWeight: FontWeight.w900,
                          color: _primaryBlue,
                          letterSpacing: -0.8,
                        ),
                      ),
                      SizedBox(height: screenHeight * 0.002),
                      Text(
                        "Factory Management",
                        style: TextStyle(
                          fontSize: isSmallScreen ? 10 : 11,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xFF666482),
                          letterSpacing: 0.3,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: screenHeight * 0.03),

            // Profile Section - FIXED
            Container(
              margin: EdgeInsets.symmetric(horizontal: screenWidth * 0.04),
              padding: EdgeInsets.all(isSmallScreen ? 14 : 18),
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [Colors.white, Color(0xFFF8FAFF)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: _primaryBlue.withOpacity(0.08),
                    blurRadius: 25,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: Colors.white.withOpacity(0.9),
                  width: 1.5,
                ),
              ),
              child: Row(
                children: [
                  Container(
                    width: isSmallScreen ? 55 : 65,
                    height: isSmallScreen ? 55 : 65,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: _primaryBlue,
                        width: isSmallScreen ? 2.0 : 2.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _primaryBlue.withOpacity(0.2),
                          blurRadius: 15,
                          offset: const Offset(0, 4),
                        ),
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
                              colors: [_primaryBlue, Color(0xFF457AED)],
                            ),
                          ),
                          child: Icon(
                            Icons.person_rounded,
                            color: Colors.white,
                            size: isSmallScreen ? 24 : 28,
                          ),
                        ),
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: SizedBox(
                              width: isSmallScreen ? 18 : 20,
                              height: isSmallScreen ? 18 : 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  SizedBox(width: screenWidth * 0.04),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          firstName,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 15 : 17,
                            fontWeight: FontWeight.w800,
                            color: _darkText,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        SizedBox(height: screenHeight * 0.004),
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: screenWidth * 0.025,
                            vertical: screenHeight * 0.004,
                          ),
                          decoration: BoxDecoration(
                            color: _primaryBlue.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: _primaryBlue.withOpacity(0.3),
                            ),
                          ),
                          child: Text(
                            role.toUpperCase(),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 10 : 11,
                              fontWeight: FontWeight.w700,
                              color: _primaryBlue,
                              letterSpacing: 0.8,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: screenHeight * 0.025),
            _buildSectionDivider(screenWidth),
            SizedBox(height: screenHeight * 0.01),
          ],
        ),

        // SCROLLABLE MIDDLE SECTION (Menu Items only)
        Expanded(
          child: SingleChildScrollView(
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.03,
                vertical: screenHeight * 0.01,
              ),
              child: Column(
                children: [
                  // 1. Dashboard 
                  _buildModernDrawerItem(
                    icon: Icons.dashboard_rounded,
                    label: "Dashboard",
                    description: "Overview & Analytics",
                    isActive: true,
                    onTap: () {
                      Navigator.of(context).pop(); 
                      Navigator.of(context).pushReplacement( 
                        MaterialPageRoute(builder: (context) => const FactoryOwnerDashboard()), 
                      );
                    },
                    screenWidth: screenWidth,
                    isSmallScreen: isSmallScreen,
                  ),
                  
                  SizedBox(height: screenHeight * 0.008),
                  
                  // 2. Factory Details
                  _buildModernDrawerItem(
                    icon: Icons.factory,
                    label: "Factory Details",
                    description: "Update company information",
                    onTap: () {
                      Navigator.of(context).pop(); 
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const FactoryDetails()),
                      );
                    },
                    screenWidth: screenWidth,
                    isSmallScreen: isSmallScreen,
                  ),
                  
                  SizedBox(height: screenHeight * 0.008),
                  
                  // 3. My Profile
                  _buildModernDrawerItem(
                    icon: Icons.person_rounded,
                    label: "My Profile",
                    description: "Personal settings",
                    onTap: () {
                      Navigator.of(context).pop(); 
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const UserDetails()),
                      );
                    },
                    screenWidth: screenWidth,
                    isSmallScreen: isSmallScreen,
                  ),
                  
                  SizedBox(height: screenHeight * 0.008),
                  
                  // 4. Land Details
                  _buildModernDrawerItem(
                    icon: Icons.landscape,
                    label: "Land Details",
                    description: "View All Associated Lands",
                    onTap: () {
                      Navigator.of(context).pop(); 
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => LandDetailsPage(
                            currentUser: FirebaseAuth.instance.currentUser,
                          ),
                        ),
                      );
                    },
                    screenWidth: screenWidth,
                    isSmallScreen: isSmallScreen,
                  ),
                  
                  SizedBox(height: screenHeight * 0.008),
                  
                  // 5. Land Details Map
                  _buildModernDrawerItem(
                    icon: Icons.location_on, 
                    label: "Land Details Map", 
                    description: "Map with Land Details", 
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const LandLocationsPage(),
                        ),
                      );
                    },
                    screenWidth: screenWidth,
                    isSmallScreen: isSmallScreen,
                  ),

                  _buildModernDrawerItem(
                   icon: Icons.info_outline, 
                    label: "Receved Products", 
                    description: "Land Owners Export Product Receved", 
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (context) => const FactoryOwnerOrdersPage(),
                          
                        ),
                      );
                    },
                    screenWidth: screenWidth,
                    isSmallScreen: isSmallScreen,
                  ),
                  
                  SizedBox(height: screenHeight * 0.008),
                  
                  // 6. Developer Info
                  _buildModernDrawerItem(
                    icon: Icons.code_rounded, 
                    label: "Developer Info", 
                    description: "About the application", 
                    onTap: () {
                      Navigator.of(context).pop();
                      Navigator.of(context).push(
                        MaterialPageRoute(builder: (context) => const DeveloperInfoPage()),
                      );
                    },
                    screenWidth: screenWidth,
                    isSmallScreen: isSmallScreen,
                  ),
                ],
              ),
            ),
          ),
        ),

        // STATIC BOTTOM SECTION (Logout Button + Footer)
        Column(
          children: [
            // Updated Logout Button
            Container(
              margin: EdgeInsets.all(screenWidth * 0.04),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Colors.red.shade50,
                    Colors.red.shade100.withOpacity(0.8),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: Colors.red.withOpacity(0.1),
                    blurRadius: 20,
                    offset: const Offset(0, 5),
                  ),
                ],
                border: Border.all(
                  color: Colors.red.withOpacity(0.2),
                  width: 1.5,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  onTap: _handleLogout,
                  borderRadius: BorderRadius.circular(18),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: screenWidth * 0.04,
                      vertical: screenHeight * 0.014,
                    ),
                    child: Row(
                      children: [
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.025),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.logout_rounded,
                            color: Colors.red,
                            size: screenWidth * 0.05,
                          ),
                        ),
                        SizedBox(width: screenWidth * 0.035),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                "Logout",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 14 : 15,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.red,
                                ),
                              ),
                              SizedBox(height: screenHeight * 0.002),
                              Text(
                                "Secure sign out",
                                style: TextStyle(
                                  fontSize: isSmallScreen ? 10 : 11,
                                  color: Colors.red.withOpacity(0.8),
                                ),
                              ),
                            ],
                          ),
                        ),
                        Container(
                          padding: EdgeInsets.all(screenWidth * 0.015),
                          decoration: BoxDecoration(
                            color: Colors.red.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.red.withOpacity(0.7),
                            size: screenWidth * 0.03,
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
              padding: EdgeInsets.all(screenWidth * 0.04),
              child: Column(
                children: [
                  Text(
                    "v2.1.0",
                    style: TextStyle(
                      fontSize: screenWidth * 0.028,
                      fontWeight: FontWeight.w600,
                      color: _darkText.withOpacity(0.4),
                      letterSpacing: 0.5,
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.004),
                  Text(
                    "CeyLogix © 2025",
                    style: TextStyle(
                      fontSize: screenWidth * 0.028,
                      color: _darkText.withOpacity(0.3),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }

  // --- Helper Widgets ---
  Widget _buildModernDrawerItem({
    required IconData icon,
    required String label,
    required String description,
    bool isActive = false,
    required VoidCallback onTap,
    required double screenWidth,
    required bool isSmallScreen,
  }) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: EdgeInsets.all(isSmallScreen ? 12 : 14),
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
            borderRadius: BorderRadius.circular(16),
            boxShadow: isActive
                ? [
                    BoxShadow(
                      color: _primaryBlue.withOpacity(0.3),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ]
                : [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.03),
                      blurRadius: 10,
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
                padding: EdgeInsets.all(isSmallScreen ? 7 : 8),
                decoration: BoxDecoration(
                  color: isActive
                      ? Colors.white.withOpacity(0.2)
                      : _primaryBlue.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  icon,
                  color: isActive ? Colors.white : _primaryBlue,
                  size: isSmallScreen ? 16 : 18,
                ),
              ),
              SizedBox(width: screenWidth * 0.035),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: isActive ? Colors.white : _darkText,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenWidth * 0.005),
                    Text(
                      description,
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10 : 11,
                        color: isActive ? Colors.white.withOpacity(0.8) : _darkText.withOpacity(0.5),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              SizedBox(width: screenWidth * 0.025),
              Icon(
                Icons.arrow_forward_ios_rounded,
                color: isActive ? Colors.white.withOpacity(0.7) : _primaryBlue.withOpacity(0.4),
                size: isSmallScreen ? 12 : 14,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionDivider(double screenWidth) {
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.05),
      child: Row(
        children: [
          Expanded(
            child: Divider(
              color: _primaryBlue.withOpacity(0.2),
              height: 1,
            ),
          ),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.03),
            child: Text(
              "MENU",
              style: TextStyle(
                fontSize: screenWidth * 0.028,
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

  Widget _buildLoadingState(double screenWidth) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: screenWidth * 0.1,
            height: screenWidth * 0.1,
            child: CircularProgressIndicator(
              strokeWidth: 3,
              valueColor: const AlwaysStoppedAnimation<Color>(_primaryBlue),
            ),
          ),
          SizedBox(height: screenWidth * 0.04),
          Text(
            "Loading...",
            style: TextStyle(
              fontSize: screenWidth * 0.04,
              fontWeight: FontWeight.w600,
              color: _darkText,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(double screenWidth) {
    return Padding(
      padding: EdgeInsets.all(screenWidth * 0.05),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            color: _primaryBlue,
            size: screenWidth * 0.12,
          ),
          SizedBox(height: screenWidth * 0.04),
          Text(
            "Unable to load",
            style: TextStyle(
              fontSize: screenWidth * 0.045,
              fontWeight: FontWeight.w700,
            ),
          ),
          if (_error != null)
            Padding(
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.06,
                vertical: screenWidth * 0.02,
              ),
              child: Text(
                _error!,
                style: TextStyle(
                  fontSize: screenWidth * 0.033,
                  color: Colors.red.shade700,
                  fontWeight: FontWeight.w500,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          SizedBox(height: screenWidth * 0.03),
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
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(
                horizontal: screenWidth * 0.06,
                vertical: screenWidth * 0.03,
              ),
            ),
            child: Text(
              "Retry",
              style: TextStyle(fontSize: screenWidth * 0.035),
            ),
          ),
        ],
      ),
    );
  }
}