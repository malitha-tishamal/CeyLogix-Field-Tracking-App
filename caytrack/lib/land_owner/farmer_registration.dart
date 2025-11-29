import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'dart:convert';
// Import the LoginPage from the specified path
import '../Auth/login_page.dart'; 

// =========================================================================
// 🟢 FIREBASE CONFIGURATION (INJECTED FROM USER'S JSON) 🟢
// **Note:** Replace this with your actual, secure Firebase config when deploying.
// The provided keys are for demonstration/debugging purposes based on previous input.
// =========================================================================
const String __firebase_config = 
 '{"apiKey": "AIzaSyAxAOhKav-NmOQeMfZh899xy4NmKXQCfM0g", "appId": "1:324646185920:android:f37297d4a7124bb308b625", "messagingSenderId": "324646185920", "projectId": "ceylogix-df065"}'; 
const String __app_id = '1:324646185920:android:f37297d4a7124bb308b625'; 
const String __initial_auth_token = ''; 
// -------------------------------------------------------------------

// Define the colors used for the consistent CeyLogix theme
class AppColors {
static const Color background = Color(0xFFEEEBFF);
static const Color darkText = Color(0xFF2C2A3A);
static const Color primaryBlue = Color(0xFF2764E7);
static const Color buttonGradientStart = Color(0xFF2764E7);
static const Color buttonGradientEnd = Color(0xFF457AED); 
static const Color cardBackground = Colors.white;
static const Color secondaryColor = Color(0xFF6AD96A); 
}

// -------------------------------------------------------------------

class FarmerRegistrationPage extends StatefulWidget {
// Hardcoded role for this specific page
final String role = 'Land owner';
const FarmerRegistrationPage({super.key});

@override
State<FarmerRegistrationPage> createState() => _FarmerRegistrationPageState();
}

class _FarmerRegistrationPageState extends State<FarmerRegistrationPage> {
final _formKey = GlobalKey<FormState>();

// Text Editing Controllers for form fields
final _nicController = TextEditingController();
final _nameController = TextEditingController();
final _emailController = TextEditingController();
final _mobileController = TextEditingController();
final _passwordController = TextEditingController();
final _confirmPasswordController = TextEditingController();

// State for password visibility and loading
bool _isPasswordVisible = false;
bool _isConfirmPasswordVisible = false;
bool _isLoading = false;

// Firebase instances
FirebaseApp? _app;
FirebaseAuth? _auth;
FirebaseFirestore? _firestore;

@override
void initState() {
 super.initState();
 _initializeFirebase();
}

// Helper function to decode the config map safely
Map<String, dynamic> _decodeConfig(String config) {
 try {
  return jsonDecode(config) as Map<String, dynamic>;
 } catch (e) {
  print('Failed to decode Firebase config: $e');
  return {};
 }
}

/// Initializes Firebase and its services.
Future<void> _initializeFirebase() async {
 try {
  final firebaseConfigMap = _decodeConfig(__firebase_config);
  
  // Use the config map values to initialize Firebase options
  final firebaseOptions = FirebaseOptions(
   apiKey: firebaseConfigMap['apiKey'] as String? ?? '', 
   appId: firebaseConfigMap['appId'] as String? ?? '',
   messagingSenderId: firebaseConfigMap['messagingSenderId'] as String? ?? '',
   projectId: firebaseConfigMap['projectId'] as String? ?? '',
  );

  // Initialize app if it hasn't been already
  if (Firebase.apps.isEmpty) {
   _app = await Firebase.initializeApp(
    options: firebaseOptions,
   );
  } else {
   _app = Firebase.app();
  }

  // Get Auth and Firestore instances
  _auth = FirebaseAuth.instanceFor(app: _app!);
  _firestore = FirebaseFirestore.instanceFor(app: _app!);
  
  // 🔴 CRITICAL FIX: Removed signInAnonymously call to prevent admin-restricted-operation error on web/desktop.
  // The app does not need to sign in anonymously just to check initialization.

 } catch (e) {
  print('Firebase Initialization Error: $e');
  if (mounted) {
   ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
     content: Text('Error initializing Firebase: $e'),
     backgroundColor: Colors.red,
    ),
   );
  }
 }
}


@override
void dispose() {
 _nicController.dispose();
 _nameController.dispose();
 _emailController.dispose();
 _mobileController.dispose();
 _passwordController.dispose();
 _confirmPasswordController.dispose();
 super.dispose();
}

// --- Form Validation Functions ---

String? _validateNIC(String? value) {
 if (value == null || value.isEmpty) {
  return 'NIC Number is required.';
 }
 // Sri Lankan NIC validation: 9 digits + V/X OR 12 digits (new)
 if (!RegExp(r'^\d{9}[vVxX]$|^\d{12}$').hasMatch(value)) {
  return 'Enter a valid NIC (e.g., 901234567V or 199012345678).';
 }
 return null;
}

String? _validateName(String? value) {
 if (value == null || value.isEmpty) {
  return 'Your Name is required.';
 }
 return null;
}

String? _validateEmail(String? value) {
 if (value == null || value.isEmpty) {
  return 'Email address is required.';
 }
 // Basic email format check
 if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(value)) {
  return 'Enter a valid email address.';
 }
 return null;
}

String? _validateMobile(String? value) {
 if (value == null || value.isEmpty) {
  return 'Mobile Number is required.';
 }
 // Sri Lankan mobile number validation (10 digits)
 if (!RegExp(r'^\d{10}$').hasMatch(value)) {
  return 'Mobile Number must be 10 digits.';
 }
 return null;
}

String? _validatePassword(String? value) {
 if (value == null || value.isEmpty) {
  return 'Password is required.';
 }
 if (value.length < 6) {
  return 'Password must be at least 6 characters.';
 }
 return null;
}

String? _validateConfirmPassword(String? value) {
 if (value == null || value.isEmpty) {
  return 'Please re-enter your password.';
 }
 if (value != _passwordController.text) {
  return 'Passwords do not match.';
 }
 return null;
}

// --- Firebase Submission Handler (The Core Logic) ---

Future<void> _handleSignUp() async {
 if (_formKey.currentState!.validate()) {
  if (_auth == null || _firestore == null) {
   // If Firebase is not fully initialized, try again.
   await _initializeFirebase();
   if (_auth == null || _firestore == null) {
    if (mounted) {
     ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
       content: Text('Firebase services are still loading. Try again.'),
       backgroundColor: Colors.orange,
      ),
     );
    }
    return;
   }
  }
  
  setState(() {
   _isLoading = true;
  });

  try {
   // 1. Firebase Authentication: Create User
   final UserCredential userCredential = await _auth!.createUserWithEmailAndPassword(
    email: _emailController.text,
    password: _passwordController.text,
   );
   
   final user = userCredential.user;
   
   // 2. Firestore Data Storage
   if (user != null) {
    final userData = {
     'role': widget.role, // 'Factory owner'
     'nic': _nicController.text,
     'name': _nameController.text,
     'email': _emailController.text,
     'mobile': _mobileController.text,
     'registrationDate': FieldValue.serverTimestamp(),
     'status': 'Pending Verification', // Initial status for new registrations
    };
    
    // Storing user data under a top-level 'users' collection with UID as doc ID
    final docRef = _firestore!.collection('users').doc(user.uid);

    await docRef.set(userData);
    
    if (mounted) {
     ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
       content: Text('${widget.role} account created successfully! Redirecting to login.'),
       backgroundColor: AppColors.secondaryColor,
      ),
     );
     // Navigate to the LoginPage and replace the current route
     Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => const LoginPage()),
     );
    }
   }

  } on FirebaseAuthException catch (e) {
   String message;
   if (e.code == 'weak-password') {
    message = 'The password provided is too weak.';
   } else if (e.code == 'email-already-in-use') {
    message = 'An account already exists for that email.';
   } else {
    message = 'Registration failed: ${e.message}';
   }
   print('Firebase Auth Error: $e');
   if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
     SnackBar(
      content: Text(message),
      backgroundColor: Colors.red,
     ),
    );
   }
  } catch (e) {
   print('Error during registration: $e');
   if (mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
     const SnackBar(
      content: Text('An unexpected error occurred during registration.'),
      backgroundColor: Colors.red,
     ),
    );
   }
  } finally {
   setState(() {
    _isLoading = false;
   });
  }
 }
}

// --- Custom Text Form Field Widget ---
Widget _buildTextField({
 required TextEditingController controller,
 required String label, 
 required String hint,
 required IconData prefixIcon,
 required String? Function(String?) validator,
 bool isPassword = false,
 bool isVisible = true,
 VoidCallback? toggleVisibility,
 TextInputType keyboardType = TextInputType.text,
 bool readOnly = false,
}) {
 return Padding(
  padding: const EdgeInsets.only(bottom: 20.0),
  child: Column(
   crossAxisAlignment: CrossAxisAlignment.start,
   children: [
    // Explicit Label Text Widget
    Text(
     label,
     style: const TextStyle(
      color: AppColors.darkText,
      fontWeight: FontWeight.bold,
      fontSize: 14.0,
     ),
    ),
    const SizedBox(height: 8.0),

    // TextFormField
    TextFormField(
     controller: controller,
     validator: validator,
     obscureText: isPassword && !isVisible,
     keyboardType: keyboardType,
     readOnly: readOnly,
     style: TextStyle(
      color: AppColors.darkText, 
      fontWeight: readOnly ? FontWeight.bold : FontWeight.normal
     ),
     decoration: InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: AppColors.darkText.withOpacity(0.6)),
      prefixIcon: Icon(prefixIcon, color: AppColors.primaryBlue),
      suffixIcon: isPassword
      ? IconButton(
       icon: Icon(
        isVisible ? Icons.visibility : Icons.visibility_off,
       ),
       onPressed: toggleVisibility,
       )
      : null,
      filled: true,
      fillColor: AppColors.cardBackground,
      border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: BorderSide.none,
      ),
      enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2.0),
      ),
      errorBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(15.0),
      borderSide: const BorderSide(color: Colors.red, width: 2.0),
      ),
     ),
    ),
   ],
  ),
 );
}

@override
Widget build(BuildContext context) {
 return Scaffold(
  backgroundColor: AppColors.background,
  appBar: AppBar(
   title: Text('${widget.role} Registration', style: const TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold)),
   backgroundColor: AppColors.background,
   elevation: 0,
   iconTheme: const IconThemeData(color: AppColors.darkText),
  ),
  body: SafeArea(
   child: SingleChildScrollView(
    padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 20.0),
    child: Form(
     key: _formKey,
     child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
       // Logo
       Center(
        child: Image.asset(
         'assets/logo/logo.png', // Ensure this asset path is correct
         width: 250, 
         height: 200, 
         fit: BoxFit.contain, 
         errorBuilder: (context, error, stackTrace) => const Icon(
          Icons.factory_outlined, 
          color: AppColors.secondaryColor,
          size: 100,
         ),
       ),
       ),
       
       const SizedBox(height: 30),

       // Role Display (Fixed - Factory owner)
       _buildTextField(
        controller: TextEditingController(text: widget.role),
        label: 'Role',
        hint: '',
        prefixIcon: Icons.badge,
        validator: (v) => null, 
        keyboardType: TextInputType.none,
        readOnly: true,
       ),

       // NIC Number Field
       _buildTextField(
        controller: _nicController,
        label: 'NIC Number',
        hint: 'Enter Your NIC',
        prefixIcon: Icons.credit_card,
        validator: _validateNIC,
        keyboardType: TextInputType.text,
       ),

       // Your Name Field
       _buildTextField(
        controller: _nameController,
        label: 'Your Name',
        hint: 'Enter Your Full Name',
        prefixIcon: Icons.person,
        validator: _validateName,
        keyboardType: TextInputType.name,
       ),

       // Your Email Field
       _buildTextField(
        controller: _emailController,
        label: 'Your Email',
        hint: 'Enter Your Email Address',
        prefixIcon: Icons.email,
        validator: _validateEmail,
        keyboardType: TextInputType.emailAddress,
       ),
       
       // Mobile Number Field
       _buildTextField(
        controller: _mobileController,
        label: 'Mobile Number',
        hint: 'Enter Your Mobile Number',
        prefixIcon: Icons.phone,
        validator: _validateMobile,
        keyboardType: TextInputType.phone,
       ),

       // Password Field
       _buildTextField(
        controller: _passwordController,
        label: 'Password',
        hint: 'Enter Your Password',
        prefixIcon: Icons.lock,
        validator: _validatePassword,
        isPassword: true,
        isVisible: _isPasswordVisible,
        toggleVisibility: () {
        setState(() { _isPasswordVisible = !_isPasswordVisible; });
        },
       ),

       // Confirm Password Field
       _buildTextField(
        controller: _confirmPasswordController,
        label: 'Enter Password Again',
        hint: 'Re-Enter Your Password',
        prefixIcon: Icons.lock_open,
        validator: _validateConfirmPassword,
        isPassword: true,
        isVisible: _isConfirmPasswordVisible,
        toggleVisibility: () {
        setState(() { _isConfirmPasswordVisible = !_isConfirmPasswordVisible; });
        },
       ),
       
       const SizedBox(height: 30),

       // Sign Up Button
       SizedBox(
        height: 60,
        child: DecoratedBox(
        decoration: BoxDecoration(
         borderRadius: BorderRadius.circular(15.0),
         gradient: _isLoading 
          ? null // No gradient when loading
          : const LinearGradient(
          colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
          begin: Alignment.centerLeft,
          end: Alignment.centerRight,
          ),
         color: _isLoading ? AppColors.primaryBlue.withOpacity(0.5) : null,
         boxShadow: [
          BoxShadow(
          color: AppColors.primaryBlue.withOpacity(0.4),
          blurRadius: 10,
          offset: const Offset(0, 5),
          ),
         ],
        ),
        child: ElevatedButton(
         onPressed: _isLoading ? null : _handleSignUp,
         style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15.0),
          ),
         ),
         child: _isLoading
          ? const CircularProgressIndicator(color: Colors.white)
          : const Text(
           'Sign Up',
           style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
           ),
           ),
        ),
       ),
       ),
       
       const SizedBox(height: 30),

       // Already Registered link
       Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
         const Text("Already Registered? ", style: TextStyle(color: AppColors.darkText)),
         GestureDetector(
          onTap: () {
           Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => const LoginPage()),
           ); 
          },
          child: const Text(
           'Sign in',
           style: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.bold,
           ),
          ),
         ),
        ],
       ),
       
       const SizedBox(height: 40),

       // Footer Text
       const Text(
        'Developed By Malitha Tishamal',
        textAlign: TextAlign.center,
        style: TextStyle(
         color: AppColors.darkText,
         fontSize: 12,
        ),
       ),
      ],
     ),
    ),
   ),
  ),
 );
}
}