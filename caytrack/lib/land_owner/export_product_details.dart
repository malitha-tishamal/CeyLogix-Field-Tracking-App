// export_product_details.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'land_owner_drawer.dart';

// -----------------------------------------------------------------------------
// --- RESPONSIVE UTILITIES ---
enum ScreenSize { 
  small,   // < 360
  medium,  // 360-600
  large,   // 600-900
  xlarge   // > 900
}

ScreenSize getScreenSize(double width) {
  if (width < 360) return ScreenSize.small;
  if (width < 600) return ScreenSize.medium;
  if (width < 900) return ScreenSize.large;
  return ScreenSize.xlarge;
}

double getResponsivePadding(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < 360) return 12.0;
  if (width < 600) return 16.0;
  if (width < 900) return 20.0;
  return 24.0;
}

double getResponsiveFontSize(BuildContext context, 
    {double small = 12.0, double medium = 14.0, 
     double large = 16.0, double xlarge = 18.0}) {
  final width = MediaQuery.of(context).size.width;
  if (width < 360) return small;
  if (width < 600) return medium;
  if (width < 900) return large;
  return xlarge;
}

// -----------------------------------------------------------------------------
// --- IMAGE URL HELPER ---
List<String> parseImageUrls(dynamic photosData) {
  final List<String> urls = [];
  
  if (photosData == null) return urls;
  
  if (photosData is String) {
    // Handle single URL string
    final trimmedUrl = photosData.trim();
    if (trimmedUrl.isNotEmpty && 
        (trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://'))) {
      urls.add(trimmedUrl);
    }
  } else if (photosData is List) {
    // Handle list of URLs
    for (var item in photosData) {
      if (item is String) {
        final trimmedUrl = item.trim();
        if (trimmedUrl.isNotEmpty && 
            (trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://'))) {
          urls.add(trimmedUrl);
        }
      }
    }
  }
  
  return urls;
}

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
      ));
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
    
    // FIXED: Use parseImageUrls helper to handle both string and list
    final orderPhotos = parseImageUrls(widget.orderData['orderPhotos']);
    
    final orderDate = widget.orderData['orderDate'] as Timestamp?;
    final createdAt = widget.orderData['createdAt'] as Timestamp?;
    final updatedAt = widget.orderData['updatedAt'] as Timestamp?;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(getResponsivePadding(context)),
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.9,
          maxHeight: MediaQuery.of(context).size.height * 0.9,
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
              padding: EdgeInsets.all(getResponsivePadding(context)),
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
                                fontSize: getResponsiveFontSize(context, small: 16, medium: 18, large: 20, xlarge: 22),
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'ID: ${widget.orderId.substring(0, 8)}',
                              style: TextStyle(
                                fontSize: getResponsiveFontSize(context, small: 12, medium: 14, large: 14, xlarge: 14),
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
                                        fontSize: getResponsiveFontSize(context, small: 10, medium: 12, large: 12, xlarge: 12),
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
                            fontSize: getResponsiveFontSize(context, small: 10, medium: 12, large: 12, xlarge: 12),
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
                  padding: EdgeInsets.all(getResponsivePadding(context)),
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
                                fontSize: getResponsiveFontSize(context, small: 10, medium: 12, large: 12, xlarge: 12),
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
                                      fontSize: getResponsiveFontSize(context, small: 12, medium: 14, large: 14, xlarge: 14),
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
                                    fontSize: getResponsiveFontSize(context, small: 16, medium: 18, large: 18, xlarge: 18),
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
                                fontSize: getResponsiveFontSize(context, small: 10, medium: 12, large: 12, xlarge: 12),
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
                                  fontSize: getResponsiveFontSize(context, small: 10, medium: 12, large: 12, xlarge: 12),
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textSecondary,
                                  letterSpacing: 1,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                description,
                                style: TextStyle(
                                  fontSize: getResponsiveFontSize(context, small: 12, medium: 14, large: 14, xlarge: 14),
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
                                  fontSize: getResponsiveFontSize(context, small: 10, medium: 12, large: 12, xlarge: 12),
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
                                            child: Column(
                                              mainAxisAlignment: MainAxisAlignment.center,
                                              children: [
                                                Icon(
                                                  Icons.broken_image,
                                                  color: AppColors.textTertiary,
                                                  size: 32,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  'Failed to load',
                                                  style: TextStyle(
                                                    fontSize: getResponsiveFontSize(context, small: 8, medium: 10, large: 10, xlarge: 10),
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
              padding: EdgeInsets.all(getResponsivePadding(context)),
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
                  child: Text(
                    'Close',
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(context, small: 14, medium: 16, large: 16, xlarge: 16),
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
    ));
  }
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

// -----------------------------------------------------------------------------
// --- STATIC FOOTER WIDGET ---
Widget _buildStaticFooter(BuildContext context) {
  final screenSize = getScreenSize(MediaQuery.of(context).size.width);
  final padding = getResponsivePadding(context);
  
  return Container(
    padding: EdgeInsets.symmetric(
      horizontal: padding,
      vertical: padding * 0.5,
    ),
    decoration: BoxDecoration(
      color: AppColors.surface,
      border: Border(
        top: BorderSide(
          color: AppColors.border,
          width: 1,
        ),
      ),
    ),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (screenSize == ScreenSize.xlarge || screenSize == ScreenSize.large)
          Text(
            '© ${DateTime.now().year} Export Management System',
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: getResponsiveFontSize(
                context,
                small: 10.0,
                medium: 11.0,
                large: 12.0,
                xlarge: 13.0,
              ),
            ),
          ),
        Expanded(
          child: Text(
            'Developed by Malitha Tishamal',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.textTertiary,
              fontSize: getResponsiveFontSize(
                context,
                small: 10.0,
                medium: 11.0,
                large: 12.0,
                xlarge: 13.0,
              ),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    ),
  );
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
  void _showSortDialog(BuildContext context) {
    final screenSize = getScreenSize(MediaQuery.of(context).size.width);
    final padding = getResponsivePadding(context);
    
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: EdgeInsets.all(padding),
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
              SizedBox(height: padding * 0.8),
              Text(
                'Sort Orders',
                style: TextStyle(
                  fontSize: getResponsiveFontSize(context, small: 16, medium: 18, large: 18, xlarge: 20),
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              SizedBox(height: padding),
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
                      fontSize: getResponsiveFontSize(context, small: 14, medium: 16, large: 16, xlarge: 16),
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
              SizedBox(height: padding),
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
    final screenSize = getScreenSize(MediaQuery.of(context).size.width);
    final padding = getResponsivePadding(context);
    
    if (_currentUser == null) {
      return Scaffold(
        body: Center(child: Text("Error: User not logged in.")),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: LandOwnerDrawer(
        onLogout: () => Navigator.of(context).pop(),
        onNavigate: _handleDrawerNavigate,
      ),
      body: SafeArea(
        child: Column(
          children: [
            // HEADER - Responsive
            _buildDashboardHeader(context),
            
            // MAIN CONTENT
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
                  
                  return RefreshIndicator(
                    onRefresh: () async => setState(() {}),
                    child: CustomScrollView(
                      slivers: [
                        // Statistics section
                        SliverToBoxAdapter(
                          child: _buildStatistics(stats, context),
                        ),
                        
                        // Search filters
                        SliverToBoxAdapter(
                          child: _buildSearchFilters(context),
                        ),
                        
                        // Orders list/grid based on screen size
                        if (sortedOrders.isEmpty)
                          SliverToBoxAdapter(
                            child: _buildEmptyState(context),
                          )
                        else if (screenSize == ScreenSize.xlarge || screenSize == ScreenSize.large)
                          // Grid view for large screens
                          SliverGrid(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: screenSize == ScreenSize.xlarge ? 2 : 1,
                              crossAxisSpacing: padding,
                              mainAxisSpacing: padding * 0.5,
                              childAspectRatio: screenSize == ScreenSize.xlarge ? 1.6 : 2.0,
                            ),
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildOrderCard(sortedOrders[index], context),
                              childCount: sortedOrders.length,
                            ),
                          )
                        else
                          // List view for small/medium screens
                          SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) => _buildOrderCard(sortedOrders[index], context),
                              childCount: sortedOrders.length,
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            
            // STATIC FOOTER (outside scrollable content)
            _buildStaticFooter(context),
          ],
        ),
      ),
      
      // Floating Action Button for small screens
      floatingActionButton: screenSize == ScreenSize.small
          ? FloatingActionButton(
              backgroundColor: AppColors.primary,
              onPressed: () => _showSortDialog(context),
              child: const Icon(Icons.filter_alt, color: Colors.white),
            )
          : null,
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

  // 🌟 ENHANCED HEADER - Fully Responsive
  Widget _buildDashboardHeader(BuildContext context) {
    final screenSize = getScreenSize(MediaQuery.of(context).size.width);
    final topPadding = MediaQuery.of(context).padding.top + 10;
    final padding = getResponsivePadding(context);
    
    // Responsive dimensions
    final profileSize = switch(screenSize) {
      ScreenSize.small => 48.0,
      ScreenSize.medium => 56.0,
      ScreenSize.large => 64.0,
      ScreenSize.xlarge => 72.0,
    };
    
    final nameFontSize = getResponsiveFontSize(
      context,
      small: 14.0,
      medium: 16.0,
      large: 18.0,
      xlarge: 20.0,
    );
    
    final titleFontSize = getResponsiveFontSize(
      context,
      small: 16.0,
      medium: 18.0,
      large: 20.0,
      xlarge: 22.0,
    );

    return Container(
      padding: EdgeInsets.only(
        top: topPadding,
        left: padding,
        right: padding,
        bottom: 16.0,
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
                icon: Icon(Icons.menu, 
                  color: AppColors.textPrimary, 
                  size: profileSize * 0.4,
                ),
                onPressed: () => _scaffoldKey.currentState?.openDrawer(),
              ),
              
              // Additional icons for larger screens
              if (screenSize == ScreenSize.xlarge || screenSize == ScreenSize.large)
                Row(
                  children: [
                    IconButton(
                      icon: Icon(Icons.refresh, color: AppColors.textPrimary, size: profileSize * 0.35),
                      onPressed: () => setState(() {}),
                    ),
                    IconButton(
                      icon: Icon(Icons.download, color: AppColors.textPrimary, size: profileSize * 0.35),
                      onPressed: () {},
                    ),
                  ],
                ),
            ],
          ),
          
          SizedBox(height: screenSize == ScreenSize.small ? 8.0 : 12.0),
          
          Row(
            children: [
              // Profile Picture
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
                    width: screenSize == ScreenSize.small ? 2.0 : 3.0
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 8.0,
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
                        size: profileSize * 0.5, 
                        color: Colors.white
                      )
                    : null,
              ),
              
              SizedBox(width: screenSize == ScreenSize.small ? 8.0 : 12.0),
              
              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // User name
                    Text(
                      _loggedInUserName,
                      style: TextStyle(
                        fontSize: nameFontSize,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                      maxLines: screenSize == ScreenSize.small ? 1 : 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    
                    SizedBox(height: screenSize == ScreenSize.small ? 2.0 : 4.0),
                    
                    // Land name and role
                    if (screenSize == ScreenSize.small)
                      Text(
                        '$_landName ($_userRole)',
                        style: TextStyle(
                          fontSize: nameFontSize * 0.8,
                          color: AppColors.textPrimary.withOpacity(0.7),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    else
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Land: $_landName',
                            style: TextStyle(
                              fontSize: nameFontSize * 0.8,
                              color: AppColors.textPrimary.withOpacity(0.7),
                            ),
                          ),
                          Text(
                            'Role: $_userRole',
                            style: TextStyle(
                              fontSize: nameFontSize * 0.8,
                              color: AppColors.textPrimary.withOpacity(0.7),
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
              ),
            ],
          ),
          
          SizedBox(height: screenSize == ScreenSize.small ? 12.0 : 16.0),
          
          // Page Title with responsive layout
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Export History',
                style: TextStyle(
                  fontSize: titleFontSize,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              
              // Quick stats for larger screens
              if (screenSize == ScreenSize.xlarge)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '${_statistics['totalOrders']} Orders',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w600,
                      fontSize: nameFontSize * 0.8,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildStatistics(Map<String, dynamic> stats, BuildContext context) {
    final screenSize = getScreenSize(MediaQuery.of(context).size.width);
    final padding = getResponsivePadding(context);
    
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Container(
        padding: EdgeInsets.all(padding),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(padding * 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          children: [
            // Header
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Export Overview',
                  style: TextStyle(
                    fontSize: getResponsiveFontSize(
                      context,
                      small: 14.0,
                      medium: 16.0,
                      large: 18.0,
                      xlarge: 20.0,
                    ),
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: padding * 0.8,
                    vertical: padding * 0.4,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.primaryLight,
                    borderRadius: BorderRadius.circular(padding * 0.8),
                  ),
                  child: Text(
                    '${stats['totalOrders']} orders',
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(
                        context,
                        small: 11.0,
                        medium: 12.0,
                        large: 13.0,
                        xlarge: 14.0,
                      ),
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
            
            SizedBox(height: padding),
            
            // Status Stats Grid
            GridView.count(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              crossAxisCount: screenSize == ScreenSize.small ? 2 : 4,
              childAspectRatio: screenSize == ScreenSize.small ? 2.5 : 3.0,
              mainAxisSpacing: padding * 0.8,
              crossAxisSpacing: padding * 0.2,
              children: [
                _buildStatusStatItem(
                  count: stats['pendingCount'],
                  label: 'Pending',
                  color: getStatusColor('pending'),
                  context: context,
                ),
                _buildStatusStatItem(
                  count: stats['factoryReceivedCount'],
                  label: 'Factory\nReceived',
                  color: getStatusColor('factory_received'),
                  context: context,
                ),
                _buildStatusStatItem(
                  count: stats['completedCount'],
                  label: 'Completed',
                  color: getStatusColor('completed'),
                  context: context,
                ),
                _buildStatusStatItem(
                  count: stats['cancelledCount'],
                  label: 'Cancelled',
                  color: getStatusColor('cancelled'),
                  context: context,
                ),
              ],
            ),
            
            SizedBox(height: padding),
            
            // Quantity Stats - Responsive layout
            if (screenSize == ScreenSize.small)
              Column(
                children: [
                  _buildQuantityStatItem(
                    icon: Icons.emoji_food_beverage_rounded,
                    label: 'Tea Exported',
                    value: '${stats['totalTea'].toStringAsFixed(1)} kg',
                    color: AppColors.teaGreen,
                    today: stats['todayTea'],
                    week: stats['weekTea'],
                    context: context,
                  ),
                  SizedBox(height: padding * 0.8),
                  _buildQuantityStatItem(
                    icon: Icons.spa_rounded,
                    label: 'Cinnamon Exported',
                    value: '${stats['totalCinnamon'].toStringAsFixed(1)} kg',
                    color: AppColors.cinnamonBrown,
                    today: stats['todayCinnamon'],
                    week: stats['weekCinnamon'],
                    context: context,
                  ),
                ],
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _buildQuantityStatItem(
                      icon: Icons.emoji_food_beverage_rounded,
                      label: 'Tea Exported',
                      value: '${stats['totalTea'].toStringAsFixed(1)} kg',
                      color: AppColors.teaGreen,
                      today: stats['todayTea'],
                      week: stats['weekTea'],
                      context: context,
                    ),
                  ),
                  SizedBox(width: padding),
                  Expanded(
                    child: _buildQuantityStatItem(
                      icon: Icons.spa_rounded,
                      label: 'Cinnamon Exported',
                      value: '${stats['totalCinnamon'].toStringAsFixed(1)} kg',
                      color: AppColors.cinnamonBrown,
                      today: stats['todayCinnamon'],
                      week: stats['weekCinnamon'],
                      context: context,
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
    required BuildContext context,
  }) {
    final screenSize = getScreenSize(MediaQuery.of(context).size.width);
    final padding = getResponsivePadding(context);
    
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: padding * 0.8,
        vertical: padding * 0.6,
      ),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(padding * 0.8),
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            '$count',
            style: TextStyle(
              fontSize: getResponsiveFontSize(
                context,
                small: 16.0,
                medium: 18.0,
                large: 20.0,
                xlarge: 22.0,
              ),
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          SizedBox(height: padding * 0.2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: getResponsiveFontSize(
                context,
                small: 10.0,
                medium: 11.0,
                large: 12.0,
                xlarge: 13.0,
              ),
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQuantityStatItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
    required double today,
    required double week,
    required BuildContext context,
  }) {
    final padding = getResponsivePadding(context);
    
    return Container(
      padding: EdgeInsets.all(padding),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(padding),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(padding * 0.5),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(padding * 0.6),
                ),
                child: Icon(
                  icon,
                  size: padding,
                  color: color,
                ),
              ),
              const Spacer(),
              Text(
                value,
                style: TextStyle(
                  fontSize: getResponsiveFontSize(
                    context,
                    small: 14.0,
                    medium: 16.0,
                    large: 18.0,
                    xlarge: 20.0,
                  ),
                  fontWeight: FontWeight.w700,
                  color: color,
                ),
              ),
            ],
          ),
          SizedBox(height: padding * 0.6),
          Text(
            label,
            style: TextStyle(
              fontSize: getResponsiveFontSize(
                context,
                small: 11.0,
                medium: 12.0,
                large: 13.0,
                xlarge: 14.0,
              ),
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: padding * 0.4),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Today',
                      style: TextStyle(
                        fontSize: getResponsiveFontSize(
                          context,
                          small: 9.0,
                          medium: 10.0,
                          large: 11.0,
                          xlarge: 12.0,
                        ),
                        color: AppColors.textTertiary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${today.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: getResponsiveFontSize(
                          context,
                          small: 11.0,
                          medium: 12.0,
                          large: 13.0,
                          xlarge: 14.0,
                        ),
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
                        fontSize: getResponsiveFontSize(
                          context,
                          small: 9.0,
                          medium: 10.0,
                          large: 11.0,
                          xlarge: 12.0,
                        ),
                        color: AppColors.textTertiary,
                      ),
                    ),
                    SizedBox(height: 2),
                    Text(
                      '${week.toStringAsFixed(1)} kg',
                      style: TextStyle(
                        fontSize: getResponsiveFontSize(
                          context,
                          small: 11.0,
                          medium: 12.0,
                          large: 13.0,
                          xlarge: 14.0,
                        ),
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

  Widget _buildSearchFilters(BuildContext context) {
    final screenSize = getScreenSize(MediaQuery.of(context).size.width);
    final padding = getResponsivePadding(context);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding, vertical: padding * 0.5),
      child: Column(
        children: [
          // Search Bar
          Container(
            height: screenSize == ScreenSize.small ? 44 : 48,
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(padding),
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
                SizedBox(width: padding * 0.8),
                Icon(
                  Icons.search_rounded,
                  color: AppColors.textTertiary,
                  size: padding,
                ),
                SizedBox(width: padding * 0.6),
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search orders...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: getResponsiveFontSize(
                          context,
                          small: 12.0,
                          medium: 13.0,
                          large: 14.0,
                          xlarge: 15.0,
                        ),
                      ),
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    icon: Icon(Icons.close, size: padding * 0.8),
                    onPressed: () => setState(() => _searchQuery = ''),
                  ),
              ],
            ),
          ),
          
          SizedBox(height: padding * 0.8),
          
          // Filter Chips - Wrap on small screens, horizontal scroll on larger
          if (screenSize == ScreenSize.small)
            Wrap(
              spacing: padding * 0.5,
              runSpacing: padding * 0.5,
              children: _statusOptions.map((status) => 
                _buildFilterChip(status, context)
              ).toList(),
            )
          else
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: _statusOptions.map((status) => 
                  _buildFilterChip(status, context)
                ).toList(),
              ),
            ),
          
          // Additional filters for medium+ screens
          if (screenSize != ScreenSize.small) ...[
            SizedBox(height: padding * 0.8),
            Row(
              children: [
                // Crop Type Filter
                Expanded(
                  child: Container(
                    padding: EdgeInsets.all(padding * 0.5),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(padding),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.category,
                          size: padding * 0.8,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: padding * 0.4),
                        Expanded(
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              value: _filterCropType,
                              onChanged: (value) => 
                                setState(() => _filterCropType = value!),
                              items: _cropTypeOptions.map((type) => 
                                DropdownMenuItem(
                                  value: type,
                                  child: Text(
                                    type,
                                    style: TextStyle(
                                      fontSize: getResponsiveFontSize(
                                        context,
                                        small: 11.0,
                                        medium: 12.0,
                                        large: 13.0,
                                        xlarge: 14.0,
                                      ),
                                    ),
                                  ),
                                )
                              ).toList(),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                
                SizedBox(width: padding * 0.8),
                
                // Sort Button
                GestureDetector(
                  onTap: () => _showSortDialog(context),
                  child: Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: padding,
                      vertical: padding * 0.5,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      borderRadius: BorderRadius.circular(padding),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.sort,
                          size: padding * 0.8,
                          color: AppColors.textSecondary,
                        ),
                        SizedBox(width: padding * 0.4),
                        Text(
                          _sortBy,
                          style: TextStyle(
                            fontSize: getResponsiveFontSize(
                              context,
                              small: 11.0,
                              medium: 12.0,
                              large: 13.0,
                              xlarge: 14.0,
                            ),
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String status, BuildContext context) {
    final isSelected = _filterStatus == status;
    final color = getStatusColor(status);
    
    return GestureDetector(
      onTap: () => setState(() => _filterStatus = status),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: getResponsivePadding(context) * 0.8,
          vertical: 6,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color : color.withOpacity(0.1),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? color : color.withOpacity(0.3),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (status != 'All')
              Icon(
                getStatusIcon(status),
                size: 14,
                color: isSelected ? Colors.white : color,
              ),
            if (status != 'All') const SizedBox(width: 4),
            Text(
              status,
              style: TextStyle(
                fontSize: getResponsiveFontSize(
                  context,
                  small: 11.0,
                  medium: 12.0,
                  large: 13.0,
                  xlarge: 14.0,
                ),
                color: isSelected ? Colors.white : color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildOrderCard(QueryDocumentSnapshot order, BuildContext context) {
    final screenSize = getScreenSize(MediaQuery.of(context).size.width);
    final padding = getResponsivePadding(context);
    final data = order.data() as Map<String, dynamic>;
    
    final status = data['status']?.toString() ?? 'Pending';
    final displayStatus = getDisplayStatus(status);
    final statusColor = getStatusColor(status);
    final cropType = data['cropType'] ?? 'Both';
    final factoryName = data['factoryName'] ?? 'Unknown Factory';
    final totalQuantity = _getQuantity(data['totalQuantity']);
    final unit = data['unit'] ?? 'kg';
    final orderPhotos = parseImageUrls(data['orderPhotos']);
    final orderDate = data['orderDate'] as Timestamp?;
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: padding * 0.5,
      ),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(padding * 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 6,
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
          // Header
          Container(
            padding: EdgeInsets.all(padding),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.08),
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(padding * 1.2),
                topRight: Radius.circular(padding * 1.2),
              ),
            ),
            child: Row(
              children: [
                // Status icon
                Container(
                  padding: EdgeInsets.all(padding * 0.6),
                  decoration: BoxDecoration(
                    color: statusColor,
                    borderRadius: BorderRadius.circular(padding * 0.8),
                  ),
                  child: Icon(
                    getStatusIcon(status),
                    size: padding * 1.2,
                    color: Colors.white,
                  ),
                ),
                
                SizedBox(width: padding * 0.8),
                
                // Factory info
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
                                fontSize: getResponsiveFontSize(
                                  context,
                                  small: 13.0,
                                  medium: 14.0,
                                  large: 15.0,
                                  xlarge: 16.0,
                                ),
                                fontWeight: FontWeight.w700,
                              ),
                              maxLines: screenSize == ScreenSize.small ? 1 : 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          
                          // Status badge
                          if (screenSize != ScreenSize.small)
                            Container(
                              padding: EdgeInsets.symmetric(
                                horizontal: padding * 0.8,
                                vertical: padding * 0.3,
                              ),
                              decoration: BoxDecoration(
                                color: statusColor.withOpacity(0.2),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                displayStatus,
                                style: TextStyle(
                                  fontSize: getResponsiveFontSize(
                                    context,
                                    small: 10.0,
                                    medium: 11.0,
                                    large: 12.0,
                                    xlarge: 13.0,
                                  ),
                                  fontWeight: FontWeight.w600,
                                  color: statusColor,
                                ),
                              ),
                            ),
                        ],
                      ),
                      
                      SizedBox(height: padding * 0.2),
                      
                      // Quantity and crop info
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: padding * 0.6,
                              vertical: padding * 0.2,
                            ),
                            decoration: BoxDecoration(
                              color: cropType == 'Tea'
                                  ? AppColors.teaGreen.withOpacity(0.1)
                                  : cropType == 'Cinnamon'
                                      ? AppColors.cinnamonBrown.withOpacity(0.1)
                                      : AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              cropType,
                              style: TextStyle(
                                fontSize: getResponsiveFontSize(
                                  context,
                                  small: 10.0,
                                  medium: 11.0,
                                  large: 12.0,
                                  xlarge: 13.0,
                                ),
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
                            '${totalQuantity.toStringAsFixed(1)} $unit',
                            style: TextStyle(
                              fontSize: getResponsiveFontSize(
                                context,
                                small: 14.0,
                                medium: 16.0,
                                large: 18.0,
                                xlarge: 20.0,
                              ),
                              fontWeight: FontWeight.w700,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          
          // Photos section for medium+ screens
          if (orderPhotos.isNotEmpty && screenSize != ScreenSize.small)
            Container(
              padding: EdgeInsets.all(padding),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Photos (${orderPhotos.length})',
                    style: TextStyle(
                      fontSize: getResponsiveFontSize(
                        context,
                        small: 11.0,
                        medium: 12.0,
                        large: 13.0,
                        xlarge: 14.0,
                      ),
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  
                  SizedBox(height: padding * 0.5),
                  
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: screenSize == ScreenSize.medium ? 2 : 3,
                      crossAxisSpacing: padding * 0.5,
                      mainAxisSpacing: padding * 0.5,
                      childAspectRatio: 1.0,
                    ),
                    itemCount: orderPhotos.length > 6 ? 6 : orderPhotos.length,
                    itemBuilder: (context, index) {
                      return Container(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          image: DecorationImage(
                            image: NetworkImage(orderPhotos[index]),
                            fit: BoxFit.cover,
                          ),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          
          // Timestamp and action button
          Container(
            padding: EdgeInsets.all(padding),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (orderDate != null)
                  Row(
                    children: [
                      Icon(
                        Icons.access_time_rounded,
                        size: padding,
                        color: AppColors.textTertiary,
                      ),
                      SizedBox(width: padding * 0.4),
                      Text(
                        DateFormat('MMM dd, yyyy').format(orderDate.toDate()),
                        style: TextStyle(
                          fontSize: getResponsiveFontSize(
                            context,
                            small: 10.0,
                            medium: 11.0,
                            large: 12.0,
                            xlarge: 13.0,
                          ),
                          color: AppColors.textTertiary,
                        ),
                      ),
                    ],
                  ),
                
                ElevatedButton(
                  onPressed: () => _showOrderDetails(context, order.id, data),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color.fromARGB(255, 37, 92, 230),
                    padding: EdgeInsets.symmetric(
                      horizontal: padding,
                      vertical: padding * 0.5,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                    ),
                  ),
                  child: Text(
                    'View Details',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: getResponsiveFontSize(
                        context,
                        small: 11.0,
                        medium: 12.0,
                        large: 13.0,
                        xlarge: 14.0,
                      ),
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

  Widget _buildEmptyState(BuildContext context) {
    final screenSize = getScreenSize(MediaQuery.of(context).size.width);
    final padding = getResponsivePadding(context);
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: 60.0,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: screenSize == ScreenSize.small ? 60.0 : 80.0,
            color: AppColors.textTertiary.withOpacity(0.3),
          ),
          SizedBox(height: screenSize == ScreenSize.small ? 16.0 : 20.0),
          Text(
            'No orders found',
            style: TextStyle(
              fontSize: getResponsiveFontSize(
                context,
                small: 16.0,
                medium: 18.0,
                large: 20.0,
                xlarge: 22.0,
              ),
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: screenSize == ScreenSize.small ? 6.0 : 8.0),
          Text(
            _searchQuery.isNotEmpty || _filterStatus != 'All' || _filterCropType != 'All' || (_selectedFactory != null && _selectedFactory != 'All')
                ? 'Try adjusting your filters'
                : 'Start exporting your products to see history',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: getResponsiveFontSize(
                context,
                small: 12.0,
                medium: 14.0,
                large: 14.0,
                xlarge: 16.0,
              ),
              color: AppColors.textTertiary,
            ),
          ),
          SizedBox(height: screenSize == ScreenSize.small ? 20.0 : 24.0),
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
                  borderRadius: BorderRadius.circular(padding * 0.8),
                ),
                padding: EdgeInsets.symmetric(
                  horizontal: padding * 1.5,
                  vertical: padding * 0.8,
                ),
              ),
              child: Text(
                'Clear All Filters',
                style: TextStyle(
                  fontSize: getResponsiveFontSize(
                    context,
                    small: 14.0,
                    medium: 16.0,
                    large: 16.0,
                    xlarge: 18.0,
                  ),
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