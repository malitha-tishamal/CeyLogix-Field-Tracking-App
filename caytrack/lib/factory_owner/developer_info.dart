import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
// Note: You must add the 'font_awesome_flutter' package to your pubspec.yaml 
// to use the actual Font Awesome icons. Using Material Icons as proxies here.
// import 'package:font_awesome_flutter/font_awesome_flutter.dart'; 
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
 final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

 void _handleDrawerNavigate(String routeName) {
  Navigator.pop(context);
 }

 // --- URL Launcher Functions (Simplified and Consolidated) ---
 Future<void> _launchURL(String url) async {
  final Uri uri = Uri.parse(url);
  try {
   if (await canLaunchUrl(uri)) {
    await launchUrl(uri);
   } else {
    throw 'Could not launch $url';
   }
  } catch (e) {
   ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
     content: Text('Error: Could not open link. $e'),
     backgroundColor: Colors.red,
    ),
   );
  }
 }

 Future<void> _launchEmail() async {
  final Uri emailLaunchUri = Uri(
   scheme: 'mailto',
   path: 'malithatishamal@gmail.com', // Direct email path
   query: encodeQueryParameters(<String, String>{
    'subject': 'CeyLogix App Inquiry',
    'body': 'Hello Malitha, I would like to know more about your work...',
   }),
  );

  await _launchURL(emailLaunchUri.toString());
 }

 Future<void> _launchPhone(String phoneNumber) async {
  await _launchURL('tel:$phoneNumber');
 }

 String? encodeQueryParameters(Map<String, String> params) {
  return params.entries
    .map((e) => '${Uri.encodeComponent(e.key)}=${Uri.encodeComponent(e.value)}')
    .join('&');
 }

 @override
 Widget build(BuildContext context) {
  return Scaffold(
   key: _scaffoldKey,
   backgroundColor: AppColors.background,
   drawer: FactoryOwnerDrawer(
    onLogout: () {
     // Implement actual logout logic
     Navigator.of(context).pop();
    },
    onNavigate: _handleDrawerNavigate,
   ),
   body: SingleChildScrollView(
    child: Column(
     children: [
      _buildDeveloperHeader(context),
      DeveloperInfoContent(
       launchURL: _launchURL,
       launchEmail: _launchEmail,
       launchPhone: _launchPhone,
      ),
      Align(
       alignment: Alignment.bottomCenter,
       child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text(
         'CeyLogix Application v2.1.0',
         textAlign: TextAlign.center,
         style: TextStyle(
          color: AppColors.darkText.withOpacity(0.7),
          fontSize: 12,
         ),
        ),
       ),
      ),
      const SizedBox(height: 20),
     ],
    ),
   ),
  );
 }

 Widget _buildDeveloperHeader(BuildContext context) {
  return Container(
   width: double.infinity,
   padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
   decoration: BoxDecoration(
    gradient: LinearGradient(
     colors: [AppColors.accentPurple.withOpacity(0.6), AppColors.cardBackground],
     begin: Alignment.topCenter,
     end: Alignment.bottomCenter,
    ),
    borderRadius: const BorderRadius.only(
     bottomLeft: Radius.circular(30),
     bottomRight: Radius.circular(30),
    ),
    boxShadow: const [
     BoxShadow(
      color: Color(0x10000000),
      blurRadius: 15,
      offset: Offset(0, 5),
     ),
    ],
   ),
   child: SafeArea(
    child: Column(
     crossAxisAlignment: CrossAxisAlignment.center,
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
        const Text(
         'Developer About Me',
         style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: AppColors.headerTextDark,
         ),
        ),
        IconButton(
         icon: const Icon(Icons.notifications_none, color: AppColors.headerTextDark, size: 28),
         onPressed: () {},
        ),
       ],
      ),
      const SizedBox(height: 20),
      const Text(
       'Meet the creator of CeyLogix Factory Management System.',
       style: TextStyle(
        fontSize: 14,
        color: AppColors.headerTextDark,
       ),
       textAlign: TextAlign.center,
      ),
      const SizedBox(height: 10),
     ],
    ),
   ),
  );
 }
}

// -----------------------------------------------------------------------------
// --- DEVELOPER INFO CONTENT WIDGET (Updated with new sections) ---
// -----------------------------------------------------------------------------
class DeveloperInfoContent extends StatelessWidget {
 // Callbacks to access URL/Email launching functions from the State object
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
  const String profileImageUrl = 'https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D&auto=format&fit=crop&w=300&q=80';

  return Padding(
   padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 30.0),
   child: Column(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
     // Developer Image (Unchanged)
     Container(
      width: 150,
      height: 150,
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
         color: AppColors.primaryBlue.withOpacity(0.3),
         blurRadius: 15,
         offset: const Offset(0, 8),
        ),
       ],
      ),
      child: ClipOval(
       child: Image.network(
        profileImageUrl,
        fit: BoxFit.cover,
        loadingBuilder: (context, child, loadingProgress) {
         if (loadingProgress == null) return child;
         return Center(
          child: CircularProgressIndicator(
           value: loadingProgress.expectedTotalBytes != null
             ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
             : null,
          ),
         );
        },
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
     ),

     const SizedBox(height: 30),

     // Developer Name and Title (Unchanged)
     const Text(
      'Malitha Tishamal',
      style: TextStyle(
       fontSize: 26,
       fontWeight: FontWeight.w900,
       color: AppColors.darkText,
      ),
     ),
     const SizedBox(height: 5),
     Text(
      'Full Stack Developer',
      style: TextStyle(
       fontSize: 18,
       fontWeight: FontWeight.w600,
       color: AppColors.primaryBlue,
      ),
     ),

     const SizedBox(height: 30),

     // --- 💡 NEW: Social Media Section ---
     _buildSectionHeader(title: "Connect with me", icon: Icons.share_rounded),
     const SizedBox(height: 15),
     _buildSocialMediaButtons(context),

     const SizedBox(height: 40),

     // --- 💡 NEW: Contact Details Section ---
     _buildSectionHeader(title: "Contact Details", icon: Icons.contact_mail_rounded),
     const SizedBox(height: 15),
     _buildContactDetailsCard(context),

     const SizedBox(height: 40),

     // --- 💡 NEW: My Skills Section ---
     _buildSectionHeader(title: "Technical Skills", icon: Icons.code_rounded),
     const SizedBox(height: 15),
     _buildSkillsChips(),

     const SizedBox(height: 40),

     // --- 💡 Projects/Other Info Section ---
     _buildSectionHeader(title: "About the Application", icon: Icons.info_rounded),
     const SizedBox(height: 15),
     _buildInfoCard(
      icon: Icons.integration_instructions_rounded,
      title: 'Technical Stack',
      content: 'The CeyLogix application is built using Flutter (Dart) for cross-platform mobile development and Firebase (Firestore, Auth) for a scalable and secure backend service.',
      buttonText: 'View GitHub',
      onButtonPressed: () => launchURL('https://github.com/malithatishamal/ceylogix-app-repo'), // Placeholder URL
     ),
    ],
   ),
  );
 }

 Widget _buildSectionHeader({required String title, required IconData icon}) {
  return Row(
   mainAxisAlignment: MainAxisAlignment.start,
   children: [
    Icon(icon, color: AppColors.primaryBlue, size: 20),
    const SizedBox(width: 8),
    Text(
     title,
     style: const TextStyle(
      fontSize: 18,
      fontWeight: FontWeight.bold,
      color: AppColors.darkText,
     ),
    ),
    const SizedBox(width: 10),
    Expanded(child: Divider(color: AppColors.primaryBlue.withOpacity(0.3))),
   ],
  );
 }

 // --- Social Media Widgets ---
 Widget _buildSocialMediaButtons(BuildContext context) {
  final List<SocialMediaItem> socialItems = [
   // Use FaIcons from 'font_awesome_flutter' here for a better look
   SocialMediaItem(icon: Icons.facebook, label: 'Facebook', url: 'https://facebook.com/malitha.tishamal', color: const Color(0xFF1877F2)),
   SocialMediaItem(icon: Icons.camera_alt, label: 'Instagram', url: 'https://instagram.com/malitha_tishamal', color: const Color(0xFFE4405F)),
   SocialMediaItem(icon: Icons.code, label: 'GitHub', url: 'https://github.com/malithatishamal', color: const Color(0xFF24292E)),
   SocialMediaItem(icon: Icons.link, label: 'LinkedIn', url: 'https://linkedin.com/in/malithatishamal', color: const Color(0xFF0A66C2)),
  ];

  return Wrap(
   spacing: 15,
   runSpacing: 15,
   children: socialItems.map((item) {
    return _buildSocialMediaButton(item);
   }).toList(),
  );
 }

 Widget _buildSocialMediaButton(SocialMediaItem item) {
  return Tooltip(
   message: 'Open ${item.label}',
   child: GestureDetector(
    onTap: () => launchURL(item.url),
    child: Container(
     width: 55,
     height: 55,
     decoration: BoxDecoration(
      color: item.color.withOpacity(0.1),
      shape: BoxShape.circle,
      border: Border.all(color: item.color.withOpacity(0.3), width: 2),
      boxShadow: [
       BoxShadow(
        color: item.color.withOpacity(0.2),
        blurRadius: 8,
        offset: const Offset(0, 3),
       ),
      ],
     ),
     child: Icon(
      item.icon,
      color: item.color,
      size: 26,
     ),
    ),
   ),
  );
 }

 // --- Contact Details Widgets ---
 Widget _buildContactDetailsCard(BuildContext context) {
  return Container(
   padding: const EdgeInsets.all(18),
   decoration: BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(15),
    boxShadow: [
     BoxShadow(
      color: AppColors.primaryBlue.withOpacity(0.08),
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
      value: '+94 71 XXX 5678', // Placeholder for privacy
      color: AppColors.secondaryColor,
      onTap: () => launchPhone('+9471XXXX5678'),
     ),
     _buildContactItem(
      icon: Icons.location_on_rounded,
      label: 'Location',
      value: 'Colombo, Sri Lanka',
      color: AppColors.primaryBlue,
      isLast: true,
      onTap: () => launchURL('https://maps.app.goo.gl/Colombo'),
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
     borderRadius: BorderRadius.circular(10),
     child: Padding(
      padding: const EdgeInsets.symmetric(vertical: 10.0, horizontal: 8.0),
      child: Row(
       children: [
        Container(
         padding: const EdgeInsets.all(8),
         decoration: BoxDecoration(color: color.withOpacity(0.15), shape: BoxShape.circle),
         child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(width: 15),
        Expanded(
         child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
           Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.darkText.withOpacity(0.6))),
           const SizedBox(height: 2),
           Text(value, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.darkText)),
          ],
         ),
        ),
        Icon(Icons.chevron_right_rounded, color: AppColors.primaryBlue.withOpacity(0.4), size: 18),
       ],
      ),
     ),
    ),
    if (!isLast) Divider(color: AppColors.accentPurple.withOpacity(0.1), height: 1),
   ],
  );
 }

 // --- Skills Widgets ---
 Widget _buildSkillsChips() {
  final List<String> skills = [
   'Flutter', 'Dart', 'Firebase', 'Firestore', 'Authentication',
   'REST APIs', 'Provider/Riverpod', 'State Management', 'UI/UX Design',
   'Git & GitHub', 'CI/CD', 'Java (Backend)', 'SQL',
  ];

  return Wrap(
   spacing: 10,
   runSpacing: 10,
   children: skills.map((skill) => _buildSkillChip(skill)).toList(),
  );
 }

 Widget _buildSkillChip(String skill) {
  return Container(
   padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
   decoration: BoxDecoration(
    color: AppColors.primaryBlue.withOpacity(0.1),
    borderRadius: BorderRadius.circular(20),
    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3), width: 1),
   ),
   child: Text(
    skill,
    style: const TextStyle(
     color: AppColors.primaryBlue,
     fontSize: 13,
     fontWeight: FontWeight.w600,
    ),
   ),
  );
 }

 // --- Info Card (Reused but simplified for the content) ---
 Widget _buildInfoCard({
  required IconData icon,
  required String title,
  required String content,
  required String buttonText,
  required VoidCallback onButtonPressed,
 }) {
  return Container(
   width: double.infinity,
   padding: const EdgeInsets.all(20),
   decoration: BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(15),
    boxShadow: [
     BoxShadow(
      color: AppColors.primaryBlue.withOpacity(0.08),
      blurRadius: 15,
      offset: const Offset(0, 5),
     ),
    ],
    border: Border.all(color: AppColors.accentPurple.withOpacity(0.1)),
   ),
   child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
     Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
       Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
         color: AppColors.accentPurple.withOpacity(0.1),
         shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppColors.accentPurple, size: 24),
       ),
       const SizedBox(width: 15),
       Expanded(
        child: Column(
         crossAxisAlignment: CrossAxisAlignment.start,
         children: [
          Text(
           title,
           style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: AppColors.darkText,
           ),
          ),
          const SizedBox(height: 8),
          Text(
           content,
           style: TextStyle(
            fontSize: 14,
            color: AppColors.darkText.withOpacity(0.7),
            height: 1.4,
           ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
           onPressed: onButtonPressed,
           style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryBlue,
            foregroundColor: Colors.white,
            elevation: 2,
            shape: RoundedRectangleBorder(
             borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
           ),
           child: Text(
            buttonText,
            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
           ),
          ),
         ],
        ),
       ),
      ],
     ),
    ],
   ),
  );
 }
}

// Social Media Item Model (Unchanged)
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