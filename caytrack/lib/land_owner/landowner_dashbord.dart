import 'package:flutter/material.dart';

// Reusing AppColors locally
class AppColors {
  static const Color background = Color(0xFFEEEBFF);
  static const Color darkText = Color(0xFF2C2A3A);
  static const Color primaryBlue = Color(0xFF2764E7);
  static const Color accentGreen = Color(0xFF6AD96A); 
  static const Color accentOrange = Color(0xFFF9A825);
  static const Color cardBackground = Colors.white;
}

class LandOwnerDashboard extends StatelessWidget {
  const LandOwnerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Land Owner Dashboard', style: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.cardBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.notifications_none, color: AppColors.darkText),
            onPressed: () {
              // Notification action
            },
          ),
          IconButton(
            icon: const Icon(Icons.account_circle, color: AppColors.darkText),
            onPressed: () {
              // Profile action
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Welcome Card
            _buildWelcomeCard('Welcome back, Mr. Perera!', 'Land ID: LO-10029', context),
            
            const SizedBox(height: 20),
            
            // Key Metrics Grid
            _buildKeyMetrics(context),

            const SizedBox(height: 20),
            const Text('Land & Harvest Status', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.darkText)),
            const SizedBox(height: 10),

            // Land Map Placeholder
            _buildMapPlaceholderCard(context),

            const SizedBox(height: 20),
            const Text('Inventory & Sales', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.darkText)),
            const SizedBox(height: 10),
            
            // Inventory List
            _buildInventoryCard(context, 'Raw Cinnamon', '2,500 kg', AppColors.primaryBlue),
            _buildInventoryCard(context, 'Tea Leaves', '800 kg', AppColors.accentGreen),

            const SizedBox(height: 20),

            // Quick Actions
            Row(
              children: [
                _buildQuickActionButton(
                  context, 
                  'Request Factory Delivery', 
                  Icons.local_shipping, 
                  AppColors.primaryBlue
                ),
                const SizedBox(width: 16),
                _buildQuickActionButton(
                  context, 
                  'View Payouts', 
                  Icons.account_balance_wallet, 
                  AppColors.accentOrange
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWelcomeCard(String title, String subtitle, BuildContext context) {
    return Container(
      
      child: Row(
        children: [
          const Icon(Icons.person, color: Colors.white, size: 40),
          const SizedBox(width: 15),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.8),
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildKeyMetrics(BuildContext context) {
    return GridView.count(
      shrinkWrap: true,
      crossAxisCount: 2,
      crossAxisSpacing: 16,
      mainAxisSpacing: 16,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        _buildMetricCard(
          context,
          'Total Land Area',
          '3.5 Hectares',
          Icons.landscape,
          AppColors.accentGreen,
        ),
        _buildMetricCard(
          context,
          'Next Harvest Date',
          'Dec 15, 2025',
          Icons.calendar_today,
          AppColors.accentOrange,
        ),
      ],
    );
  }

  Widget _buildMetricCard(
      BuildContext context, String title, String value, IconData icon, Color color) {
    return Card(
      color: AppColors.cardBackground,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Icon(icon, color: color, size: 30),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: AppColors.darkText,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.darkText.withOpacity(0.7),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMapPlaceholderCard(BuildContext context) {
    return Card(
      color: AppColors.cardBackground,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Container(
        height: 180,
        width: double.infinity,
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.map, color: AppColors.primaryBlue.withOpacity(0.7), size: 50),
            const SizedBox(height: 8),
            const Text(
              'Interactive Land Map (GIS Integration)',
              style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText),
            ),
            Text(
              'Tap to view boundaries, soil health, and zoning details.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppColors.darkText.withOpacity(0.6)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryCard(BuildContext context, String title, String quantity, Color color) {
    return Card(
      color: AppColors.cardBackground,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(Icons.inventory_2, color: color, size: 30),
        title: Text(
          title,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText),
        ),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            quantity,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ),
        onTap: () {
          // Navigate to detailed inventory view
        },
      ),
    );
  }

  Widget _buildQuickActionButton(
      BuildContext context, String label, IconData icon, Color color) {
    return Expanded(
      child: ElevatedButton.icon(
        onPressed: () {
          // Action handler
        },
        icon: Icon(icon, color: Colors.white),
        label: Text(label, style: const TextStyle(color: Colors.white)),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}