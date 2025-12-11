// export_product_details.dart - MODERN VERSION WITH HEADER & FOOTER
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:math';
import 'land_owner_drawer.dart';

// -----------------------------------------------------------------------------
// --- MODERN COLOR PALETTE ---
class AppColors {
  // Modern gradient colors
  static const Color primary = Color(0xFF4361EE);
  static const Color primaryDark = Color(0xFF3A56D4);
  static const Color secondary = Color(0xFF7209B7);
  static const Color accent = Color(0xFF4CC9F0);
  
  // Surface colors
  static const Color background = Color(0xFFF8FAFC);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color card = Color(0xFFF8FAFF);
  
  // Text colors
  static const Color textPrimary = Color(0xFF1E293B);
  static const Color textSecondary = Color(0xFF64748B);
  static const Color textTertiary = Color(0xFF94A3B8);
  
  // Status colors
  static const Color success = Color(0xFF10B981);
  static const Color successLight = Color(0xFFD1FAE5);
  static const Color warning = Color(0xFFF59E0B);
  static const Color warningLight = Color(0xFFFEF3C7);
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);
  
  // Special colors
  static const Color teaGreen = Color(0xFF059669);
  static const Color teaGreenLight = Color(0xFFD1FAE5);
  static const Color cinnamonBrown = Color(0xFF92400E);
  static const Color cinnamonBrownLight = Color(0xFFFEF3C7);
  
  // Border colors
  static const Color border = Color(0xFFE2E8F0);
  static const Color divider = Color(0xFFF1F5F9);
  static const Color hover = Color(0xFFF8FAFC);
  
  // Gradient colors for header
  static const List<Color> headerGradient = [
    Color(0xFF4361EE),
    Color(0xFF3A56D4),
    Color(0xFF2D4BC8),
  ];
  
  // Header gradient colors matching UserDetails page
  static const Color headerGradientStart = Color(0xFF869AEC);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
}

// -----------------------------------------------------------------------------
// --- RESPONSIVE UTILITIES ---
enum ScreenSize { 
  mobile,   // < 600
  tablet,   // 600-900
  desktop   // > 900
}

ScreenSize getScreenSize(double width) {
  if (width < 600) return ScreenSize.mobile;
  if (width < 900) return ScreenSize.tablet;
  return ScreenSize.desktop;
}

double getResponsivePadding(BuildContext context) {
  final width = MediaQuery.of(context).size.width;
  if (width < 600) return 16.0;
  if (width < 900) return 20.0;
  return 24.0;
}

double getResponsiveFontSize(BuildContext context, 
    {double mobile = 14.0, double tablet = 16.0, double desktop = 18.0}) {
  final width = MediaQuery.of(context).size.width;
  if (width < 600) return mobile;
  if (width < 900) return tablet;
  return desktop;
}

// -----------------------------------------------------------------------------
// --- MODERN SHADOWS ---
class AppShadows {
  static const List<BoxShadow> small = [
    BoxShadow(
      color: Color(0x0A000000),
      blurRadius: 4,
      offset: Offset(0, 1),
    ),
  ];
  
  static const List<BoxShadow> medium = [
    BoxShadow(
      color: Color(0x14000000),
      blurRadius: 8,
      offset: Offset(0, 2),
    ),
  ];
  
  static const List<BoxShadow> large = [
    BoxShadow(
      color: Color(0x1A000000),
      blurRadius: 12,
      offset: Offset(0, 4),
    ),
  ];
  
  static const List<BoxShadow> xlarge = [
    BoxShadow(
      color: Color(0x24000000),
      blurRadius: 16,
      offset: Offset(0, 8),
    ),
  ];
  
  static const List<BoxShadow> glow = [
    BoxShadow(
      color: Color(0x334361EE),
      blurRadius: 16,
      spreadRadius: 2,
    ),
  ];
}

// -----------------------------------------------------------------------------
// --- ANIMATION CONSTANTS ---
class AppAnimations {
  static const Duration fast = Duration(milliseconds: 200);
  static const Duration medium = Duration(milliseconds: 300);
  static const Duration slow = Duration(milliseconds: 500);
  
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve spring = Curves.elasticOut;
}

// -----------------------------------------------------------------------------
// --- HELPER FUNCTIONS ---
List<String> parseImageUrls(dynamic photosData) {
  final List<String> urls = [];
  
  if (photosData == null) return urls;
  
  if (photosData is String) {
    final trimmedUrl = photosData.trim();
    if (trimmedUrl.isNotEmpty && 
        (trimmedUrl.startsWith('http://') || trimmedUrl.startsWith('https://'))) {
      urls.add(trimmedUrl);
    }
  } else if (photosData is List) {
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
      return AppColors.info;
    case 'completed':
      return AppColors.success;
    case 'cancelled':
      return AppColors.error;
    default:
      return AppColors.primary;
  }
}

Color getStatusColorLight(String status) {
  final normalizedStatus = normalizeStatus(status);
  
  switch (normalizedStatus) {
    case 'pending':
      return AppColors.warningLight;
    case 'factory_received':
      return AppColors.infoLight;
    case 'completed':
      return AppColors.successLight;
    case 'cancelled':
      return AppColors.errorLight;
    default:
      return AppColors.hover;
  }
}

IconData getStatusIcon(String status) {
  final normalizedStatus = normalizeStatus(status);
  
  switch (normalizedStatus) {
    case 'pending':
      return Icons.pending_actions_rounded;
    case 'factory_received':
      return Icons.factory_rounded;
    case 'completed':
      return Icons.check_circle_rounded;
    case 'cancelled':
      return Icons.cancel_rounded;
    default:
      return Icons.info_rounded;
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
// --- MODERN ORDER DETAILS MODAL ---
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
  double _modalOpacity = 0.0;

  @override
  void initState() {
    super.initState();
    _fetchFactoryData();
    Future.delayed(Duration.zero, () {
      setState(() => _modalOpacity = 1.0);
    });
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
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 0),
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
            flex: 2,
            child: Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          Expanded(
            flex: 3,
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
    return DateFormat('MMM dd, yyyy • hh:mm a').format(timestamp.toDate());
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = getScreenSize(MediaQuery.of(context).size.width);
    final padding = getResponsivePadding(context);
    
    final status = widget.orderData['status']?.toString() ?? 'Pending';
    final displayStatus = getDisplayStatus(status);
    final statusColor = getStatusColor(status);
    final cropType = widget.orderData['cropType'] ?? 'Both';
    final factoryName = widget.orderData['factoryName'] ?? 'Unknown Factory';
    final totalQuantity = widget.orderData['totalQuantity']?.toString() ?? '0';
    final teaQuantity = widget.orderData['teaQuantity']?.toString() ?? '0';
    final cinnamonQuantity = widget.orderData['cinnamonQuantity']?.toString() ?? '0';
    final description = widget.orderData['description'] ?? '';
    final unit = widget.orderData['unit'] ?? 'kg';
    final orderPhotos = parseImageUrls(widget.orderData['orderPhotos']);
    final orderDate = widget.orderData['orderDate'] as Timestamp?;
    final createdAt = widget.orderData['createdAt'] as Timestamp?;
    final updatedAt = widget.orderData['updatedAt'] as Timestamp?;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.all(padding),
      child: AnimatedOpacity(
        opacity: _modalOpacity,
        duration: AppAnimations.medium,
        curve: AppAnimations.easeInOut,
        child: Container(
          constraints: BoxConstraints(
            maxWidth: screenSize == ScreenSize.desktop 
                ? 600 
                : MediaQuery.of(context).size.width * 0.9,
            maxHeight: MediaQuery.of(context).size.height * 0.85,
          ),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(24),
            boxShadow: AppShadows.xlarge,
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Header with gradient
                Container(
                  padding: EdgeInsets.all(padding),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [
                        statusColor.withOpacity(0.9),
                        statusColor.withOpacity(0.7),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          IconButton(
                            onPressed: () => Navigator.of(context).pop(),
                            icon: Icon(
                              Icons.close_rounded,
                              color: Colors.white,
                              size: 24,
                            ),
                            style: IconButton.styleFrom(
                              backgroundColor: Colors.white.withOpacity(0.2),
                              padding: EdgeInsets.all(8),
                            ),
                          ),
                          
                          // Status badge
                          Container(
                            padding: EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.3),
                              ),
                            ),
                            child: Text(
                              displayStatus.toUpperCase(),
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: Colors.white,
                                letterSpacing: 1,
                              ),
                            ),
                          ),
                        ],
                      ),
                      
                      SizedBox(height: 16),
                      
                      Text(
                        'Order Details',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      
                      SizedBox(height: 4),
                      
                      Text(
                        'ID: ${widget.orderId.substring(0, 8).toUpperCase()}',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: Padding(
                      padding: EdgeInsets.all(padding),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Factory Info
                          _buildFactoryCard(factoryName, context),
                          
                          SizedBox(height: 16),

                          // Order Summary Card
                          Container(
                            padding: EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              color: AppColors.card,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
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
                                    Container(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 6,
                                      ),
                                      decoration: BoxDecoration(
                                        color: cropType == 'Tea'
                                            ? AppColors.teaGreenLight
                                            : cropType == 'Cinnamon'
                                                ? AppColors.cinnamonBrownLight
                                                : statusColor.withOpacity(0.1),
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
                                                  : statusColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                
                                SizedBox(height: 16),
                                
                                // Total Quantity
                                Center(
                                  child: Column(
                                    children: [
                                      Text(
                                        'Total Quantity',
                                        style: TextStyle(
                                          fontSize: 14,
                                          color: AppColors.textSecondary,
                                        ),
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        '$totalQuantity $unit',
                                        style: TextStyle(
                                          fontSize: 32,
                                          fontWeight: FontWeight.w700,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                
                                SizedBox(height: 16),
                                
                                // Breakdown
                                if (cropType == 'Both' && (double.parse(teaQuantity) > 0 || double.parse(cinnamonQuantity) > 0))
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                    children: [
                                      if (double.parse(teaQuantity) > 0)
                                        _buildBreakdownItem(
                                          icon: Icons.emoji_food_beverage_rounded,
                                          label: 'Tea',
                                          value: '$teaQuantity $unit',
                                          color: AppColors.teaGreen,
                                        ),
                                      if (double.parse(cinnamonQuantity) > 0)
                                        _buildBreakdownItem(
                                          icon: Icons.spa_rounded,
                                          label: 'Cinnamon',
                                          value: '$cinnamonQuantity $unit',
                                          color: AppColors.cinnamonBrown,
                                        ),
                                    ],
                                  ),
                              ],
                            ),
                          ),

                          SizedBox(height: 16),

                          // Order Information
                          _buildInfoSection(
                            title: 'ORDER INFORMATION',
                            children: [
                              _buildDetailRow('Order Date', _formatDate(orderDate)),
                              _buildDetailRow('Created', _formatDate(createdAt)),
                              _buildDetailRow('Last Updated', _formatDate(updatedAt)),
                            ],
                          ),

                          // Description
                          if (description.isNotEmpty) ...[
                            SizedBox(height: 16),
                            _buildInfoSection(
                              title: 'DESCRIPTION',
                              children: [
                                Text(
                                  description,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.textPrimary,
                                    height: 1.5,
                                  ),
                                ),
                              ],
                            ),
                          ],

                          // Photos
                          if (orderPhotos.isNotEmpty) ...[
                            SizedBox(height: 16),
                            _buildInfoSection(
                              title: 'ORDER PHOTOS (${orderPhotos.length})',
                              children: [
                                SizedBox(
                                  height: 120,
                                  child: ListView.builder(
                                    scrollDirection: Axis.horizontal,
                                    itemCount: orderPhotos.length,
                                    itemBuilder: (context, index) {
                                      return Container(
                                        margin: EdgeInsets.only(right: 12),
                                        width: 120,
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(12),
                                          color: AppColors.hover,
                                        ),
                                        child: ClipRRect(
                                          borderRadius: BorderRadius.circular(12),
                                          child: CachedNetworkImage(
                                            imageUrl: orderPhotos[index],
                                            fit: BoxFit.cover,
                                            placeholder: (context, url) => Center(
                                              child: CircularProgressIndicator(
                                                color: AppColors.primary,
                                                strokeWidth: 2,
                                              ),
                                            ),
                                            errorWidget: (context, url, error) => Center(
                                              child: Icon(
                                                Icons.broken_image_rounded,
                                                color: AppColors.textTertiary,
                                                size: 32,
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
                          ],
                          
                          SizedBox(height: 20),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFactoryCard(String factoryName, BuildContext context) {
    final factoryLogo = _factoryData?['factoryLogoUrl'];
    final contactNumber = _factoryData?['contactNumber'] ?? 'Not available';
    final address = _factoryData?['address'] ?? 'Not available';

    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          // Factory Logo
          Container(
            width: 60,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              color: AppColors.primary.withOpacity(0.1),
            ),
            child: factoryLogo != null && factoryLogo.toString().startsWith('http')
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: CachedNetworkImage(
                      imageUrl: factoryLogo.toString(),
                      fit: BoxFit.cover,
                    ),
                  )
                : Icon(
                    Icons.factory_rounded,
                    size: 32,
                    color: AppColors.primary,
                  ),
          ),
          
          SizedBox(width: 16),
          
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
                
                SizedBox(height: 4),
                
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
                      SizedBox(width: 8),
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
                      SizedBox(height: 2),
                      Text(
                        '📍 $address',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
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

  Widget _buildBreakdownItem({
    required IconData icon,
    required String label,
    required String value,
    required Color color,
  }) {
    return Column(
      children: [
        Container(
          padding: EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        SizedBox(height: 8),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
        SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _buildInfoSection({
    required String title,
    required List<Widget> children,
  }) {
    return Container(
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
              letterSpacing: 1,
            ),
          ),
          SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// --- MODERN STATS CARD ---
class _StatsCard extends StatelessWidget {
  final String title;
  final String value;
  final Color color;
  final IconData icon;
  final String? subtitle;

  const _StatsCard({
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(
  left: 30,
  right: 16,
  top: 4,
  bottom: 2,
),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.medium,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 16),
              ),
              Spacer(),
              if (subtitle != null)
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    subtitle!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: color,
                    ),
                  ),
                ),
            ],
          ),
          
          SizedBox(height: 12),
          
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: AppColors.textSecondary,
            ),
          ),
          
          SizedBox(height: 4),
          
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// --- MAIN EXPORT PRODUCTS HISTORY PAGE WITH HEADER & FOOTER ---
class ExportProductsHistoryPage extends StatefulWidget {
  const ExportProductsHistoryPage({super.key});

  @override
  State<ExportProductsHistoryPage> createState() => _ExportProductsHistoryPageState();
}

class _ExportProductsHistoryPageState extends State<ExportProductsHistoryPage> 
    with SingleTickerProviderStateMixin {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();
  
  // Animation
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;
  
  // User info for header
  String _loggedInUserName = 'Loading User...';
  String _landName = 'Loading Land...';
  String _userRole = 'Land Owner';
  String _landID = 'L-ID';
  String? _profileImageUrl;
  
  // Filter and search
  String _filterStatus = 'All';
  String _searchQuery = '';
  String _sortBy = 'Newest';
  bool _showFilters = false;
  
  // Status options
  final List<String> _statusOptions = [
    'All',
    'Pending',
    'Factory Received',
    'Completed',
    'Cancelled'
  ];
  
  // Sort options
  final List<String> _sortOptions = [
    'Newest',
    'Oldest',
    'Most Quantity',
    'Least Quantity'
  ];
  
  // Statistics
  Map<String, dynamic> _statistics = {
    'totalOrders': 0,
    'pendingCount': 0,
    'factoryReceivedCount': 0,
    'completedCount': 0,
    'cancelledCount': 0,
    'totalTea': 0.0,
    'totalCinnamon': 0.0,
    'todayOrders': 0,
    'todayTea': 0.0,
    'todayCinnamon': 0.0,
  };

  @override
  void initState() {
    super.initState();
    
    // Initialize animations
    _animationController = AnimationController(
      vsync: this,
      duration: AppAnimations.medium,
    );
    _fadeAnimation = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _animationController,
        curve: Curves.easeInOut,
      ),
    );
    
    _fetchHeaderData();
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  // --- HEADER DATA FETCHING (Same as UserDetails) ---
  void _fetchHeaderData() async {
    final user = _currentUser;
    if (user == null) return;
    
    final String uid = user.uid;
    setState(() {
      _landID = uid.length >= 8 ? uid.substring(0, 8) : uid.padRight(8, '0'); 
    });

    try {
      // 1. Fetch User Name and Role from 'users' collection
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner Name Missing';
          _profileImageUrl = userData?['profileImageUrl'];
          _userRole = userData?['role'] ?? 'Land Owner';
        });
      }
      
      // 2. Fetch Land Name from 'lands' collection
      final landDoc = await _firestore.collection('lands').doc(uid).get();
      if (landDoc.exists) {
        setState(() {
          _landName = landDoc.data()?['landName'] ?? 'Land Name Missing';
        });
      } else {
        // If land doesn't exist, show user email as fallback
        setState(() {
          _landName = user.email?.split('@')[0] ?? 'User Account';
        });
      }

    } catch (e) {
      debugPrint("Error fetching header data: $e");
      setState(() {
        _loggedInUserName = 'Data Error';
        _landName = 'Data Error';
      });
    }
  }

  Map<String, dynamic> _calculateStatistics(List<QueryDocumentSnapshot> orders) {
    double teaTotal = 0;
    double cinnamonTotal = 0;
    double todayTea = 0;
    double todayCinnamon = 0;
    
    int pendingCount = 0;
    int factoryReceivedCount = 0;
    int completedCount = 0;
    int cancelledCount = 0;
    int todayOrders = 0;
    
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    
    for (final order in orders) {
      final data = order.data() as Map<String, dynamic>;
      
      // Status counts
      final status = data['status']?.toString() ?? 'pending';
      final normalizedStatus = normalizeStatus(status);
      
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
      
      // Quantities
      final totalQty = _getQuantity(data['totalQuantity']);
      final teaQty = _getQuantity(data['teaQuantity']);
      final cinnamonQty = _getQuantity(data['cinnamonQuantity']);
      final cropType = data['cropType']?.toString() ?? 'Both';
      
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
      
      // Today's stats
      final orderDate = (data['orderDate'] as Timestamp?)?.toDate();
      if (orderDate != null && orderDate.isAfter(todayStart)) {
        todayOrders++;
        
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
      }
    }
    
    return {
      'totalOrders': orders.length,
      'pendingCount': pendingCount,
      'factoryReceivedCount': factoryReceivedCount,
      'completedCount': completedCount,
      'cancelledCount': cancelledCount,
      'totalTea': teaTotal,
      'totalCinnamon': cinnamonTotal,
      'todayOrders': todayOrders,
      'todayTea': todayTea,
      'todayCinnamon': todayCinnamon,
    };
  }

  double _getQuantity(dynamic value) {
    if (value == null) return 0.0;
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }

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

  bool _shouldShowOrder(Map<String, dynamic> orderData) {
    // Status filter
    if (_filterStatus != 'All') {
      final status = orderData['status']?.toString() ?? 'pending';
      final displayStatus = getDisplayStatus(status);
      if (_filterStatus != displayStatus) return false;
    }
    
    // Search filter
    if (_searchQuery.isNotEmpty) {
      final factoryName = (orderData['factoryName'] ?? '').toString().toLowerCase();
      final description = (orderData['description'] ?? '').toString().toLowerCase();
      final cropType = (orderData['cropType'] ?? '').toString().toLowerCase();
      final searchLower = _searchQuery.toLowerCase();
      
      return factoryName.contains(searchLower) ||
             description.contains(searchLower) ||
             cropType.contains(searchLower);
    }
    
    return true;
  }

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

  void _toggleFilters() {
    setState(() {
      _showFilters = !_showFilters;
    });
  }

  void _handleDrawerNavigate(String routeName) {
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final screenSize = getScreenSize(MediaQuery.of(context).size.width);
    final padding = getResponsivePadding(context);
    
    if (_currentUser == null) {
      return Scaffold(
        body: Center(
          child: Text(
            "Please login to continue",
            style: TextStyle(
              fontSize: 16,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      );
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: LandOwnerDrawer(
        onLogout: () {
          FirebaseAuth.instance.signOut();
          Navigator.of(context).pop();
        },
        onNavigate: _handleDrawerNavigate,
      ),
      body: Column(
        children: [
          // 🌟 FIXED HEADER - Matching UserDetails page
          _buildDashboardHeader(context),
          
          // 🌟 SCROLLABLE CONTENT ONLY with Footer
          Expanded(
            child: Column(
              children: [
                // Scrollable content
                Expanded(
                  child: SingleChildScrollView(
                    physics: const BouncingScrollPhysics(),
                    child: FadeTransition(
                      opacity: _fadeAnimation,
                      child: Column(
                        children: [
                          // Content Area
                          StreamBuilder<QuerySnapshot>(
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
                              
                              final filteredOrders = orders.where((order) => 
                                  _shouldShowOrder(order.data() as Map<String, dynamic>)).toList();
                              final sortedOrders = _sortOrders(filteredOrders);
                              
                              return Column(
                                children: [
                                  // Stats Overview
                                  _buildStatsOverview(stats, context),
                                  
                                  // Search and Filters
                                  _buildSearchAndFilters(context),
                                  
                                  // Orders Grid/List
                                  if (sortedOrders.isEmpty)
                                    _buildEmptyState(context)
                                  else
                                    Padding(
                                      padding: EdgeInsets.symmetric(horizontal: padding),
                                      child: Column(
                                        children: sortedOrders.map((order) => 
                                          _buildOrderCard(order, context)
                                        ).toList(),
                                      ),
                                    ),
                                ],
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                
                // Footer (Fixed at bottom of content area) - Matching UserDetails page
                Container(
                  padding: EdgeInsets.all(screenSize == ScreenSize.mobile ? 12.0 : 16.0),
                  child: Text(
                    'Developed by Malitha Tishamal',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: AppColors.textSecondary.withOpacity(0.7),
                      fontSize: screenSize == ScreenSize.mobile ? 11.0 : 12.0,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      
      // Floating Action Button
      floatingActionButton: screenSize == ScreenSize.mobile
          ? FloatingActionButton(
              onPressed: _toggleFilters,
              backgroundColor: AppColors.primary,
              child: Icon(
                _showFilters ? Icons.close : Icons.filter_alt,
                color: Colors.white,
              ),
            )
          : null,
    );
  }

  // 🌟 FIXED HEADER - Matching UserDetails page
  Widget _buildDashboardHeader(BuildContext context) {
    final screenSize = getScreenSize(MediaQuery.of(context).size.width);
    final isSmallScreen = screenSize == ScreenSize.mobile;
    final isMediumScreen = screenSize == ScreenSize.tablet;
    final padding = getResponsivePadding(context);
    
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
                    // Land Name and Role
                    Text(
                      'Land Name: $_landName \n($_userRole)', 
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
            'Export Product History',
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

  Widget _buildStatsOverview(Map<String, dynamic> stats, BuildContext context) {
    final screenSize = getScreenSize(MediaQuery.of(context).size.width);
    final padding = getResponsivePadding(context);
    
    return Padding(
      padding: EdgeInsets.all(padding),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Export Overview',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                Container(
                  padding: EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    'Today: ${stats['todayOrders']}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Status Stats
          GridView.count(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            crossAxisCount: screenSize == ScreenSize.mobile ? 2 : 4,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: screenSize == ScreenSize.mobile ? 1.8 : 2.0,
            children: [
              _StatsCard(
                title: 'Pending',
                value: '${stats['pendingCount']}',
                color: AppColors.warning,
                icon: Icons.pending_actions_rounded,
                subtitle: 'Awaiting',
              ),
              _StatsCard(
                title: 'Factory Received',
                value: '${stats['factoryReceivedCount']}',
                color: AppColors.info,
                icon: Icons.factory_rounded,
                subtitle: 'Processing',
              ),
              _StatsCard(
                title: 'Completed',
                value: '${stats['completedCount']}',
                color: AppColors.success,
                icon: Icons.check_circle_rounded,
                subtitle: 'Delivered',
              ),
              _StatsCard(
                title: 'Cancelled',
                value: '${stats['cancelledCount']}',
                color: AppColors.error,
                icon: Icons.cancel_rounded,
                subtitle: 'Rejected',
              ),
            ],
          ),
          
          SizedBox(height: 20),
          
          // Quantity Stats
          Row(
            children: [
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppShadows.medium,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.teaGreenLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.emoji_food_beverage_rounded,
                              color: AppColors.teaGreen,
                              size: 20,
                            ),
                          ),
                          Spacer(),
                          Text(
                            '${stats['todayTea'].toStringAsFixed(1)} kg today',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.teaGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Tea Exported',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${stats['totalTea'].toStringAsFixed(1)} kg',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              SizedBox(width: 12),
              
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    boxShadow: AppShadows.medium,
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: AppColors.cinnamonBrownLight,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              Icons.spa_rounded,
                              color: AppColors.cinnamonBrown,
                              size: 16,
                            ),
                          ),
                          Spacer(),
                          Text(
                            '${stats['todayCinnamon'].toStringAsFixed(1)} kg today',
                            style: TextStyle(
                              fontSize: 12,
                              color: AppColors.cinnamonBrown,
                            fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: 12),
                      Text(
                        'Cinnamon Exported',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        '${stats['totalCinnamon'].toStringAsFixed(1)} kg',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSearchAndFilters(BuildContext context) {
    final screenSize = getScreenSize(MediaQuery.of(context).size.width);
    final padding = getResponsivePadding(context);
    
    return Padding(
      padding: EdgeInsets.symmetric(horizontal: padding),
      child: Column(
        children: [
          // Search Bar
          Container(
            height: 48,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              boxShadow: AppShadows.small,
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                SizedBox(width: 16),
                Icon(
                  Icons.search_rounded,
                  color: AppColors.textTertiary,
                  size: 20,
                ),
                SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    onChanged: (value) => setState(() => _searchQuery = value),
                    decoration: InputDecoration(
                      hintText: 'Search orders by factory, crop, description...',
                      border: InputBorder.none,
                      hintStyle: TextStyle(
                        color: AppColors.textTertiary,
                        fontSize: 14,
                      ),
                    ),
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                if (_searchQuery.isNotEmpty)
                  IconButton(
                    onPressed: () => setState(() => _searchQuery = ''),
                    icon: Icon(
                      Icons.close_rounded,
                      color: AppColors.textTertiary,
                      size: 20,
                    ),
                  ),
                SizedBox(width: 8),
              ],
            ),
          ),
          
          SizedBox(height: 12),
          
          // Filter Chips - Always visible on desktop/tablet, conditionally on mobile
          if (screenSize != ScreenSize.mobile || _showFilters)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  // Status Filters
                  ..._statusOptions.map((status) {
                    final isSelected = _filterStatus == status;
                    final color = status == 'All' 
                        ? AppColors.primary 
                        : getStatusColor(status);
                    
                    return GestureDetector(
                      onTap: () => setState(() => _filterStatus = status),
                      child: Container(
                        margin: EdgeInsets.only(right: 8),
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: isSelected ? color : color.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isSelected ? color : Colors.transparent,
                          ),
                          boxShadow: isSelected ? AppShadows.small : null,
                        ),
                        child: Row(
                          children: [
                            if (status != 'All')
                              Icon(
                                getStatusIcon(status),
                                size: 14,
                                color: isSelected ? Colors.white : color,
                              ),
                            if (status != 'All') SizedBox(width: 6),
                            Text(
                              status,
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isSelected ? Colors.white : color,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }).toList(),
                  
                  // Sort Button
                  GestureDetector(
                    onTap: () => _showSortDialog(context),
                    child: Container(
                      margin: EdgeInsets.only(left: 8),
                      padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.border),
                        boxShadow: AppShadows.small,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.sort_rounded,
                            size: 14,
                            color: AppColors.textSecondary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            _sortBy,
                            style: TextStyle(
                              fontSize: 13,
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
            ),
        ],
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
    final statusColorLight = getStatusColorLight(status);
    final cropType = data['cropType'] ?? 'Both';
    final factoryName = data['factoryName'] ?? 'Unknown Factory';
    final totalQuantity = _getQuantity(data['totalQuantity']);
    final unit = data['unit'] ?? 'kg';
    final orderPhotos = parseImageUrls(data['orderPhotos']);
    final orderDate = data['orderDate'] as Timestamp?;
    final factoryId = data['factoryId']?.toString() ?? '';
    
    return Container(
      margin: EdgeInsets.symmetric(
        horizontal: padding,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: AppShadows.medium,
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
          Container(
            padding: EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: statusColorLight,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(16),
                topRight: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                // Status Indicator
                Container(
                  padding: EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: statusColor,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: statusColor.withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  child: Icon(
                    getStatusIcon(status),
                    color: Colors.white,
                    size: 18,
                  ),
                ),
                
                SizedBox(width: 12),
                
                // Factory Info
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        factoryName,
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      SizedBox(height: 2),
                      Text(
                        'ID: ${factoryId.isNotEmpty ? factoryId.substring(0, 8).toUpperCase() : 'N/A'}',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                
                // Status Badge
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: statusColor.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    displayStatus,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: statusColor,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Content
          Padding(
            padding: EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Quantity and Crop
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Crop Type
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: cropType == 'Tea'
                            ? AppColors.teaGreenLight
                            : cropType == 'Cinnamon'
                                ? AppColors.cinnamonBrownLight
                                : AppColors.primary.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            cropType == 'Tea'
                                ? Icons.emoji_food_beverage_rounded
                                : cropType == 'Cinnamon'
                                    ? Icons.spa_rounded
                                    : Icons.category_rounded,
                            size: 14,
                            color: cropType == 'Tea'
                                ? AppColors.teaGreen
                                : cropType == 'Cinnamon'
                                    ? AppColors.cinnamonBrown
                                    : AppColors.primary,
                          ),
                          SizedBox(width: 6),
                          Text(
                            cropType,
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: cropType == 'Tea'
                                  ? AppColors.teaGreen
                                  : cropType == 'Cinnamon'
                                      ? AppColors.cinnamonBrown
                                      : AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    
                    // Total Quantity
                    Text(
                      '${totalQuantity.toStringAsFixed(1)} $unit',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ],
                ),
                
                SizedBox(height: 12),
                
                // Order Date
                if (orderDate != null)
                  Row(
                    children: [
                      Icon(
                        Icons.calendar_today_rounded,
                        size: 14,
                        color: AppColors.textTertiary,
                      ),
                      SizedBox(width: 6),
                      Text(
                        DateFormat('MMM dd, yyyy').format(orderDate.toDate()),
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                
                SizedBox(height: 12),
                
                // Photos Preview
                if (orderPhotos.isNotEmpty)
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${orderPhotos.length} photo${orderPhotos.length > 1 ? 's' : ''} attached',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textTertiary,
                        ),
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        height: 60,
                        child: ListView.builder(
                          scrollDirection: Axis.horizontal,
                          itemCount: min(orderPhotos.length, 3),
                          itemBuilder: (context, index) {
                            return Container(
                              margin: EdgeInsets.only(right: 8),
                              width: 60,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                color: AppColors.hover,
                              ),
                              child: ClipRRect(
                                borderRadius: BorderRadius.circular(8),
                                child: CachedNetworkImage(
                                  imageUrl: orderPhotos[index],
                                  fit: BoxFit.cover,
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                
                SizedBox(height: 16),
                
                // View Details Button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => _showOrderDetails(context, order.id, data),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                      elevation: 0,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'View Order Details',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.arrow_forward_rounded, size: 16),
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

  Widget _buildLoadingScreen() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          SizedBox(
            width: 60,
            height: 60,
            child: CircularProgressIndicator(
              strokeWidth: 4,
              color: AppColors.primary,
            ),
          ),
          SizedBox(height: 20),
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
          SizedBox(height: 20),
          Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
              ),
            ),
          ),
          SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => setState(() {}),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
            child: Text(
              'Try Again',
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

  Widget _buildEmptyState(BuildContext context) {
    final screenSize = getScreenSize(MediaQuery.of(context).size.width);
    
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: getResponsivePadding(context),
        vertical: 60,
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2_outlined,
            size: screenSize == ScreenSize.mobile ? 64 : 80,
            color: AppColors.textTertiary.withOpacity(0.3),
          ),
          SizedBox(height: 24),
          Text(
            'No orders found',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          SizedBox(height: 8),
          Text(
            _searchQuery.isNotEmpty || _filterStatus != 'All'
                ? 'Try adjusting your search or filters'
                : 'Start exporting your products to see history here',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          SizedBox(height: 24),
          if (_searchQuery.isNotEmpty || _filterStatus != 'All')
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _searchQuery = '';
                  _filterStatus = 'All';
                  _showFilters = false;
                });
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
              child: Text(
                'Clear All Filters',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Colors.white,
                ),
              ),
            ),
        ],
      ),
    );
  }

  void _showSortDialog(BuildContext context) {
    final screenSize = getScreenSize(MediaQuery.of(context).size.width);
    
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) {
        return Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.only(
              topLeft: Radius.circular(24),
              topRight: Radius.circular(24),
            ),
          ),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Handle
                Container(
                  width: 40,
                  height: 4,
                  margin: EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                
                // Title
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: 24),
                  child: Text(
                    'Sort Orders',
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    ),
                  ),
                ),
                
                SizedBox(height: 16),
                
                // Options
                ..._sortOptions.map((option) {
                  final isSelected = _sortBy == option;
                  
                  return ListTile(
                    contentPadding: EdgeInsets.symmetric(horizontal: 24),
                    leading: Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: isSelected 
                            ? AppColors.primary.withOpacity(0.1) 
                            : AppColors.hover,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Icon(
                        _getSortIcon(option),
                        color: isSelected ? AppColors.primary : AppColors.textSecondary,
                      ),
                    ),
                    title: Text(
                      option,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    trailing: isSelected
                        ? Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.primary,
                          )
                        : null,
                    onTap: () {
                      setState(() => _sortBy = option);
                      Navigator.pop(context);
                    },
                  );
                }).toList(),
                
                SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
              ],
            ),
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
}