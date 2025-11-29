import 'package:flutter/material.dart';
import '../land_owner/farmer_registration.dart'; // Land Owner now navigates here
import '../factory_owner/factory_owner_registration.dart'; // Factory Owner navigates here

// Define the colors used, consistent with login_page.dart
class AppColors {
  static const Color background = Color(0xFFEEEBFF);
  static const Color darkText = Color(0xFF2C2A3A);
  static const Color primaryBlue = Color(0xFF2764E7);
  static const Color buttonGradientStart = Color(0xFF2764E7);
  static const Color buttonGradientEnd = Color(0xFF457AED); 
  static const Color cardBackground = Colors.white;
  static const Color secondaryColor = Color(0xFF6AD96A); // CeyLogix logo green
}

class SignUpPage extends StatelessWidget {
  const SignUpPage({super.key});

  // Handler for when a role card is tapped
  void _onRoleSelected(BuildContext context, String role) {
    Widget nextPage;

    // Determine the target page based on the selected role
    if (role == 'Land Owner') {
      nextPage = const FarmerRegistrationPage(); // Navigate to Farmer Registration
    } else if (role == 'Factory Owner') {
      nextPage = const FactoryOwnerRegistrationPage(); // Navigate to Factory Owner Registration
    } else {
      // Fallback
      return; 
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Navigating to $role registration.', style: const TextStyle(color: AppColors.darkText)),
        backgroundColor: AppColors.secondaryColor,
        duration: const Duration(milliseconds: 1500),
      ),
    );
    
    // Navigate to the specific registration page
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => nextPage),
    );
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

              // 2. Title and Subtitle (Create Account)
              const Text(
                'Create Account',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 32,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Text(
                'Please select account type for registration.',
                style: TextStyle(
                  color: AppColors.darkText,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 40),

              // 3. Land Owner Card (Navigates to farmer_registration.dart)
              _RoleSelectionCard(
                title: 'Land Owner',
                // Placeholder for tea plantation image
                imageUrl: 'assets/logo/land.jpg', 
                onTap: () => _onRoleSelected(context, 'Land Owner'),
              ),

              const SizedBox(height: 20),

              // 4. Factory Owner Card (Navigates to factory_owner_registration.dart)
              _RoleSelectionCard(
                title: 'Factory Owner',
                // Placeholder for factory image
                imageUrl: 'assets/logo/fac.png', 
                onTap: () => _onRoleSelected(context, 'Factory Owner'),
              ),

              const SizedBox(height: 60),
              
              // Already have an account link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text("Already have an account? ", style: TextStyle(color: AppColors.darkText)),
                  GestureDetector(
                    onTap: () {
                      Navigator.pop(context);
                    },
                    child: const Text(
                      'Login',
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
}

// Custom widget to display a Network Image with fallback
class _ImagePlaceholder extends StatelessWidget {
  final String imageUrl;
  final double size;

  const _ImagePlaceholder({
    required this.imageUrl,
    this.size = 50.0,
  });

  @override
  Widget build(BuildContext context) {
    // Using Image.network for placeholder URLs
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: AppColors.secondaryColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(
            Icons.image_not_supported,
            size: size * 0.6,
            color: AppColors.darkText.withOpacity(0.5),
          ),
        ),
      ),
    );
  }
}

// Custom widget for the role selection cards
class _RoleSelectionCard extends StatelessWidget {
  final String title;
  final String imageUrl;
  final VoidCallback onTap;

  const _RoleSelectionCard({
    required this.title,
    required this.imageUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(15),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 20.0),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withOpacity(0.1),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Row(
          children: [
            // Icon/Image Placeholder
            _ImagePlaceholder(
              imageUrl: imageUrl,
              size: 50,
            ),
            const SizedBox(width: 20),
            // Title
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: AppColors.darkText,
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const Icon(Icons.arrow_forward_ios, color: AppColors.primaryBlue),
          ],
        ),
      ),
    );
  }
}