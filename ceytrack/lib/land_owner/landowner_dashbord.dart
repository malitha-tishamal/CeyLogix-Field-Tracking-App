// land_owner_dashboard.dart — MODERN REDESIGN
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'land_owner_drawer.dart';
import 'export_product_details.dart';

class AppColors {
  static const Color background        = Color(0xFFF4F6FA);
  static const Color darkText          = Color(0xFF1A1D26);
  static const Color primaryBlue       = Color(0xFF2764E7);
  static const Color accentRed         = Color(0xFFE53935);
  static const Color accentTeal        = Color(0xFF00BFA5);
  static const Color cardBackground    = Colors.white;
  static const Color secondaryText     = Color(0xFF6A798A);
  static const Color secondaryColor    = Color(0xFF6AD96A);
  static const Color successGreen      = Color(0xFF2E9E5B);
  static const Color warningOrange     = Color(0xFFE8840A);
  static const Color purpleAccent      = Color(0xFF7C3AED);
  static const Color amberAccent       = Color(0xFFF59E0B);
  static const Color headerGradientStart = Color(0xFF869AEC);
  static const Color headerGradientEnd   = Color(0xFFF7FAFF);
  static const Color headerTextDark      = Color(0xFF333333);
  static const Color info              = Color(0xFF0EA5E9);
  static const Color textTertiary      = Color(0xFFB0BAC8);
  static const Color hover             = Color(0xFFF8FAFC);
  static const Color border            = Color(0xFFE8ECF2);
}

// ─── compact design tokens ────────────────────────────────────
class _D {
  static const double cardRadius  = 10.0;
  static const double cardPad     = 10.0;
  static const double sectionGap  = 14.0;
  static const double chipRadius  = 6.0;
  static const double iconBox     = 28.0;
  static const double iconSize    = 14.0;
}

// ─────────────────────────────────────────────────────────────
class LandOwnerDashboard extends StatefulWidget {
  const LandOwnerDashboard({super.key});
  @override
  State<LandOwnerDashboard> createState() => _LandOwnerDashboardState();
}

class _LandOwnerDashboardState extends State<LandOwnerDashboard> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final GlobalKey<ScaffoldState> _key = GlobalKey<ScaffoldState>();

  String  _name       = 'Loading...';
  String  _landName   = 'Loading...';
  String  _userRole   = 'Land Owner';
  String  _landID     = 'L-ID';
  String? _avatarUrl;

  List<Map<String, dynamic>> _allFactories   = [];
  List<Map<String, dynamic>> _teaFact        = [];
  List<Map<String, dynamic>> _cinnamonFact   = [];
  List<Map<String, dynamic>> _multiFact      = [];
  bool   _loadingFact = true;
  String? _factError;

  String? _landSize, _landSizeUnit, _cropType;
  String? _teaLandSize, _cinnamonLandSize, _landSizeDetails;
  List<String> _landPhotos = [];

  @override
  void initState() {
    super.initState();
    _fetchHeaderData();
    _fetchFactories();
    _fetchLandSize();
  }

  // ── data ──────────────────────────────────────────────────
  void _fetchHeaderData() async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    setState(() => _landID = uid.substring(0, 8));
    try {
      final ud = await _db.collection('users').doc(uid).get();
      if (ud.exists) setState(() { _name = ud['name'] ?? 'Owner'; _avatarUrl = ud['profileImageUrl']; });
      final ld = await _db.collection('lands').doc(uid).get();
      if (ld.exists) setState(() => _landName = ld['landName'] ?? 'Land');
    } catch (_) {}
  }

  void _fetchLandSize() async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    try {
      final d = await _db.collection('lands').doc(uid).get();
      if (d.exists) setState(() {
        _landSize          = d['landSize']?.toString();
        _landSizeUnit      = d['landSizeUnit'] ?? 'Acre';
        _cropType          = d['cropType'];
        _teaLandSize       = d['teaLandSize']?.toString();
        _cinnamonLandSize  = d['cinnamonLandSize']?.toString();
        _landSizeDetails   = d['landSizeDetails'];
        _landPhotos        = List<String>.from(d['landPhotos'] ?? []);
      });
    } catch (_) {}
  }

  void _fetchFactories() async {
    final uid = currentUser?.uid;
    if (uid == null) return;
    setState(() { _loadingFact = true; _factError = null; });
    try {
      final ld = await _db.collection('lands').doc(uid).get();
      if (!ld.exists) { setState(() { _allFactories = []; _loadingFact = false; }); return; }
      final ids = List<String>.from(ld['factoryIds'] ?? []);
      if (ids.isEmpty) { setState(() { _allFactories = []; _loadingFact = false; }); return; }
      List<Map<String, dynamic>> fList = [];
      for (final id in ids) {
        try {
          final fd = await _db.collection('factories').doc(id).get();
          if (!fd.exists) continue;
          final fData = fd.data() as Map<String, dynamic>;
          String ownerName = 'Unknown';
          try {
            final ud = await _db.collection('users').doc(id).get();
            if (ud.exists) ownerName = ud['name'] ?? 'Unknown';
          } catch (_) {}
          fList.add({'id': id, ...fData, 'ownerName': ownerName});
        } catch (_) {}
      }
      final tea      = fList.where((f) => f['cropType'] == 'Tea').toList();
      final cinnamon = fList.where((f) => f['cropType'] == 'Cinnamon').toList();
      final multi    = fList.where((f) => f['cropType'] == 'Both').toList();
      setState(() { _allFactories = fList; _teaFact = tea; _cinnamonFact = cinnamon; _multiFact = multi; _loadingFact = false; });
    } catch (e) {
      setState(() { _factError = 'Failed to load factories'; _loadingFact = false; });
    }
  }

  Future<void> _call(String phone) async {
    if (phone.isEmpty || phone == 'N/A') { _snack('Phone not available'); return; }
    final tel = 'tel:${phone.replaceAll(RegExp(r'[-\s]'), '')}';
    try {
      if (await canLaunchUrl(Uri.parse(tel))) await launchUrl(Uri.parse(tel));
      else _showCallError(phone);
    } catch (_) { _showCallError(phone); }
  }

  void _showCallError(String phone) => showDialog(context: context,
    builder: (_) => AlertDialog(
      title: const Text('Cannot Make Call'),
      content: Text('No phone app found.\n\nNumber: $phone'),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('OK'))],
    ));

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg), duration: const Duration(seconds: 2), behavior: SnackBarBehavior.floating));

  // ── helpers ───────────────────────────────────────────────
  Color _cropColor([String? c]) {
    switch ((c ?? _cropType ?? '').toLowerCase()) {
      case 'tea'      : return AppColors.successGreen;
      case 'cinnamon' : return AppColors.warningOrange;
      case 'both'     : return AppColors.purpleAccent;
      default         : return AppColors.primaryBlue;
    }
  }
  IconData _cropIcon([String? c]) {
    switch ((c ?? _cropType ?? '').toLowerCase()) {
      case 'tea'      : return Icons.eco_rounded;
      case 'cinnamon' : return Icons.forest_rounded;
      case 'both'     : return Icons.layers_rounded;
      default         : return Icons.landscape_rounded;
    }
  }
  Color _statusColor(String s) {
    switch (s.toLowerCase()) {
      case 'pending'          : return AppColors.warningOrange;
      case 'factory recived'  :
      case 'factory received' : return AppColors.info;
      case 'delivered': case 'completed': case 'accepted': return AppColors.successGreen;
      case 'cancelled': case 'rejected' : return AppColors.accentRed;
      default: return AppColors.primaryBlue;
    }
  }
  IconData _statusIcon(String s) {
    switch (s.toLowerCase()) {
      case 'pending'          : return Icons.schedule_rounded;
      case 'factory recived'  :
      case 'factory received' : return Icons.factory_rounded;
      case 'delivered': case 'completed': case 'accepted': return Icons.check_circle_rounded;
      case 'cancelled': case 'rejected' : return Icons.cancel_rounded;
      default: return Icons.info_rounded;
    }
  }

  // ── build ─────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _key,
      backgroundColor: AppColors.background,
      drawer: LandOwnerDrawer(
        onLogout   : () => Navigator.pop(context),
        onNavigate : (_) => Navigator.pop(context),
      ),
      body: Column(children: [
        _buildHeader(context),
        Expanded(child: Column(children: [
          Expanded(child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _sectionLabel('Land Summary', Icons.landscape_rounded),
              const SizedBox(height: 8),
              _buildLandCard(),
              const SizedBox(height: _D.sectionGap),
              _buildExportSection(),
              const SizedBox(height: _D.sectionGap),
              _buildFactoriesSection(),
              const SizedBox(height: 20),
            ]),
          )),
          _buildFooter(),
        ])),
      ]),
    );
  }

  // ── HEADER (factory-owner style) ─────────────────────────
  Widget _buildHeader(BuildContext ctx) {
    final w  = MediaQuery.of(ctx).size.width;
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
          begin: Alignment.topCenter, end: Alignment.bottomCenter),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30), bottomRight: Radius.circular(30)),
        boxShadow: [BoxShadow(color: Color(0x10000000), blurRadius: 15, offset: Offset(0, 5))],
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
        // Top row: menu | name+role | avatar
        Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
          // Menu button
          GestureDetector(
            onTap: () => _key.currentState?.openDrawer(),
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
          // Centre: name + role
          Column(mainAxisSize: MainAxisSize.min, children: [
            Text(_name,
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
          ]),
          const Spacer(),
          // Avatar
          _buildAvatar(),
        ]),
        const SizedBox(height: 12),
        // Bottom title
        Text('Land Overview (ID: $_landID)',
          style: const TextStyle(
            fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.headerTextDark)),
      ]),
    );
  }

  Widget _buildAvatar() {
    if (_avatarUrl != null && _avatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: NetworkImage(_avatarUrl!),
        backgroundColor: Colors.grey.shade200,
        onBackgroundImageError: (_, __) => setState(() => _avatarUrl = null),
      );
    }
    return CircleAvatar(
      radius: 40,
      backgroundColor: AppColors.primaryBlue.withOpacity(0.15),
      child: const Icon(Icons.person, color: AppColors.primaryBlue, size: 40),
    );
  }

  // ── LAND SUMMARY CARD ─────────────────────────────────────
  Widget _buildLandCard() {
    final cc = _cropColor();

    // build display values
    String areaVal  = 'No Data';
    String areaLbl  = 'Land Area';
    String? subLine;

    if (_cropType != null && _landSize != null) {
      final u = _landSizeUnit ?? 'Ac';
      if (_cropType == 'Both') {
        final t = double.tryParse(_teaLandSize ?? '0') ?? 0;
        final c = double.tryParse(_cinnamonLandSize ?? '0') ?? 0;
        areaVal = '${(t + c).toStringAsFixed(1)} $u';
        areaLbl = 'Total Land Area';
        if (t > 0 && c > 0) subLine = 'Tea ${t}Ac  ·  Cinnamon ${c}Ac';
      } else {
        areaVal = '$_landSize $u';
        areaLbl = '${_cropType} Land Area';
      }
    }

    return GestureDetector(
      onTap: _showLandModal,
      child: Container(
        padding: const EdgeInsets.all(_D.cardPad),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(_D.cardRadius),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Row(children: [
          // Icon box
          Container(
            width: 44, height: 44,
            decoration: BoxDecoration(color: cc.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
            child: Icon(_cropIcon(), color: cc, size: 22),
          ),
          const SizedBox(width: 12),
          // Info
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(areaVal, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.darkText, height: 1.1)),
            Text(areaLbl, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText)),
            if (subLine != null) ...[
              const SizedBox(height: 3),
              Text(subLine!, style: TextStyle(fontSize: 10, color: cc.withOpacity(0.9))),
            ],
          ])),
          // Crop badge + arrow
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            if (_cropType != null)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: cc.withOpacity(0.1), borderRadius: BorderRadius.circular(6)),
                child: Text(_cropType!, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: cc)),
              ),
            const SizedBox(height: 6),
            Icon(Icons.chevron_right_rounded, size: 16, color: AppColors.textTertiary),
          ]),
        ]),
      ),
    );
  }

  // ── EXPORT SUMMARY SECTION ────────────────────────────────
  Widget _buildExportSection() {
    return FutureBuilder<QuerySnapshot>(
      future: _db.collection('land_orders').where('landOwnerId', isEqualTo: currentUser?.uid).limit(5).get(),
      builder: (ctx, snap) {
        if (snap.connectionState == ConnectionState.waiting) return _exportLoading();
        if (snap.hasError || !snap.hasData || snap.data!.docs.isEmpty) return _exportEmpty();

        final docs = snap.data!.docs;
        double total = 0, tea = 0, cinn = 0;
        int delivered = 0;
        for (final d in docs) {
          final data = d.data() as Map<String, dynamic>;
          final s    = (data['status'] ?? '').toString().toLowerCase();
          final ct   = data['cropType'] ?? '';
          final tq   = double.tryParse(data['totalQuantity']?.toString() ?? '0') ?? 0;
          final teaq = double.tryParse(data['teaQuantity']?.toString() ?? '0') ?? 0;
          final cinq = double.tryParse(data['cinnamonQuantity']?.toString() ?? '0') ?? 0;
          total += tq;
          if (ct == 'Tea')      tea  += tq;
          if (ct == 'Cinnamon') cinn += cinq;
          if (ct == 'Both') { tea += teaq; cinn += cinq; }
          if (s.contains('delivered') || s.contains('completed') || s.contains('accepted')) delivered++;
        }

        return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          _sectionLabel('Export Summary', Icons.inventory_2_rounded,
            trailing: GestureDetector(
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ExportProductsHistoryPage())),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(8)),
                child: const Row(children: [
                  Text('View All', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: AppColors.primaryBlue)),
                  SizedBox(width: 3),
                  Icon(Icons.arrow_forward_rounded, size: 11, color: AppColors.primaryBlue),
                ]),
              ),
            ),
          ),
          const SizedBox(height: 8),

          // 3 stat mini-cards
          Row(children: [
            Expanded(child: _miniStat('Total', docs.length.toString(),         Icons.receipt_long_rounded, AppColors.primaryBlue)),
            const SizedBox(width: 6),
            Expanded(child: _miniStat('Delivered', delivered.toString(),        Icons.check_circle_rounded,  AppColors.successGreen)),
            const SizedBox(width: 6),
            Expanded(child: _miniStat('Total Qty', '${total.toStringAsFixed(0)}kg', Icons.scale_rounded,    AppColors.purpleAccent)),
          ]),

          // Crop breakdown
          if (tea > 0 || cinn > 0) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(_D.cardPad),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(_D.cardRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 3, height: 12, decoration: BoxDecoration(color: AppColors.primaryBlue, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  const Text('Crop Breakdown', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.darkText)),
                ]),
                const SizedBox(height: 8),
                if (tea > 0)  _cropBar('Tea',      tea,  total, AppColors.successGreen),
                if (cinn > 0) _cropBar('Cinnamon', cinn, total, AppColors.warningOrange),
              ]),
            ),
          ],

          // Recent exports
          if (docs.isNotEmpty) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(_D.cardPad),
              decoration: BoxDecoration(
                color: AppColors.cardBackground,
                borderRadius: BorderRadius.circular(_D.cardRadius),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(width: 3, height: 12, decoration: BoxDecoration(color: AppColors.primaryBlue, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 6),
                  const Text('Recent Exports', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.darkText)),
                ]),
                const SizedBox(height: 8),
                ...docs.take(3).map((d) => _exportRow(d)).toList(),
              ]),
            ),
          ],
        ]);
      },
    );
  }

  Widget _miniStat(String label, String value, IconData icon, Color color) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
    decoration: BoxDecoration(
      color: AppColors.cardBackground,
      borderRadius: BorderRadius.circular(_D.cardRadius),
      border: Border.all(color: AppColors.border),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
    ),
    child: Row(children: [
      Container(
        width: 28, height: 28,
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: 13, color: color),
      ),
      const SizedBox(width: 7),
      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(value, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color, height: 1.1)),
        Text(label, style: const TextStyle(fontSize: 9, color: AppColors.secondaryText)),
      ])),
    ]),
  );

  Widget _cropBar(String label, double val, double total, Color color) {
    final pct = total > 0 ? val / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          Text('${val.toStringAsFixed(0)} kg  (${(pct * 100).toStringAsFixed(0)}%)',
            style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
        ]),
        const SizedBox(height: 3),
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, minHeight: 5,
            backgroundColor: color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation(color)),
        ),
      ]),
    );
  }

  Widget _exportRow(QueryDocumentSnapshot doc) {
    final data     = doc.data() as Map<String, dynamic>;
    final factory  = data['factoryName'] ?? 'Unknown';
    final status   = data['status'] ?? 'Pending';
    final qty      = data['totalQuantity']?.toString() ?? '0';
    final crop     = data['cropType'] ?? 'N/A';
    final date     = data['orderDate'] as Timestamp?;
    final unit     = data['unit'] ?? 'kg';
    final sc       = _statusColor(status);
    final cc       = _cropColor(crop);

    return GestureDetector(
      onTap: () => _showOrderModal(doc, data),
      child: Container(
        margin: const EdgeInsets.only(bottom: 6),
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.hover,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: sc.withOpacity(0.12), shape: BoxShape.circle),
            child: Icon(_statusIcon(status), size: 12, color: sc),
          ),
          const SizedBox(width: 9),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(factory, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkText), overflow: TextOverflow.ellipsis),
            Row(children: [
              Text('$qty $unit  ·  ', style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                decoration: BoxDecoration(color: cc.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
                child: Text(crop, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: cc)),
              ),
            ]),
            if (date != null)
              Text(DateFormat('dd MMM  •  HH:mm').format(date.toDate()),
                style: const TextStyle(fontSize: 9.5, color: AppColors.textTertiary)),
          ])),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
            decoration: BoxDecoration(color: sc.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: sc.withOpacity(0.2))),
            child: Text(status, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: sc)),
          ),
        ]),
      ),
    );
  }

  Widget _exportLoading() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(_D.cardRadius), border: Border.all(color: AppColors.border)),
    child: const Row(children: [
      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue)),
      SizedBox(width: 12),
      Text('Loading export data…', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
    ]),
  );

  Widget _exportEmpty() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(_D.cardRadius), border: Border.all(color: AppColors.border)),
    child: Column(children: [
      const Icon(Icons.inbox_rounded, size: 36, color: AppColors.textTertiary),
      const SizedBox(height: 8),
      const Text('No Export History', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.darkText)),
      const SizedBox(height: 4),
      const Text('Start exporting your products to see history', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
      const SizedBox(height: 10),
      ElevatedButton(onPressed: () {},
        style: ElevatedButton.styleFrom(backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)), elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8)),
        child: const Text('Start Exporting', style: TextStyle(fontSize: 11))),
    ]),
  );

  // ── FACTORIES SECTION ─────────────────────────────────────
  Widget _buildFactoriesSection() {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      _sectionLabel('Associated Factories', Icons.factory_rounded,
        trailing: _allFactories.isNotEmpty ? _countBadge(_allFactories.length.toString()) : null),
      const SizedBox(height: 8),

      // mini stat row
      if (_allFactories.isNotEmpty) ...[
        Row(children: [
          Expanded(child: _factStat('Total',      _allFactories.length.toString(),  Icons.factory_rounded,   AppColors.primaryBlue)),
          const SizedBox(width: 6),
          Expanded(child: _factStat('Tea',        _teaFact.length.toString(),       Icons.eco_rounded,       AppColors.successGreen,  onTap: () => _teaFact.isNotEmpty     ? _showCatDialog('Tea Factories',      _teaFact,     AppColors.successGreen)  : null)),
          const SizedBox(width: 6),
          Expanded(child: _factStat('Cinnamon',   _cinnamonFact.length.toString(),  Icons.forest_rounded,    AppColors.warningOrange, onTap: () => _cinnamonFact.isNotEmpty ? _showCatDialog('Cinnamon Factories', _cinnamonFact, AppColors.warningOrange) : null)),
          const SizedBox(width: 6),
          Expanded(child: _factStat('Multi',      _multiFact.length.toString(),     Icons.layers_rounded,    AppColors.purpleAccent,  onTap: () => _multiFact.isNotEmpty    ? _showCatDialog('Multi-Crop',         _multiFact,    AppColors.purpleAccent)  : null)),
        ]),
        const SizedBox(height: 10),
      ],

      if (_loadingFact)        _factLoading()
      else if (_factError != null) _factErr()
      else if (_allFactories.isEmpty) _factEmpty()
      else _buildFactoryList(),
    ]);
  }

  Widget _factStat(String label, String val, IconData icon, Color color, {VoidCallback? onTap}) =>
    GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 7),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(_D.cardRadius),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
        ),
        child: Column(children: [
          Container(
            width: 26, height: 26,
            decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
            child: Icon(icon, size: 13, color: color),
          ),
          const SizedBox(height: 4),
          Text(val,   style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: color, height: 1.1)),
          Text(label, style: const TextStyle(fontSize: 8.5, color: AppColors.secondaryText)),
        ]),
      ),
    );

  Widget _buildFactoryList() => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
    if (_cinnamonFact.isNotEmpty) _catSection('Cinnamon Factories', Icons.forest_rounded, AppColors.warningOrange, _cinnamonFact),
    if (_teaFact.isNotEmpty)      _catSection('Tea Factories',      Icons.eco_rounded,    AppColors.successGreen,  _teaFact),
    if (_multiFact.isNotEmpty)    _catSection('Multi-Crop Factories', Icons.layers_rounded, AppColors.purpleAccent, _multiFact),
  ]);

  Widget _catSection(String title, IconData icon, Color color, List<Map<String, dynamic>> list) =>
    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 12),
      Row(children: [
        Container(
          width: _D.iconBox, height: _D.iconBox,
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, size: _D.iconSize, color: color),
        ),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.darkText)),
        const Spacer(),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
          child: Text('${list.length}', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
        ),
      ]),
      const SizedBox(height: 8),
      ...list.map((f) => _factoryCard(f, color)).toList(),
    ]);

  Widget _factoryCard(Map<String, dynamic> f, Color color) {
    final name       = f['factoryName'] ?? 'Unknown';
    final owner      = f['ownerName']   ?? 'N/A';
    final phone      = f['contactNumber'] ?? 'N/A';
    final cropType   = f['cropType'] ?? 'N/A';
    final village    = f['village']  ?? 'N/A';
    final district   = f['district'] ?? 'N/A';
    final logoUrl    = f['factoryLogoUrl'];
    final updatedAt  = f['updatedAt'] != null ? (f['updatedAt'] as Timestamp).toDate() : null;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(_D.cardRadius),
        border: Border.all(color: AppColors.border),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 4, offset: const Offset(0, 2))],
      ),
      child: Column(children: [
        // top strip
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
          decoration: BoxDecoration(
            color: color.withOpacity(0.04),
            border: Border(bottom: BorderSide(color: AppColors.border)),
            borderRadius: const BorderRadius.vertical(top: Radius.circular(_D.cardRadius)),
          ),
          child: Row(children: [
            // logo
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(9),
                boxShadow: [BoxShadow(color: color.withOpacity(0.2), blurRadius: 4, offset: const Offset(0, 2))]),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(9),
                child: logoUrl != null && logoUrl.isNotEmpty
                  ? Image.network(logoUrl, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => _logoFallback(color, cropType))
                  : _logoFallback(color, cropType),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.darkText), overflow: TextOverflow.ellipsis),
              Text('Owner: $owner', style: const TextStyle(fontSize: 10.5, color: AppColors.secondaryText), overflow: TextOverflow.ellipsis),
              if (updatedAt != null)
                Text('Updated ${DateFormat('dd MMM yyyy').format(updatedAt)}',
                  style: const TextStyle(fontSize: 9.5, color: AppColors.textTertiary)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
              decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(6), border: Border.all(color: color.withOpacity(0.2))),
              child: Text(cropType, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
            ),
          ]),
        ),

        // body
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
          child: Column(children: [
            Row(children: [
              Icon(Icons.phone_rounded, size: 12, color: color),
              const SizedBox(width: 6),
              Text(phone, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.darkText)),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              Icon(Icons.location_on_rounded, size: 12, color: color),
              const SizedBox(width: 6),
              Expanded(child: Text('$village, $district', style: const TextStyle(fontSize: 11, color: AppColors.secondaryText), overflow: TextOverflow.ellipsis)),
            ]),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => _call(phone),
                icon: Icon(Icons.phone_rounded, size: 13, color: color),
                label: Text('Call', style: TextStyle(fontSize: 11, color: color, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  side: BorderSide(color: color.withOpacity(0.4)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )),
              const SizedBox(width: 8),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => _showFactoryModal(f),
                icon: const Icon(Icons.info_outline_rounded, size: 13, color: Colors.white),
                label: const Text('Details', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: color, elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                ),
              )),
            ]),
          ]),
        ),
      ]),
    );
  }

  Widget _logoFallback(Color color, String cropType) => Container(
    color: color.withOpacity(0.15),
    child: Icon(_cropIcon(cropType), color: color, size: 18),
  );

  Widget _factLoading() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(_D.cardRadius), border: Border.all(color: AppColors.border)),
    child: const Row(children: [
      SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primaryBlue)),
      SizedBox(width: 12),
      Text('Loading factories…', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
    ]),
  );

  Widget _factErr() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(_D.cardRadius), border: Border.all(color: AppColors.border)),
    child: Column(children: [
      const Icon(Icons.cloud_off_rounded, size: 36, color: AppColors.textTertiary),
      const SizedBox(height: 8),
      Text(_factError ?? 'Error', style: const TextStyle(fontSize: 12, color: AppColors.secondaryText), textAlign: TextAlign.center),
      const SizedBox(height: 8),
      TextButton.icon(onPressed: _fetchFactories, icon: const Icon(Icons.refresh_rounded, size: 14), label: const Text('Retry', style: TextStyle(fontSize: 12)),
        style: TextButton.styleFrom(foregroundColor: AppColors.primaryBlue)),
    ]),
  );

  Widget _factEmpty() => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(color: AppColors.cardBackground, borderRadius: BorderRadius.circular(_D.cardRadius), border: Border.all(color: AppColors.border)),
    child: Column(children: [
      Container(
        width: 52, height: 52,
        decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.08), borderRadius: BorderRadius.circular(14)),
        child: const Icon(Icons.factory_outlined, size: 26, color: AppColors.primaryBlue),
      ),
      const SizedBox(height: 10),
      const Text('No Associated Factories', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.darkText)),
      const SizedBox(height: 4),
      const Text('Add factories to start supplying your crops.', textAlign: TextAlign.center,
        style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
      const SizedBox(height: 10),
      ElevatedButton.icon(onPressed: () {},
        icon: const Icon(Icons.add_business_rounded, size: 14),
        label: const Text('Add Factory', style: TextStyle(fontSize: 11)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primaryBlue, foregroundColor: Colors.white, elevation: 0,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9))),
    ]),
  );

  // ── SECTION LABEL ─────────────────────────────────────────
  Widget _sectionLabel(String title, IconData icon, {Widget? trailing}) => Row(children: [
    Container(
      width: _D.iconBox, height: _D.iconBox,
      decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
      child: Icon(icon, size: _D.iconSize, color: AppColors.primaryBlue),
    ),
    const SizedBox(width: 8),
    Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.darkText)),
    if (trailing != null) ...[const Spacer(), trailing],
  ]);

  Widget _countBadge(String n) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 3),
    decoration: BoxDecoration(
      gradient: const LinearGradient(colors: [AppColors.primaryBlue, AppColors.purpleAccent]),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(children: [
      const Icon(Icons.business_rounded, size: 11, color: Colors.white),
      const SizedBox(width: 4),
      Text(n, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)),
    ]),
  );

  // ── FOOTER ────────────────────────────────────────────────
  Widget _buildFooter() => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
    child: const Text('Developed By Malitha Tishamal',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
  );

  // ── MODALS ────────────────────────────────────────────────
  void _showLandModal() => showModalBottomSheet(context: context, isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => LandSizeDetailsModal(
      cropType: _cropType, landSize: _landSize, landSizeUnit: _landSizeUnit,
      teaLandSize: _teaLandSize, cinnamonLandSize: _cinnamonLandSize,
      landSizeDetails: _landSizeDetails, landPhotos: _landPhotos));

  void _showFactoryModal(Map<String, dynamic> f) => showModalBottomSheet(context: context,
    isScrollControlled: true, backgroundColor: Colors.transparent,
    builder: (_) => FactoryDetailsModal(factory: f, makePhoneCall: _call));

  void _showCatDialog(String title, List<Map<String, dynamic>> list, Color color) =>
    showDialog(context: context, builder: (_) => AlertDialog(
      title: Row(children: [
        Icon(_cropIcon(), color: color),
        const SizedBox(width: 10),
        Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 15)),
      ]),
      content: SizedBox(width: double.maxFinite, child: ListView.builder(
        shrinkWrap: true, itemCount: list.length,
        itemBuilder: (_, i) => ListTile(
          leading: CircleAvatar(backgroundColor: color.withOpacity(0.1), child: Icon(Icons.factory_rounded, color: color, size: 18)),
          title: Text(list[i]['factoryName'] ?? 'Unknown', style: const TextStyle(fontSize: 13)),
          subtitle: Text('Owner: ${list[i]['ownerName'] ?? 'N/A'}', style: const TextStyle(fontSize: 11)),
          trailing: Icon(Icons.chevron_right_rounded, color: color),
          onTap: () { Navigator.pop(context); _showFactoryModal(list[i]); },
        ),
      )),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close'))],
    ));

  void _showOrderModal(QueryDocumentSnapshot doc, Map<String, dynamic> data) async {
    final factoryId = data['factoryId'];
    Map<String, dynamic> fd = {};
    String ownerName = 'Loading…';
    if (factoryId != null) {
      try {
        final fDoc = await _db.collection('factories').doc(factoryId).get();
        if (fDoc.exists) fd = fDoc.data() as Map<String, dynamic>;
        final uDoc = await _db.collection('users').doc(factoryId).get();
        if (uDoc.exists) ownerName = uDoc['name'] ?? 'Unknown';
      } catch (_) {}
    }
    final sc = _statusColor(data['status'] ?? '');
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent,
      builder: (_) => OrderDetailsModal(
        orderId: doc.id,
        factoryName: data['factoryName'] ?? 'Unknown',
        ownerName: ownerName,
        contactNumber: fd['contactNumber'] ?? 'N/A',
        address: fd['address'] ?? 'N/A',
        village: fd['village'] ?? 'N/A',
        district: fd['district'] ?? 'N/A',
        factoryLogoUrl: fd['factoryLogoUrl'],
        status: data['status'] ?? 'Pending',
        statusColor: sc,
        cropType: data['cropType'] ?? 'N/A',
        totalQuantity: data['totalQuantity']?.toString() ?? '0',
        teaQuantity: data['teaQuantity']?.toString() ?? '0',
        cinnamonQuantity: data['cinnamonQuantity']?.toString() ?? '0',
        unit: data['unit'] ?? 'kg',
        description: data['description'] ?? '',
        orderDate: data['orderDate'] as Timestamp?,
        createdAt: data['createdAt'] as Timestamp?,
        updatedAt: data['updatedAt'] as Timestamp?,
        orderPhotos: List<String>.from(data['orderPhotos'] ?? []),
        makePhoneCall: _call,
      ));
  }
}

// ─────────────────────────────────────────────────────────────
// MODAL WIDGETS — unchanged logic, compact style
// ─────────────────────────────────────────────────────────────

class FactoryDetailsModal extends StatelessWidget {
  final Map<String, dynamic> factory;
  final Function(String) makePhoneCall;
  const FactoryDetailsModal({super.key, required this.factory, required this.makePhoneCall});

  Color get _mainColor {
    switch ((factory['cropType'] ?? '').toString()) {
      case 'Tea'      : return AppColors.successGreen;
      case 'Cinnamon' : return AppColors.warningOrange;
      case 'Both'     : return AppColors.purpleAccent;
      default         : return AppColors.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c        = _mainColor;
    final name     = factory['factoryName']   ?? 'Unknown';
    final owner    = factory['ownerName']     ?? 'N/A';
    final phone    = factory['contactNumber'] ?? 'N/A';
    final crop     = factory['cropType']      ?? 'N/A';
    final address  = factory['address']       ?? 'N/A';
    final village  = factory['village']       ?? 'N/A';
    final province = factory['province']      ?? 'N/A';
    final district = factory['district']      ?? 'N/A';
    final agDiv    = factory['agDivision']    ?? 'N/A';
    final gnDiv    = factory['gnDivision']    ?? 'N/A';
    final country  = factory['country']       ?? 'Sri Lanka';
    final logo     = factory['factoryLogoUrl'];
    final photos   = List<String>.from(factory['factoryPhotos'] ?? []);
    final updAt    = factory['updatedAt'] != null ? (factory['updatedAt'] as Timestamp).toDate() : null;

    return Container(
      height: MediaQuery.of(context).size.height * 0.88,
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        // handle
        Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 3,
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
        // header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 12),
          child: Row(children: [
            _logo(logo, c, crop),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(name, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.darkText)),
              Text('$crop Factory', style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
            ])),
            GestureDetector(onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close_rounded, size: 18, color: AppColors.secondaryText)),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sec('Basic Information', Icons.info_outline_rounded, [
              _row('Factory',  name),
              _row('Owner',    owner),
              _row('Contact',  phone),
              _row('Crop',     crop),
              if (updAt != null) _row('Updated', DateFormat('dd MMM yyyy  HH:mm').format(updAt)),
            ]),
            const SizedBox(height: 12),
            if (photos.isNotEmpty) ...[
              _sec('Factory Photos', Icons.photo_camera_rounded, [
                const SizedBox(height: 6),
                _photoGrid(photos, c),
              ]),
              const SizedBox(height: 12),
            ],
            _sec('Location', Icons.location_on_rounded, [
              _row('Address',  address),
              _row('Village',  village),
              _row('District', district),
              _row('Province', province),
              _row('A/G Div',  agDiv),
              _row('G/N Div',  gnDiv),
              _row('Country',  country),
            ]),
            const SizedBox(height: 20),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => makePhoneCall(phone),
                icon: Icon(Icons.phone_rounded, size: 14, color: c),
                label: Text('Call', style: TextStyle(fontSize: 12, color: c, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 11),
                  side: BorderSide(color: c), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: () {},
                icon: const Icon(Icons.message_rounded, size: 14, color: Colors.white),
                label: const Text('Message', style: TextStyle(fontSize: 12, color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: c, elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              )),
            ]),
            const SizedBox(height: 16),
          ]),
        )),
      ]),
    );
  }

  Widget _logo(String? url, Color c, String crop) => Container(
    width: 46, height: 46,
    decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
      boxShadow: [BoxShadow(color: c.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 3))]),
    child: ClipRRect(borderRadius: BorderRadius.circular(10),
      child: url != null && url.isNotEmpty
        ? Image.network(url, fit: BoxFit.cover, errorBuilder: (_, __, ___) => _fb(c, crop))
        : _fb(c, crop)),
  );

  Widget _fb(Color c, String crop) => Container(
    color: c.withOpacity(0.12),
    child: Icon(_cropIconFromString(crop), color: c, size: 22));

  IconData _cropIconFromString(String ct) {
    switch (ct.toLowerCase()) {
      case 'tea': return Icons.eco_rounded;
      case 'cinnamon': return Icons.forest_rounded;
      case 'both': return Icons.layers_rounded;
      default: return Icons.factory_rounded;
    }
  }

  Widget _sec(String title, IconData icon, List<Widget> ch) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Container(width: 26, height: 26,
          decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, size: 13, color: AppColors.primaryBlue)),
        const SizedBox(width: 7),
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkText)),
      ]),
      const SizedBox(height: 7),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.hover, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
        child: Column(children: ch),
      ),
    ],
  );

  Widget _row(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5))),
    child: Row(children: [
      SizedBox(width: 80, child: Text(label, style: const TextStyle(fontSize: 11, color: AppColors.secondaryText))),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.darkText))),
    ]),
  );

  Widget _photoGrid(List<String> photos, Color c) => GridView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
    itemCount: photos.length,
    itemBuilder: (_, i) => ClipRRect(borderRadius: BorderRadius.circular(7),
      child: Image.network(photos[i], fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: AppColors.hover, child: const Icon(Icons.broken_image_outlined, size: 18, color: AppColors.textTertiary)))));
}


// ── Order Details Modal ───────────────────────────────────────
class OrderDetailsModal extends StatelessWidget {
  final String orderId, factoryName, ownerName, contactNumber, address, village, district;
  final String? factoryLogoUrl;
  final String status, cropType, totalQuantity, teaQuantity, cinnamonQuantity, unit, description;
  final Color statusColor;
  final Timestamp? orderDate, createdAt, updatedAt;
  final List<String> orderPhotos;
  final Function(String) makePhoneCall;

  const OrderDetailsModal({
    super.key, required this.orderId, required this.factoryName, required this.ownerName,
    required this.contactNumber, required this.address, required this.village, required this.district,
    required this.factoryLogoUrl, required this.status, required this.statusColor,
    required this.cropType, required this.totalQuantity, required this.teaQuantity,
    required this.cinnamonQuantity, required this.unit, required this.description,
    required this.orderDate, required this.createdAt, required this.updatedAt,
    required this.orderPhotos, required this.makePhoneCall,
  });

  IconData get _statusIcon {
    switch (status.toLowerCase()) {
      case 'pending'          : return Icons.schedule_rounded;
      case 'factory recived'  :
      case 'factory received' : return Icons.factory_rounded;
      case 'delivered': case 'completed': case 'accepted': return Icons.check_circle_rounded;
      case 'cancelled': case 'rejected' : return Icons.cancel_rounded;
      default: return Icons.info_rounded;
    }
  }
  Color get _cropColor {
    switch (cropType.toLowerCase()) {
      case 'tea'      : return AppColors.successGreen;
      case 'cinnamon' : return AppColors.warningOrange;
      case 'both'     : return AppColors.purpleAccent;
      default         : return AppColors.primaryBlue;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 3,
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),

        // header
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(children: [
            Container(width: 44, height: 44,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(10),
                boxShadow: [BoxShadow(color: statusColor.withOpacity(0.25), blurRadius: 6, offset: const Offset(0, 3))]),
              child: ClipRRect(borderRadius: BorderRadius.circular(10),
                child: factoryLogoUrl != null && factoryLogoUrl!.isNotEmpty
                  ? Image.network(factoryLogoUrl!, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(color: statusColor.withOpacity(0.12), child: const Icon(Icons.factory_rounded, color: Colors.white, size: 20)))
                  : Container(color: statusColor.withOpacity(0.12), child: Icon(Icons.factory_rounded, color: statusColor, size: 20))),
            ),
            const SizedBox(width: 10),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(factoryName, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: AppColors.darkText), overflow: TextOverflow.ellipsis),
              Text('Order: ${orderId.substring(0, 8)}…', style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
            ])),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(color: statusColor.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: statusColor.withOpacity(0.25))),
              child: Row(children: [
                Icon(_statusIcon, size: 10, color: statusColor),
                const SizedBox(width: 4),
                Text(status.toUpperCase(), style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: statusColor)),
              ]),
            ),
            const SizedBox(width: 6),
            GestureDetector(onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close_rounded, size: 18, color: AppColors.secondaryText)),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _sec('Order Information', Icons.receipt_long_rounded, [
              _row('Order ID', '${orderId.substring(0, 12)}…'),
              _row('Crop Type', cropType),
              _rowBadge('Total Qty', '$totalQuantity $unit', _cropColor),
              if (cropType == 'Both' || cropType == 'Tea')      _row('Tea Qty',      '$teaQuantity $unit'),
              if (cropType == 'Both' || cropType == 'Cinnamon') _row('Cinnamon Qty', '$cinnamonQuantity $unit'),
              if (orderDate != null) _row('Order Date', DateFormat('dd MMM yyyy  HH:mm').format(orderDate!.toDate())),
              if (description.isNotEmpty) ...[
                const SizedBox(height: 4),
                Text('Description', style: const TextStyle(fontSize: 10, color: AppColors.secondaryText)),
                const SizedBox(height: 3),
                Text(description, style: const TextStyle(fontSize: 11.5, color: AppColors.darkText, height: 1.45)),
              ],
            ]),
            const SizedBox(height: 12),
            _sec('Factory Information', Icons.factory_rounded, [
              _row('Factory',  factoryName),
              _row('Owner',    ownerName),
              _row('Contact',  contactNumber),
              _row('Address',  address),
              _row('Village',  village),
              _row('District', district),
            ]),
            if (orderPhotos.isNotEmpty) ...[
              const SizedBox(height: 12),
              _sec('Order Photos', Icons.photo_library_rounded, [
                const SizedBox(height: 6),
                _photoGrid(orderPhotos),
              ]),
            ],
            if (createdAt != null || updatedAt != null) ...[
              const SizedBox(height: 12),
              _sec('Timestamps', Icons.access_time_rounded, [
                if (createdAt != null) _row('Created',  DateFormat('dd MMM yyyy  HH:mm').format(createdAt!.toDate())),
                if (updatedAt != null) _row('Updated',  DateFormat('dd MMM yyyy  HH:mm').format(updatedAt!.toDate())),
              ]),
            ],
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: OutlinedButton.icon(
                onPressed: () => makePhoneCall(contactNumber),
                icon: Icon(Icons.phone_rounded, size: 13, color: statusColor),
                label: Text('Call Factory', style: TextStyle(fontSize: 11, color: statusColor, fontWeight: FontWeight.w600)),
                style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 11),
                  side: BorderSide(color: statusColor), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              )),
              const SizedBox(width: 10),
              Expanded(child: ElevatedButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.close_rounded, size: 13, color: Colors.white),
                label: const Text('Close', style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(backgroundColor: statusColor, elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 11),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
              )),
            ]),
            const SizedBox(height: 16),
          ]),
        )),
      ]),
    );
  }

  Widget _sec(String title, IconData icon, List<Widget> ch) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Container(width: 26, height: 26,
          decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
          child: Icon(icon, size: 12, color: AppColors.primaryBlue)),
        const SizedBox(width: 7),
        Text(title, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkText)),
      ]),
      const SizedBox(height: 6),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(color: AppColors.hover, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
        child: Column(children: ch),
      ),
    ],
  );

  Widget _row(String label, String value) => Container(
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5))),
    child: Row(children: [
      SizedBox(width: 85, child: Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.secondaryText))),
      const SizedBox(width: 8),
      Expanded(child: Text(value, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.darkText))),
    ]),
  );

  Widget _rowBadge(String label, String value, Color color) => Container(
    padding: const EdgeInsets.symmetric(vertical: 7),
    decoration: const BoxDecoration(border: Border(bottom: BorderSide(color: AppColors.border, width: 0.5))),
    child: Row(children: [
      SizedBox(width: 85, child: Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.secondaryText))),
      const SizedBox(width: 8),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
        decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(5), border: Border.all(color: color.withOpacity(0.25))),
        child: Text(value, style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: color)),
      ),
    ]),
  );

  Widget _photoGrid(List<String> p) => GridView.builder(
    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
    itemCount: p.length,
    itemBuilder: (_, i) => ClipRRect(borderRadius: BorderRadius.circular(7),
      child: Image.network(p[i], fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => Container(color: AppColors.hover,
          child: const Icon(Icons.broken_image_outlined, size: 18, color: AppColors.textTertiary)))));
}


// ── Land Size Details Modal ───────────────────────────────────
class LandSizeDetailsModal extends StatelessWidget {
  final String? cropType, landSize, landSizeUnit, teaLandSize, cinnamonLandSize, landSizeDetails;
  final List<String> landPhotos;

  const LandSizeDetailsModal({
    super.key, required this.cropType, required this.landSize, required this.landSizeUnit,
    required this.teaLandSize, required this.cinnamonLandSize, required this.landSizeDetails,
    required this.landPhotos,
  });

  Color get _cc {
    switch (cropType) {
      case 'Tea'      : return AppColors.successGreen;
      case 'Cinnamon' : return AppColors.warningOrange;
      case 'Both'     : return AppColors.purpleAccent;
      default         : return AppColors.primaryBlue;
    }
  }
  IconData get _ci {
    switch (cropType) {
      case 'Tea'      : return Icons.eco_rounded;
      case 'Cinnamon' : return Icons.forest_rounded;
      case 'Both'     : return Icons.layers_rounded;
      default         : return Icons.landscape_rounded;
    }
  }

  @override
  Widget build(BuildContext context) {
    final c   = _cc;
    final u   = landSizeUnit ?? 'Ac';
    final tea = double.tryParse(teaLandSize ?? '0') ?? 0;
    final cin = double.tryParse(cinnamonLandSize ?? '0') ?? 0;
    final tot = cropType == 'Both' ? tea + cin : double.tryParse(landSize ?? '0') ?? 0;

    return Container(
      height: MediaQuery.of(context).size.height * 0.82,
      decoration: const BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Column(children: [
        Container(margin: const EdgeInsets.only(top: 10), width: 36, height: 3,
          decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2))),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
          child: Row(children: [
            Container(width: 42, height: 42,
              decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(10)),
              child: Icon(_ci, color: Colors.white, size: 22)),
            const SizedBox(width: 12),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Land Size Details', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: AppColors.darkText)),
              Text('${cropType ?? 'Unknown'} Land', style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
            ])),
            GestureDetector(onTap: () => Navigator.pop(context),
              child: const Icon(Icons.close_rounded, size: 18, color: AppColors.secondaryText)),
          ]),
        ),
        const Divider(height: 1, color: AppColors.border),

        Expanded(child: SingleChildScrollView(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // big area card
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: c.withOpacity(0.07),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: c.withOpacity(0.2)),
              ),
              child: Row(children: [
                Icon(_ci, size: 28, color: c),
                const SizedBox(width: 14),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${tot.toStringAsFixed(1)} $u', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.darkText, height: 1.1)),
                  Text(cropType ?? 'Land', style: TextStyle(fontSize: 11, color: c, fontWeight: FontWeight.w600)),
                ]),
              ]),
            ),
            const SizedBox(height: 12),

            // breakdown
            if (cropType == 'Both' && (tea > 0 || cin > 0)) ...[
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: AppColors.hover, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    Container(width: 3, height: 12, decoration: BoxDecoration(color: AppColors.primaryBlue, borderRadius: BorderRadius.circular(2))),
                    const SizedBox(width: 6),
                    const Text('Crop Breakdown', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.darkText)),
                  ]),
                  const SizedBox(height: 10),
                  if (tea > 0)  _bar('Tea',      tea,  tot, AppColors.successGreen, u),
                  if (cin > 0)  _bar('Cinnamon', cin,  tot, AppColors.warningOrange, u),
                  const Divider(height: 12, color: AppColors.border),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
                    const Text('Total', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.darkText)),
                    Text('${tot.toStringAsFixed(1)} $u', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.primaryBlue)),
                  ]),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            if (landSizeDetails != null && landSizeDetails!.isNotEmpty) ...[
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(color: AppColors.hover, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
                child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Icon(Icons.notes_rounded, size: 13, color: AppColors.secondaryText),
                  const SizedBox(width: 7),
                  Expanded(child: Text(landSizeDetails!, style: const TextStyle(fontSize: 11.5, color: AppColors.darkText, height: 1.5))),
                ]),
              ),
              const SizedBox(height: 12),
            ],

            if (landPhotos.isNotEmpty) ...[
              Row(children: [
                Container(width: 26, height: 26,
                  decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
                  child: const Icon(Icons.photo_camera_rounded, size: 13, color: AppColors.primaryBlue)),
                const SizedBox(width: 7),
                Text('Land Photos (${landPhotos.length})', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.darkText)),
              ]),
              const SizedBox(height: 7),
              GridView.builder(
                shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 3, crossAxisSpacing: 6, mainAxisSpacing: 6),
                itemCount: landPhotos.length,
                itemBuilder: (_, i) => ClipRRect(borderRadius: BorderRadius.circular(8),
                  child: Image.network(landPhotos[i], fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: AppColors.hover,
                      child: const Icon(Icons.broken_image_outlined, size: 18, color: AppColors.textTertiary))))),
            ],

            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.05), borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.primaryBlue.withOpacity(0.15))),
              child: Row(children: [
                const Icon(Icons.info_outline_rounded, size: 13, color: AppColors.primaryBlue),
                const SizedBox(width: 8),
                Expanded(child: Text('All sizes measured in $u (${_unitFull(u)})',
                  style: const TextStyle(fontSize: 11, color: AppColors.darkText))),
              ]),
            ),
            const SizedBox(height: 16),
          ]),
        )),
      ]),
    );
  }

  String _unitFull(String u) {
    switch (u.toLowerCase()) {
      case 'ac': case 'acre': return 'Acres';
      case 'ha': return 'Hectares';
      case 'perch': return 'Perches';
      default: return u;
    }
  }

  Widget _bar(String label, double val, double total, Color color, String u) {
    final pct = total > 0 ? val / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text(label, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: color)),
          Text('${val.toStringAsFixed(1)} $u  (${(pct * 100).toStringAsFixed(0)}%)',
            style: const TextStyle(fontSize: 10.5, color: AppColors.secondaryText)),
        ]),
        const SizedBox(height: 4),
        ClipRRect(borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(value: pct, minHeight: 5,
            backgroundColor: color.withOpacity(0.15), valueColor: AlwaysStoppedAnimation(color))),
      ]),
    );
  }
}