import 'package:flutter/material.dart';

// Reusing AppColors locally
class AppColors {
  static const Color background = Color(0xFFEEEBFF);
  static const Color darkText = Color(0xFF2C2A3A);
  static const Color primaryBlue = Color(0xFF2764E7);
  static const Color accentRed = Color(0xFFE53935); 
  static const Color accentTeal = Color(0xFF00BFA5);
  static const Color cardBackground = Colors.white;
}

class FactoryOwnerDashboard extends StatelessWidget {
  const FactoryOwnerDashboard({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Factory Owner Dashboard', style: TextStyle(color: AppColors.darkText, fontWeight: FontWeight.bold)),
        backgroundColor: AppColors.cardBackground,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings, color: AppColors.darkText),
            onPressed: () {
              // Settings action
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout, color: AppColors.darkText),
            onPressed: () {
              // Logout action
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
            _buildWelcomeCard('Welcome, CeyLogix Management', 'Factory ID: F-045A', context),
            
            const SizedBox(height: 20),
            
            // Key Metrics Grid
            _buildKeyMetrics(context),

            const SizedBox(height: 20),
            const Text('Processing & Compliance', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.darkText)),
            const SizedBox(height: 10),

            // Raw Material Inventory Card
            _buildInventorySummaryCard(context),

            const SizedBox(height: 20),
            const Text('Export Orders', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.darkText)),
            const SizedBox(height: 10),
            
            // Export Order List
            _buildExportOrderCard(context, 'ORD-2025-450', 'Dubai', 'Processing', AppColors.accentTeal),
            _buildExportOrderCard(context, 'ORD-2025-449', 'Germany', 'Shipped', AppColors.primaryBlue),

            const SizedBox(height: 20),

            // Quick Actions
            Row(
              children: [
                _buildQuickActionButton(
                  context, 
                  'Certificates', 
                  Icons.verified_user, 
                  AppColors.accentTeal
                ),
                const SizedBox(width: 16),
                _buildQuickActionButton(
                  context, 
                  'Staff Management', 
                  Icons.people, 
                  AppColors.primaryBlue
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
      padding: const EdgeInsets.all(20),
      
      child: Row(
        children: [
          const Icon(Icons.factory, color: Colors.white, size: 40),
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
          'Total Raw Stock (kg)',
          '42,500',
          Icons.storage,
          AppColors.primaryBlue,
        ),
        _buildMetricCard(
          context,
          'Pending Exports',
          '8 Orders',
          Icons.flight_takeoff,
          AppColors.accentRed,
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

  Widget _buildInventorySummaryCard(BuildContext context) {
    return Card(
      color: AppColors.cardBackground,
      elevation: 4,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Raw Material Inventory Overview',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: AppColors.darkText),
            ),
            const Divider(),
            _buildInventoryItem('Received Today:', '2,100 kg', AppColors.accentTeal),
            _buildInventoryItem('Needs Processing:', '15,000 kg', AppColors.accentRed),
            _buildInventoryItem('Finished Goods:', '12,500 kg', AppColors.primaryBlue),
          ],
        ),
      ),
    );
  }

  Widget _buildInventoryItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: TextStyle(color: AppColors.darkText.withOpacity(0.8))),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildExportOrderCard(BuildContext context, String orderId, String destination, String status, Color statusColor) {
    return Card(
      color: AppColors.cardBackground,
      elevation: 2,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      child: ListTile(
        leading: Icon(Icons.assessment, color: statusColor, size: 30),
        title: Text(
          orderId,
          style: const TextStyle(fontWeight: FontWeight.w600, color: AppColors.darkText),
        ),
        subtitle: Text('Destination: $destination'),
        trailing: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: statusColor.withOpacity(0.1),
            borderRadius: BorderRadius.circular(6),
          ),
          child: Text(
            status,
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: statusColor,
              fontSize: 12,
            ),
          ),
        ),
        onTap: () {
          // Navigate to detailed order view
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
        label: Text(label, style: const TextStyle(color: Colors.white), overflow: TextOverflow.ellipsis),
        style: ElevatedButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 15),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }
}