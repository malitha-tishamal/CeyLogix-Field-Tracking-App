// export_product_details.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'land_owner_drawer.dart';

// -----------------------------------------------------------------------------
// --- MODERN COLOR PALETTE ---
class AppColors {
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color primary = Color(0xFF4361EE);
  static const Color primaryLight = Color(0xFFE6EBFF);
  static const Color secondary = Color(0xFF4CC9F0);
  static const Color accent = Color(0xFF7209B7);
  static const Color success = Color(0xFF4CAF50);
  static const Color warning = Color(0xFFFF9800);
  static const Color error = Color(0xFFF44336);
  static const Color info = Color(0xFF2196F3);
  
  static const Color textPrimary = Color(0xFF1A1A1A);
  static const Color textSecondary = Color(0xFF666666);
  static const Color textTertiary = Color(0xFF999999);
  
  static const Color border = Color(0xFFE1E5E9);
  static const Color divider = Color(0xFFF0F2F5);
  static const Color hover = Color(0xFFF5F7FA);
  
  static const Color teaGreen = Color(0xFF2E7D32);
  static const Color cinnamonBrown = Color(0xFF795548);
  static const Color factoryReceivedBlue = Color(0xFF2196F3);
  
  // Header gradient colors
  static const Color headerGradientStart = Color(0xFF869AEC);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
}

// -----------------------------------------------------------------------------
// --- STATUS HELPER FUNCTIONS ---
String normalizeStatus(String status) {
  if (status.isEmpty) return 'pending';
  
  final lowerStatus = status.toLowerCase().trim();
  
  if (lowerStatus.contains('factory') && lowerStatus.contains('receive')) {
    return 'factory_received';
  } else if (lowerStatus.contains('factory') && lowerStatus.contains('reciv')) {
    return 'factory_received';
  } else if (lowerStatus == 'factory recived') {
    return 'factory_received';
  } else if (lowerStatus == 'received factory') {
    return 'factory_received';
  } else if (lowerStatus.contains('delivered') || 
             lowerStatus.contains('completed') || 
             lowerStatus.contains('accepted')) {
    return 'completed';
  } else if (lowerStatus.contains('cancel') || 
             lowerStatus.contains('rejected')) {
    return 'cancelled';
  } else if (lowerStatus.contains('pending')) {
    return 'pending';
  }
  
  return lowerStatus;
}

Color getStatusColor(String status) {
  final normalizedStatus = normalizeStatus(status);
  
  switch (normalizedStatus) {
    case 'pending':
      return AppColors.warning;
    case 'factory_received':
      return AppColors.factoryReceivedBlue;
    case 'completed':
      return AppColors.success;
    case 'cancelled':
      return AppColors.error;
    default:
      return AppColors.primary;
  }
}

IconData getStatusIcon(String status) {
  final normalizedStatus = normalizeStatus(status);
  
  switch (normalizedStatus) {
    case 'pending':
      return Icons.pending_outlined;
    case 'factory_received':
      return Icons.factory_rounded;
    case 'completed':
      return Icons.check_circle_outline_rounded;
    case 'cancelled':
      return Icons.cancel_outlined;
    default:
      return Icons.info_outline_rounded;
  }
}

String getDisplayStatus(String status) {
  final normalizedStatus = normalizeStatus(status);
  
  switch (normalizedStatus) {
    case 'pending':
      return 'Pending';
    case 'factory_received':
      return 'Factory Received';
    case 'completed':
      return 'Completed';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status.isNotEmpty 
          ? status[0].toUpperCase() + status.substring(1)
          : 'Pending';
  }
}

// -----------------------------------------------------------------------------
// --- ORDER DETAILS MODAL ---
class OrderDetailsModal extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String orderId;

  const OrderDetailsModal({
    super.key,
    required this.orderData,
    required this.orderId,
  });

  @override
  State<OrderDetailsModal> createState() => _OrderDetailsModalState();
}

class _OrderDetailsModalState extends State<OrderDetailsModal> {
  Map<String, dynamic>? _factoryData;
  bool _loadingFactoryData = true;

  @override
  void initState() {
    super.initState();
    _fetchFactoryData();
  }

  Future<void> _fetchFactoryData() async {
    final factoryId = widget.orderData['factoryId']?.toString();
    if (factoryId == null || factoryId.isEmpty) {
      setState(() {
        _loadingFactoryData = false;
      });
      return;
    }

    try {
      final factoryDoc = await FirebaseFirestore.instance
          .collection('factories')
          .doc(factoryId)
          .get();

      if (factoryDoc.exists) {
        setState(() {
          _factoryData = factoryDoc.data();
          _loadingFactoryData = false;
        });
      } else {
        setState(() {
          _loadingFactoryData = false;
        });
      }
    } catch (e) {
      debugPrint('Error fetching factory data: $e');
      setState(() {
        _loadingFactoryData = false;
      });
    }
  }

  Widget _buildDetailRow(String title, String value, {bool isLast = false}) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
      decoration: BoxDecoration(
        border: isLast
            ? null
            : Border(
                bottom: BorderSide(
                  color: AppColors.border,
                  width: 1,
                ),
              ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 2,
            child: Text(
              value,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.right,
            ),
          ),
        ],
      ),
    );
  }

  String _formatDate(Timestamp? timestamp) {
    if (timestamp == null) return 'N/A';
    return DateFormat('MMM dd, yyyy • HH:mm').format(timestamp.toDate());
  }

  Widget _buildStatusTimeline(Color statusColor, String currentStatus) {
    final normalizedStatus = normalizeStatus(currentStatus);
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Timeline Step 1 - Order Placed
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: AppColors.success,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check,
                    size: 14,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Order Placed',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          
          // Timeline connector
          Expanded(
            child: Container(
              height: 2,
              color: AppColors.border,
            ),
          ),
          
          // Timeline Step 2 - Factory Received (if applicable)
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: normalizedStatus == 'factory_received' 
                        ? statusColor 
                        : AppColors.border,
                    shape: BoxShape.circle,
                    boxShadow: normalizedStatus == 'factory_received'
                        ? [
                            BoxShadow(
                              color: statusColor.withOpacity(0.4),
                              blurRadius: 6,
                              offset: const Offset(0, 2),
                            ),
                          ]
                        : null,
                  ),
                  child: Icon(
                    Icons.factory_rounded,
                    size: 14,
                    color: normalizedStatus == 'factory_received'
                        ? Colors.white
                        : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Factory Received',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: normalizedStatus == 'factory_received'
                        ? statusColor
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
          
          // Timeline connector
          Expanded(
            child: Container(
              height: 2,
              color: AppColors.border,
            ),
          ),
          
          // Timeline Step 3 - Delivery/Completed
          Expanded(
            child: Column(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: normalizedStatus == 'completed'
                        ? AppColors.success
                        : AppColors.border,
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    normalizedStatus == 'completed'
                        ? Icons.check
                        : Icons.local_shipping_rounded,
                    size: 14,
                    color: normalizedStatus == 'completed'
                        ? Colors.white
                        : AppColors.textTertiary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  normalizedStatus == 'completed' ? 'Completed' : 'Delivery',
                  style: TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: normalizedStatus == 'completed'
                        ? AppColors.success
                        : AppColors.textTertiary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final status = widget.orderData['status']?.toString() ?? 'Pending';
    final displayStatus = getDisplayStatus(status);
    final statusColor = getStatusColor(status);
    final normalizedStatus = normalizeStatus(status);
    final cropType = widget.orderData['cropType'] ?? 'Both';
    final factoryName = widget.orderData['factoryName'] ?? 'Unknown Factory';
    final factoryId = widget.orderData['factoryId'] ?? '';
    final totalQuantity = widget.orderData['totalQuantity']?.toString() ?? '0';
    final teaQuantity = widget.orderData['teaQuantity']?.toString() ?? '0';
    final cinnamonQuantity = widget.orderData['cinnamonQuantity']?.toString() ?? '0';
    final description = widget.orderData['description'] ?? '';
    final unit = widget.orderData['unit'] ?? 'kg';
    final orderPhotos = (widget.orderData['orderPhotos'] as List<dynamic>?) ?? [];
    final orderDate = widget.orderData['orderDate'] as Timestamp?;
    final createdAt = widget.orderData['createdAt'] as Timestamp?;
    final updatedAt = widget.orderData['updatedAt'] as Timestamp?;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        constraints: const BoxConstraints(
          maxWidth: 500,
          maxHeight: 600,
        ),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 30,
              spreadRadius: 5,
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: statusColor.withOpacity(0.1),
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(24),
                  topRight: Radius.circular(24),
                ),
                border: Border(
                  bottom: BorderSide(
                    color: statusColor.withOpacity(0.2),
                    width: 1,
                  ),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: statusColor,
                          borderRadius: BorderRadius.circular(16),
                          boxShadow: [
                            BoxShadow(
                              color: statusColor.withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Icon(
                          getStatusIcon(status),
                          size: 24,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Order Details',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${widget.orderId.substring(0, 8)}',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            
                            // Status-specific message
                            if (normalizedStatus == 'factory_received')
                              Padding(
                                padding: const EdgeInsets.only(top: 8),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.check_circle_outline_rounded,
                                      size: 14,
                                      color: statusColor,
                                    ),
                                    const SizedBox(width: 6),
                                    Text(
                                      'Products received by factory',
                                      style: TextStyle(
                                        fontSize: 12,
                                        color: statusColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                          ],
                        ),
                      ),
                      
                      // Status Badge
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 16,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: statusColor.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: statusColor.withOpacity(0.4),
                            width: 2,
                          ),
                        ),
                        child: Text(
                          displayStatus.toUpperCase(),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: statusColor,
                            letterSpacing: 1,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  // Status Timeline for Factory Received or Completed
                  if (normalizedStatus == 'factory_received' || normalizedStatus == 'completed') ...[
                    const SizedBox(height: 16),
                    _buildStatusTimeline(statusColor, status),
                  ],
                ],
              ),
            ),

            // Content
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Factory Info with Logo
                      _buildFactorySection(factoryName, factoryId),
                      
                      const SizedBox(height: 16),

                      // Order Summary
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.hover,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ORDER SUMMARY',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            
                            // Crop Type
                            Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: cropType == 'Tea'
                                        ? AppColors.teaGreen.withOpacity(0.1)
                                        : cropType == 'Cinnamon'
                                            ? AppColors.cinnamonBrown.withOpacity(0.1)
                                            : AppColors.primary.withOpacity(0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    cropType,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: cropType == 'Tea'
                                          ? AppColors.teaGreen
                                          : cropType == 'Cinnamon'
                                              ? AppColors.cinnamonBrown
                                              : AppColors.primary,
                                    ),
                                  ),
                                ),
                                const Spacer(),
                                Text(
                                  'TOTAL: $totalQuantity $unit',
                                  style: TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.primary,
                                  ),
                                ),
                              ],
                            ),

                            const SizedBox(height: 16),

                            // Quantity Breakdown
                            if (cropType == 'Both' && (double.parse(teaQuantity) > 0 || double.parse(cinnamonQuantity) > 0))
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceAround,
                                children: [
                                  if (double.parse(teaQuantity) > 0)
                                    _buildQuantityPill(
                                      label: 'TEA',
                                      value: teaQuantity,
                                      unit: unit,
                                      color: AppColors.teaGreen,
                                    ),
                                  if (double.parse(cinnamonQuantity) > 0)
                                    _buildQuantityPill(
                                      label: 'CINNAMON',
                                      value: cinnamonQuantity,
                                      unit: unit,
                                      color: AppColors.cinnamonBrown,
                                    ),
                                ],
                              ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Order Details
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: AppColors.border),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'ORDER INFORMATION',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                                letterSpacing: 1,
                              ),
                            ),
                            const SizedBox(height: 12),
                            _buildDetailRow('Order Date', _formatDate(orderDate)),
                            _buildDetailRow('Created', _formatDate(createdAt)),
                            _buildDetailRow('Last Updated', _formatDate(updatedAt)),
                          ],
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Description
                      if (description.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'DESCRIPTION',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                            ],
                          ),
                        ),

                      const SizedBox(height: 16),

                      // Photos
                      if (orderPhotos.isNotEmpty)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: AppColors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: AppColors.border),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'ORDER PHOTOS (${orderPhotos.length})',
                                style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 12),
                              SizedBox(
                                height: 100,
                                child: ListView.builder(
                                  scrollDirection: Axis.horizontal,
                                  itemCount: orderPhotos.length,
                                  itemBuilder: (context, index) {
                                    return Container(
                                      margin: const EdgeInsets.only(right: 12),
                                      width: 100,
                                      height: 100,
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(color: AppColors.border),
                                      ),
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(12),
                                        child: CachedNetworkImage(
                                          imageUrl: orderPhotos[index],
                                          fit: BoxFit.cover,
                                          placeholder: (context, url) => Container(
                                            color: AppColors.hover,
                                            child: Center(
                                              child: CircularProgressIndicator(
                                                color: AppColors.primary,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                          ),
                                          errorWidget: (context, url, error) => Container(
                                            color: AppColors.hover,
                                            child: const Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.broken_image,
                                                  color: AppColors.textTertiary,
                                                  size: 32,
                                                ),
                                                SizedBox(height: 8),
                                                Text(
                                                  'Failed to load',
                                                  style: TextStyle(
                                                    fontSize: 10,
                                                    color: AppColors.textTertiary,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ),

            // Close Button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                border: Border(
                  top: BorderSide(
                    color: AppColors.border,
                    width: 1,
                  ),
                ),
              ),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Close',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

Widget _buildFactorySection(String factoryName, String factoryId) {
  final factoryLogo = _factoryData?['factoryLogoUrl'] ?? 
                     _factoryData?['logoUrl'] ?? 
                     _factoryData?['logo'] ?? 
                     _factoryData?['imageUrl'];
  final contactNumber = _factoryData?['contactNumber'] ?? 'Not available';
  final address = _factoryData?['address'] ?? 'Not available';

  // Use factory initials as fallback
  String getFactoryInitials(String name) {
    if (name.isEmpty) return 'F';
    final parts = name.split(' ');
    if (parts.length >= 2) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return name.substring(0, 1).toUpperCase();
  }

  Widget _buildDefaultFactoryLogo(String name) {
    return Container(
      color: AppColors.primaryLight,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.factory,
            size: 32,
            color: AppColors.primary,
          ),
          const SizedBox(height: 4),
          Text(
            getFactoryInitials(name),
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            'Factory',
            style: TextStyle(
              fontSize: 10,
              color: AppColors.primary,
            ),
          ),
        ],
      ),
    );
  }

  return Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: AppColors.hover,
      borderRadius: BorderRadius.circular(16),
    ),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Factory Logo
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.border),
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: factoryLogo != null && 
                   factoryLogo.toString().isNotEmpty && 
                   factoryLogo.toString().startsWith('http')
                ? CachedNetworkImage(
                    imageUrl: factoryLogo.toString(),
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(
                      color: AppColors.primaryLight,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: AppColors.primary,
                          strokeWidth: 2,
                        ),
                      ),
                    ),
                    errorWidget: (context, url, error) => _buildDefaultFactoryLogo(factoryName),
                  )
                : _buildDefaultFactoryLogo(factoryName),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                factoryName,
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'ID: $factoryId',
                style: TextStyle(
                  fontSize: 14,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),
              if (_loadingFactoryData)
                Row(
                  children: [
                    SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'Loading factory details...',
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                )
              else if (_factoryData != null)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '📞 $contactNumber',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '📍 $address',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
            ],
          ),
        ),
      ],
    ),
  );
}

  Widget _buildQuantityPill({
    required String label,
    required String value,
    required String unit,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '$value $unit',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// --- EXPORT PRODUCTS HISTORY PAGE ---
// -----------------------------------------------------------------------------
class ExportProductsHistoryPage extends StatefulWidget {
  const ExportProductsHistoryPage({super.key});

  @override
  State<ExportProductsHistoryPage> createState() => _ExportProductsHistoryPageState();
}

class _ExportProductsHistoryPageState extends State<ExportProductsHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // User info variables
  String _loggedInUserName = 'Loading...';
  String _landName = 'Loading...';
  String _userRole = 'Land Owner';
  String? _profileImageUrl;
  
  // Responsive variables
  late double _screenWidth;
  late double _screenHeight;
  
  // Filter and search variables
  String _filterStatus = 'All';
  String _filterCropType = 'All';
  String _searchQuery = '';
  String _sortBy = 'Newest';
  String? _selectedFactory;
  
  // Status filter options - Enhanced
  final List<String> _statusOptions = [
    'All',
    'Pending',
    'Factory Received',
    'Completed',
    'Cancelled'
  ];

  // Crop type options
  final List<String> _cropTypeOptions = [
    'All',
    'Tea',
    'Cinnamon',
    'Both'
  ];

  // Sort options
  final List<String> _sortOptions = [
    'Newest',
    'Oldest',
    'Most Quantity',
    'Least Quantity'
  ];

  // Available factories list
  final List<String> _allFactories = ['All'];
  
  // Statistics variables
  Map<String, dynamic> _statistics = {
    'totalTea': 0.0,
    'totalCinnamon': 0.0,
    'totalOrders': 0,
    'todayTea': 0.0,
    'todayCinnamon': 0.0,
    'todayOrders': 0,
    'weekTea': 0.0,
    'weekCinnamon': 0.0,
    'weekOrders': 0,
    'pendingCount': 0,
    'factoryReceivedCount': 0,
    'completedCount': 0,
    'cancelledCount': 0,
  };

  @override
  void initState() {
    super.initState();
    _fetchHeaderData();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _updateScreenDimensions();
  }

  void _updateScreenDimensions() {
    final mediaQuery = MediaQuery.of(context);
    _screenWidth = mediaQuery.size.width;
    _screenHeight = mediaQuery.size.height;
  }

  void _handleDrawerNavigate(String routeName) {
    Navigator.pop(context);
  }

  void _fetchHeaderData() async {
    final user = _currentUser;
    if (user == null) return;

    try {
      final userDoc = await _firestore.collection('users').doc(user.uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner Name';
          _profileImageUrl = userData?['profileImageUrl'];
          _userRole = userData?['role'] ?? 'Land Owner';
        });
      }
      
      final landDoc = await _firestore.collection('lands').doc(user.uid).get();
      if (landDoc.exists) {
        setState(() {
          _landName = landDoc.data()?['landName'] ?? 'Land Name';
        });
      }
    } catch (e) {
      debugPrint("Error fetching header data: $e");
    }
  }

  // Calculate statistics
  Map<String, dynamic> _calculateStatistics(List<QueryDocumentSnapshot> orders) {
    double teaTotal = 0;
    double cinnamonTotal = 0;
    
    // Status counters
    int pendingCount = 0;
    int factoryReceivedCount = 0;
    int completedCount = 0;
    int cancelledCount = 0;
    
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final weekStart = now.subtract(Duration(days: now.weekday - 1));
    
    double todayTea = 0;
    double todayCinnamon = 0;
    double weekTea = 0;
    double weekCinnamon = 0;
    int todayOrders = 0;
    int weekOrders = 0;
    
    final factorySet = <String>{};
    
    for (final order in orders) {
      final data = order.data() as Map<String, dynamic>;
      
      // Get status and normalize
      final status = data['status']?.toString() ?? 'pending';
      final normalizedStatus = normalizeStatus(status);
      
      // Count by status
      switch (normalizedStatus) {
        case 'pending':
          pendingCount++;
          break;
        case 'factory_received':
          factoryReceivedCount++;
          break;
        case 'completed':
          completedCount++;
          break;
        case 'cancelled':
          cancelledCount++;
          break;
      }
      
      // Add factory to set
      final factoryName = data['factoryName']?.toString() ?? 'Unknown';
      final factoryId = data['factoryId']?.toString() ?? '';
      if (factoryName.isNotEmpty && factoryId.isNotEmpty) {
        factorySet.add('$factoryName\n$factoryId');
      }
      
      // Get quantities
      final totalQty = _getQuantity(data['totalQuantity']);
      final teaQty = _getQuantity(data['teaQuantity']);
      final cinnamonQty = _getQuantity(data['cinnamonQuantity']);
      final cropType = data['cropType']?.toString() ?? 'Both';
      
      // Calculate based on crop type
      if (cropType == 'Tea') {
        teaTotal += totalQty;
      } else if (cropType == 'Cinnamon') {
        cinnamonTotal += totalQty;
      } else if (cropType == 'Both') {
        if (teaQty > 0 || cinnamonQty > 0) {
          teaTotal += teaQty;
          cinnamonTotal += cinnamonQty;
        } else {
          teaTotal += totalQty;
          cinnamonTotal += totalQty;
        }
      }
      
      // Check order date
      final orderDate = (data['orderDate'] as Timestamp?)?.toDate();
      if (orderDate != null) {
        // Today's orders
        if (orderDate.isAfter(todayStart)) {
          if (cropType == 'Tea') {
            todayTea += totalQty;
          } else if (cropType == 'Cinnamon') {
            todayCinnamon += totalQty;
          } else if (cropType == 'Both') {
            if (teaQty > 0 || cinnamonQty > 0) {
              todayTea += teaQty;
              todayCinnamon += cinnamonQty;
            } else {
              todayTea += totalQty;
              todayCinnamon += totalQty;
            }
          }
          todayOrders++;
        }
        
        // This week's orders
        if (orderDate.isAfter(weekStart)) {
          if (cropType == 'Tea') {
            weekTea += totalQty;
          } else if (cropType == 'Cinnamon') {
            weekCinnamon += totalQty;
          } else if (cropType == 'Both') {
            if (teaQty > 0 || cinnamonQty > 0) {
              weekTea += teaQty;
              weekCinnamon += cinnamonQty;
            } else {
              weekTea += totalQty;
              weekCinnamon += totalQty;
            }
          }
          weekOrders++;
        }
      }
    }
    
    // Update factories list
    if (factorySet.isNotEmpty) {
      _allFactories.clear();
      _allFactories.addAll(['All', ...factorySet.toList()]);
    }
    
    return {
      'totalTea': teaTotal,
      'totalCinnamon': cinnamonTotal,
      'totalOrders': orders.length,
      'todayTea': todayTea,
      'todayCinnamon': todayCinnamon,
      'todayOrders': todayOrders,
      'weekTea': weekTea,
      'weekCinnamon': weekCinnamon,
      'weekOrders': weekOrders,
      'pendingCount': pendingCount,
      'factoryReceivedCount': factoryReceivedCount,
      'completedCount': completedCount,
      'cancelledCount': cancelledCount,
    };
  }

  double _getQuantity(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) {
      return double.tryParse(value) ?? 0.0;
    }
    return 0.0;
  }

  // Sort orders
  List<QueryDocumentSnapshot> _sortOrders(List<QueryDocumentSnapshot> orders) {
    return List.from(orders)..sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aDate = (aData['orderDate'] as Timestamp?)?.toDate() ?? DateTime(0);
      final bDate = (bData['orderDate'] as Timestamp?)?.toDate() ?? DateTime(0);
      
      switch (_sortBy) {
        case 'Newest':
          return bDate.compareTo(aDate);
        case 'Oldest':
          return aDate.compareTo(bDate);
        case 'Most Quantity':
          final aQty = _getQuantity(aData['totalQuantity'] ?? 0);
          final bQty = _getQuantity(bData['totalQuantity'] ?? 0);
          return bQty.compareTo(aQty);
        case 'Least Quantity':
          final aQty = _getQuantity(aData['totalQuantity'] ?? 0);
          final bQty = _getQuantity(bData['totalQuantity'] ?? 0);
          return aQty.compareTo(bQty);
        default:
          return bDate.compareTo(aDate);
      }
    });
  }

  // Enhanced filter function
  bool _shouldShowOrder(Map<String, dynamic> orderData) {
    // Get normalized status
    final status = orderData['status']?.toString() ?? 'pending';
    final displayStatus = getDisplayStatus(status);
    
    // Filter by status
    if (_filterStatus != 'All' && _filterStatus != displayStatus) {
      return false;
    }
    
    // Filter by crop type
    if (_filterCropType != 'All' && orderData['cropType'] != _filterCropType) {
      return false;
    }
    
    // Filter by factory
    if (_selectedFactory != null && _selectedFactory != 'All') {
      final factoryName = orderData['factoryName']?.toString() ?? '';
      final factoryId = orderData['factoryId']?.toString() ?? '';
      final factoryDisplay = '$factoryName\n$factoryId';
      if (factoryDisplay != _selectedFactory) {
        return false;
      }
    }
    
    // Search filter
    if (_searchQuery.isNotEmpty) {
      final factoryName = (orderData['factoryName'] ?? '').toString().toLowerCase();
      final description = (orderData['description'] ?? '').toString().toLowerCase();
      final orderId = orderData['id']?.toString().toLowerCase() ?? '';
      final cropType = (orderData['cropType'] ?? '').toString().toLowerCase();
      final searchLower = _searchQuery.toLowerCase();
      
      return factoryName.contains(searchLower) ||
          description.contains(searchLower) ||
          orderId.contains(searchLower) ||
          cropType.contains(searchLower);
    }
    
    return true;
  }

  // Format currency
  String _formatCurrency(double amount) {
    return NumberFormat.currency(
      symbol: 'LKR ',
      decimalDigits: 0,
    ).format(amount);
  }

  // Show order details modal
  void _showOrderDetails(BuildContext context, String orderId, Map<String, dynamic> orderData) {
    showDialog(
      context: context,
      barrierColor: Colors.black.withOpacity(0.5),
      builder: (context) {
        return OrderDetailsModal(
          orderData: orderData,
          orderId: orderId,
        );
      },
    );
  }

  // Show sort dialog
  void _showSortDialog() {
    final isSmallScreen = _screenWidth < 360;
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              SizedBox(height: isSmallScreen ? 12.0 : 16.0),
              Text(
                'Sort Orders',
                style: TextStyle(
                  fontSize: isSmallScreen ? 16.0 : 18.0,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: isSmallScreen ? 16.0 : 20.0),
              ..._sortOptions.map((option) {
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _sortBy == option ? AppColors.primaryLight : AppColors.hover,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      _getSortIcon(option),
                      color: _sortBy == option ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
                  title: Text(
                    option,
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  trailing: _sortBy == option
                      ? Icon(
                          Icons.check_circle_rounded,
                          color: AppColors.primary,
                        )
                      : null,
                  onTap: () {
                    setState(() {
                      _sortBy = option;
                    });
                    Navigator.pop(context);
                  },
                );
              }).toList(),
              SizedBox(height: isSmallScreen ? 16.0 : 20.0),
            ],
          ),
        );
      },
    );
  }

  IconData _getSortIcon(String option) {
    switch (option) {
      case 'Newest':
        return Icons.new_releases_rounded;
      case 'Oldest':
        return Icons.history_rounded;
      case 'Most Quantity':
        return Icons.arrow_upward_rounded;
      case 'Least Quantity':
        return Icons.arrow_downward_rounded;
      default:
        return Icons.sort_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    _updateScreenDimensions();
    final isSmallScreen = _screenWidth < 360;
    final isMediumScreen = _screenWidth >= 360 && _screenWidth < 400;
    
    if (_currentUser == null) {
      return Scaffold(
        body: Center(child: Text("Error: User not logged in.")),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: LandOwnerDrawer(
        onLogout: () {
          Navigator.of(context).pop();
        },
        onNavigate: _handleDrawerNavigate,
      ),
      body: Column(
        children: [
          // 🌟 FIXED HEADER - Responsive
          _buildDashboardHeader(context, isSmallScreen, isMediumScreen),
          
          // 🌟 SCROLLABLE CONTENT ONLY with Footer
          Expanded(
            child: Column(
              children: [
                // Scrollable content
                Expanded(
                  child: StreamBuilder<QuerySnapshot>(
                    stream: _firestore
                        .collection('land_orders')
                        .where('landOwnerId', isEqualTo: _currentUser?.uid)
                        .snapshots(),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return _buildLoadingScreen();
                      }
                      
                      if (snapshot.hasError) {
                        return _buildErrorScreen(snapshot.error.toString());
                      }
                      
                      final orders = snapshot.data?.docs ?? [];
                      final stats = _calculateStatistics(orders);
                      _statistics = stats;
                      
                      final filteredOrders = orders.where((order) => _shouldShowOrder(order.data() as Map<String, dynamic>)).toList();
                      final sortedOrders = _sortOrders(filteredOrders);
                      
                      return SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Column(
                          children: [
                            // Statistics
                            _buildStatistics(stats, isSmallScreen, isMediumScreen),
                            
                            // Search and Filters
                            _buildSearchFilters(isSmallScreen, isMediumScreen),
                            
                            // Orders List
                            sortedOrders.isEmpty
                                ? _buildEmptyState(isSmallScreen, isMediumScreen)
                                : Column(
                                    children: sortedOrders.map((order) => 
                                      _buildOrderCard(order, isSmallScreen, isMediumScreen)
                                    ).toList(),
                                  ),
                            
                            const SizedBox(height: 20),
                          ],
                        ),
                      );
                    },
                  ),
                ),
                
                // Footer (Fixed at bottom of content area)
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                  child: Text(
                    'Developed by Malitha Tishamal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textPrimary.withOpacity(0.7),
                      fontSize: isSmallScreen ? 11 : 12,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(
            color: AppColors.primary,
          ),
          const SizedBox(height: 16),
          Text(
            'Loading export history...',
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorScreen(String error) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.error_outline_rounded,
            size: 64,
            color: AppColors.error,
          ),
          const SizedBox(height: 16),
          Text(
            'Error loading data',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: const Text(
              'Retry',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // 🌟 FIXED HEADER - Responsive version
  Widget _buildDashboardHeader(BuildContext context, bool isSmallScreen, bool isMediumScreen) {
    final topPadding = MediaQuery.of(context).padding.top + 10;
    final horizontalPadding = isSmallScreen ? 16.0 : 20.0;
    final profileSize = isSmallScreen ? 60.0 : 70.0;
    final menuIconSize = isSmallScreen ? 24.0 : 28.0;
    final nameFontSize = isSmallScreen ? 16.0 : 20.0;
    final landFontSize = isSmallScreen ? 14.0 : 16.0;
    final titleFontSize = isSmallScreen ? 14.0 : 16.0;

    return Container(
      padding: EdgeInsets.only(
        top: topPadding,
        left: horizontalPadding,
        right: horizontalPadding,
        bottom: isSmallScreen ? 16.0 : 20.0,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(20),
          bottomRight: Radius.circular(20),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 10,
            offset: Offset(0, 3),
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
                icon: Icon(Icons.menu, color: AppColors.textPrimary, size: menuIconSize),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
                padding: EdgeInsets.zero,
                constraints: BoxConstraints(
                  minWidth: menuIconSize + 16,
                  minHeight: menuIconSize + 16,
                ),
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 8.0 : 10.0),
          
          Row(
            children: [
              // Profile Picture with Firebase image
              Container(
                width: profileSize,
                height: profileSize,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _profileImageUrl == null 
                    ? const LinearGradient(
                        colors: [AppColors.primary, Color(0xFF457AED)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      )
                    : null,
                  border: Border.all(
                    color: Colors.white, 
                    width: isSmallScreen ? 2.0 : 3.0
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: isSmallScreen ? 8.0 : 10.0,
                      offset: const Offset(0, 3),
                    ),
                  ],
                  image: _profileImageUrl != null 
                    ? DecorationImage(
                        image: NetworkImage(_profileImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                ),
                child: _profileImageUrl == null
                    ? Icon(
                        Icons.person, 
                        size: isSmallScreen ? 32.0 : 40.0, 
                        color: Colors.white
                      )
                    : null,
              ),
              
              SizedBox(width: isSmallScreen ? 12.0 : 15.0),
              
              // User Info Display from Firebase
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1. Land Owner Name
                    Text(
                      _loggedInUserName,
                      style: TextStyle(
                        fontSize: nameFontSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    //Land Name Name and Role
                    Text(
                      'Land: $_landName\n($_userRole)', 
                      style: TextStyle(
                        fontSize: landFontSize,
                        color: AppColors.textPrimary.withOpacity(0.7),
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: isSmallScreen ? 20.0 : 25.0), 
          
          // Page Title
          Text(
            'Export History',
            style: TextStyle(
              fontSize: titleFontSize,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(Map<String, dynamic> stats, bool isSmallScreen, bool isMediumScreen) {
    final horizontalPadding = isSmallScreen ? 12.0 : 16.0;
    final verticalPadding = isSmallScreen ? 20.0 : 25.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Container(
        padding: EdgeInsets.all(isSmallScreen ? 16.0 : 20.0),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: isSmallScreen ? 10.0 : 20.0,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Export Overview',
                  style: TextStyle(
                    fontSize: isSmallScreen ? 16.0 : 18.0,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 10.0 : 12.0, vertical: isSmallScreen ? 4.0 : 6.0),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                  ),
                  child: Text(
                    '${stats['totalOrders']} orders',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 12.0 : 14.0,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            SizedBox(height: isSmallScreen ? 16.0 : 20.0),
            
            // Status Statistics
            Container(
              padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
              decoration: BoxDecoration(
                color: AppColors.hover,
                borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Order Status Breakdown',
                    style: TextStyle(
                      fontSize: isSmallScreen ? 14.0 : 16.0,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  SizedBox(height: isSmallScreen ? 8.0 : 12.0),
                  Wrap(
                    spacing: isSmallScreen ? 8.0 : 12.0,
                    runSpacing: isSmallScreen ? 8.0 : 12.0,
                    children: [
                      _buildStatusStatItem(
                        count: stats['pendingCount'],
                        label: 'Pending',
                        color: getStatusColor('pending'),
                        isSmallScreen: isSmallScreen,
                      ),
                      _buildStatusStatItem(
                        count: stats['factoryReceivedCount'],
                        label: 'Factory Received',
                        color: getStatusColor('factory_received'),
                        isSmallScreen: isSmallScreen,
                      ),
                      _buildStatusStatItem(
                        count: stats['completedCount'],
                        label: 'Completed',
                        color: getStatusColor('completed'),
                        isSmallScreen: isSmallScreen,
                      ),
                      _buildStatusStatItem(
                        count: stats['cancelledCount'],
                        label: 'Cancelled',
                        color: getStatusColor('cancelled'),
                        isSmallScreen: isSmallScreen,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(height: isSmallScreen ? 16.0 : 20.0),
            
            // Quantity Statistics
            Row(
              children: [
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.emoji_food_beverage_rounded,
                    label: 'Tea Exported',
                    value: '${stats['totalTea'].toStringAsFixed(1)} kg',
                    color: AppColors.teaGreen,
                    today: stats['todayTea'],
                    week: stats['weekTea'],
                    isSmallScreen: isSmallScreen,
                    isMediumScreen: isMediumScreen,
                  ),
                ),
                SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                Expanded(
                  child: _buildStatItem(
                    icon: Icons.spa_rounded,
                    label: 'Cinnamon Exported',
                    value: '${stats['totalCinnamon'].toStringAsFixed(1)} kg',
                    color: AppColors.cinnamonBrown,
                    today: stats['todayCinnamon'],
                    week: stats['weekCinnamon'],
                    isSmallScreen: isSmallScreen,
                    isMediumScreen: isMediumScreen,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatusStatItem({
    required int count,
    required String label,
    required Color color,
    required bool isSmallScreen,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 12.0 : 16.0, vertical: isSmallScreen ? 6.0 : 8.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: isSmallScreen ? 8.0 : 10.0,
            height: isSmallScreen ? 8.0 : 10.0,
            decoration: BoxDecoration(
              color: color,
              shape: BoxShape.circle,
            ),
          ),
          SizedBox(width: isSmallScreen ? 6.0 : 8.0),
          Text(
            '$count',
            style: TextStyle(
              fontSize: isSmallScreen ? 14.0 : 16.0,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(width: isSmallScreen ? 4.0 : 6.0),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 12.0 : 14.0,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required double today,
    required double week,
    required bool isSmallScreen,
    required bool isMediumScreen,
  }) {
    return Container(
      padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 6.0 : 8.0),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
                ),
                child: Icon(
                  icon,
                  size: isSmallScreen ? 16.0 : 20.0,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: isSmallScreen ? 14.0 : 18.0,
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: isSmallScreen ? 8.0 : 12.0),
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 12.0 : 14.0,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: isSmallScreen ? 6.0 : 8.0),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10.0 : 12.0,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 1.0 : 2.0),
                    Text(
                      '${today.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12.0 : 14.0,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'This Week',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 10.0 : 12.0,
                        color: AppColors.textTertiary,
                      ),
                    ),
                    SizedBox(height: isSmallScreen ? 1.0 : 2.0),
                    Text(
                      '${week.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: isSmallScreen ? 12.0 : 14.0,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchFilters(bool isSmallScreen, bool isMediumScreen) {
    final horizontalPadding = isSmallScreen ? 12.0 : 16.0;
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontalPadding),
      child: Column(
        children: [
          // Search Bar
          Container(
            height: isSmallScreen ? 48.0 : 52.0,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(isSmallScreen ? 12.0 : 16.0),
              border: Border.all(color: AppColors.border),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.03),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Row(
              children: [
                SizedBox(width: isSmallScreen ? 12.0 : 16.0),
                Icon(
                  Icons.search_rounded,
                  color: AppColors.textTertiary,
                  size: isSmallScreen ? 18.0 : 20.0,
                ),
                SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                Expanded(
                  child: TextField(
                    onChanged: (value) {
                      setState(() {
                        _searchQuery = value;
                      });
                    },
                    decoration: InputDecoration(
                      hintText: 'Search orders...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: isSmallScreen ? 13.0 : 14.0,
                      ),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textTertiary,
                      size: isSmallScreen ? 18.0 : 20.0,
                    ),
                    onPressed: () {
                      setState(() {
                        _searchQuery = '';
                      });
                    },
                  ),
                SizedBox(width: isSmallScreen ? 6.0 : 8.0),
              ],
            ),
          ),
          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
          
          // Status Filter Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _statusOptions.map((status) {
                final isSelected = _filterStatus == status;
                final color = getStatusColor(status);
                
                return GestureDetector(
                  onTap: () {
                    setState(() {
                      _filterStatus = status;
                    });
                  },
                  child: Container(
                    margin: EdgeInsets.only(right: isSmallScreen ? 8.0 : 12.0),
                    padding: EdgeInsets.symmetric(
                      horizontal: isSmallScreen ? 16.0 : 20.0,
                      vertical: isSmallScreen ? 8.0 : 10.0,
                    ),
                    decoration: BoxDecoration(
                      color: isSelected ? color : color.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
                      border: Border.all(
                        color: isSelected ? color : color.withOpacity(0.3),
                        width: isSelected ? 2 : 1,
                      ),
                      boxShadow: isSelected
                          ? [
                              BoxShadow(
                                color: color.withOpacity(0.3),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ]
                          : null,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (status != 'All')
                          Icon(
                            getStatusIcon(status),
                            size: isSmallScreen ? 16.0 : 18.0,
                            color: isSelected ? Colors.white : color,
                          ),
                        if (status != 'All') SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                        Text(
                          status,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13.0 : 14.0,
                            fontWeight: FontWeight.w600,
                            color: isSelected ? Colors.white : color,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          
          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
          
          // Crop Type and Factory Filters
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                // Crop Type Filter
                Container(
                  padding: EdgeInsets.all(isSmallScreen ? 2.0 : 4.0),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 6.0 : 8.0),
                        child: Icon(
                          Icons.category_rounded,
                          size: isSmallScreen ? 14.0 : 16.0,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      ..._cropTypeOptions.map((cropType) {
                        final isSelected = _filterCropType == cropType;
                        final color = cropType == 'Tea'
                            ? AppColors.teaGreen
                            : cropType == 'Cinnamon'
                                ? AppColors.cinnamonBrown
                                : AppColors.primary;
                        
                        return GestureDetector(
                          onTap: () {
                            setState(() {
                              _filterCropType = cropType;
                            });
                          },
                          child: Container(
                            margin: EdgeInsets.only(right: isSmallScreen ? 3.0 : 4.0),
                            padding: EdgeInsets.symmetric(
                              horizontal: isSmallScreen ? 10.0 : 12.0,
                              vertical: isSmallScreen ? 4.0 : 6.0,
                            ),
                            decoration: BoxDecoration(
                              color: isSelected ? color : Colors.transparent,
                              borderRadius: BorderRadius.circular(isSmallScreen ? 6.0 : 8.0),
                            ),
                            child: Text(
                              cropType,
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11.0 : 13.0,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      }).toList(),
                    ],
                  ),
                ),
                
                SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                
                // Factory Filter
                if (_allFactories.length > 1)
                  Container(
                    padding: EdgeInsets.all(isSmallScreen ? 2.0 : 4.0),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Padding(
                          padding: EdgeInsets.symmetric(horizontal: isSmallScreen ? 6.0 : 8.0),
                          child: Icon(
                            Icons.factory_rounded,
                            size: isSmallScreen ? 14.0 : 16.0,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        DropdownButtonHideUnderline(
                          child: DropdownButton<String>(
                            value: _selectedFactory ?? 'All',
                            icon: Icon(
                              Icons.arrow_drop_down_rounded,
                              size: isSmallScreen ? 16.0 : 20.0,
                              color: AppColors.textSecondary,
                            ),
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12.0 : 14.0,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textPrimary,
                            ),
                            onChanged: (String? newValue) {
                              setState(() {
                                _selectedFactory = newValue;
                              });
                            },
                            items: _allFactories.map<DropdownMenuItem<String>>((String value) {
                              return DropdownMenuItem<String>(
                                value: value,
                                child: Text(
                                  value.length > 20 ? '${value.substring(0, 20)}...' : value,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 11.0 : 13.0,
                                  ),
                                ),
                              );
                            }).toList(),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                SizedBox(width: isSmallScreen ? 8.0 : 12.0),
                
                // Sort Button
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isSmallScreen ? 12.0 : 16.0,
                    vertical: isSmallScreen ? 8.0 : 10.0,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: GestureDetector(
                    onTap: _showSortDialog,
                    child: Row(
                      children: [
                        Icon(
                          Icons.sort_rounded,
                          size: isSmallScreen ? 16.0 : 18.0,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: isSmallScreen ? 6.0 : 8.0),
                        Text(
                          _sortBy,
                          style: TextStyle(
                            fontSize: isSmallScreen ? 13.0 : 14.0,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Icon(
                          Icons.arrow_drop_down_rounded,
                          size: isSmallScreen ? 16.0 : 18.0,
                          color: AppColors.textSecondary,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOrderCard(QueryDocumentSnapshot order, bool isSmallScreen, bool isMediumScreen) {
    final data = order.data() as Map<String, dynamic>;
    final status = data['status']?.toString() ?? 'Pending';
    final displayStatus = getDisplayStatus(status);
    final statusColor = getStatusColor(status);
    final normalizedStatus = normalizeStatus(status);
    final cropType = data['cropType'] ?? 'Both';
    final factoryName = data['factoryName'] ?? 'Unknown Factory';
    final factoryId = data['factoryId'] ?? '';
    final totalQuantity = _getQuantity(data['totalQuantity']);
    final teaQuantity = _getQuantity(data['teaQuantity']);
    final cinnamonQuantity = _getQuantity(data['cinnamonQuantity']);
    final description = data['description'] ?? '';
    final orderPhotos = (data['orderPhotos'] as List<dynamic>?) ?? [];
    final orderDate = data['orderDate'] as Timestamp?;
    final unit = data['unit'] ?? 'kg';
    final horizontalPadding = isSmallScreen ? 12.0 : 16.0;
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: isSmallScreen ? 8.0 : 12.0,
      ),
      child: GestureDetector(
        onTap: () {
          _showOrderDetails(context, order.id, data);
        },
        child: Container(
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: isSmallScreen ? 8.0 : 10.0,
                offset: const Offset(0, 2),
              ),
            ],
            border: Border.all(
              color: statusColor.withOpacity(0.2),
              width: 1,
            ),
          ),
          child: Column(
            children: [
              // Enhanced Order Header with status
              Container(
                padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                decoration: BoxDecoration(
                  color: statusColor.withOpacity(0.08),
                  borderRadius: BorderRadius.only(
                    topLeft: Radius.circular(isSmallScreen ? 16.0 : 20.0),
                    topRight: Radius.circular(isSmallScreen ? 16.0 : 20.0),
                  ),
                  border: Border(
                    bottom: BorderSide(
                      color: statusColor.withOpacity(0.1),
                      width: 1,
                    ),
                  ),
                ),
                child: Row(
                  children: [
                    // Status Indicator
                    Container(
                      padding: EdgeInsets.all(isSmallScreen ? 8.0 : 10.0),
                      decoration: BoxDecoration(
                        color: statusColor,
                        borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
                        boxShadow: [
                          BoxShadow(
                            color: statusColor.withOpacity(0.4),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: Icon(
                        getStatusIcon(status),
                        size: isSmallScreen ? 16.0 : 20.0,
                        color: Colors.white,
                      ),
                    ),
                    
                    SizedBox(width: isSmallScreen ? 10.0 : 12.0),
                    
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(
                                child: Text(
                                  factoryName,
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 14.0 : 16.0,
                                    fontWeight: FontWeight.w700,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              const SizedBox(width: 8),
                              // Status Badge
                              Container(
                                padding: EdgeInsets.symmetric(
                                  horizontal: isSmallScreen ? 10.0 : 12.0, 
                                  vertical: isSmallScreen ? 4.0 : 6.0
                                ),
                                decoration: BoxDecoration(
                                  color: statusColor.withOpacity(0.2),
                                  borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
                                  border: Border.all(
                                    color: statusColor.withOpacity(0.4),
                                    width: 1,
                                  ),
                                ),
                                child: Text(
                                  displayStatus.toUpperCase(),
                                  style: TextStyle(
                                    fontSize: isSmallScreen ? 10.0 : 12.0,
                                    fontWeight: FontWeight.w700,
                                    color: statusColor,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          SizedBox(height: isSmallScreen ? 2.0 : 4.0),
                          
                          // Status-specific message
                          if (normalizedStatus == 'factory_received')
                            Text(
                              'Your products have been received by the factory',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11.0 : 12.0,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          
                          // Factory ID
                          if (factoryId.isNotEmpty)
                            Text(
                              'ID: $factoryId',
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11.0 : 12.0,
                                color: AppColors.textTertiary,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              
              // Order Details
              Padding(
                padding: EdgeInsets.all(isSmallScreen ? 12.0 : 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Crop and Quantity
                    Row(
                      children: [
                        Container(
                          padding: EdgeInsets.symmetric(
                            horizontal: isSmallScreen ? 10.0 : 12.0, 
                            vertical: isSmallScreen ? 4.0 : 6.0
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.hover,
                            borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
                          ),
                          child: Text(
                            cropType,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12.0 : 14.0,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        const Spacer(),
                        Text(
                          '${totalQuantity.toStringAsFixed(1)} $unit',
                          style: TextStyle(
                            fontSize: isSmallScreen ? 18.0 : 24.0,
                            fontWeight: FontWeight.w700,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                    
                    SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                    
                    // Quantity Breakdown
                    if (cropType == 'Both' && (teaQuantity > 0 || cinnamonQuantity > 0))
                      Container(
                        padding: EdgeInsets.all(isSmallScreen ? 10.0 : 12.0),
                        decoration: BoxDecoration(
                          color: AppColors.hover,
                          borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceAround,
                          children: [
                            if (teaQuantity > 0)
                              _buildQuantityPill(
                                label: 'Tea',
                                value: teaQuantity,
                                unit: unit,
                                color: AppColors.teaGreen,
                                isSmallScreen: isSmallScreen,
                                isMediumScreen: isMediumScreen,
                              ),
                            if (cinnamonQuantity > 0)
                              _buildQuantityPill(
                                label: 'Cinnamon',
                                value: cinnamonQuantity,
                                unit: unit,
                                color: AppColors.cinnamonBrown,
                                isSmallScreen: isSmallScreen,
                                isMediumScreen: isMediumScreen,
                              ),
                          ],
                        ),
                      ),
                    
                    SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                    
                    // Description preview
                    if (description.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Description',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12.0 : 14.0,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 4.0 : 6.0),
                          Text(
                            description.length > 100 
                                ? '${description.substring(0, 100)}...' 
                                : description,
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12.0 : 14.0,
                              color: AppColors.textPrimary,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    
                    // Photos preview
                    if (orderPhotos.isNotEmpty)
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(height: isSmallScreen ? 12.0 : 16.0),
                          Text(
                            'Photos (${orderPhotos.length})',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 12.0 : 14.0,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textSecondary,
                            ),
                          ),
                          SizedBox(height: isSmallScreen ? 6.0 : 8.0),
                          SizedBox(
                            height: isSmallScreen ? 60.0 : 80.0,
                            child: ListView.builder(
                              scrollDirection: Axis.horizontal,
                              itemCount: orderPhotos.length > 3 ? 3 : orderPhotos.length,
                              itemBuilder: (context, index) {
                                return Container(
                                  margin: EdgeInsets.only(right: isSmallScreen ? 6.0 : 8.0),
                                  width: isSmallScreen ? 60.0 : 80.0,
                                  height: isSmallScreen ? 60.0 : 80.0,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
                                    image: DecorationImage(
                                      image: NetworkImage(orderPhotos[index]),
                                      fit: BoxFit.cover,
                                    ),
                                  ),
                                  child: index == 2 && orderPhotos.length > 3
                                      ? Container(
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(isSmallScreen ? 8.0 : 12.0),
                                            color: Colors.black.withOpacity(0.5),
                                          ),
                                          child: Center(
                                            child: Text(
                                              '+${orderPhotos.length - 3}',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontSize: 16,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                          ),
                                        )
                                      : null,
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    
                    // Timestamp
                    if (orderDate != null)
                      Padding(
                        padding: EdgeInsets.only(top: isSmallScreen ? 12.0 : 16.0),
                        child: Row(
                          children: [
                            Icon(
                              Icons.access_time_rounded,
                              size: isSmallScreen ? 14.0 : 16.0,
                              color: AppColors.textTertiary,
                            ),
                            SizedBox(width: isSmallScreen ? 4.0 : 6.0),
                            Text(
                              DateFormat('MMM dd, yyyy • HH:mm').format(orderDate.toDate()),
                              style: TextStyle(
                                fontSize: isSmallScreen ? 11.0 : 13.0,
                                color: AppColors.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    
                    // Click hint
                    Padding(
                      padding: EdgeInsets.only(top: isSmallScreen ? 12.0 : 16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.touch_app,
                            size: isSmallScreen ? 14.0 : 16.0,
                            color: AppColors.primary,
                          ),
                          SizedBox(width: isSmallScreen ? 4.0 : 6.0),
                          Text(
                            'Tap to view full details',
                            style: TextStyle(
                              fontSize: isSmallScreen ? 11.0 : 12.0,
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildQuantityPill({
    required String label,
    required double value,
    required String unit,
    required Color color,
    required bool isSmallScreen,
    required bool isMediumScreen,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isSmallScreen ? 12.0 : 16.0, 
        vertical: isSmallScreen ? 6.0 : 8.0
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(isSmallScreen ? 16.0 : 20.0),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: isSmallScreen ? 11.0 : 13.0,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
          SizedBox(width: isSmallScreen ? 6.0 : 8.0),
          Text(
            '${value.toStringAsFixed(1)} $unit',
            style: TextStyle(
              fontSize: isSmallScreen ? 12.0 : 14.0,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      )
    );
  }

  Widget _buildEmptyState(bool isSmallScreen, bool isMediumScreen) {
    final horizontalPadding = isSmallScreen ? 12.0 : 16.0;
    final verticalPadding = isSmallScreen ? 40.0 : 60.0;

    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: horizontalPadding,
        vertical: verticalPadding,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: isSmallScreen ? 60.0 : 80.0,
            color: AppColors.textTertiary.withOpacity(0.3),
          ),
          SizedBox(height: isSmallScreen ? 16.0 : 20.0),
          Text(
            'No orders found',
            style: TextStyle(
              fontSize: isSmallScreen ? 16.0 : 18.0,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: isSmallScreen ? 6.0 : 8.0),
          Text(
            _searchQuery.isNotEmpty || _filterStatus != 'All' || _filterCropType != 'All' || (_selectedFactory != null && _selectedFactory != 'All')
                ? 'Try adjusting your filters'
                : 'Start exporting your products to see history',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: isSmallScreen ? 12.0 : 14.0,
              color: AppColors.textTertiary,
            ),
          ),
          SizedBox(height: isSmallScreen ? 20.0 : 24.0),
          if (_searchQuery.isNotEmpty || _filterStatus != 'All' || _filterCropType != 'All' || (_selectedFactory != null && _selectedFactory != 'All'))
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _filterStatus = 'All';
                  _filterCropType = 'All';
                  _selectedFactory = 'All';
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(isSmallScreen ? 10.0 : 12.0),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: isSmallScreen ? 20.0 : 24.0, 
                  vertical: isSmallScreen ? 10.0 : 12.0
                ),
              ),
              child: Text(
                'Clear All Filters',
                style: TextStyle(
                  fontSize: isSmallScreen ? 14.0 : 16.0,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }
}