import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'land_owner_drawer.dart';

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
  String _landName = 'Loading Land...';
  String _userRole = 'Land Owner';
  String _landID = 'L-ID';
  String? _profileImageUrl;
  
  // Responsive variables
  late bool _isPortrait;
  late double _screenWidth;
  late double _screenHeight;

  @override
  void initState() {
    super.initState();
    _fetchHeaderData();
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

  // --- DATA FETCHING FUNCTION ---
  void _fetchHeaderData() async {
    final user = currentUser;
    if (user == null) {
      return;
    }
    
    final String uid = user.uid;
    setState(() {
      _landID = uid.length >= 8 ? uid.substring(0, 8) : uid.padRight(8, '0');
    });

    try {
      // 1. Fetch User Name and Role from 'users' collection
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner Name Missing';
          _profileImageUrl = userData?['profileImageUrl'];
          _userRole = userData?['role'] ?? 'Land Owner';
        });
      }
      
      // 2. Fetch Land Name from 'lands' collection
      final landDoc = await FirebaseFirestore.instance.collection('lands').doc(uid).get();
      if (landDoc.exists) {
        setState(() {
          _landName = landDoc.data()?['landName'] ?? 'Land Name Missing';
        });
      }

    } catch (e) {
      debugPrint("Error fetching header data: $e");
      setState(() {
        _loggedInUserName = 'Data Error';
        _landName = 'Data Error';
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
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    _updateScreenDimensions();
    final isSmallScreen = _screenWidth < 360;
    final isMediumScreen = _screenWidth >= 360 && _screenWidth < 400;
    
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: LandOwnerDrawer(
        onLogout: () {
          Navigator.of(context).pop();
        },
        onNavigate: _handleDrawerNavigate,
      ),
      body: Column(
        children: [
          // 🌟 FIXED HEADER - Responsive
          _buildDashboardHeader(context, isSmallScreen, isMediumScreen),
          
          // 🌟 SCROLLABLE CONTENT ONLY with Footer
          Expanded(
            child: Column(
              children: [
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Column(
                      children: [
                        // Pass the launcher functions to the content widget
                        DeveloperInfoContent(
                          screenWidth: _screenWidth,
                          screenHeight: _screenHeight,
                          isPortrait: _isPortrait,
                          launchURL: _launchURL,
                          launchEmail: _launchEmail,
                          launchPhone: _launchPhone,
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                
                // Footer (Fixed at bottom of content area)
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                  child: Text(
                    'Developed by Malitha Tishamal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.darkText.withOpacity(0.7),
                      fontSize: isSmallScreen ? 11 : 12,
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

  // 🌟 FIXED HEADER - Responsive version
  Widget _buildDashboardHeader(BuildContext context, bool isSmallScreen, bool isMediumScreen) {
    final topPadding = MediaQuery.of(context).padding.top + 10;
    final horizontalPadding = isSmallScreen ? 16.0 : 20.0;
    final profileSize = isSmallScreen ? 60.0 : 70.0;
    final menuIconSize = isSmallScreen ? 24.0 : 28.0;
    final nameFontSize = isSmallScreen ? 16.0 : 20.0;
    final landFontSize = isSmallScreen ? 14.0 : 16.0;
    final titleFontSize = isSmallScreen ? 14.0 : 16.0;

    return Container(
      padding: EdgeInsets.only(
        top: topPadding,
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: isSmallScreen ? 16.0 : 20.0,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF869AEC), AppColors.headerGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 3),
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
                icon: Icon(Icons.menu, color: AppColors.headerTextDark, size: menuIconSize),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: menuIconSize + 16,
                  minHeight: menuIconSize + 16,
                ),
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 8.0 : 10.0),
          
          Row(
            children: [
              // Profile Picture with Firebase image
              Container(
                width: profileSize,
                height: profileSize,
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
                    width: isSmallScreen ? 2.0 : 3.0
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.3),
                      blurRadius: isSmallScreen ? 8.0 : 10.0,
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
                        color: Colors.white
                      )
                    : null,
              ),
              
              SizedBox(width: isSmallScreen ? 12.0 : 15.0),
              
              // User Info Display from Firebase
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Land Owner Name
                    Text(
                      _loggedInUserName,
                      style: TextStyle(
                        fontSize: nameFontSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headerTextDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    //Land Name Name and Role
                    Text(
                      'Land Name: $_landName \n($_userRole)', 
                      style: TextStyle(
                        fontSize: landFontSize,
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
          
          SizedBox(height: isSmallScreen ? 20.0 : 25.0), 
          
          // Page Title with Land ID
          Text(
            'Developer About Me',
            style: TextStyle(
              fontSize: titleFontSize,
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
  final double screenWidth;
  final double screenHeight;
  final bool isPortrait;
  final Function(String url) launchURL;
  final VoidCallback launchEmail;
  final Function(String phoneNumber) launchPhone;

  const DeveloperInfoContent({
    super.key,
    required this.screenWidth,
    required this.screenHeight,
    required this.isPortrait,
    required this.launchURL,
    required this.launchEmail,
    required this.launchPhone,
  });

  @override
  Widget build(BuildContext context) {
    final isSmallScreen = screenWidth < 360;
    final isMediumScreen = screenWidth >= 360 && screenWidth < 400;
    const String profileImageUrl = 'assets/developer/developer_photo.png';

    // Calculate responsive sizes
    final imageSize = isSmallScreen ? 150.0 : 
                     isMediumScreen ? 180.0 : 
                     (screenWidth > 600 ? 250.0 : 220.0);
    
    final horizontalPadding = isSmallScreen ? 16.0 : 
                            isMediumScreen ? 18.0 : 
                            (screenWidth > 600 ? 24.0 : 20.0);
    
    final verticalPadding = isSmallScreen ? 20.0 : 
                          isMediumScreen ? 25.0 : 
                          30.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding, 
        vertical: verticalPadding
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Developer Image with responsive sizing
          Container(
            width: imageSize,
            height: imageSize,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primaryBlue, AppColors.accentPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(
                color: Colors.white, 
                width: isSmallScreen ? 3.0 : 4.0
              ),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.3),
                  blurRadius: isSmallScreen ? 12.0 : 20.0,
                  spreadRadius: isSmallScreen ? 1.0 : 2.0,
                  offset: const Offset(0, 6),
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
                        size: imageSize * 0.3, 
                        color: Colors.white
                      ),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Colors.white.withOpacity(0.3), 
                      width: 1.5
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: isSmallScreen ? 20.0 : 30.0),

          // Developer Name and Title with responsive typography
          Text(
            'Malitha Tishamal',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 22.0 : 
                      isMediumScreen ? 24.0 : 
                      (screenWidth > 600 ? 32.0 : 28.0),
              fontWeight: FontWeight.w900,
              color: AppColors.darkText,
              letterSpacing: -0.5,
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 6.0 : 8.0),
          
          Container(
            padding: EdgeInsets.symmetric(
              horizontal: isSmallScreen ? 12.0 : 16.0, 
              vertical: isSmallScreen ? 4.0 : 6.0
            ),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
            ),
            child: Text(
              'Full Stack Developer',
              style: TextStyle(
                fontSize: isSmallScreen ? 14.0 : 
                        isMediumScreen ? 15.0 : 
                        16.0,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ),

          SizedBox(height: isSmallScreen ? 20.0 : 30.0),

          // --- 🌟 Responsive Social Media Section ---
          _buildSectionHeader(
            title: "Connect with me", 
            icon: Icons.share_rounded,
            isSmallScreen: isSmallScreen,
            isMediumScreen: isMediumScreen,
          ),
          SizedBox(height: isSmallScreen ? 15.0 : 20.0),
          _buildSocialMediaButtons(isSmallScreen, isMediumScreen),

          SizedBox(height: isSmallScreen ? 25.0 : 40.0),

          // --- 💡 Responsive Contact Details Section ---
          _buildSectionHeader(
            title: "Contact Details", 
            icon: Icons.contact_mail_rounded,
            isSmallScreen: isSmallScreen,
            isMediumScreen: isMediumScreen,
          ),
          SizedBox(height: isSmallScreen ? 15.0 : 20.0),
          _buildContactDetailsCard(isSmallScreen, isMediumScreen),

          SizedBox(height: isSmallScreen ? 25.0 : 40.0),

          // --- 💡 Responsive Skills Section ---
          _buildSectionHeader(
            title: "Technical Skills", 
            icon: Icons.code_rounded,
            isSmallScreen: isSmallScreen,
            isMediumScreen: isMediumScreen,
          ),
          SizedBox(height: isSmallScreen ? 15.0 : 20.0),
          _buildSkillsChips(isSmallScreen, isMediumScreen),

          SizedBox(height: isSmallScreen ? 25.0 : 40.0),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({
    required String title, 
    required IconData icon,
    required bool isSmallScreen,
    required bool isMediumScreen,
  }) {
    final iconSize = isSmallScreen ? 16.0 : 18.0;
    final titleFontSize = isSmallScreen ? 16.0 : 
                        isMediumScreen ? 17.0 : 
                        18.0;
    
    return Container(
      width: double.infinity,
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 6.0 : 8.0, 
        vertical: isSmallScreen ? 6.0 : 8.0
      ),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
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
              size: iconSize
            ),
          ),
          SizedBox(width: isSmallScreen ? 8.0 : 12.0),
          Flexible(
            child: Text(
              title,
              style: TextStyle(
                fontSize: titleFontSize,
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

  // --- 🌟 Responsive Social Media Widgets ---
  Widget _buildSocialMediaButtons(bool isSmallScreen, bool isMediumScreen) {
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

    // Determine columns based on screen width
    final columns = isSmallScreen ? 3 : 
                   (isMediumScreen ? 4 : 6);
    
    final buttonSize = isSmallScreen ? 55.0 : 
                      isMediumScreen ? 60.0 : 
                      70.0;
    
    final iconSize = isSmallScreen ? 24.0 : 
                    isMediumScreen ? 30.0 : 
                    40.0;
    
    final labelFontSize = isSmallScreen ? 10.0 : 
                         isMediumScreen ? 11.0 : 
                         12.0;

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 
                             isMediumScreen ? 16.0 : 
                             20.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.1),
            blurRadius: isSmallScreen ? 10.0 : 15.0,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: AppColors.accentPurple.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Text(
            'Follow me on social media',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 12.0 : 
                      isMediumScreen ? 13.0 : 
                      14.0,
              color: AppColors.darkText,
              fontWeight: FontWeight.w500,
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
          
          GridView.count(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            crossAxisCount: columns,
            mainAxisSpacing: isSmallScreen ? 12.0 : 20.0,
            crossAxisSpacing: isSmallScreen ? 12.0 : 20.0,
            childAspectRatio: 0.8,
            children: socialItems.map((item) {
              return _buildSocialMediaButton(
                item, 
                buttonSize, 
                iconSize, 
                labelFontSize,
                isSmallScreen
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialMediaButton(
    SocialMediaItem item, 
    double buttonSize, 
    double iconSize, 
    double labelFontSize,
    bool isSmallScreen
  ) {
    return Column(
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
                    blurRadius: isSmallScreen ? 8.0 : 12.0,
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

        SizedBox(height: isSmallScreen ? 6.0 : 10.0),

        Text(
          item.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: labelFontSize,
            fontWeight: FontWeight.w500,
            color: AppColors.darkText.withOpacity(0.7),
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );
  }

  // --- Responsive Contact Details Widgets ---
  Widget _buildContactDetailsCard(bool isSmallScreen, bool isMediumScreen) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 
                             isMediumScreen ? 16.0 : 
                             20.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.1),
            blurRadius: isSmallScreen ? 10.0 : 15.0,
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
            isMediumScreen: isMediumScreen,
          ),
          _buildContactItem(
            icon: Icons.call_rounded,
            label: 'Mobile Number',
            value: '+94 78 553 0992',
            color: AppColors.secondaryColor,
            onTap: () => launchPhone('+94785530992'),
            isSmallScreen: isSmallScreen,
            isMediumScreen: isMediumScreen,
          ),
          _buildContactItem(
            icon: Icons.location_on_rounded,
            label: 'Location',
            value: 'Matara, Sri Lanka',
            color: AppColors.primaryBlue,
            isLast: true,
            onTap: () => launchURL('https://maps.app.goo.gl/Matara'),
            isSmallScreen: isSmallScreen,
            isMediumScreen: isMediumScreen,
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
    required bool isSmallScreen,
    required bool isMediumScreen,
    bool isLast = false,
  }) {
    final iconSize = isSmallScreen ? 18.0 : 22.0;
    final labelFontSize = isSmallScreen ? 11.0 : 
                         isMediumScreen ? 12.0 : 
                         13.0;
    final valueFontSize = isSmallScreen ? 14.0 : 
                         isMediumScreen ? 15.0 : 
                         16.0;
    
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
          child: Container(
            padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
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
                    size: iconSize
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: labelFontSize,
                          fontWeight: FontWeight.w500,
                          color: AppColors.darkText.withOpacity(0.6),
                        ),
                      ),
                      SizedBox(height: isSmallScreen ? 3.0 : 4.0),
                      Text(
                        value,
                        style: TextStyle(
                          fontSize: valueFontSize,
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
                  padding: EdgeInsets.all(isSmallScreen ? 4.0 : 6.0),
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
        ),
        if (!isLast) SizedBox(height: isSmallScreen ? 8.0 : 12.0),
      ],
    );
  }

  // --- Responsive Skills Widgets ---
  Widget _buildSkillsChips(bool isSmallScreen, bool isMediumScreen) {
    final List<String> skills = [
      'Flutter', 'Dart', 'Firebase', 'Firestore', 'Authentication',
      'REST APIs', 'Provider/Riverpod', 'State Management', 'UI/UX Design',
      'Git & GitHub', 'CI/CD', 'Java', 'SQL',
    ];

    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 
                             isMediumScreen ? 16.0 : 
                             20.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.1),
            blurRadius: isSmallScreen ? 10.0 : 15.0,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: AppColors.accentPurple.withOpacity(0.1)),
      ),
      child: Wrap(
        spacing: isSmallScreen ? 8.0 : 12.0,
        runSpacing: isSmallScreen ? 8.0 : 12.0,
        children: skills.map((skill) => _buildSkillChip(
          skill, 
          isSmallScreen, 
          isMediumScreen
        )).toList(),
      ),
    );
  }

  Widget _buildSkillChip(String skill, bool isSmallScreen, bool isMediumScreen) {
    final chipFontSize = isSmallScreen ? 12.0 : 
                        isMediumScreen ? 13.0 : 
                        14.0;
    final iconSize = isSmallScreen ? 14.0 : 16.0;
    final horizontalPadding = isSmallScreen ? 12.0 : 
                             isMediumScreen ? 14.0 : 
                             16.0;
    final verticalPadding = isSmallScreen ? 6.0 : 
                           isMediumScreen ? 8.0 : 
                           10.0;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding, 
        vertical: verticalPadding
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primaryBlue.withOpacity(0.1), 
            AppColors.accentPurple.withOpacity(0.1)
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(
          color: AppColors.primaryBlue.withOpacity(0.2), 
          width: 1
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.05),
            blurRadius: 6,
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
            size: iconSize,
          ),
          SizedBox(width: isSmallScreen ? 4.0 : 6.0),
          Text(
            skill,
            style: TextStyle(
              color: AppColors.primaryBlue,
              fontSize: chipFontSize,
              fontWeight: FontWeight.w600,
            ),
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