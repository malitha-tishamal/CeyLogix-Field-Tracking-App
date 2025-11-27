import 'package:flutter/material.dart';
// Note: In a real Flutter project, AppColors would be imported from a shared file like 'package:app_name/app_colors.dart'.
// For this self-contained example, we'll redefine the necessary colors for readability and context.

// Define the colors used from the main.dart context
class AppColors {
  static const Color background = Color(0xFFEEEBFF);
  static const Color darkText = Color(0xFF2C2A3A);
  static const Color primaryBlue = Color(0xFF2764E7);
  static const Color buttonGradientStart = Color(0xFF2764E7);
  static const Color buttonGradientEnd = Color(0xFF457AED); 
}

// Custom color for the CeyLogix logo text
const Color _logoGreen = Color(0xFF6AD96A);

// The custom painter (TeaCupPainter) and graphic widget (TeaCupGraphic) have been removed.

class StartPage extends StatelessWidget {
  const StartPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Determine screen height for proportional top padding
    final screenHeight = MediaQuery.of(context).size.height;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        // Use a Column with spaceBetween to push the content up and the footer down
        child: Column(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // --- MAIN CONTENT AREA (Space, Logo, Title, Text) ---
            Padding(
              padding: EdgeInsets.only(top: screenHeight * 0.1),
              child: Column(
                children: [
                  // 1. Placeholder for the removed graphic (maintaining vertical space)
                  const SizedBox(height: 100), 
                  
                  const SizedBox(height: 30),

                  // 2. Branding (Logo + Text) - USING LOCAL ASSET IMAGE
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8.0),
                        child: Image.asset(
                          'assets/logo.png', // <-- Using local asset path
                          width: 40,
                          height: 40,
                          fit: BoxFit.cover,
                          // Fallback in case the image cannot be loaded
                          errorBuilder: (context, error, stackTrace) => Icon(
                            Icons.eco, 
                            color: _logoGreen,
                            size: 32,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Text(
                        'CeyLogix',
                        style: TextStyle(
                          color: _logoGreen,
                          fontSize: 32,
                          fontWeight: FontWeight.w800,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 20),

                  // 3. Main Headline: "Smart Tracking for Ceylon Exports."
                  SizedBox(
                    width: MediaQuery.of(context).size.width * 0.8, // Control max width
                    child: const Text(
                      'Smart Tracking\nfor Ceylon\nExports.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        height: 1.2, // Tighter line spacing
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // --- BOTTOM SECTION (Button and Footer) ---
            Column(
              children: [
                // 4. "Let's Start..." Button with Gradient
                _GradientButton(
                  text: "Let's Start...",
                  onPressed: () {
                    // Action for starting the app (e.g., navigate to login/home)
                  },
                ),
                
                const SizedBox(height: 40), // Spacing before the footer

                // 5. Footer Text: "Developed By Malitha Tishamal"
                Center( 
                  child: const Padding(
                    padding: EdgeInsets.only(bottom: 16.0),
                    child: Text(
                      'Developed By Malitha Tishamal',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: AppColors.darkText,
                        fontSize: 12,
                        fontFamily: 'Inter',
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// Custom widget to create the gradient button effect
class _GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback onPressed;

  const _GradientButton({required this.text, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: MediaQuery.of(context).size.width * 0.8, // 80% screen width
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          gradient: const LinearGradient(
            colors: [AppColors.buttonGradientStart, AppColors.buttonGradientEnd],
            begin: Alignment.centerLeft,
            end: Alignment.centerRight,
          ),
          boxShadow: [
            BoxShadow(
              color: AppColors.primaryBlue.withOpacity(0.5),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
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
    );
  }
}