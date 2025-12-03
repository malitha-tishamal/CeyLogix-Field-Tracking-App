import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'factory_owner_drawer.dart';

// --- 1. COLOR PALETTE (Reusable for consistency) ---
class AppColors {
  static const Color background = Color(0xFFEEEBFF);
  static const Color darkText = Color(0xFF2C2A3A);
  static const Color primaryBlue = Color(0xFF2764E7);
  static const Color cardBackground = Colors.white;
  static const Color secondaryColor = Color(0xFF6AD96A);
  static const Color headerTextDark = Color(0xFF333333);
  static const Color accentPurple = Color.fromRGBO(134, 164, 236, 1);
  static const Color errorRed = Color(0xFFD32F2F);
  
  // Header gradient colors matching Factory Owner Dashboard
  static const Color headerGradientStart = Color(0xFF869AEC);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
}

// -----------------------------------------------------------------------------
// --- 2. MAIN SCREEN (DeveloperInfoPage - StatefulWidget for Key) ---
// -----------------------------------------------------------------------------
class DeveloperInfoPage extends StatefulWidget {
  const DeveloperInfoPage({super.key});

  @override
  State<DeveloperInfoPage> createState() => _DeveloperInfoPageState();
}

class _DeveloperInfoPageState extends State<DeveloperInfoPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // State variables to hold fetched data
  String _loggedInUserName = 'Loading User...';
  String _factoryName = 'Loading Factory...';
  String _userRole = 'Factory Owner';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchHeaderData();
  }

  // --- DATA FETCHING FUNCTION ---
  void _fetchHeaderData() async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    
    final String uid = user.uid;

    try {
      // 1. Fetch User Name and Role from 'users' collection
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner Name Missing';
          _profileImageUrl = userData?['profileImageUrl'];
          _userRole = userData?['role'] ?? 'Factory Owner';
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

  void _handleDrawerNavigate(String routeName) {
    Navigator.pop(context);
  }

  // --- Improved URL Launcher Functions with Better Error Handling ---
  Future<void> _launchURL(String url) async {
    if (url.isEmpty) {
      _showErrorSnackBar('Cannot open link: URL is empty');
      return;
    }

    final Uri uri;
    try {
      uri = Uri.parse(url);
    } catch (e) {
      _showErrorSnackBar('Invalid URL format: $url');
      return;
    }

    if (!await canLaunchUrl(uri)) {
      _showErrorSnackBar('Cannot open link: No app found to handle this URL');
      return;
    }

    try {
      await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
    } catch (e) {
      _showErrorSnackBar('Failed to open link: ${e.toString()}');
    }
  }

  Future<void> _launchEmail() async {
    const email = 'malithatishamal@gmail.com';
    final Uri emailLaunchUri = Uri(
      scheme: 'mailto',
      path: email,
      query: encodeQueryParameters(<String, String>{
        'subject': 'CeyLogix App Inquiry',
        'body': 'Hello Malitha, I would like to know more about your work...',
      }),
    );

    await _launchURL(emailLaunchUri.toString());
  }

  Future<void> _launchPhone(String phoneNumber) async {
    if (phoneNumber.isEmpty) {
      _showErrorSnackBar('Phone number is empty');
      return;
    }
    
    final cleanedNumber = phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
    if (cleanedNumber.isEmpty) {
      _showErrorSnackBar('Invalid phone number format');
      return;
    }
    
    await _launchURL('tel:$cleanedNumber');
  }

  String? encodeQueryParameters(Map<String, String> params) {
    return params.entries
        .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
        .join('&');
  }

  void _showErrorSnackBar(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white, size: 20),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: AppColors.errorRed,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenWidth < 360;
    
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: FactoryOwnerDrawer(
        onLogout: () {
          Navigator.of(context).pop();
        },
        onNavigate: _handleDrawerNavigate,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // 🌟 FIXED HEADER - Factory Owner Dashboard Style with Firebase Data
            _buildDashboardHeader(context, screenWidth, screenHeight),
            
            // 🌟 SCROLLABLE CONTENT ONLY with Footer
            Expanded(
              child: Column(
                children: [
                  // Scrollable content
                  Expanded(
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Pass the launcher functions to the content widget
                          DeveloperInfoContent(
                            launchURL: _launchURL,
                            launchEmail: _launchEmail,
                            launchPhone: _launchPhone,
                            screenWidth: screenWidth,
                            screenHeight: screenHeight,
                          ),
                          SizedBox(height: screenHeight * 0.02),
                        ],
                      ),
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

  // 🌟 FIXED HEADER - Factory Owner Dashboard Style with Firebase Data
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
                        size: isSmallScreen ? 32.0 : 40.0,
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
                        fontSize: isSmallScreen ? 16.0 : 20.0,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headerTextDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: screenHeight * 0.004),
                    Text(
                      'Factory Name: $_factoryName\n($_userRole)',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 11.0 : 14.0,
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
            'Developer About Me',
            style: TextStyle(
              fontSize: isSmallScreen ? 14.0 : 16.0,
              fontWeight: FontWeight.w600,
              color: AppColors.headerTextDark,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// --- DEVELOPER INFO CONTENT WIDGET ---
// -----------------------------------------------------------------------------
class DeveloperInfoContent extends StatelessWidget {
  final Function(String url) launchURL;
  final VoidCallback launchEmail;
  final Function(String phoneNumber) launchPhone;
  final double screenWidth;
  final double screenHeight;

  const DeveloperInfoContent({
    super.key,
    required this.launchURL,
    required this.launchEmail,
    required this.launchPhone,
    required this.screenWidth,
    required this.screenHeight,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = screenWidth < 360;
    const String profileImageUrl = 'assets/developer/developer_photo.png';

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.05,
        vertical: screenHeight * 0.03,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Developer Image with improved styling
          Container(
            width: screenWidth * 0.5,
            height: screenWidth * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primaryBlue, AppColors.accentPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white,
                width: isSmallScreen ? 3.0 : 4.0,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.4),
                  blurRadius: 20.0,
                  spreadRadius: 2.0,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Stack(
              children: [
                ClipOval(
                  child: Image.asset(
                    profileImageUrl,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          colors: [AppColors.primaryBlue, AppColors.accentPurple],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                      ),
                      child: Icon(
                        Icons.person,
                        size: screenWidth * 0.15,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2.0),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: screenHeight * 0.03),

          // Developer Name and Title with improved typography
          Text(
            'Malitha Tishamal',
            style: TextStyle(
              fontSize: isSmallScreen ? 22.0 : 28.0,
              fontWeight: FontWeight.w900,
              color: AppColors.darkText,
              letterSpacing: -0.5,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: screenHeight * 0.008),
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: screenWidth * 0.04,
              vertical: screenHeight * 0.006,
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20.0),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
            ),
            child: Text(
              'Full Stack Developer',
              style: TextStyle(
                fontSize: isSmallScreen ? 14.0 : 16.0,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ),

          SizedBox(height: screenHeight * 0.04),

          // --- 🌟 UPDATED Social Media Section with Font Awesome Icons ---
          _buildSectionHeader(
            title: "Connect with me",
            icon: Icons.share_rounded,
            screenWidth: screenWidth,
            isSmallScreen: isSmallScreen,
          ),
          SizedBox(height: screenHeight * 0.02),
          _buildSocialMediaButtons(isSmallScreen),

          SizedBox(height: screenHeight * 0.04),

          // --- 💡 Contact Details Section ---
          _buildSectionHeader(
            title: "Contact Details",
            icon: Icons.contact_mail_rounded,
            screenWidth: screenWidth,
            isSmallScreen: isSmallScreen,
          ),
          SizedBox(height: screenHeight * 0.02),
          _buildContactDetailsCard(isSmallScreen),

          SizedBox(height: screenHeight * 0.04),

          // --- 💡 My Skills Section ---
          _buildSectionHeader(
            title: "Technical Skills",
            icon: Icons.code_rounded,
            screenWidth: screenWidth,
            isSmallScreen: isSmallScreen,
          ),
          SizedBox(height: screenHeight * 0.02),
          _buildSkillsChips(isSmallScreen),

          SizedBox(height: screenHeight * 0.04),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required IconData icon,
    required double screenWidth,
    required bool isSmallScreen,
  }) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: screenWidth * 0.03,
        vertical: screenHeight * 0.01,
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12.0),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: EdgeInsets.all(isSmallScreen ? 5.0 : 6.0),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: Colors.white,
              size: isSmallScreen ? 16.0 : 18.0,
            ),
          ),
          SizedBox(width: screenWidth * 0.03),
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: isSmallScreen ? 16.0 : 18.0,
                fontWeight: FontWeight.bold,
                color: AppColors.darkText,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  // --- 🌟 UPDATED Social Media Widgets: Font Awesome Icons and Links ---
  Widget _buildSocialMediaButtons(bool isSmallScreen) {
    final List<SocialMediaItem> socialItems = [
      SocialMediaItem(
        icon: FontAwesomeIcons.facebookF,
        label: 'Facebook', 
        url: 'https://facebook.com/malitha.tishamal',
        color: const Color(0xFF1877F2),
      ),
      SocialMediaItem(
        icon: FontAwesomeIcons.instagram,
        label: 'Instagram',
        url: 'https://instagram.com/malithatishamal',
        color: const Color(0xFFE4405F),
      ),
      SocialMediaItem(
        icon: FontAwesomeIcons.github,
        label: 'GitHub',
        url: 'https://github.com/malithatishamal',
        color: const Color(0xFF181717),
      ),
      SocialMediaItem(
        icon: FontAwesomeIcons.linkedinIn,
        label: 'LinkedIn',
        url: 'https://linkedin.com/in/malithatishamal',
        color: const Color(0xFF0A66C2),
      ),
      SocialMediaItem(
        icon: FontAwesomeIcons.twitter,
        label: 'Twitter',
        url: 'https://twitter.com/malithatishamal',
        color: const Color(0xFF1DA1F2),
      ),
      SocialMediaItem(
        icon: FontAwesomeIcons.globe,
        label: 'Portfolio',
        url: 'https://malithatishamal.42web.io',
        color: const Color(0xFF6E5494),
      ),
    ];

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.1),
            blurRadius: 15.0,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: AppColors.accentPurple.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            'Follow me on social media',
            style: TextStyle(
              fontSize: isSmallScreen ? 13.0 : 14.0,
              color: AppColors.darkText,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: screenHeight * 0.016),
          Wrap(
            spacing: isSmallScreen ? 12.0 : 20.0,
            runSpacing: isSmallScreen ? 16.0 : 20.0,
            alignment: WrapAlignment.center,
            children: socialItems.map((item) {
              return _buildSocialMediaButton(item, isSmallScreen);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialMediaButton(SocialMediaItem item, bool isSmallScreen) {
    final double buttonSize = (isSmallScreen ? screenWidth * 0.18 : 70.0);
    final double iconSize = (isSmallScreen ? screenWidth * 0.08 : 40.0);
    
    return SizedBox(
      width: buttonSize + 20.0,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Tooltip(
            message: 'Open ${item.label}',
            child: GestureDetector(
              onTap: () => launchURL(item.url),
              child: Container(
                width: buttonSize,
                height: buttonSize,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [item.color.withOpacity(0.9), item.color],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: item.color.withOpacity(0.3),
                      blurRadius: 12.0,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Center(
                  child: FaIcon(
                    item.icon,
                    color: Colors.white,
                    size: iconSize,
                  ),
                ),
              ),
            ),
          ),
          SizedBox(height: screenHeight * 0.01),
          Text(
            item.label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 11.0 : 12.0,
              fontWeight: FontWeight.w500,
              color: AppColors.darkText.withOpacity(0.7),
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  // --- Contact Details Widgets: Clickable Email/Phone ---
  Widget _buildContactDetailsCard(bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.1),
            blurRadius: 15.0,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: AppColors.accentPurple.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildContactItem(
            icon: Icons.email_rounded,
            label: 'Email Address',
            value: 'malithatishamal@gmail.com',
            color: const Color(0xFFEA4335),
            onTap: launchEmail,
            isSmallScreen: isSmallScreen,
          ),
          SizedBox(height: screenHeight * 0.012),
          _buildContactItem(
            icon: Icons.call_rounded,
            label: 'Mobile Number',
            value: '+94 78 553 0992',
            color: AppColors.secondaryColor,
            onTap: () => launchPhone('+94785530992'),
            isSmallScreen: isSmallScreen,
          ),
          SizedBox(height: screenHeight * 0.012),
          _buildContactItem(
            icon: Icons.location_on_rounded,
            label: 'Location',
            value: 'Matara, Sri Lanka',
            color: AppColors.primaryBlue,
            isLast: true,
            onTap: () => launchURL('https://maps.app.goo.gl/Matara'),
            isSmallScreen: isSmallScreen,
          ),
        ],
      ),
    );
  }

  Widget _buildContactItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
    bool isLast = false,
    required bool isSmallScreen,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12.0),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 14.0 : 16.0),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12.0),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
              decoration: BoxDecoration(
                color: color.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                color: color,
                size: isSmallScreen ? 20.0 : 22.0,
              ),
            ),
            SizedBox(width: screenWidth * 0.04),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12.0 : 13.0,
                      fontWeight: FontWeight.w500,
                      color: AppColors.darkText.withOpacity(0.6),
                    ),
                  ),
                  SizedBox(height: screenHeight * 0.004),
                  Text(
                    value,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                      fontWeight: FontWeight.w600,
                      color: AppColors.darkText,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 5.0 : 6.0),
              decoration: BoxDecoration(
                color: color.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.arrow_forward_ios_rounded,
                color: color,
                size: isSmallScreen ? 12.0 : 14.0,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // --- Skills Widgets with improved design ---
  Widget _buildSkillsChips(bool isSmallScreen) {
    final List<String> skills = [
      'Flutter', 'Dart', 'Firebase', 'Firestore', 'Authentication',
      'REST APIs', 'Provider', 'State Management', 'UI/UX Design',
      'Git & GitHub', 'CI/CD', 'Java', 'SQL',
    ];

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.1),
            blurRadius: 15.0,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: AppColors.accentPurple.withOpacity(0.1)),
      ),
      child: Wrap(
        spacing: isSmallScreen ? 8.0 : 12.0,
        runSpacing: isSmallScreen ? 10.0 : 12.0,
        alignment: WrapAlignment.center,
        children: skills.map((skill) => _buildSkillChip(skill, isSmallScreen)).toList(),
      ),
    );
  }

  Widget _buildSkillChip(String skill, bool isSmallScreen) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: (isSmallScreen ? screenWidth * 0.035 : 16.0).toDouble(),
        vertical: (isSmallScreen ? screenHeight * 0.008 : 10.0).toDouble(),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryBlue.withOpacity(0.1),
            AppColors.accentPurple.withOpacity(0.1),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25.0),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2), width: 1.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.05),
            blurRadius: 8.0,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.check_circle_rounded,
            color: AppColors.primaryBlue,
            size: isSmallScreen ? 14.0 : 16.0,
          ),
          SizedBox(width: screenWidth * 0.015),
          Text(
            skill,
            style: TextStyle(
              color: AppColors.primaryBlue,
              fontSize: isSmallScreen ? 13.0 : 14.0,
              fontWeight: FontWeight.w600,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}

// Social Media Item Model
class SocialMediaItem {
  final IconData icon;
  final String label;
  final String url;
  final Color color;

  SocialMediaItem({
    required this.icon,
    required this.label,
    required this.url,
    required this.color,
  });
}