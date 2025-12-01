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
    setState(() {
      _landID = uid.substring(0, 8); 
    });

    try {
      // 1. Fetch User Name and Role from 'users' collection
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner Name Missing';
          _profileImageUrl = userData?['profileImageUrl'];
          _userRole = userData?['role'] ?? 'Land Owner'; // Updated to use role from database
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
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
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
          // 🌟 FIXED HEADER - Won't scroll with content
          _buildDashboardHeader(context),
          
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
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                ),
                
                // Footer (Fixed at bottom of content area)
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

  // 🌟 FIXED HEADER - Factory Owner Dashboard Style with Firebase Data
  Widget _buildDashboardHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
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
                    // 1. Land Name
                    Text(
                      _landName, 
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headerTextDark,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    // 2. Logged-in User Name and Role
                    Text(
                      'Logged in as: $_loggedInUserName \n($_userRole)', 
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
          
          // Page Title with Land ID
          Text(
            'Developer About Me',
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
}

// -----------------------------------------------------------------------------
// --- DEVELOPER INFO CONTENT WIDGET ---
// -----------------------------------------------------------------------------
class DeveloperInfoContent extends StatelessWidget {
  final Function(String url) launchURL;
  final VoidCallback launchEmail;
  final Function(String phoneNumber) launchPhone;

  const DeveloperInfoContent({
    super.key,
    required this.launchURL,
    required this.launchEmail,
    required this.launchPhone,
  });

  @override
  Widget build(BuildContext context) {
    const String profileImageUrl = 'assets/developer/developer_photo.png';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Developer Image with improved styling
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                colors: [AppColors.primaryBlue, AppColors.accentPurple],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white, width: 4),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.4),
                  blurRadius: 20,
                  spreadRadius: 2,
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
                      child: const Icon(Icons.person, size: 60, color: Colors.white),
                    ),
                  ),
                ),
                Container(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 2),
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 30),

          // Developer Name and Title with improved typography
          const Text(
            'Malitha Tishamal',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w900,
              color: AppColors.darkText,
              letterSpacing: -0.5,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
            ),
            child: Text(
              'Full Stack Developer',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ),

          const SizedBox(height: 30),

          // --- 🌟 UPDATED Social Media Section with Font Awesome Icons ---
          _buildSectionHeader(title: "Connect with me", icon: Icons.share_rounded),
          const SizedBox(height: 20),
          _buildSocialMediaButtons(),

          const SizedBox(height: 40),

          // --- 💡 Contact Details Section ---
          _buildSectionHeader(title: "Contact Details", icon: Icons.contact_mail_rounded),
          const SizedBox(height: 20),
          _buildContactDetailsCard(),

          const SizedBox(height: 40),

          // --- 💡 My Skills Section ---
          _buildSectionHeader(title: "Technical Skills", icon: Icons.code_rounded),
          const SizedBox(height: 20),
          _buildSkillsChips(),

          const SizedBox(height: 40),
        ],
      ),
    );
  }

  Widget _buildSectionHeader({required String title, required IconData icon}) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
        ],
      ),
    );
  }

  // --- 🌟 UPDATED Social Media Widgets: Font Awesome Icons and Links ---
  Widget _buildSocialMediaButtons() {
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
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: AppColors.accentPurple.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          const Text(
            'Follow me on social media',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.darkText,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 20,
            runSpacing: 20,
            children: socialItems.map((item) {
              return _buildSocialMediaButton(item);
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialMediaButton(SocialMediaItem item) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Tooltip(
          message: 'Open ${item.label}',
          child: GestureDetector(
            onTap: () => launchURL(item.url),
            child: Container(
              width: 70,
              height: 70,
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
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: Center(
                child: FaIcon(
                  item.icon,
                  color: Colors.white,
                  size: 40,
                ),
              ),
            ),
          ),
        ),

        const SizedBox(height: 10),

        Text(
          item.label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: AppColors.darkText.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  // --- Contact Details Widgets: Clickable Email/Phone ---
  Widget _buildContactDetailsCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.1),
            blurRadius: 15,
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
          ),
          _buildContactItem(
            icon: Icons.call_rounded,
            label: 'Mobile Number',
            value: '+94 78 553 0992',
            color: AppColors.secondaryColor,
            onTap: () => launchPhone('+94785530992'),
          ),
          _buildContactItem(
            icon: Icons.location_on_rounded,
            label: 'Location',
            value: 'Matara, Sri Lanka',
            color: AppColors.primaryBlue,
            isLast: true,
            onTap: () => launchURL('https://maps.app.goo.gl/Matara'),
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
  }) {
    return Column(
      children: [
        InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: color.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: color.withOpacity(0.1)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(icon, color: color, size: 22),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w500,
                          color: AppColors.darkText.withOpacity(0.6),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        value,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.darkText,
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: color,
                    size: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
        if (!isLast) const SizedBox(height: 12),
      ],
    );
  }

  // --- Skills Widgets with improved design ---
  Widget _buildSkillsChips() {
    final List<String> skills = [
      'Flutter', 'Dart', 'Firebase', 'Firestore', 'Authentication',
      'REST APIs', 'Provider/Riverpod', 'State Management', 'UI/UX Design',
      'Git & GitHub', 'CI/CD', 'Java (Backend)', 'SQL',
    ];

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 5),
          ),
        ],
        border: Border.all(color: AppColors.accentPurple.withOpacity(0.1)),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 12,
        children: skills.map((skill) => _buildSkillChip(skill)).toList(),
      ),
    );
  }

  Widget _buildSkillChip(String skill) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.primaryBlue.withOpacity(0.1), AppColors.accentPurple.withOpacity(0.1)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2), width: 1),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryBlue.withOpacity(0.05),
            blurRadius: 8,
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
            size: 16,
          ),
          const SizedBox(width: 6),
          Text(
            skill,
            style: const TextStyle(
              color: AppColors.primaryBlue,
              fontSize: 14,
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