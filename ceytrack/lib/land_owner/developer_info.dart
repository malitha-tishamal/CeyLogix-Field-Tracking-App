// developer_info.dart — MODERN BLUE THEME + PER‑SKILL COLOURS (original)
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'land_owner_drawer.dart';

// ==================== BLUE THEME TOKENS (unified) ====================
class AppColors {
  static const Color background        = Color(0xFFF4F6FA);
  static const Color darkText          = Color(0xFF1A1D26);
  static const Color primaryBlue       = Color(0xFF2764E7);
  static const Color lightBlue         = Color(0xFF5B8DF5);
  static const Color mediumBlue        = Color(0xFF3D6DF2);
  static const Color softBlue          = Color(0xFF8DAAFF);
  static const Color accentRed         = Color(0xFFE53935);
  static const Color cardBackground    = Colors.white;
  static const Color secondaryText     = Color(0xFF6A798A);
  static const Color headerGradientStart = Color(0xFF869AEC);
  static const Color headerGradientEnd   = Color(0xFFF7FAFF);
  static const Color headerTextDark      = Color(0xFF333333);
  static const Color textTertiary        = Color(0xFFB0BAC8);
  static const Color hover               = Color(0xFFF8FAFC);
  static const Color border              = Color(0xFFE8ECF2);
  static const Color errorRed            = Color(0xFFD32F2F);
  
  // Keep original brand colours for social/contact icons
  static const Color emailColor  = Color(0xFFEA4335);
  static const Color phoneColor  = Color(0xFF34A853);
  static const Color locationColor = Color(0xFF4285F4);
}

class _D {
  static const double cardRadius = 10.0;
  static const double cardPad    = 10.0;
  static const double sectionGap = 14.0;
  static const double iconBox    = 28.0;
  static const double iconSize   = 14.0;
}

// Responsive helper
extension ResponsiveExtensions on BuildContext {
  double get paddingSmall => MediaQuery.of(this).size.width < 600 ? 12.0 : 16.0;
  double get paddingMedium => MediaQuery.of(this).size.width < 600 ? 16.0 : 20.0;
  double get paddingLarge => MediaQuery.of(this).size.width < 600 ? 20.0 : 24.0;
  bool get isSmallScreen => MediaQuery.of(this).size.width < 600;
  bool get isMediumScreen => MediaQuery.of(this).size.width >= 600 && MediaQuery.of(this).size.width < 900;
}

// ==================== MAIN PAGE ====================
class DeveloperInfoPage extends StatefulWidget {
  const DeveloperInfoPage({super.key});

  @override
  State<DeveloperInfoPage> createState() => _DeveloperInfoPageState();
}

class _DeveloperInfoPageState extends State<DeveloperInfoPage> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  String _loggedInUserName = 'Loading...';
  String _factoryName = 'Loading...';
  String _userRole = 'Factory Owner';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchHeaderData();
  }

  void _fetchHeaderData() async {
    final user = currentUser;
    if (user == null) return;
    final String uid = user.uid;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner';
          _profileImageUrl = userData?['profileImageUrl'];
          _userRole = userData?['role'] ?? 'Factory Owner';
        });
      }
      final factoryDoc = await FirebaseFirestore.instance.collection('factories').doc(uid).get();
      if (factoryDoc.exists) {
        setState(() {
          _factoryName = factoryDoc.data()?['factoryName'] ?? 'Factory';
        });
      }
    } catch (e) {
      debugPrint("Error fetching header data: $e");
      setState(() {
        _loggedInUserName = 'Data Error';
        _factoryName = 'Error';
      });
    }
  }

  void _handleDrawerNavigate(String routeName) => Navigator.pop(context);

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
      await launchUrl(uri, mode: LaunchMode.externalApplication);
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

  // ===================== MODERN HEADER (blue theme) =====================
  Widget _buildModernHeader(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    final sm = w < 360;
    final md = w >= 360 && w < 400;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(ctx).padding.top + 2,
        left: 16, right: 16, bottom: 12,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x10000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu, color: AppColors.headerTextDark, size: 24),
                ),
              ),
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_loggedInUserName,
                    style: TextStyle(
                      fontSize: sm ? 14 : md ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    )),
                  const SizedBox(height: 3),
                  Text('Factory: $_factoryName',
                    style: TextStyle(
                      fontSize: sm ? 9 : md ? 10 : 11,
                      color: AppColors.headerTextDark.withOpacity(0.75),
                    )),
                  Text('($_userRole)',
                    style: TextStyle(
                      fontSize: sm ? 9 : md ? 10 : 11,
                      color: AppColors.headerTextDark.withOpacity(0.75),
                    )),
                ],
              ),
              const Spacer(),
              _buildAvatar(),
            ],
          ),
          const SizedBox(height: 12),
          const Text('About Developer',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.headerTextDark)),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: NetworkImage(_profileImageUrl!),
        backgroundColor: Colors.grey.shade200,
        onBackgroundImageError: (_, __) => setState(() => _profileImageUrl = null),
      );
    }
    return CircleAvatar(
      radius: 40,
      backgroundColor: AppColors.primaryBlue.withOpacity(0.15),
      child: const Icon(Icons.person, color: AppColors.primaryBlue, size: 40),
    );
  }

  Widget _buildFooter(double w) => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
    child: Text('Developed By Malitha Tishamal',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: w * 0.028, color: AppColors.secondaryText)),
  );

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: LandOwnerDrawer(
        onLogout: () {
          FirebaseAuth.instance.signOut();
          Navigator.pop(context);
        },
        onNavigate: _handleDrawerNavigate,
      ),
      body: SafeArea(
        child: Column(
          children: [
            _buildModernHeader(context),
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  children: [
                    DeveloperInfoContent(
                      launchURL: _launchURL,
                      launchEmail: _launchEmail,
                      launchPhone: _launchPhone,
                      screenWidth: screenWidth,
                      screenHeight: screenHeight,
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
            _buildFooter(screenWidth),
          ],
        ),
      ),
    );
  }
}

// ===================== DEVELOPER INFO CONTENT (BLUE THEME, PER-SKILL COLOURS) =====================
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
    final isSmall = screenWidth < 360;
    const String profileImageUrl = 'assets/developer/developer_photo.png';

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: screenWidth * 0.04, vertical: screenHeight * 0.02),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Developer Image (blue gradient)
          Container(
            width: screenWidth * 0.35,
            height: screenWidth * 0.35,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [AppColors.primaryBlue, AppColors.mediumBlue],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              border: Border.all(color: Colors.white, width: isSmall ? 2.5 : 3),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primaryBlue.withOpacity(0.3),
                  blurRadius: 15,
                  offset: const Offset(0, 5),
                ),
              ],
            ),
            child: ClipOval(
              child: Image.asset(
                profileImageUrl,
                fit: BoxFit.cover,
                errorBuilder: (_, __, ___) => const Icon(Icons.person, size: 50, color: Colors.white),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Malitha Tishamal',
            style: TextStyle(
              fontSize: isSmall ? 20 : 24,
              fontWeight: FontWeight.bold,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: AppColors.primaryBlue.withOpacity(0.1),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              'Full Stack Developer',
              style: TextStyle(
                fontSize: isSmall ? 12 : 14,
                fontWeight: FontWeight.w600,
                color: AppColors.primaryBlue,
              ),
            ),
          ),
          const SizedBox(height: 24),

          // Connect with me section (blue theme)
          _buildSectionHeader('Connect with me', Icons.share_rounded, isSmall),
          const SizedBox(height: 12),
          _buildSocialMediaButtons(isSmall),
          const SizedBox(height: 24),

          // Contact Details (brand colours preserved for icons)
          _buildSectionHeader('Contact Details', Icons.contact_mail_rounded, isSmall),
          const SizedBox(height: 12),
          _buildContactDetailsCard(isSmall),
          const SizedBox(height: 24),

          // Technical Skills (ORIGINAL PER-SKILL COLOURS)
          _buildSectionHeader('Technical Skills', Icons.code_rounded, isSmall),
          const SizedBox(height: 12),
          _buildSkillsChips(isSmall),
          const SizedBox(height: 8),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, IconData icon, bool isSmall) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primaryBlue.withOpacity(0.05),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(5),
            decoration: const BoxDecoration(color: AppColors.primaryBlue, shape: BoxShape.circle),
            child: Icon(icon, color: Colors.white, size: isSmall ? 14 : 16),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              title,
              style: TextStyle(fontSize: isSmall ? 14 : 16, fontWeight: FontWeight.bold, color: AppColors.darkText),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSocialMediaButtons(bool isSmall) {
    final List<SocialMediaItem> items = [
      SocialMediaItem(icon: FontAwesomeIcons.facebookF, label: 'Facebook', url: 'https://facebook.com/malitha.tishamal', color: const Color(0xFF1877F2)),
      SocialMediaItem(icon: FontAwesomeIcons.instagram, label: 'Instagram', url: 'https://instagram.com/malithatishamal', color: const Color(0xFFE4405F)),
      SocialMediaItem(icon: FontAwesomeIcons.github, label: 'GitHub', url: 'https://github.com/malithatishamal', color: const Color(0xFF181717)),
      SocialMediaItem(icon: FontAwesomeIcons.linkedinIn, label: 'LinkedIn', url: 'https://linkedin.com/in/malithatishamal', color: const Color(0xFF0A66C2)),
      SocialMediaItem(icon: FontAwesomeIcons.twitter, label: 'Twitter', url: 'https://twitter.com/malithatishamal', color: const Color(0xFF1DA1F2)),
      SocialMediaItem(icon: FontAwesomeIcons.globe, label: 'Portfolio', url: 'https://malithatishamal.42web.io', color: const Color(0xFF6E5494)),
    ];

    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(_D.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Wrap(
        spacing: isSmall ? 12 : 16,
        runSpacing: isSmall ? 16 : 20,
        alignment: WrapAlignment.center,
        children: items.map((item) => _buildSocialButton(item, isSmall)).toList(),
      ),
    );
  }

  Widget _buildSocialButton(SocialMediaItem item, bool isSmall) {
    final double size = isSmall ? 50 : 60;
    final double iconSize = isSmall ? 22 : 28;
    return SizedBox(
      width: size + 10,
      child: Column(
        children: [
          GestureDetector(
            onTap: () => launchURL(item.url),
            child: Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: [item.color.withOpacity(0.9), item.color], begin: Alignment.topLeft, end: Alignment.bottomRight),
                shape: BoxShape.circle,
                boxShadow: [BoxShadow(color: item.color.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 3))],
              ),
              child: Center(child: FaIcon(item.icon, color: Colors.white, size: iconSize)),
            ),
          ),
          const SizedBox(height: 6),
          Text(
            item.label,
            style: TextStyle(fontSize: isSmall ? 10 : 11, color: AppColors.secondaryText),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }

  Widget _buildContactDetailsCard(bool isSmall) {
    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(_D.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(
        children: [
          _buildContactTile(
            icon: Icons.email_rounded,
            label: 'Email',
            value: 'malithatishamal@gmail.com',
            color: AppColors.emailColor,
            onTap: launchEmail,
            isSmall: isSmall,
          ),
          const SizedBox(height: 10),
          _buildContactTile(
            icon: Icons.call_rounded,
            label: 'Mobile',
            value: '+94 78 553 0992',
            color: AppColors.phoneColor,
            onTap: () => launchPhone('+94785530992'),
            isSmall: isSmall,
          ),
          const SizedBox(height: 10),
          _buildContactTile(
            icon: Icons.location_on_rounded,
            label: 'Location',
            value: 'Matara, Sri Lanka',
            color: AppColors.locationColor,
            onTap: () => launchURL('https://maps.app.goo.gl/Matara'),
            isSmall: isSmall,
          ),
        ],
      ),
    );
  }

  Widget _buildContactTile({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required VoidCallback onTap,
    required bool isSmall,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: EdgeInsets.symmetric(horizontal: 12, vertical: isSmall ? 10 : 12),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
              child: Icon(icon, color: color, size: isSmall ? 18 : 20),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: TextStyle(fontSize: isSmall ? 10 : 11, color: AppColors.secondaryText)),
                  const SizedBox(height: 2),
                  Text(value, style: TextStyle(fontSize: isSmall ? 13 : 14, fontWeight: FontWeight.w600, color: AppColors.darkText)),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: color, size: isSmall ? 12 : 14),
          ],
        ),
      ),
    );
  }

  // ===================== SKILLS WITH ORIGINAL PER-SKILL COLOURS =====================
  Widget _buildSkillsChips(bool isSmall) {
    final List<String> skills = [
      'Flutter', 'Dart', 'Firebase', 'Firestore', 'Authentication',
      'REST APIs', 'Provider', 'State Management', 'UI/UX Design',
      'Git & GitHub', 'CI/CD', 'Java', 'SQL',
    ];
    
    final Map<String, Color> skillColors = {
      'Flutter': const Color(0xFF027DFD),
      'Dart': const Color(0xFF00B4AB),
      'Firebase': const Color(0xFFFFA611),
      'Firestore': const Color(0xFFFFA611),
      'Authentication': const Color(0xFF4285F4),
      'REST APIs': const Color(0xFF9C27B0),
      'Provider': const Color(0xFF2196F3),
      'State Management': const Color(0xFF3F51B5),
      'UI/UX Design': const Color(0xFF009688),
      'Git & GitHub': const Color(0xFFF05032),
      'CI/CD': const Color(0xFF2088FF),
      'Java': const Color(0xFFB07219),
      'SQL': const Color(0xFF4479A1),
    };

    return Container(
      padding: EdgeInsets.all(isSmall ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(_D.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Wrap(
        spacing: isSmall ? 8 : 10,
        runSpacing: isSmall ? 10 : 12,
        alignment: WrapAlignment.center,
        children: skills.map((skill) => _buildSkillChip(skill, skillColors[skill] ?? AppColors.primaryBlue, isSmall)).toList(),
      ),
    );
  }

  Widget _buildSkillChip(String skill, Color color, bool isSmall) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 10 : 14, vertical: isSmall ? 6 : 8),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [color.withOpacity(0.9), color],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(25),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.3),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.check_circle_rounded, color: Colors.white, size: isSmall ? 12 : 14),
          const SizedBox(width: 6),
          Text(
            skill,
            style: TextStyle(
              fontSize: isSmall ? 12 : 13,
              fontWeight: FontWeight.w600,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class SocialMediaItem {
  final IconData icon;
  final String label;
  final String url;
  final Color color;
  SocialMediaItem({required this.icon, required this.label, required this.url, required this.color});
}