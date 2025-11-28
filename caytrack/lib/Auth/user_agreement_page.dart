
import 'package:flutter/material.dart';
// Import the LoginPage to navigate to it
import 'login_page.dart'; 

// Assuming AppColors is accessible globally or via a shared file like main.dart
class AppColors {
 // Redefine colors locally for standalone file context, consistent with previous files
 static const Color background = Color(0xFFEEEBFF);
 static const Color darkText = Color(0xFF2C2A3A);
 static const Color primaryBlue = Color(0xFF2764E7);
}

class UserAgreementPage extends StatefulWidget {
 const UserAgreementPage({super.key});

 @override
 State<UserAgreementPage> createState() => _UserAgreementPageState();
}

class _UserAgreementPageState extends State<UserAgreementPage> {
 // State for scroll tracking and button enablement
 final ScrollController _scrollController = ScrollController();
 bool _isScrolledToBottom = false;

 @override
 void initState() {
  super.initState();
  _scrollController.addListener(_scrollListener);
 
  // Check initial scroll state in case the content is shorter than the screen
  WidgetsBinding.instance.addPostFrameCallback((_) {
   _checkIfScrolledToBottom();
  });
 }

 @override
 void dispose() {
  _scrollController.removeListener(_scrollListener);
  _scrollController.dispose();
  super.dispose();
 }

 // Check if the scroll has reached the bottom (with a small tolerance)
 void _checkIfScrolledToBottom() {
  if (!_scrollController.hasClients) return;

  final double maxScroll = _scrollController.position.maxScrollExtent;
  final double currentScroll = _scrollController.position.pixels;
 
  // Check if the user is within 5 pixels of the bottom
  if (currentScroll >= maxScroll - 5.0) {
   if (!_isScrolledToBottom) {
    setState(() {
     _isScrolledToBottom = true;
    });
   }
  } else {
   // If the user scrolls up after reaching the bottom, disable the button again
   if (_isScrolledToBottom) {
    setState(() {
     _isScrolledToBottom = false;
    });
   }
  }
 }

 void _scrollListener() {
  _checkIfScrolledToBottom();
 }

 // Helper widget for consistent section styling
 Widget _buildTermsSection({required String title, required String content, required Color darkText}) {
  return Padding(
   padding: const EdgeInsets.only(bottom: 20.0),
   child: Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
     Text(
      title,
      style: TextStyle(
       fontSize: 16,
       fontWeight: FontWeight.bold,
       color: darkText.withOpacity(0.9),
       fontFamily: 'Inter',
      ),
     ),
     const SizedBox(height: 8),
     Text(
      content,
      style: TextStyle(
       fontSize: 14,
       height: 1.5,
       color: darkText.withOpacity(0.8),
       fontFamily: 'Inter',
      ),
      textAlign: TextAlign.justify,
     ),
    ],
   ),
  );
 }

 @override
 Widget build(BuildContext context) {
  // Defined local colors for standalone use
  const Color primaryColor = AppColors.primaryBlue;
  const Color darkText = AppColors.darkText;
  const Color background = AppColors.background;

  return Scaffold(
   backgroundColor: background,
   appBar: AppBar(
    title: const Text(
     'User Agreement',
     style: TextStyle(
      color: darkText,
      fontWeight: FontWeight.bold,
      fontFamily: 'Inter',
     ),
    ),
    backgroundColor: background,
    elevation: 1,
    surfaceTintColor: background,
    iconTheme: const IconThemeData(color: darkText),
   ),
   body: Column(
    children: [
     // Scrollable Terms and Conditions Section
     Expanded(
      child: SingleChildScrollView(
       controller: _scrollController, // Attach the scroll controller
       padding: const EdgeInsets.all(24.0),
       child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         // Modified to include an Image Asset and the Text within a Row
         Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
           // Replaced Icon with Image.asset using the specified path
           ClipRRect(
            borderRadius: BorderRadius.circular(8.0),
            child: Image.asset(
             'assets/logo/logo.png', // The specified asset path
             width: 80,
             height: 80,
             fit: BoxFit.cover,
             errorBuilder: (context, error, stackTrace) => Icon(
              Icons.description, // Fallback icon in case image asset is missing
              color: darkText,
              size: 40,
             ),
            ),
           ),
           const SizedBox(width: 12), // Spacing between logo and text
           Expanded(
            child: const Text(
             'CeyLogix – User Agreement & Terms and Conditions',
             style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w800,
              color: primaryColor, // Changed color to primaryColor (blue)
              fontFamily: 'Inter',
             ),
             overflow: TextOverflow.visible, // Ensure text wraps if needed
            ),
           ),
          ],
         ),
         const SizedBox(height: 16),
         const Text(
          'Last Updated: November 2025',
          style: TextStyle(
           fontSize: 14,
           fontStyle: FontStyle.italic,
           color: darkText,
           fontFamily: 'Inter',
          ),
         ),
         const SizedBox(height: 24),

         _buildTermsSection(
          title: '1. Approved Use and Data Collection',
          content: 'By using this system, you agree to use it only for approved purposes such as land detail checking, ownership verification, and tracking cinnamon/tea export records. The system may securely collect basic activity logs and user data to improve performance and ensure security.',
          darkText: darkText
         ),
         _buildTermsSection(
          title: '2. Confidentiality and Compliance',
          content: 'All information is kept strictly confidential and shared only when required by governmental or judicial authorities under applicable law.',
          darkText: darkText
         ),
         _buildTermsSection(
          title: '3. User Responsibility and Misuse',
          content: 'Users must enter accurate details, follow official guidelines, and protect their login credentials. Any unauthorized access, data manipulation, or misuse of the platform may result in immediate account suspension or legal action.',
          darkText: darkText
         ),
         _buildTermsSection(
          title: '4. Service Disclaimer',
          content: 'The platform is provided “as is,” and is not responsible for errors caused by user actions, network issues, external delays, or hardware failure. System updates and maintenance may occur without prior notice.',
          darkText: darkText
         ),
        
         const SizedBox(height: 30),
         const Text(
          'By continuing, you acknowledge that you have read, understood, and agree to be bound by these Terms and Conditions.',
          textAlign: TextAlign.center,
          style: TextStyle(
           fontSize: 16,
           fontWeight: FontWeight.w600,
           color: darkText,
           fontFamily: 'Inter',
          ),
         ),
         const SizedBox(height: 10),
        ],
       ),
      ),
     ),
    
     // Fixed Bottom Button
     Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24.0, vertical: 16.0),
      child: SizedBox(
       width: double.infinity,
       height: 50,
       child: ElevatedButton(
        // Button is enabled only if _isScrolledToBottom is true
        onPressed: _isScrolledToBottom
          ? () {
            // Navigate to LoginPage and replace the current route
            Navigator.pushReplacement(
             context,
             MaterialPageRoute(builder: (context) => const LoginPage()),
            );
           }
          : null, // Disabled if not scrolled
        style: ElevatedButton.styleFrom(
         backgroundColor: primaryColor,
         disabledBackgroundColor: primaryColor.withOpacity(0.3), // Show disabled state
         shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12.0),
         ),
         elevation: 5,
         shadowColor: primaryColor.withOpacity(0.4),
        ),
        child: Text(
         _isScrolledToBottom ? "I Agree and Continue" : "Scroll to Read Agreement", // Contextual button text
         style: const TextStyle(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: Colors.white,
          fontFamily: 'Inter',
         ),
        ),
       ),
      ),
     ),
    ],
   ),
  );
 }
}