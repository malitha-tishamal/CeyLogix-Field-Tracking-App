import 'package:flutter/material.dart';

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
    // In a real application, this would navigate to a registration form 
    // specific to the chosen role (e.g., LandOwnerRegistrationPage).
    // For now, we'll show a message and go back to login.
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Selected $role registration. Proceeding to form...', style: const TextStyle(color: AppColors.darkText)),
        backgroundColor: AppColors.secondaryColor,
        duration: const Duration(seconds: 2),
      ),
    );
    // Simulate navigation to the next screen (or just pop for now)
    Future.delayed(const Duration(seconds: 1), () {
      Navigator.pop(context); // Go back to login page
    });
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
              // 1. Logo Section (Tea cup/Icon) - Using a placeholder URL for the tea cup image
              _ImagePlaceholder(
                imageUrl: 'https://placehold.co/100x100/96D3A0/fff?text=Tea+Cup',
                size: 100,
              ),
              
              const SizedBox(height: 10),

              Text(
                'CeyLogix',
                style: TextStyle(
                  color: AppColors.secondaryColor,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 20),

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

              // 3. Land Owner Card
              _RoleSelectionCard(
                title: 'Land Owner',
                // Placeholder for tea plantation image
                imageUrl: 'https://placehold.co/50x50/A6D990/fff?text=Plantation', 
                onTap: () => _onRoleSelected(context, 'Land Owner'),
              ),

              const SizedBox(height: 20),

              // 4. Factory Owner Card
              _RoleSelectionCard(
                title: 'Factory Owner',
                // Placeholder for factory image
                imageUrl: 'https://placehold.co/50x50/457AED/fff?text=Factory', 
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
    return ClipRRect(
      borderRadius: BorderRadius.circular(10),
      child: Image.network(
        imageUrl,
        width: size,
        height: size,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => Icon(
          Icons.image_not_supported,
          size: size,
          color: AppColors.darkText.withOpacity(0.5),
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