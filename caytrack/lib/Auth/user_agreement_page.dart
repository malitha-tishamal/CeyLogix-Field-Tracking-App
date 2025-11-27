import 'package:flutter/material.dart';
// Note: Assuming AppColors is accessible globally or via a shared file like main.dart

class UserAgreementPage extends StatelessWidget {
  const UserAgreementPage({super.key});

  @override
  Widget build(BuildContext context) {
    // Defined local colors for standalone use, assuming a default white/blue theme
    const Color primaryColor = Color(0xFF2764E7); 
    const Color darkText = Color(0xFF2C2A3A);

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'User Agreement',
          style: TextStyle(
            color: darkText,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.white,
        elevation: 1,
        surfaceTintColor: Colors.white,
      ),
      body: Column(
        children: [
          // Scrollable Terms and Conditions Section
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Terms of Service for Antibiotics Management System (AMS)',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Last Updated: November 2025',
                    style: TextStyle(
                      fontSize: 14,
                      fontStyle: FontStyle.italic,
                      color: darkText,
                    ),
                  ),
                  const SizedBox(height: 24),

                  _buildTermsSection(
                    title: '1. Acceptance of Terms',
                    content: 'By accessing or using the Antibiotics Management System ("AMS"), you agree to be bound by these Terms of Service and all policies incorporated by reference. If you do not agree to these terms, do not use the service.',
                    darkText: darkText
                  ),
                  _buildTermsSection(
                    title: '2. Data Confidentiality',
                    content: 'All patient data, antibiotic usage logs, and clinical information entered into AMS are treated with the highest degree of confidentiality and are subject to all applicable privacy laws (e.g., HIPAA, GDPR, etc.). You are responsible for maintaining the confidentiality of your login credentials.',
                    darkText: darkText
                  ),
                  _buildTermsSection(
                    title: '3. Scope of Use',
                    content: 'AMS is provided as a management and tracking tool. It is not a substitute for professional medical judgment. Clinicians must rely on their own training and experience when making prescribing decisions. The system is intended only for authorized healthcare professionals.',
                    darkText: darkText
                  ),
                  _buildTermsSection(
                    title: '4. System Availability',
                    content: 'We strive for 24/7 system availability but do not guarantee uninterrupted service. We reserve the right to perform scheduled maintenance or emergency repairs which may temporarily affect service access.',
                    darkText: darkText
                  ),
                  _buildTermsSection(
                    title: '5. Limitation of Liability',
                    content: 'The developers and providers of AMS shall not be liable for any indirect, incidental, special, consequential or punitive damages, including without limitation, loss of profits, data, use, goodwill, or other intangible losses, resulting from (i) your access to or use of or inability to access or use the service; (ii) any unauthorized access to or use of our servers and/or any personal information stored therein.',
                    darkText: darkText
                  ),
                  const SizedBox(height: 30),
                  const Text(
                    'Please read the terms thoroughly before proceeding.',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: darkText,
                    ),
                  ),
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
                onPressed: () {
                  // Action when accepted - typically navigates to the next step (e.g., Login/Home)
                  // For now, we simply navigate back to the StartPage.
                  Navigator.pop(context); 
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: primaryColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12.0),
                  ),
                  elevation: 5,
                  shadowColor: primaryColor.withOpacity(0.4),
                ),
                child: const Text(
                  "I Agree and Continue",
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
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
            ),
          ),
          const SizedBox(height: 8),
          Text(
            content,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: darkText.withOpacity(0.8),
            ),
            textAlign: TextAlign.justify,
          ),
        ],
      ),
    );
  }
}