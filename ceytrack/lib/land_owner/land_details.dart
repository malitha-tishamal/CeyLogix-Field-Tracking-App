// land_details.dart — MODERN BLUE THEME + UNIQUE EXTENSION (fixed)
// No manual refresh; data updates automatically after save.
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'land_owner_drawer.dart';
import 'landowner_dashbord.dart';
import 'user_profile.dart';
import 'land_location.dart';
import 'developer_info.dart';
import '../Auth/login_page.dart';

// ==================== BLUE THEME TOKENS ====================
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

class _D {
  static const double cardRadius = 10.0;
  static const double cardPad    = 10.0;
  static const double sectionGap = 14.0;
  static const double chipRadius = 6.0;
  static const double iconBox    = 28.0;
  static const double iconSize   = 14.0;
}

// ==================== UNIQUE RESPONSIVE EXTENSION (no conflicts) ====================
extension LandDetailsResponsiveExtensions on BuildContext {
  double get ldPaddingSmall => MediaQuery.of(this).size.width < 600 ? 12.0 : 16.0;
  double get ldPaddingMedium => MediaQuery.of(this).size.width < 600 ? 16.0 : 20.0;
  double get ldPaddingLarge => MediaQuery.of(this).size.width < 600 ? 20.0 : 24.0;
  bool get ldIsSmallScreen => MediaQuery.of(this).size.width < 600;
  bool get ldIsMediumScreen => MediaQuery.of(this).size.width >= 600 && MediaQuery.of(this).size.width < 900;
  bool get ldIsLargeScreen => MediaQuery.of(this).size.width >= 900;
  int get ldPhotoGridColumns {
    final width = MediaQuery.of(this).size.width;
    if (width < 400) return 2;
    if (width < 600) return 3;
    if (width < 900) return 4;
    return 5;
  }
}

// ==================== MAIN PAGE ====================
class LandDetails extends StatefulWidget {
  const LandDetails({super.key});

  @override
  State<LandDetails> createState() => _LandDetailsState();
}

class _LandDetailsState extends State<LandDetails> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _loggedInUserName = 'Loading...';
  String _landName = 'Loading...';
  String _userRole = 'Land Owner';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchHeaderData();
  }

  void _fetchHeaderData() async {
    final user = currentUser;
    if (user == null) return;
    final String uid = user.uid;
    try {
      final userDoc = await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (userDoc.exists) {
        final userData = userDoc.data();
        setState(() {
          _loggedInUserName = userData?['name'] ?? 'Owner';
          _profileImageUrl = userData?['profileImageUrl'];
          _userRole = userData?['role'] ?? 'Land Owner';
        });
      }
      final landDoc = await FirebaseFirestore.instance.collection('lands').doc(uid).get();
      if (landDoc.exists) {
        setState(() {
          _landName = landDoc.data()?['landName'] ?? 'Land';
        });
      } else {
        setState(() {
          _landName = user.email?.split('@')[0] ?? 'User Account';
        });
      }
    } catch (e) {
      debugPrint("Error fetching header data: $e");
      setState(() {
        _loggedInUserName = 'Data Error';
        _landName = 'Error';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("User not logged in.")));
    }

    void handleDrawerNavigate(String route) {
      Navigator.of(context).pop();
      switch (route) {
        case 'dashboard':
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LandOwnerDashboard()));
          break;
        case 'land_details': break;
        case 'profile':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const UserDetails()));
          break;
        case 'location':
          Navigator.push(context, MaterialPageRoute(builder: (_) => LocationSelectionPage(
            onLocationSelected: (locationData) => print('Selected Location: $locationData'),
          )));
          break;
        case 'developer_info':
          Navigator.push(context, MaterialPageRoute(builder: (_) => const DeveloperInfoPage()));
          break;
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: LandOwnerDrawer(
        onNavigate: handleDrawerNavigate,
        onLogout: () {
          Navigator.of(context).pushAndRemoveUntil(
            MaterialPageRoute(builder: (_) => const LoginPage()),
            (route) => false,
          );
        },
      ),
      body: Column(
        children: [
          _buildModernHeader(context),
          Expanded(
            child: LandOwnerProfileContent(
              key: ValueKey(currentUser!.uid),
              landOwnerUID: currentUser!.uid,
              onProfileUpdated: _fetchHeaderData,
              onDataUpdated: _showSuccessAndRefresh,
            ),
          ),
          _buildFooter(),
        ],
      ),
    );
  }

  void _showSuccessAndRefresh() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Land details updated successfully!'),
        duration: const Duration(seconds: 3),
        backgroundColor: AppColors.successGreen,
      ),
    );
    _fetchHeaderData();
  }

  // ==================== MODERN HEADER ====================
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
                  Text(_loggedInUserName,
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
          Text('Manage Land Information',
            style: const TextStyle(
              fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.headerTextDark)),
        ],
      ),
    );
  }

  Widget _buildAvatar() {
    if (_profileImageUrl != null && _profileImageUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: 40,
        backgroundImage: NetworkImage(_profileImageUrl!),
        backgroundColor: Colors.grey.shade200,
        onBackgroundImageError: (_, __) => setState(() => _profileImageUrl = null),
      );
    }
    return CircleAvatar(
      radius: 40,
      backgroundColor: AppColors.primaryBlue.withOpacity(0.15),
      child: const Icon(Icons.person, color: AppColors.primaryBlue, size: 40),
    );
  }

  Widget _buildFooter() => Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: const BoxDecoration(border: Border(top: BorderSide(color: AppColors.border))),
    child: const Text('Developed By Malitha Tishamal',
      textAlign: TextAlign.center,
      style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
  );
}

// ==================== LAND DETAILS FORM (NO MANUAL REFRESH BUTTON) ====================
class LandOwnerProfileContent extends StatefulWidget {
  final String landOwnerUID;
  final VoidCallback? onProfileUpdated;
  final VoidCallback? onDataUpdated;

  const LandOwnerProfileContent({
    required this.landOwnerUID,
    this.onProfileUpdated,
    this.onDataUpdated,
    super.key,
  });

  @override
  State<LandOwnerProfileContent> createState() => _LandOwnerProfileContentState();
}

class _LandOwnerProfileContentState extends State<LandOwnerProfileContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  final String _cloudName = "dqeptzlsb";
  final String _uploadPreset = "flutter_ceytrack_upload";

  late TextEditingController _landNameController;
  late TextEditingController _addressController;
  late TextEditingController _landSizeController;
  late TextEditingController _agDivisionController;
  late TextEditingController _gnDivisionController;
  late TextEditingController _villageController;

  List<XFile> _selectedLandPhotos = [];
  List<String> _uploadedLandPhotoUrls = [];
  bool _uploadingPhotos = false;
  int _maxPhotos = 5;

  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedCropType;
  List<String> _selectedFactoryIds = [];
  List<Map<String, dynamic>> _availableFactories = [];

  bool _isSaving = false;
  String? _statusMessage;
  bool _isLoading = true;
  Map<String, dynamic>? _loadedData;

  late TextEditingController _teaLandSizeController;
  late TextEditingController _cinnamonLandSizeController;

  static final Map<String, List<String>> _geoData = _getGeoData();

  @override
  void initState() {
    super.initState();
    _landNameController = TextEditingController();
    _addressController = TextEditingController();
    _landSizeController = TextEditingController();
    _teaLandSizeController = TextEditingController();
    _cinnamonLandSizeController = TextEditingController();
    _agDivisionController = TextEditingController();
    _gnDivisionController = TextEditingController();
    _villageController = TextEditingController();
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() => _isLoading = true);
    try {
      final factoriesSnapshot = await _firestore.collection('factories').get();
      final landDoc = await _firestore.collection('lands').doc(widget.landOwnerUID).get();
      if (mounted) {
        _availableFactories = factoriesSnapshot.docs.map((doc) {
          final factoryData = doc.data();
          return {
            'id': doc.id,
            'factoryName': factoryData['factoryName'] ?? 'Unknown Factory',
          };
        }).toList();

        final landData = landDoc.data();
        if (landData != null) {
          _loadedData = landData;
          _populateFormData(landData);
          if (landData['landPhotos'] != null && landData['landPhotos'] is List) {
            _uploadedLandPhotoUrls = List<String>.from(landData['landPhotos']);
          }
        }
        setState(() => _isLoading = false);
      }
    } catch (e) {
      if (mounted) setState(() { _isLoading = false; _statusMessage = "Error loading data: $e"; });
    }
  }

  void _populateFormData(Map<String, dynamic> data) {
    _landNameController.text = data['landName'] ?? '';
    _addressController.text = data['address'] ?? '';
    _villageController.text = data['village'] ?? '';
    _agDivisionController.text = data['agDivision'] ?? '';
    _gnDivisionController.text = data['gnDivision'] ?? '';
    _selectedProvince = data['province'];
    _selectedDistrict = data['district'];
    _selectedCropType = data['cropType'];
    _selectedFactoryIds = List<String>.from(data['factoryIds'] ?? []);

    if (_selectedCropType == 'Tea') {
      _landSizeController.text = data['landSize']?.toString() ?? data['teaLandSize']?.toString() ?? '';
    } else if (_selectedCropType == 'Cinnamon') {
      _landSizeController.text = data['landSize']?.toString() ?? data['cinnamonLandSize']?.toString() ?? '';
    } else if (_selectedCropType == 'Both') {
      _teaLandSizeController.text = data['teaLandSize']?.toString() ?? '';
      _cinnamonLandSizeController.text = data['cinnamonLandSize']?.toString() ?? '';
    }

    if (_selectedProvince != null && !_geoData.containsKey(_selectedProvince)) _selectedProvince = null;
    if (_selectedDistrict != null && !(_geoData[_selectedProvince] ?? []).contains(_selectedDistrict)) _selectedDistrict = null;
  }

  @override
  void dispose() {
    _landNameController.dispose();
    _addressController.dispose();
    _landSizeController.dispose();
    _teaLandSizeController.dispose();
    _cinnamonLandSizeController.dispose();
    _agDivisionController.dispose();
    _gnDivisionController.dispose();
    _villageController.dispose();
    super.dispose();
  }

  // ==================== PHOTO HANDLING ====================
  Future<void> _pickLandPhotos() async {
    if (_selectedLandPhotos.length >= _maxPhotos) {
      _showStatusMessage('Maximum $_maxPhotos photos allowed');
      return;
    }
    final List<XFile>? pickedFiles = await _imagePicker.pickMultiImage(maxWidth: 1200, maxHeight: 1200, imageQuality: 85);
    if (pickedFiles != null) {
      int slotsLeft = _maxPhotos - _selectedLandPhotos.length;
      int toAdd = pickedFiles.length > slotsLeft ? slotsLeft : pickedFiles.length;
      for (int i = 0; i < toAdd; i++) {
        final file = File(pickedFiles[i].path);
        if (await file.exists()) {
          final sizeMB = (await file.stat()).size / (1024 * 1024);
          if (sizeMB > 10) {
            _showStatusMessage('${pickedFiles[i].name} is too large (${sizeMB.toStringAsFixed(1)} MB). Max 10MB.');
            continue;
          }
          _selectedLandPhotos.add(pickedFiles[i]);
        }
      }
      setState(() {});
      _showStatusMessage('Added $toAdd photo(s). Total: ${_selectedLandPhotos.length}/$_maxPhotos');
    }
  }

  void _removeSelectedPhoto(int index) => setState(() => _selectedLandPhotos.removeAt(index));

  Future<void> _removeUploadedPhoto(int index) async {
    try {
      setState(() => _uploadingPhotos = true);
      final urlToRemove = _uploadedLandPhotoUrls[index];
      await _firestore.collection('lands').doc(widget.landOwnerUID).update({
        'landPhotos': FieldValue.arrayRemove([urlToRemove]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      setState(() => _uploadedLandPhotoUrls.removeAt(index));
      _showStatusMessage('Photo removed successfully');
    } catch (e) {
      _showStatusMessage('Error removing photo: ${e.toString()}');
    } finally {
      setState(() => _uploadingPhotos = false);
    }
  }

  Future<List<String>> _uploadLandPhotosToCloudinary() async {
    List<String> uploadedUrls = [];
    for (int i = 0; i < _selectedLandPhotos.length; i++) {
      final photo = _selectedLandPhotos[i];
      try {
        final bytes = await photo.readAsBytes();
        final url = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
        final request = http.MultipartRequest('POST', url)
          ..fields['upload_preset'] = _uploadPreset
          ..files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'land_${widget.landOwnerUID}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          ));
        final streamedResponse = await request.send().timeout(const Duration(seconds: 45));
        final response = await http.Response.fromStream(streamedResponse);
        if (response.statusCode == 200) {
          uploadedUrls.add(json.decode(response.body)['secure_url']);
        } else {
          _showStatusMessage('Failed to upload photo ${i+1}.');
        }
      } catch (e) {
        _showStatusMessage('Error uploading photo ${i+1}.');
      }
    }
    return uploadedUrls;
  }

  // ==================== SAVE LOGIC ====================
  Future<void> _updateLandData() async {
    if (!_formKey.currentState!.validate()) {
      _showStatusMessage("Please correct the errors in the form.");
      return;
    }
    if (_selectedProvince == null || _selectedDistrict == null || _selectedCropType == null) {
      _showStatusMessage("Please ensure all required fields are filled.");
      return;
    }
    setState(() { _isSaving = true; _statusMessage = null; });

    try {
      List<String> newPhotoUrls = [];
      if (_selectedLandPhotos.isNotEmpty) {
        setState(() => _uploadingPhotos = true);
        newPhotoUrls = await _uploadLandPhotosToCloudinary();
        setState(() => _uploadingPhotos = false);
      }

      final landDataToUpdate = {
        'landName': _landNameController.text.trim(),
        'address': _addressController.text.trim(),
        'village': _villageController.text.trim(),
        'cropType': _selectedCropType,
        'country': 'Sri Lanka',
        'province': _selectedProvince,
        'district': _selectedDistrict,
        'agDivision': _agDivisionController.text.trim(),
        'gnDivision': _gnDivisionController.text.trim(),
        'factoryIds': _selectedFactoryIds,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      if (_selectedCropType == 'Tea') {
        double teaSize = double.tryParse(_landSizeController.text.trim()) ?? 0.0;
        if (teaSize <= 0) throw Exception('Tea land size must be greater than 0');
        landDataToUpdate['landSize'] = teaSize.toString();
        landDataToUpdate['landSizeUnit'] = 'Acre';
        landDataToUpdate['teaLandSize'] = teaSize.toString();
      } else if (_selectedCropType == 'Cinnamon') {
        double cinnamonSize = double.tryParse(_landSizeController.text.trim()) ?? 0.0;
        if (cinnamonSize <= 0) throw Exception('Cinnamon land size must be greater than 0');
        landDataToUpdate['landSize'] = cinnamonSize.toString();
        landDataToUpdate['landSizeUnit'] = 'Acre';
        landDataToUpdate['cinnamonLandSize'] = cinnamonSize.toString();
      } else if (_selectedCropType == 'Both') {
        double teaSize = double.tryParse(_teaLandSizeController.text.trim()) ?? 0.0;
        double cinnamonSize = double.tryParse(_cinnamonLandSizeController.text.trim()) ?? 0.0;
        if (teaSize <= 0 && cinnamonSize <= 0) throw Exception('At least one land size must be greater than 0');
        double totalLandSize = teaSize + cinnamonSize;
        String landSizeDetails = '';
        if (teaSize > 0 && cinnamonSize > 0) landSizeDetails = 'Tea: ${teaSize}Ac, Cinnamon: ${cinnamonSize}Ac (Total: ${totalLandSize}Ac)';
        else if (teaSize > 0) landSizeDetails = 'Tea: ${teaSize}Ac';
        else landSizeDetails = 'Cinnamon: ${cinnamonSize}Ac';
        if (teaSize > 0) landDataToUpdate['teaLandSize'] = teaSize.toString();
        if (cinnamonSize > 0) landDataToUpdate['cinnamonLandSize'] = cinnamonSize.toString();
        landDataToUpdate['landSize'] = totalLandSize.toString();
        landDataToUpdate['landSizeUnit'] = 'Acre';
        landDataToUpdate['landSizeDetails'] = landSizeDetails;
      }

      if (newPhotoUrls.isNotEmpty) {
        landDataToUpdate['landPhotos'] = FieldValue.arrayUnion(newPhotoUrls);
      }

      await _firestore.collection('lands').doc(widget.landOwnerUID).set(landDataToUpdate, SetOptions(merge: true));

      if (newPhotoUrls.isNotEmpty) {
        setState(() {
          _uploadedLandPhotoUrls.addAll(newPhotoUrls);
          _selectedLandPhotos.clear();
        });
      }

      _showStatusMessage("Land details updated successfully!");
      widget.onProfileUpdated?.call();
      widget.onDataUpdated?.call();
      await _refreshDataAutomatically();
    } catch (e) {
      _showStatusMessage("Error updating land details: $e");
    } finally {
      setState(() => _isSaving = false);
    }
  }

  Future<void> _refreshDataAutomatically() async {
    await Future.delayed(const Duration(milliseconds: 500));
    await _loadInitialData();
    if (mounted) setState(() => _statusMessage = "Data refreshed successfully!");
  }

  void _showStatusMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: message.toLowerCase().contains('success') ? AppColors.successGreen : Colors.red,
      ),
    );
    setState(() => _statusMessage = message);
  }

  // ==================== UI BUILD (NO REFRESH BUTTON) ====================
  @override
  Widget build(BuildContext context) {
    final isSmall = context.ldIsSmallScreen;
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryBlue),
            SizedBox(height: 16),
            Text('Loading land details...'),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: EdgeInsets.symmetric(horizontal: isSmall ? 16 : 20, vertical: isSmall ? 12 : 16),
      child: Center(
        child: ConstrainedBox(
          constraints: BoxConstraints(maxWidth: context.ldIsMediumScreen ? 700 : 900),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_statusMessage != null) _buildInfoCard(_statusMessage!),
                const SizedBox(height: _D.sectionGap),
                _buildPhotosCard(),
                const SizedBox(height: _D.sectionGap),
                _buildBasicInfoCard(),
                const SizedBox(height: _D.sectionGap),
                _buildLocationCard(),
                const SizedBox(height: _D.sectionGap),
                _buildFactoryCard(),
                const SizedBox(height: 30),
                _buildSaveButton(),
                const SizedBox(height: 50),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ==================== MODERN CARD WIDGETS ====================
  Widget _buildInfoCard(String message) {
    final isError = !message.toLowerCase().contains('success');
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(_D.cardPad),
      margin: const EdgeInsets.only(bottom: _D.sectionGap),
      decoration: BoxDecoration(
        color: (isError ? AppColors.accentRed : AppColors.successGreen).withOpacity(0.1),
        borderRadius: BorderRadius.circular(_D.cardRadius),
        border: Border.all(color: (isError ? AppColors.accentRed : AppColors.successGreen).withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Icon(isError ? Icons.error_outline : Icons.check_circle, size: 18, color: isError ? AppColors.accentRed : AppColors.successGreen),
          const SizedBox(width: 8),
          Expanded(child: Text(message, style: TextStyle(fontSize: 12, color: isError ? AppColors.accentRed : AppColors.successGreen))),
        ],
      ),
    );
  }

  BoxDecoration _cardDecoration() => BoxDecoration(
    color: AppColors.cardBackground,
    borderRadius: BorderRadius.circular(_D.cardRadius),
    border: Border.all(color: AppColors.border),
    boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2))],
  );

  Widget _buildPhotosCard() => Container(
    padding: const EdgeInsets.all(_D.cardPad),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Land Photos', Icons.photo_camera_rounded),
        const SizedBox(height: 8),
        if (_uploadedLandPhotoUrls.isNotEmpty) ...[
          const Text('Current Photos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: context.ldPhotoGridColumns,
              crossAxisSpacing: 6, mainAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: _uploadedLandPhotoUrls.length,
            itemBuilder: (_, index) => Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.network(_uploadedLandPhotoUrls[index], fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(color: AppColors.hover, child: const Icon(Icons.broken_image, color: AppColors.textTertiary))),
                ),
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: () => _removeUploadedPhoto(index),
                    child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: AppColors.accentRed, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 12, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        if (_selectedLandPhotos.isNotEmpty) ...[
          const Text('New Photos', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
          const SizedBox(height: 6),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: context.ldPhotoGridColumns,
              crossAxisSpacing: 6, mainAxisSpacing: 6,
              childAspectRatio: 1,
            ),
            itemCount: _selectedLandPhotos.length,
            itemBuilder: (_, index) => Stack(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: Image.file(File(_selectedLandPhotos[index].path), fit: BoxFit.cover),
                ),
                Positioned(
                  top: 4, right: 4,
                  child: GestureDetector(
                    onTap: () => _removeSelectedPhoto(index),
                    child: Container(padding: const EdgeInsets.all(3), decoration: const BoxDecoration(color: AppColors.accentRed, shape: BoxShape.circle),
                      child: const Icon(Icons.close, size: 12, color: Colors.white)),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
        ],
        GestureDetector(
          onTap: _selectedLandPhotos.length >= _maxPhotos ? null : _pickLandPhotos,
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: AppColors.hover,
              borderRadius: BorderRadius.circular(_D.cardRadius),
              border: Border.all(color: AppColors.border),
            ),
            child: Column(
              children: [
                Icon(Icons.add_photo_alternate_rounded, size: 32, color: _selectedLandPhotos.length >= _maxPhotos ? AppColors.textTertiary : AppColors.primaryBlue),
                const SizedBox(height: 4),
                Text(_selectedLandPhotos.length >= _maxPhotos ? 'Maximum $_maxPhotos photos reached' : 'Add Photos (${_selectedLandPhotos.length}/$_maxPhotos)',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: _selectedLandPhotos.length >= _maxPhotos ? AppColors.textTertiary : AppColors.primaryBlue)),
              ],
            ),
          ),
        ),
      ],
    ),
  );

  Widget _buildBasicInfoCard() => Container(
    padding: const EdgeInsets.all(_D.cardPad),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Basic Information', Icons.info_outline_rounded),
        const SizedBox(height: 8),
        _buildTextFieldRow('Land Name', _landNameController, 'e.g., Green Valley'),
        const SizedBox(height: 12),
        _buildTextFieldRow('Village', _villageController, 'e.g., Peradeniya'),
        const SizedBox(height: 12),
        _buildTextFieldRow('Address', _addressController, 'e.g., Kandy Road'),
        const SizedBox(height: 12),
        _buildDropdownRow('Crop Type', _selectedCropType, ['Tea', 'Cinnamon', 'Both'], (val) => setState(() {
          _selectedCropType = val;
          if (val != 'Both') { _teaLandSizeController.clear(); _cinnamonLandSizeController.clear(); } else { _landSizeController.clear(); }
        })),
        const SizedBox(height: 12),
        if (_selectedCropType == 'Tea')
          _buildLandSizeField('Tea Land Size', _landSizeController, AppColors.successGreen)
        else if (_selectedCropType == 'Cinnamon')
          _buildLandSizeField('Cinnamon Land Size', _landSizeController, AppColors.warningOrange)
        else if (_selectedCropType == 'Both')
          Column(children: [
            _buildLandSizeField('Tea Land Size', _teaLandSizeController, AppColors.successGreen),
            const SizedBox(height: 12),
            _buildLandSizeField('Cinnamon Land Size', _cinnamonLandSizeController, AppColors.warningOrange),
            if (_teaLandSizeController.text.isEmpty && _cinnamonLandSizeController.text.isEmpty)
              Padding(padding: const EdgeInsets.only(top: 8), child: Text('At least one land size required', style: TextStyle(fontSize: 11, color: AppColors.accentRed))),
          ]),
      ],
    ),
  );

  Widget _buildLocationCard() => Container(
    padding: const EdgeInsets.all(_D.cardPad),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Location', Icons.location_on_rounded),
        const SizedBox(height: 8),
        _buildDropdownRow('Province', _selectedProvince, _geoData.keys.toList(), (val) => setState(() {
          _selectedProvince = val;
          _selectedDistrict = null;
        })),
        const SizedBox(height: 12),
        if (_selectedProvince != null)
          _buildDropdownRow('District', _selectedDistrict, _geoData[_selectedProvince] ?? [], (val) => setState(() => _selectedDistrict = val)),
        const SizedBox(height: 12),
        _buildTextFieldRow('A/G Division', _agDivisionController, 'e.g., Kandy Divisional Secretariat'),
        const SizedBox(height: 12),
        _buildTextFieldRow('G/N Division', _gnDivisionController, 'e.g., Kandy Town'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(color: AppColors.hover, borderRadius: BorderRadius.circular(8), border: Border.all(color: AppColors.border)),
          child: Row(children: [
            const Icon(Icons.public_rounded, size: 14, color: AppColors.secondaryText),
            const SizedBox(width: 8),
            const Text('Country', style: TextStyle(fontSize: 11, color: AppColors.secondaryText)),
            const Spacer(),
            Text('Sri Lanka', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: AppColors.darkText)),
          ]),
        ),
      ],
    ),
  );

  Widget _buildFactoryCard() => Container(
    padding: const EdgeInsets.all(_D.cardPad),
    decoration: _cardDecoration(),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionLabel('Associated Factories', Icons.factory_rounded),
        const SizedBox(height: 8),
        if (_availableFactories.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            alignment: Alignment.center,
            child: Column(children: [
              Icon(Icons.factory_outlined, size: 40, color: AppColors.textTertiary),
              const SizedBox(height: 6),
              Text('No factories available', style: TextStyle(fontSize: 12, color: AppColors.secondaryText)),
            ]),
          )
        else ...[
          Wrap(spacing: 8, runSpacing: 8,
            children: _availableFactories.map((f) {
              final selected = _selectedFactoryIds.contains(f['id']);
              return FilterChip(
                label: Text(f['factoryName'], style: TextStyle(fontSize: 12, color: selected ? Colors.white : AppColors.darkText)),
                selected: selected,
                onSelected: (_) => setState(() {
                  if (selected) _selectedFactoryIds.remove(f['id']);
                  else _selectedFactoryIds.add(f['id']);
                }),
                backgroundColor: AppColors.hover,
                selectedColor: AppColors.primaryBlue,
                checkmarkColor: Colors.white,
                shape: StadiumBorder(side: BorderSide(color: selected ? AppColors.primaryBlue : AppColors.border)),
              );
            }).toList(),
          ),
          const SizedBox(height: 12),
          if (_selectedFactoryIds.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(color: AppColors.hover, borderRadius: BorderRadius.circular(8)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Selected (${_selectedFactoryIds.length})', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
                  const SizedBox(height: 4),
                  Wrap(spacing: 4, children: _selectedFactoryIds.map((id) {
                    final name = _availableFactories.firstWhere((f) => f['id'] == id, orElse: () => {'factoryName': 'Unknown'})['factoryName'];
                    return Chip(label: Text(name, style: const TextStyle(fontSize: 10)), backgroundColor: AppColors.primaryBlue.withOpacity(0.1), deleteIcon: const Icon(Icons.close, size: 12), onDeleted: () => setState(() => _selectedFactoryIds.remove(id)));
                  }).toList()),
                ],
              ),
            ),
        ],
      ],
    ),
  );

  Widget _buildSaveButton() => Container(
    width: double.infinity,
    child: ElevatedButton(
      onPressed: (_isSaving || _uploadingPhotos) ? null : _updateLandData,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primaryBlue,
        foregroundColor: Colors.white,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      child: Text(_isSaving ? 'Updating...' : 'Update Land Details',
        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
    ),
  );

  // ==================== HELPER WIDGETS ====================
  Widget _sectionLabel(String title, IconData icon) => Row(
    children: [
      Container(
        width: _D.iconBox, height: _D.iconBox,
        decoration: BoxDecoration(color: AppColors.primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(7)),
        child: Icon(icon, size: _D.iconSize, color: AppColors.primaryBlue),
      ),
      const SizedBox(width: 8),
      Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.darkText)),
    ],
  );

  Widget _buildTextFieldRow(String label, TextEditingController controller, String hint) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
      const SizedBox(height: 4),
      Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: TextFormField(
          controller: controller,
          style: const TextStyle(fontSize: 13),
          decoration: InputDecoration(
            hintText: hint,
            contentPadding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
            border: InputBorder.none,
          ),
          validator: (v) => v == null || v.isEmpty ? 'Required' : null,
        ),
      ),
    ],
  );

  Widget _buildDropdownRow<T>(String label, T? value, List<T> items, void Function(T?) onChanged) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
      const SizedBox(height: 4),
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<T>(
            value: value,
            isExpanded: true,
            hint: Text('Select $label', style: TextStyle(fontSize: 13, color: AppColors.secondaryText)),
            items: items.map((e) => DropdownMenuItem(value: e, child: Text(e.toString(), style: const TextStyle(fontSize: 13)))).toList(),
            onChanged: onChanged,
          ),
        ),
      ),
    ],
  );

  Widget _buildLandSizeField(String label, TextEditingController controller, Color color) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Row(children: [
        Text(label, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.secondaryText)),
        const SizedBox(width: 6),
        Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
          decoration: BoxDecoration(color: color.withOpacity(0.1), borderRadius: BorderRadius.circular(4)),
          child: Text('Acre', style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color))),
      ]),
      const SizedBox(height: 4),
      Container(
        decoration: BoxDecoration(
          color: AppColors.cardBackground,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextFormField(
                controller: controller,
                keyboardType: TextInputType.numberWithOptions(decimal: true),
                style: const TextStyle(fontSize: 13),
                decoration: const InputDecoration(
                  hintText: 'Enter size',
                  contentPadding: EdgeInsets.symmetric(vertical: 12, horizontal: 12),
                  border: InputBorder.none,
                ),
                validator: (v) {
                  if (label.contains('Tea') || label.contains('Cinnamon')) {
                    if (v != null && v.isNotEmpty) {
                      final num = double.tryParse(v);
                      if (num == null) return 'Invalid number';
                      if (num <= 0) return 'Must be > 0';
                    }
                    return null;
                  } else {
                    if (v == null || v.isEmpty) return 'Required';
                    final num = double.tryParse(v);
                    if (num == null) return 'Invalid number';
                    if (num <= 0) return 'Must be > 0';
                    return null;
                  }
                },
              ),
            ),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12),
              child: const Text('Ac', style: TextStyle(fontWeight: FontWeight.w600, color: AppColors.primaryBlue, fontSize: 12))),
          ],
        ),
      ),
    ],
  );
}

Map<String, List<String>> _getGeoData() {
  return {
    'Western Province': ['Colombo District', 'Gampaha District', 'Kalutara District'],
    'Central Province': ['Kandy District', 'Matale District', 'Nuwara Eliya District'],
    'Southern Province': ['Galle District', 'Matara District', 'Hambantota District'],
    'Eastern Province': ['Trincomalee District', 'Batticaloa District', 'Ampara District'],
    'Northern Province': ['Jaffna District', 'Vavuniya District', 'Kilinochchi District', 'Mannar District', 'Mullaitivu District'],
    'North Western Province': ['Kurunegala District', 'Puttalam District'],
    'North Central Province': ['Anuradhapura District', 'Polonnaruwa District'],
    'Uva Province': ['Badulla District', 'Monaragala District'],
    'Sabaragamuwa Province': ['Ratnapura District', 'Kegalle District'],
  };
}