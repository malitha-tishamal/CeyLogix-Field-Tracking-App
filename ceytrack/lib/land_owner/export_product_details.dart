import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'land_owner_drawer.dart';

class AppColors {
  static const Color background        = Color(0xFFF4F6FA);
  static const Color darkText          = Color(0xFF1A1D26);
  static const Color primaryBlue       = Color(0xFF2764E7);

  static const Color teaGreen          = Color(0xFF4CAF50);
  static const Color teaGreenLight     = Color(0xFFE8F5E9);
  static const Color cinnamonOrange    = Color(0xFFFF9800);
  static const Color cinnamonOrangeLight = Color(0xFFFFF3E0);

  static const Color successGreen      = Color(0xFF4CAF50);
  static const Color warningOrange     = Color(0xFFFF9800);
  static const Color infoBlue          = Color(0xFF2196F3);
  static const Color accentRed         = Color(0xFFE53935);

  static const Color cardBackground    = Colors.white;
  static const Color secondaryText     = Color(0xFF6A798A);
  static const Color headerGradientStart = Color(0xFF869AEC);
  static const Color headerGradientEnd   = Color(0xFFF7FAFF);
  static const Color headerTextDark      = Color(0xFF333333);
  static const Color textTertiary        = Color(0xFFB0BAC8);
  static const Color hover               = Color(0xFFF8FAFC);
  static const Color border              = Color(0xFFE8ECF2);
}

class _D {
  static const double cardRadius = 10.0;
  static const double cardPad    = 10.0;
  static const double sectionGap = 14.0;
  static const double iconBox    = 28.0;
  static const double iconSize   = 14.0;
}

extension ResponsiveExtensions on BuildContext {
  double get paddingSmall => MediaQuery.of(this).size.width < 600 ? 12.0 : 16.0;
  double get paddingMedium => MediaQuery.of(this).size.width < 600 ? 16.0 : 20.0;
  double get paddingLarge => MediaQuery.of(this).size.width < 600 ? 20.0 : 24.0;
  bool get isSmallScreen  => MediaQuery.of(this).size.width < 600;
  bool get isMediumScreen => MediaQuery.of(this).size.width >= 600 && MediaQuery.of(this).size.width < 900;
}

List<String> parseImageUrls(dynamic photosData) {
  final List<String> urls = [];
  if (photosData == null) return urls;
  if (photosData is String) {
    final trimmed = photosData.trim();
    if (trimmed.isNotEmpty && (trimmed.startsWith('http://') || trimmed.startsWith('https://'))) {
      urls.add(trimmed);
    }
  } else if (photosData is List) {
    for (var item in photosData) {
      if (item is String) {
        final trimmed = item.trim();
        if (trimmed.isNotEmpty && (trimmed.startsWith('http://') || trimmed.startsWith('https://'))) {
          urls.add(trimmed);
        }
      }
    }
  }
  return urls;
}

String normalizeStatus(String status) {
  if (status.isEmpty) return 'pending';
  final lower = status.toLowerCase().trim();
  if (lower.contains('factory') && (lower.contains('receive') || lower.contains('reciv'))) return 'factory_received';
  if (lower.contains('delivered') || lower.contains('completed') || lower.contains('accepted')) return 'completed';
  if (lower.contains('cancel') || lower.contains('reject')) return 'cancelled';
  if (lower.contains('pending')) return 'pending';
  return lower;
}

Color getStatusColor(String status) {
  switch (normalizeStatus(status)) {
    case 'pending':          return AppColors.warningOrange;
    case 'factory_received': return AppColors.infoBlue;
    case 'completed':        return AppColors.successGreen;
    case 'cancelled':        return AppColors.accentRed;
    default:                 return AppColors.primaryBlue;
  }
}

IconData getStatusIcon(String status) {
  switch (normalizeStatus(status)) {
    case 'pending':          return Icons.schedule_rounded;
    case 'factory_received': return Icons.factory_rounded;
    case 'completed':        return Icons.check_circle_rounded;
    case 'cancelled':        return Icons.cancel_rounded;
    default:                 return Icons.info_rounded;
  }
}

String getDisplayStatus(String status) {
  switch (normalizeStatus(status)) {
    case 'pending':          return 'Pending';
    case 'factory_received': return 'Factory Received';
    case 'completed':        return 'Completed';
    case 'cancelled':        return 'Cancelled';
    default:                 return status.isNotEmpty ? status[0].toUpperCase() + status.substring(1) : 'Pending';
  }
}

double _getQuantity(dynamic value) {
  if (value == null) return 0.0;
  if (value is num) return value.toDouble();
  if (value is String) return double.tryParse(value) ?? 0.0;
  return 0.0;
}

Color _getCropColor(String cropType) {
  switch (cropType.toLowerCase()) {
    case 'tea':      return AppColors.teaGreen;
    case 'cinnamon': return AppColors.cinnamonOrange;
    default:         return AppColors.primaryBlue;
  }
}

Color _getCropLightColor(String cropType) {
  switch (cropType.toLowerCase()) {
    case 'tea':      return AppColors.teaGreenLight;
    case 'cinnamon': return AppColors.cinnamonOrangeLight;
    default:         return AppColors.primaryBlue.withOpacity(0.1);
  }
}

class OrderDetailsModal extends StatefulWidget {
  final Map<String, dynamic> orderData;
  final String orderId;
  const OrderDetailsModal({super.key, required this.orderData, required this.orderId});

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
      setState(() => _loadingFactoryData = false);
      return;
    }
    try {
      final doc = await FirebaseFirestore.instance.collection('factories').doc(factoryId).get();
      if (doc.exists) setState(() { _factoryData = doc.data(); _loadingFactoryData = false; });
      else setState(() => _loadingFactoryData = false);
    } catch (e) {
      setState(() => _loadingFactoryData = false);
    }
  }

  String _formatDate(Timestamp? ts) => ts == null ? 'N/A' : DateFormat('MMM dd, yyyy • hh:mm a').format(ts.toDate());

  @override
  Widget build(BuildContext context) {
    final status = widget.orderData['status']?.toString() ?? 'Pending';
    final displayStatus = getDisplayStatus(status);
    final statusColor = getStatusColor(status);
    final cropType = widget.orderData['cropType'] ?? 'Both';
    final factoryName = widget.orderData['factoryName'] ?? 'Unknown Factory';
    final totalQty = _getQuantity(widget.orderData['totalQuantity']);
    final teaQty = _getQuantity(widget.orderData['teaQuantity']);
    final cinnamonQty = _getQuantity(widget.orderData['cinnamonQuantity']);
    final unit = widget.orderData['unit'] ?? 'kg';
    final description = widget.orderData['description'] ?? '';
    final orderPhotos = parseImageUrls(widget.orderData['orderPhotos']);
    final orderDate = widget.orderData['orderDate'] as Timestamp?;
    final createdAt = widget.orderData['createdAt'] as Timestamp?;
    final updatedAt = widget.orderData['updatedAt'] as Timestamp?;

    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(16),
      child: Container(
        constraints: BoxConstraints(maxWidth: 500, maxHeight: MediaQuery.of(context).size.height * 0.85),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(16), boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.12), blurRadius: 24)]),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: statusColor, borderRadius: const BorderRadius.vertical(top: Radius.circular(16))),
              child: Row(
                children: [
                  Container(width: 34, height: 34, decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(8)),
                    child: Icon(getStatusIcon(status), color: Colors.white, size: 18)),
                  const SizedBox(width: 12),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    const Text('Order Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.white)),
                    Text('ID: ${widget.orderId.substring(0, 8).toUpperCase()}', style: TextStyle(fontSize: 11, color: Colors.white.withOpacity(0.8))),
                  ])),
                  Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: Colors.white.withOpacity(0.2), borderRadius: BorderRadius.circular(20)),
                    child: Text(displayStatus, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.white))),
                  const SizedBox(width: 8),
                  GestureDetector(onTap: () => Navigator.pop(context), child: const Icon(Icons.close, size: 20, color: Colors.white)),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    _sectionCard('Factory', Icons.factory_rounded, AppColors.primaryBlue, [
                      Row(children: [
                        Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
                          child: _factoryData?['factoryLogoUrl'] != null
                              ? ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedNetworkImage(imageUrl: _factoryData!['factoryLogoUrl'], fit: BoxFit.cover))
                              : const Icon(Icons.factory_rounded, color: AppColors.primaryBlue, size: 28)),
                        const SizedBox(width: 12),
                        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(factoryName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkText), maxLines: 1),
                          if (_loadingFactoryData)
                            const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue))
                          else if (_factoryData != null) ...[
                            Text('📞 ${_factoryData!['contactNumber'] ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
                            Text('📍 ${_factoryData!['address'] ?? 'N/A'}', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText), maxLines: 1),
                          ],
                        ])),
                      ]),
                    ]),
                    const SizedBox(height: 12),
                    _sectionCard('Order Summary', Icons.receipt_long_rounded, AppColors.primaryBlue, [
                      _row('Crop Type', cropType),
                      _row('Total Quantity', '${totalQty.toStringAsFixed(1)} $unit'),
                      if (cropType == 'Both' && teaQty > 0) _row('Tea', '${teaQty.toStringAsFixed(1)} $unit'),
                      if (cropType == 'Both' && cinnamonQty > 0) _row('Cinnamon', '${cinnamonQty.toStringAsFixed(1)} $unit'),
                      _divider(),
                      _row('Order Date', _formatDate(orderDate)),
                      _row('Created', _formatDate(createdAt)),
                      _row('Last Updated', _formatDate(updatedAt)),
                    ]),
                    if (description.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _sectionCard('Description', Icons.notes_rounded, AppColors.secondaryText, [
                        Text(description, style: const TextStyle(fontSize: 13, color: AppColors.darkText, height: 1.4)),
                      ]),
                    ],
                    if (orderPhotos.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      _sectionCard('Photos (${orderPhotos.length})', Icons.photo_library_rounded, AppColors.primaryBlue, [
                        SizedBox(
                          height: 100,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: orderPhotos.length,
                            separatorBuilder: (_, __) => const SizedBox(width: 8),
                            itemBuilder: (_, i) => ClipRRect(
                              borderRadius: BorderRadius.circular(8),
                              child: CachedNetworkImage(imageUrl: orderPhotos[i], width: 100, height: 100, fit: BoxFit.cover,
                                errorWidget: (_, __, ___) => Container(color: AppColors.hover, child: const Icon(Icons.broken_image, size: 24))),
                            ),
                          ),
                        ),
                      ]),
                    ],
                    const SizedBox(height: 8),
                  ],
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
              decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
              child: SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 10), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Text('Close', style: TextStyle(fontSize: 13)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionCard(String title, IconData icon, Color color, List<Widget> children) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(color: AppColors.hover, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Icon(icon, size: 14, color: color), const SizedBox(width: 8), Text(title, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: color))]),
      const SizedBox(height: 8),
      ...children,
    ]),
  );

  Widget _row(String label, String value) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(children: [
      Expanded(child: Text(label, style: const TextStyle(fontSize: 12, color: AppColors.secondaryText))),
      Text(value, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: AppColors.darkText)),
    ]),
  );

  Widget _divider() => const Divider(height: 8, color: AppColors.border);
}

class ExportProductsHistoryPage extends StatefulWidget {
  const ExportProductsHistoryPage({super.key});

  @override
  State<ExportProductsHistoryPage> createState() => _ExportProductsHistoryPageState();
}

class _ExportProductsHistoryPageState extends State<ExportProductsHistoryPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final User? _currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _userName = 'Loading...';
  String _landName = 'Loading...';
  String _userRole = 'Land Owner';
  String? _profileImageUrl;

  String _filterStatus = 'All';
  String _searchQuery = '';
  String _sortBy = 'Newest';

  final List<String> _statusOptions = ['All', 'Pending', 'Factory Received', 'Completed', 'Cancelled'];
  final List<String> _sortOptions = ['Newest', 'Oldest', 'Most Quantity', 'Least Quantity'];

  Map<String, dynamic> _statistics = {
    'totalOrders': 0, 'pendingCount': 0, 'factoryReceivedCount': 0, 'completedCount': 0, 'cancelledCount': 0,
    'totalTea': 0.0, 'totalCinnamon': 0.0, 'todayOrders': 0, 'todayTea': 0.0, 'todayCinnamon': 0.0,
  };

  @override
  void initState() {
    super.initState();
    _fetchHeaderData();
  }

  void _fetchHeaderData() async {
    final user = _currentUser;
    if (user == null) return;
    final uid = user.uid;
    try {
      final userDoc = await _firestore.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final data = userDoc.data();
        setState(() {
          _userName = data?['name'] ?? 'Owner';
          _profileImageUrl = data?['profileImageUrl'];
          _userRole = data?['role'] ?? 'Land Owner';
        });
      }
      final landDoc = await _firestore.collection('lands').doc(uid).get();
      if (landDoc.exists) {
        setState(() { _landName = landDoc.data()?['landName'] ?? 'Land'; });
      } else {
        setState(() { _landName = user.email?.split('@')[0] ?? 'User Account'; });
      }
    } catch (e) {
      setState(() { _userName = 'Error'; _landName = 'Error'; });
    }
  }

  Map<String, dynamic> _calculateStatistics(List<QueryDocumentSnapshot> orders) {
    double teaTotal = 0, cinnamonTotal = 0, todayTea = 0, todayCinnamon = 0;
    int pending = 0, factoryReceived = 0, completed = 0, cancelled = 0, todayOrders = 0;
    final todayStart = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);

    for (final order in orders) {
      final data = order.data() as Map<String, dynamic>;
      final status = data['status']?.toString() ?? 'pending';
      final norm = normalizeStatus(status);
      if (norm == 'pending') pending++;
      else if (norm == 'factory_received') factoryReceived++;
      else if (norm == 'completed') completed++;
      else if (norm == 'cancelled') cancelled++;

      final cropType = data['cropType'] ?? 'Both';
      final totalQty = _getQuantity(data['totalQuantity']);
      final teaQty = _getQuantity(data['teaQuantity']);
      final cinnamonQty = _getQuantity(data['cinnamonQuantity']);
      if (cropType == 'Tea') teaTotal += totalQty;
      else if (cropType == 'Cinnamon') cinnamonTotal += totalQty;
      else if (cropType == 'Both') {
        if (teaQty > 0 || cinnamonQty > 0) { teaTotal += teaQty; cinnamonTotal += cinnamonQty; }
        else { teaTotal += totalQty; cinnamonTotal += totalQty; }
      }

      final orderDate = (data['orderDate'] as Timestamp?)?.toDate();
      if (orderDate != null && orderDate.isAfter(todayStart)) {
        todayOrders++;
        if (cropType == 'Tea') todayTea += totalQty;
        else if (cropType == 'Cinnamon') todayCinnamon += totalQty;
        else if (cropType == 'Both') {
          if (teaQty > 0 || cinnamonQty > 0) { todayTea += teaQty; todayCinnamon += cinnamonQty; }
          else { todayTea += totalQty; todayCinnamon += totalQty; }
        }
      }
    }
    return {
      'totalOrders': orders.length, 'pendingCount': pending, 'factoryReceivedCount': factoryReceived,
      'completedCount': completed, 'cancelledCount': cancelled,
      'totalTea': teaTotal, 'totalCinnamon': cinnamonTotal,
      'todayOrders': todayOrders, 'todayTea': todayTea, 'todayCinnamon': todayCinnamon,
    };
  }

  List<QueryDocumentSnapshot> _sortOrders(List<QueryDocumentSnapshot> orders) {
    final list = orders.toList();
    list.sort((a, b) {
      final aData = a.data() as Map<String, dynamic>;
      final bData = b.data() as Map<String, dynamic>;
      final aDate = (aData['orderDate'] as Timestamp?)?.toDate() ?? DateTime(0);
      final bDate = (bData['orderDate'] as Timestamp?)?.toDate() ?? DateTime(0);
      switch (_sortBy) {
        case 'Newest': return bDate.compareTo(aDate);
        case 'Oldest': return aDate.compareTo(bDate);
        case 'Most Quantity': return _getQuantity(bData['totalQuantity']).compareTo(_getQuantity(aData['totalQuantity']));
        case 'Least Quantity': return _getQuantity(aData['totalQuantity']).compareTo(_getQuantity(bData['totalQuantity']));
        default: return bDate.compareTo(aDate);
      }
    });
    return list;
  }

  bool _shouldShow(Map<String, dynamic> data) {
    if (_filterStatus != 'All') {
      final display = getDisplayStatus(data['status'] ?? 'pending');
      if (_filterStatus != display) return false;
    }
    if (_searchQuery.isNotEmpty) {
      final q = _searchQuery.toLowerCase();
      final factory = (data['factoryName'] ?? '').toString().toLowerCase();
      final desc = (data['description'] ?? '').toString().toLowerCase();
      final crop = (data['cropType'] ?? '').toString().toLowerCase();
      return factory.contains(q) || desc.contains(q) || crop.contains(q);
    }
    return true;
  }

  void _showSortDialog() => showModalBottomSheet(
    context: context,
    shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(16))),
    builder: (_) => Column(mainAxisSize: MainAxisSize.min, children: [
      const SizedBox(height: 12),
      Center(child: Container(width: 36, height: 3, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
      const SizedBox(height: 16),
      const Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('Sort Orders', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700))),
      ..._sortOptions.map((opt) => ListTile(
        leading: Icon(_sortIcon(opt), color: _sortBy == opt ? AppColors.primaryBlue : AppColors.secondaryText),
        title: Text(opt),
        trailing: _sortBy == opt ? Icon(Icons.check_circle, color: AppColors.primaryBlue, size: 18) : null,
        onTap: () { setState(() => _sortBy = opt); Navigator.pop(context); },
      )),
      const SizedBox(height: 16),
    ]),
  );

  IconData _sortIcon(String opt) {
    switch (opt) {
      case 'Newest': return Icons.new_releases_rounded;
      case 'Oldest': return Icons.history_rounded;
      case 'Most Quantity': return Icons.arrow_upward_rounded;
      case 'Least Quantity': return Icons.arrow_downward_rounded;
      default: return Icons.sort_rounded;
    }
  }

  Widget _buildModernHeader(BuildContext ctx) {
    final w = MediaQuery.of(ctx).size.width;
    final sm = w < 360;
    final md = w >= 360 && w < 400;

    return Container(
      padding: EdgeInsets.only(
        top: MediaQuery.of(ctx).padding.top + 2,
        left: 16, right: 16, bottom: 12,
      ),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
          begin: Alignment.topCenter, end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x10000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              GestureDetector(
                onTap: () => _scaffoldKey.currentState?.openDrawer(),
                child: Container(
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(Icons.menu, color: AppColors.headerTextDark, size: 24),
                ),
              ),
              const Spacer(),
              Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_userName,
                    style: TextStyle(
                      fontSize: sm ? 14 : md ? 16 : 18,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    )),
                  const SizedBox(height: 3),
                  Text('Land Name: $_landName',
                    style: TextStyle(
                      fontSize: sm ? 9 : md ? 10 : 11,
                      color: AppColors.headerTextDark.withOpacity(0.75),
                    )),
                  Text('($_userRole)',
                    style: TextStyle(
                      fontSize: sm ? 9 : md ? 10 : 11,
                      color: AppColors.headerTextDark.withOpacity(0.75),
                    )),
                ],
              ),
              const Spacer(),
              _buildAvatar(),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Export Product History',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.headerTextDark)),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(radius: 40, backgroundImage: NetworkImage(_profileImageUrl!),
        onBackgroundImageError: (_, __) => setState(() => _profileImageUrl = null));
    }
    return CircleAvatar(radius: 40, backgroundColor: AppColors.primaryBlue.withOpacity(0.15),
      child: const Icon(Icons.person, color: AppColors.primaryBlue, size: 40));
  }

  Widget _buildFooter() => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
    child: const Text('Developed By Malitha Tishamal',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
  );

  Widget _statsCard(String title, String value, Color color, IconData icon, {String? subtitle}) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
    decoration: BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(_D.cardRadius),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 13, color: color),
          ),
          const Spacer(),
          if (subtitle != null)
            Text(subtitle,
              style: TextStyle(
                fontSize: 9,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
        ]),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: color,
            height: 1.1,
          ),
        ),
        Text(
          title,
          style: const TextStyle(fontSize: 9, color: AppColors.secondaryText),
        ),
      ],
    ),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: LandOwnerDrawer(onLogout: () => FirebaseAuth.instance.signOut(), onNavigate: (_) => Navigator.pop(context)),
      body: Column(
        children: [
          _buildModernHeader(context),
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: _firestore.collection('land_orders').where('landOwnerId', isEqualTo: _currentUser?.uid).snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
                if (snapshot.hasError) return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: AppColors.accentRed)));
                final orders = snapshot.data?.docs ?? [];
                final stats = _calculateStatistics(orders);
                _statistics = stats;
                final filtered = orders.where((o) => _shouldShow(o.data() as Map<String, dynamic>)).toList();
                final sorted = _sortOrders(filtered);
                return Column(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                        child: Column(
                          children: [
                            Row(children: [
                              Expanded(child: _statsCard('Pending', '${stats['pendingCount']}', AppColors.warningOrange, Icons.schedule_rounded, subtitle: 'Awaiting')),
                              const SizedBox(width: 6),
                              Expanded(child: _statsCard('Factory Received', '${stats['factoryReceivedCount']}', AppColors.infoBlue, Icons.factory_rounded, subtitle: 'Processing')),
                              const SizedBox(width: 6),
                              Expanded(child: _statsCard('Completed', '${stats['completedCount']}', AppColors.successGreen, Icons.check_circle_rounded, subtitle: 'Delivered')),
                              const SizedBox(width: 6),
                              Expanded(child: _statsCard('Cancelled', '${stats['cancelledCount']}', AppColors.accentRed, Icons.cancel_rounded, subtitle: 'Rejected')),
                            ]),
                            const SizedBox(height: 12),
                            Row(children: [
                              Expanded(child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(_D.cardRadius), border: Border.all(color: AppColors.border)),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AppColors.teaGreen.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                      child: const Icon(Icons.emoji_food_beverage_rounded, size: 14, color: AppColors.teaGreen)),
                                    const Spacer(),
                                    Text('${stats['todayTea'].toStringAsFixed(1)} kg today', style: const TextStyle(fontSize: 9, color: AppColors.teaGreen, fontWeight: FontWeight.w600)),
                                  ]),
                                  const SizedBox(height: 4),
                                  const Text('Tea Exported', style: TextStyle(fontSize: 10, color: AppColors.secondaryText)),
                                  Text('${stats['totalTea'].toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkText)),
                                ]),
                              )),
                              const SizedBox(width: 6),
                              Expanded(child: Container(
                                padding: const EdgeInsets.all(8),
                                decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(_D.cardRadius), border: Border.all(color: AppColors.border)),
                                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                                  Row(children: [
                                    Container(padding: const EdgeInsets.all(4), decoration: BoxDecoration(color: AppColors.cinnamonOrange.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                                      child: const Icon(Icons.spa_rounded, size: 14, color: AppColors.cinnamonOrange)),
                                    const Spacer(),
                                    Text('${stats['todayCinnamon'].toStringAsFixed(1)} kg today', style: const TextStyle(fontSize: 9, color: AppColors.cinnamonOrange, fontWeight: FontWeight.w600)),
                                  ]),
                                  const SizedBox(height: 4),
                                  const Text('Cinnamon Exported', style: TextStyle(fontSize: 10, color: AppColors.secondaryText)),
                                  Text('${stats['totalCinnamon'].toStringAsFixed(1)} kg', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkText)),
                                ]),
                              )),
                            ]),
                            const SizedBox(height: 12),
                            TextFormField(
                              onChanged: (v) => setState(() => _searchQuery = v),
                              decoration: InputDecoration(
                                hintText: 'Search by factory, crop, description...',
                                prefixIcon: Icon(Icons.search, size: 18, color: AppColors.primaryBlue),
                                suffixIcon: _searchQuery.isNotEmpty ? IconButton(icon: Icon(Icons.close, size: 16), onPressed: () => setState(() => _searchQuery = '')) : null,
                                contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                                enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.border)),
                                focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(8), borderSide: BorderSide(color: AppColors.primaryBlue, width: 2)),
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: [
                                ..._statusOptions.map((s) =>
                                    _filterChip(s, _filterStatus == s, () => setState(() => _filterStatus = s))),
                                GestureDetector(
                                  onTap: _showSortDialog,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                                    decoration: BoxDecoration(
                                      color: AppColors.hover,
                                      borderRadius: BorderRadius.circular(20),
                                      border: Border.all(color: AppColors.border),
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(Icons.sort_rounded, size: 14, color: AppColors.primaryBlue),
                                        const SizedBox(width: 4),
                                        Text(_sortBy, style: const TextStyle(fontSize: 12, color: AppColors.primaryBlue)),
                                      ],
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 12),
                            if (sorted.isEmpty)
                              Container(padding: const EdgeInsets.all(40), child: Column(children: [
                                Icon(Icons.inbox_rounded, size: 64, color: AppColors.textTertiary),
                                const SizedBox(height: 12),
                                Text('No orders found', style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
                                const SizedBox(height: 4),
                                Text(_searchQuery.isNotEmpty || _filterStatus != 'All' ? 'Try adjusting filters' : 'Start exporting to see history',
                                  style: const TextStyle(fontSize: 12, color: AppColors.secondaryText), textAlign: TextAlign.center),
                                if (_searchQuery.isNotEmpty || _filterStatus != 'All')
                                  Padding(padding: const EdgeInsets.only(top: 16), child: ElevatedButton(onPressed: () => setState(() { _searchQuery = ''; _filterStatus = 'All'; }), child: const Text('Clear Filters'))),
                              ]))
                            else
                              Column(children: sorted.map((doc) => _orderCard(doc)).toList()),
                            const SizedBox(height: 20),
                          ],
                        ),
                      ),
                    ),
                    _buildFooter(),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _filterChip(String label, bool selected, VoidCallback onTap) => GestureDetector(
    onTap: onTap,
    child: Container(
      margin: const EdgeInsets.only(right: 6),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
      decoration: BoxDecoration(
        color: selected ? AppColors.primaryBlue : AppColors.cardBackground,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppColors.primaryBlue : AppColors.border),
      ),
      child: Text(label, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: selected ? Colors.white : AppColors.primaryBlue)),
    ),
  );

  Widget _orderCard(QueryDocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    final status = data['status'] ?? 'Pending';
    final displayStatus = getDisplayStatus(status);
    final statusColor = getStatusColor(status);
    final cropType = data['cropType'] ?? 'Both';
    final factoryName = data['factoryName'] ?? 'Unknown';
    final totalQty = _getQuantity(data['totalQuantity']);
    final unit = data['unit'] ?? 'kg';
    final orderPhotos = parseImageUrls(data['orderPhotos']);
    final orderDate = (data['orderDate'] as Timestamp?)?.toDate();

    final cropColor = _getCropColor(cropType);
    final cropLightColor = _getCropLightColor(cropType);

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(_D.cardRadius), border: Border.all(color: AppColors.border)),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: statusColor.withOpacity(0.04),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(_D.cardRadius)),
              border: Border(bottom: BorderSide(color: AppColors.border)),
            ),
            child: Row(children: [
              Container(width: 26, height: 26, decoration: BoxDecoration(color: statusColor.withOpacity(0.12), shape: BoxShape.circle),
                child: Icon(getStatusIcon(status), size: 12, color: statusColor)),
              const SizedBox(width: 8),
              Expanded(child: Text(factoryName, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.darkText), overflow: TextOverflow.ellipsis)),
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3), decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: Text(displayStatus, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: statusColor))),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: cropLightColor,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    cropType,
                    style: TextStyle(
                      fontSize: 9,
                      fontWeight: FontWeight.w600,
                      color: cropColor,
                    ),
                  ),
                ),
                const Spacer(),
                Text('$totalQty $unit', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.darkText)),
              ]),
              if (orderDate != null) ...[
                const SizedBox(height: 4),
                Row(children: [
                  const Icon(Icons.calendar_today_rounded, size: 10, color: AppColors.textTertiary),
                  const SizedBox(width: 4),
                  Text(DateFormat('dd MMM yyyy').format(orderDate), style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
                  if (orderPhotos.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    const Icon(Icons.photo_camera_rounded, size: 10, color: AppColors.primaryBlue),
                    const SizedBox(width: 3),
                    Text('${orderPhotos.length}', style: const TextStyle(fontSize: 10, color: AppColors.primaryBlue)),
                  ],
                ]),
              ],
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => showDialog(context: context, builder: (_) => OrderDetailsModal(orderData: data, orderId: doc.id)),
                  style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 8), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
                  child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Text('View Details', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                    SizedBox(width: 4),
                    Icon(Icons.arrow_forward_rounded, size: 12),
                  ]),
                ),
              ),
            ]),
          ),
        ],
      ),
    );
  }
}