import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'signup_page.dart';
// Import the two required dashboard pages directly
import '../land_owner/landowner_dashbord.dart';
import '../factory_owner/factory_owner_dashbord.dart';

// Define the colors used from the main.dart context
class AppColors {
 static const Color background = Color(0xFFEEEBFF);
 static const Color darkText = Color(0xFF2C2A3A);
 static const Color primaryBlue = Color(0xFF2764E7);
 static const Color buttonGradientStart = Color(0xFF2764E7);
 static const Color buttonGradientEnd = Color(0xFF457AED); 
 static const Color cardBackground = Colors.white;
 // Changed secondaryColor to match the green text/logo in the image (CeyLogix)
 static const Color secondaryColor = Color(0xFF6AD96A); 
}

enum UserRole { landowner, factoryOwner, unknown }

class LoginPage extends StatefulWidget {
 const LoginPage({super.key});

 @override
 State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
 final _emailController = TextEditingController();
 final _passwordController = TextEditingController();
 final _auth = FirebaseAuth.instance; 
 bool _isLoading = false;
 bool _showPassword = false;
 String? _errorMessage;

 @override
 void dispose() {
  _emailController.dispose();
  _passwordController.dispose();
  super.dispose();
 }
 
 // NOTE: In a real app, this function would query a database (like Firestore) 
 // or check Firebase Custom Claims to get the role linked to the authenticated user's UID.
 Future<UserRole> _fetchUserRole(String email) async {
  // Simulated Role Mapping based on email prefix for demonstration:
  await Future.delayed(const Duration(milliseconds: 500)); // Simulate DB lookup time

  if (email.toLowerCase().startsWith('land')) {
   return UserRole.landowner;
  } else if (email.toLowerCase().startsWith('factory')) {
   return UserRole.factoryOwner;
  }
  return UserRole.unknown;
 }

 Future<void> _signIn() async {
  setState(() {
   _isLoading = true;
   _errorMessage = null;
  });

  try {
   // Basic input validation before calling Firebase
   if (_emailController.text.trim().isEmpty || _passwordController.text.trim().isEmpty) {
    throw Exception("Email and password fields cannot be empty.");
   }

   final userCredential = await _auth.signInWithEmailAndPassword(
    email: _emailController.text.trim(),
    password: _passwordController.text.trim(),
   );
   
   final email = userCredential.user?.email ?? '';
   final role = await _fetchUserRole(email);

   // Navigate based on the fetched role
   if (role == UserRole.landowner) {
    Navigator.pushReplacement(
     context,
     MaterialPageRoute(builder: (context) => const LandOwnerDashboard()),
    );
   } else if (role == UserRole.factoryOwner) {
    Navigator.pushReplacement(
     context,
     MaterialPageRoute(builder: (context) => const FactoryOwnerDashboard()),
    );
   } else {
    // Log user out if role is unknown, assuming the role check is essential for access
    await _auth.signOut(); 
    throw Exception("Your account role could not be determined. Please contact support.");
   }


  } on FirebaseAuthException catch (e) {
   String message;
   if (e.code == 'user-not-found' || e.code == 'wrong-password') {
    message = 'Invalid email or password.';
   } else if (e.code == 'invalid-email') {
    message = 'The email address is badly formatted.';
   } else {
    message = 'Login failed: ${e.message}';
   }
   setState(() {
    _errorMessage = message;
   });
  } catch (e) {
   setState(() {
    _errorMessage = 'An unexpected error occurred: ${e.toString()}';
   });
  } finally {
   setState(() {
    _isLoading = false;
   });
  }
 }

 @override
 Widget build(BuildContext context) {
  return Scaffold(
   backgroundColor: AppColors.background,
   body: SafeArea(
    child: SingleChildScrollView(
     padding: const EdgeInsets.symmetric(horizontal: 32.0, vertical: 40.0),
     child: Column(
      mainAxisAlignment: MainAxisAlignment.start,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
       // 1. Logo - Updated to match the visual style (large image)
       Image.asset(
        'assets/logo/logo.png', // Assuming this path holds the cup/leaf image
        width: 250, // Made wider to match the visual width
        height: 200, // Made taller
        fit: BoxFit.contain, // Use contain to ensure the whole image is visible
        errorBuilder: (context, error, stackTrace) => const Icon(
         Icons.local_cafe, // Changed icon to suggest tea/coffee instead of shipping
         color: AppColors.secondaryColor,
         size: 100,
        ),
       ),
       
       const SizedBox(height: 10),

       // 2. Title and Subtitle
       Text(
        'CeyLogix',
        style: TextStyle(
         color: AppColors.secondaryColor,
         fontSize: 28,
         fontWeight: FontWeight.bold,
        ),
       ),
       const SizedBox(height: 5),
       const Text(
        'Login In Now',
        style: TextStyle(
         color: AppColors.darkText,
         fontSize: 32,
         fontWeight: FontWeight.w800,
        ),
       ),
       const Text(
        'please login to continue using the app',
        style: TextStyle(
         color: AppColors.darkText,
         fontSize: 14,
        ),
       ),

       const SizedBox(height: 40),

       // 3. Email Input
       _buildInputLabel('Enter Your Email'),
       const SizedBox(height: 8),
       _buildTextField(
        controller: _emailController,
        hintText: 'example@email.com',
        keyboardType: TextInputType.emailAddress,
        icon: Icons.email_outlined,
       ),

       const SizedBox(height: 24),

       // 4. Password Input
       _buildInputLabel('Enter Your Password'),
       const SizedBox(height: 8),
       _buildTextField(
        controller: _passwordController,
        hintText: '*************',
        obscureText: !_showPassword,
        icon: Icons.lock_outline,
        suffixIcon: IconButton(
         icon: Icon(
          _showPassword ? Icons.visibility : Icons.visibility_off,
          color: AppColors.darkText.withOpacity(0.6),
         ),
         onPressed: () {
          setState(() {
           _showPassword = !_showPassword;
          });
         },
        ),
       ),

       // Forgot Password link
       Align(
        alignment: Alignment.centerRight,
        child: TextButton(
         onPressed: () {
          // Placeholder for navigation to Forgot Password page
         },
         child: const Text(
          'Forgot Password?',
          style: TextStyle(
           color: AppColors.primaryBlue,
           fontSize: 14,
           fontWeight: FontWeight.w500,
          ),
         ),
        ),
       ),

       // Error Message
       if (_errorMessage != null)
        Padding(
         padding: const EdgeInsets.only(bottom: 16.0),
         child: Text(
          _errorMessage!,
          style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
          textAlign: TextAlign.center,
         ),
        ),

       // 5. Login Button
       _GradientButton(
        text: _isLoading ? 'Signing In...' : 'Login',
        onPressed: _isLoading ? null : _signIn,
        isEnabled: !_isLoading,
       ),

       const SizedBox(height: 20),

       // 6. Sign Up Link
       Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
         const Text("Don't have account? ", style: TextStyle(color: AppColors.darkText)),
         GestureDetector(
          onTap: () {
           Navigator.push(
            context,
            MaterialPageRoute(builder: (context) => const SignUpPage()),
           );
          },
          child: const Text(
           'Sign up',
           style: TextStyle(
            color: AppColors.primaryBlue,
            fontWeight: FontWeight.bold,
           ),
          ),
         ),
        ],
       ),
       
       const SizedBox(height: 40),

       // 7. Footer Text
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
  );
 }

 // Reusable widget for input labels
 Widget _buildInputLabel(String text) {
  return Align(
   alignment: Alignment.centerLeft,
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

 // Reusable widget for styled text fields
 Widget _buildTextField({
  required TextEditingController controller,
  required String hintText,
  TextInputType keyboardType = TextInputType.text,
  bool obscureText = false,
  IconData? icon,
  Widget? suffixIcon,
 }) {
  return Container(
   decoration: BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(12),
    boxShadow: [
     BoxShadow(
      color: AppColors.primaryBlue.withOpacity(0.05),
      blurRadius: 8,
      offset: const Offset(0, 4),
     ),
    ],
   ),
   child: TextField(
    controller: controller,
    keyboardType: keyboardType,
    obscureText: obscureText,
    style: const TextStyle(color: AppColors.darkText),
    decoration: InputDecoration(
     hintText: hintText,
     hintStyle: TextStyle(color: AppColors.darkText.withOpacity(0.5)),
     contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
     prefixIcon: icon != null ? Icon(icon, color: AppColors.primaryBlue) : null,
     suffixIcon: suffixIcon,
     border: InputBorder.none,
     enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide(color: AppColors.primaryBlue.withOpacity(0.1), width: 1),
     ),
     focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: const BorderSide(color: AppColors.primaryBlue, width: 2),
     ),
    ),
   ),
  );
 }
}

// Custom widget to create the gradient button effect (local definition for simplicity)
class _GradientButton extends StatelessWidget {
 final String text;
 final VoidCallback? onPressed;
 final bool isEnabled;

 const _GradientButton({required this.text, required this.onPressed, this.isEnabled = true});

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
          colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
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