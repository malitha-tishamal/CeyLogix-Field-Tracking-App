import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'factory_owner_drawer.dart'; // Ensure this file exists for the drawer

// --- 1. COLOR PALETTE ---
class AppColors {
 static const Color background = Color(0xFFEEEBFF);
 static const Color darkText = Color(0xFF2C2A3A);
 static const Color primaryBlue = Color(0xFF2764E7);
 static const Color cardBackground = Colors.white;
 static const Color secondaryColor = Color(0xFF6AD96A);
 
 static const Color headerGradientStart = Color.fromARGB(255, 134, 164, 236);
 static const Color headerGradientEnd = Color(0xFFF7FAFF);
 static const Color headerTextDark = Color(0xFF333333);
}

// --- 2. MAIN SCREEN (User Details - Handles the Header) ---
class UserDetails extends StatefulWidget {
 const UserDetails({super.key});

 @override
 State<UserDetails> createState() => _UserDetailsState();
}

class _UserDetailsState extends State<UserDetails> {
 final User? currentUser = FirebaseAuth.instance.currentUser;
 final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

 // State variables for dynamic user info
 String _userName = 'Loading...';
 String _userRole = 'Loading...';
 String? _userEmail;

 @override
 void initState() {
  super.initState();
  _fetchUserInfo();
 }

 // Fetch user data from the 'users' collection (for Header Display)
 void _fetchUserInfo() async {
  final user = currentUser;
  if (user != null) {
   try {
    final doc = await FirebaseFirestore.instance
      .collection('users')
      .doc(user.uid)
      .get();
      
    if (doc.exists) {
     final data = doc.data();
     setState(() {
      _userName = data?['name'] ?? 'Land Owner';
      _userRole = data?['role'] ?? 'Land owner';
      _userEmail = data?['email'] ?? user.email; 
     });
    } else {
     // Fallback
     setState(() {
      _userName = user.displayName ?? user.email ?? 'Land User';
      _userRole = 'Land owner';
      _userEmail = user.email;
     });
    }
   } catch (e) {
    debugPrint("Error fetching user info: $e");
    setState(() {
     _userName = 'Error Loading Name';
     _userRole = 'Land owner';
     _userEmail = user.email;
    });
   }
  }
 }

 @override
 Widget build(BuildContext context) {
  if (currentUser == null) {
   return const Scaffold(body: Center(child: Text("Error: User not logged in.")));
  }

  void handleDrawerNavigate(String routeName) {
   Navigator.pop(context);
   // Implement navigation logic here (e.g., to dashboard)
  }

  return Scaffold(
   key: _scaffoldKey,
   backgroundColor: AppColors.background,
   drawer: FactoryOwnerDrawer( // Re-using FactoryOwnerDrawer
    onLogout: () {
     FirebaseAuth.instance.signOut();
     Navigator.pop(context);
    },
    onNavigate: handleDrawerNavigate,
   ),
   body: Stack(
    children: [
     SafeArea(
      child: Column(
       children: [
        _buildProfileHeader(context),
        Expanded(
         child: SingleChildScrollView(
          // Using the modified widget
          child: UserProfileContentOnly(userUID: currentUser!.uid), 
         ),
        ),
       ],
      ),
     ),
     // Footer Text
     Align(
      alignment: Alignment.bottomCenter,
      child: Padding(
       padding: const EdgeInsets.all(16.0),
       child: Text(
        'Developed By Malitha Tishamal',
        textAlign: TextAlign.center,
        style: TextStyle(
         color: AppColors.darkText.withOpacity(0.7),
         fontSize: 12,
        ),
       ),
      ),
     ),
    ],
   ),
  );
 }
 
 // Profile Header (Displays fetched Name, Role, Email)
 Widget _buildProfileHeader(BuildContext context) {
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
       Container(
        width: 70,
        height: 70,
        decoration: BoxDecoration(
         shape: BoxShape.circle,
         gradient: const LinearGradient(
          colors: [AppColors.primaryBlue, Color(0xFF457AED)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
         ),
         border: Border.all(color: Colors.white, width: 3),
         boxShadow: [
          BoxShadow(
           color: AppColors.primaryBlue.withOpacity(0.4),
           blurRadius: 10,
           offset: const Offset(0, 3),
          ),
         ],
        ),
        child: const Icon(Icons.person, size: 50, color: Colors.white),
       ),
       
       const SizedBox(width: 15),
       
       Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
         Text(
          _userName,
          style: const TextStyle(
           fontSize: 20,
           fontWeight: FontWeight.bold,
           color: AppColors.headerTextDark,
          ),
         ),
         Text(
          _userRole,
          style: TextStyle(
           fontSize: 14,
           color: AppColors.headerTextDark.withOpacity(0.7),
          ),
         ),
         
        ],
       ),
      ],
     ),
     
     const SizedBox(height: 25),
     
     const Text(
      'Manage User Details', // Updated header text
      style: TextStyle(
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
// --- 3. USER PROFILE CONTENT (Removed Land Data/Logic) ---
// -----------------------------------------------------------------------------

class UserProfileContentOnly extends StatefulWidget {
 final String userUID;
 const UserProfileContentOnly({required this.userUID, super.key});

 @override
 State<UserProfileContentOnly> createState() => _UserProfileContentOnlyState();
}

class _UserProfileContentOnlyState extends State<UserProfileContentOnly> {
 final FirebaseFirestore _firestore = FirebaseFirestore.instance;
 final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
 final User? currentUser = FirebaseAuth.instance.currentUser;

 // Text Controllers for Editable User Fields
 late TextEditingController _ownerNameController;
 late TextEditingController _contactNumberController;
 late TextEditingController _nicController;
 
 // Stored Fixed/Read-only Fields
 String _fetchedEmail = 'N/A';
 String _fetchedRole = 'N/A';
 
 bool _isSaving = false;
 String? _statusMessage;

 @override
 void initState() {
  super.initState();
  _ownerNameController = TextEditingController();
  _contactNumberController = TextEditingController();
  _nicController = TextEditingController();
  
  // Fetch initial user data
  _fetchUserData(); 
 }

 @override
 void dispose() {
  _ownerNameController.dispose();
  _contactNumberController.dispose();
  _nicController.dispose();
  super.dispose();
 }

 // --- Data Fetching Logic (Only for 'users' collection) ---
 Future<void> _fetchUserData() async {
  final userDoc = await _firestore.collection('users').doc(widget.userUID).get();
  
  if (userDoc.exists) {
   final userData = userDoc.data();
   if (mounted) {
    // Populate editable user fields
    _ownerNameController.text = userData?['name'] ?? '';
    _contactNumberController.text = userData?['mobile'] ?? '';
    _nicController.text = userData?['nic'] ?? '';
    
    // Populate fixed fields
    _fetchedEmail = userData?['email'] ?? currentUser?.email ?? 'N/A';
    _fetchedRole = userData?['role'] ?? 'Land owner';
    
    setState(() {}); // Rebuild to display initial data
   }
  } else if (mounted) {
    // Fallback for new user or missing doc
    _fetchedEmail = currentUser?.email ?? 'N/A';
    _fetchedRole = 'Land owner';
    setState(() {}); 
  }
 }

 // --- Data Update Logic for Editable User Data (Only 'users' collection) ---
 Future<void> _updateUserData() async {
  if (!_formKey.currentState!.validate()) {
   setState(() => _statusMessage = "Please correct the errors in the form before saving details.");
   return;
  }
  
  setState(() {
   _isSaving = true;
   _statusMessage = null;
  });

  try {
   final userDataToUpdate = {
    'name': _ownerNameController.text.trim(),
    'mobile': _contactNumberController.text.trim(),
    'nic': _nicController.text.trim(),
    'updatedAt': FieldValue.serverTimestamp(),
   };

   // Save to the 'users' collection
   await _firestore.collection('users').doc(widget.userUID).set(userDataToUpdate, SetOptions(merge: true));
   
   setState(() {
    _statusMessage = "Profile details updated successfully!";
   });

   // Re-fetch user info in UserDetails to update header immediately
   (context.findAncestorStateOfType<_UserDetailsState>()?._fetchUserInfo());

  } catch (e) {
   setState(() {
    _statusMessage = "Error updating profile: $e";
   });
   debugPrint('Update Error: $e');
  } finally {
   setState(() {
    _isSaving = false;
   });
  }
 }

 @override
 Widget build(BuildContext context) {
  // Show loading while fetching initial user data
  if (_ownerNameController.text.isEmpty && !_isSaving && currentUser?.email != null && _fetchedEmail == 'N/A') {
   return const Center(child: Padding(
    padding: EdgeInsets.only(top: 100.0),
    child: CircularProgressIndicator(color: AppColors.primaryBlue),
   ));
  }

  return Padding(
   padding: const EdgeInsets.all(20.0),
   child: Form(
    key: _formKey,
    child: Column(
     crossAxisAlignment: CrossAxisAlignment.start,
     children: [
      if (_statusMessage != null)
       InfoCard(
        message: _statusMessage!,
        color: _statusMessage!.toLowerCase().contains('success') ? AppColors.secondaryColor : Colors.red,
       ),

      const SizedBox(height: 16),
      
      // -----------------------------------------------------------------
      // --- EDITABLE USER FIELDS (Registration Data) ---
      // -----------------------------------------------------------------
      
      _buildInputLabel('Full Name'),
      _buildTextField(_ownerNameController, 'Enter your full name', (value) {
        if (value == null || value.isEmpty) return 'Name is required.';
        return null;
      }),

      _buildInputLabel('Contact Number (Mobile)'),
      _buildTextField(_contactNumberController, 'e.g., 0712345678', (value) {
        if (value == null || value.isEmpty) return 'Mobile number is required.';
        if (value.length != 10) return 'Mobile number must be 10 digits.';
        return null;
      }, keyboardType: TextInputType.phone),
      
      _buildInputLabel('NIC Number'),
      _buildTextField(_nicController, 'Enter your NIC', (value) {
        if (value == null || value.isEmpty) return 'NIC is required.';
        if (value.length < 10) return 'Enter a valid NIC (10 or 12 digits).';
        return null;
      }, keyboardType: TextInputType.text),
      
      // -----------------------------------------------------------------
      // --- FIXED (READ-ONLY) FIELDS ---
      // -----------------------------------------------------------------
      
      _buildInputLabel('Email Address (Fixed)'),
      FixedInfoBox(value: _fetchedEmail),

      _buildInputLabel('User Role (Fixed)'),
      FixedInfoBox(value: _fetchedRole),

      const SizedBox(height: 30),

      // Update Button
      GradientButton(
       text: _isSaving ? 'Updating...' : 'Update Profile Details',
       onPressed: _isSaving ? null : _updateUserData, 
       isEnabled: !_isSaving,
      ),
      
      const SizedBox(height: 50),
     ],
    ),
   ),
  );
 }

 // --- Helper Widgets ---

 Widget _buildInputLabel(String text) {
  return Padding(
   padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
   child: Text(
    text,
    style: const TextStyle(
     color: AppColors.darkText,
     fontWeight: FontWeight.w600,
     fontSize: 16,
    ),
   ),
  );
 }

 Widget _buildTextField(
  TextEditingController controller, 
  String hintText, 
  String? Function(String?)? validator,
  {TextInputType keyboardType = TextInputType.text} 
 ) {
  return Container(
   decoration: BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
   ),
   child: TextFormField(
    controller: controller,
    keyboardType: keyboardType,
    style: const TextStyle(color: AppColors.darkText),
    decoration: InputDecoration(
     hintText: hintText,
     contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
     border: InputBorder.none,
    ),
    validator: validator,
   ),
  );
 }
}

// -----------------------------------------------------------------------------
// --- 4. GEO DATA & REUSABLE WIDGETS (Cleaned up) ---
// -----------------------------------------------------------------------------

// Removed _getGeoData as it's no longer used.

class GradientButton extends StatelessWidget {
 final String text;
 final VoidCallback? onPressed;
 final bool isEnabled;

 const GradientButton({required this.text, required this.onPressed, this.isEnabled = true, super.key});

 @override
 Widget build(BuildContext context) {
  return InkWell(
   onTap: isEnabled ? onPressed : null,
   borderRadius: BorderRadius.circular(12),
   child: Opacity(
    opacity: isEnabled ? 1.0 : 0.6,
    child: Container(
     width: double.infinity,
     padding: const EdgeInsets.symmetric(vertical: 16.0),
     decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(12),
      gradient: isEnabled
       ? const LinearGradient(
         colors: [AppColors.primaryBlue, Color(0xFF457AED)],
         begin: Alignment.centerLeft,
         end: Alignment.centerRight,
        )
       : LinearGradient(
         colors: [Colors.grey.shade500, Colors.grey.shade400],
         begin: Alignment.centerLeft,
         end: Alignment.centerRight,
        ),
      boxShadow: isEnabled
       ? [
         BoxShadow(
          color: AppColors.primaryBlue.withOpacity(0.5),
          blurRadius: 10,
          offset: const Offset(0, 5),
         ),
        ]
       : null,
     ),
     child: Text(
      text,
      textAlign: TextAlign.center,
      style: const TextStyle(
       color: Colors.white,
       fontSize: 20,
       fontWeight: FontWeight.w600,
       fontFamily: 'Inter',
      ),
     ),
    ),
   ),
  );
 }
}

class FixedInfoBox extends StatelessWidget {
 final String value;
 const FixedInfoBox({required this.value, super.key});

 @override
 Widget build(BuildContext context) {
  return Container(
   width: double.infinity,
   padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
   decoration: BoxDecoration(
    color: Colors.grey[100], // Use a slightly different background for fixed fields
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.1)),
   ),
   child: Text(
    value,
    style: TextStyle(
     color: AppColors.darkText.withOpacity(0.7),
     fontSize: 16,
     fontWeight: FontWeight.w500,
    ),
   ),
  );
 }
}

class InfoCard extends StatelessWidget {
 final String message;
 final Color color;
 const InfoCard({required this.message, required this.color, super.key});

 @override
 Widget build(BuildContext context) {
  return Container(
   width: double.infinity,
   padding: const EdgeInsets.all(12),
   margin: const EdgeInsets.symmetric(vertical: 8),
   decoration: BoxDecoration(
    color: color.withOpacity(0.1),
    borderRadius: BorderRadius.circular(8),
    border: Border.all(color: color, width: 1),
   ),
   child: Text(
    message,
    style: TextStyle(color: color, fontWeight: FontWeight.w500),
   ),
  );
 }
}