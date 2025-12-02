// factory_details.dart
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'factory_owner_drawer.dart';

class AppColors {
  static const Color background = Color(0xFFEEEBFF);
  static const Color darkText = Color(0xFF2C2A3A);
  static const Color primaryBlue = Color(0xFF2764E7);
  static const Color cardBackground = Colors.white;
  static const Color secondaryColor = Color(0xFF6AD96A);
  static const Color headerGradientStart = Color.fromARGB(255, 134, 164, 236);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
  static const Color accentColor = Color(0xFF4A90E2);
}

class FactoryDetails extends StatefulWidget {
  const FactoryDetails({super.key});

  @override
  State<FactoryDetails> createState() => _FactoryDetailsState();
}

class _FactoryDetailsState extends State<FactoryDetails> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _userName = 'Loading';
  String _userRole = 'Factory Owner';
  String? _profileImageUrl;
  String _factoryName = 'Loading';
  String _factoryLocation = '';
  String? _factoryLogoUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
    _fetchFactoryInfo();
  }

  void _fetchUserInfo() async {
    final user = currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          if (mounted) {
            setState(() {
              _userName = data?['name'] ?? 'Factory Owner';
              _userRole = data?['role'] ?? 'Factory Owner';
              _profileImageUrl = data?['profileImageUrl'];
            });
          }
        }
      } catch (e) {
        print("Error fetching user info: $e");
      }
    }
  }

  void _fetchFactoryInfo() async {
    final user = currentUser;
    if (user != null) {
      try {
        final factoryDoc = await FirebaseFirestore.instance
            .collection('factories')
            .doc(user.uid)
            .get();
        
        if (factoryDoc.exists) {
          final factoryData = factoryDoc.data();
          if (mounted) {
            setState(() {
              _factoryName = factoryData?['factoryName'] ?? 'No Factory Name';
              _factoryLocation = factoryData?['address'] ?? '';
              _factoryLogoUrl = factoryData?['factoryLogoUrl'];
            });
          }
        } else {
          if (mounted) {
            setState(() {
              _factoryName = 'Factory Not Registered';
              _factoryLocation = '';
              _factoryLogoUrl = null;
            });
          }
        }
      } catch (e) {
        print("Error fetching factory info: $e");
        if (mounted) {
          setState(() {
            _factoryName = 'Error Loading';
            _factoryLogoUrl = null;
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Error: User not logged in.")));
    }

    void handleDrawerNavigate(String routeName) {
      Navigator.pop(context);
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: FactoryOwnerDrawer(
        onLogout: () {
          FirebaseAuth.instance.signOut();
          Navigator.pop(context);
        },
        onNavigate: handleDrawerNavigate,
      ),
      body: Stack(
        children: [
          SafeArea(
            child: Column(
              children: [
                _buildProfileHeader(context),
                Expanded(
                  child: FactoryOwnerProfileContent(
                    key: ValueKey(currentUser!.uid),
                    factoryOwnerUID: currentUser!.uid,
                    onProfileUpdated: _fetchUserInfo,
                    onDataUpdated: _showSuccessAndRefresh,
                    factoryLogoUrl: _factoryLogoUrl,
                    onLogoUpdated: (String? newLogoUrl) {
                      setState(() {
                        _factoryLogoUrl = newLogoUrl;
                      });
                    },
                  ),
                ),
              ],
            ),
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Developed By Malitha Tishamal',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.darkText.withOpacity(0.7),
                  fontSize: 12,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showSuccessAndRefresh() {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: const Text('Factory details updated successfully!'),
        duration: const Duration(seconds: 3),
        backgroundColor: AppColors.secondaryColor,
      ),
    );
    
    _fetchUserInfo();
    _fetchFactoryInfo();
  }
  
  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30),
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000),
            blurRadius: 15,
            offset: Offset(0, 5),
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
                icon: const Icon(Icons.menu, color: AppColors.headerTextDark, size: 28),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
            ],
          ),
          
          const SizedBox(height: 10),
          
          Row(
            children: [
              // Factory Logo Display
              Stack(
                children: [
                  Container(
                    width: 70,
                    height: 70,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: _factoryLogoUrl == null 
                        ? const LinearGradient(
                            colors: [AppColors.primaryBlue, Color(0xFF457AED)],
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                          )
                        : null,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primaryBlue.withOpacity(0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 3),
                        ),
                      ],
                      image: _factoryLogoUrl != null 
                        ? DecorationImage(
                            image: NetworkImage(_factoryLogoUrl!),
                            fit: BoxFit.cover,
                          )
                        : null,
                    ),
                    child: _factoryLogoUrl == null
                      ? const Icon(Icons.factory, size: 40, color: Colors.white)
                      : null,
                  ),
                  // Badge indicating factory logo
                  if (_factoryLogoUrl != null)
                    Positioned(
                      top: 0,
                      right: 0,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.secondaryColor,
                        ),
                        child: const Icon(Icons.business, size: 12, color: Colors.white),
                      ),
                    ),
                ],
              ),
              
              const SizedBox(width: 15),
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _factoryName,
                      style: const TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                        color: AppColors.headerTextDark,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      _factoryLocation.isNotEmpty 
                        ? _factoryLocation 
                        : 'Factory Location',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.headerTextDark.withOpacity(0.7),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        Text(
                          'Owner: $_userName',
                          style: TextStyle(
                            fontSize: 12,
                            color: AppColors.headerTextDark.withOpacity(0.6),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          
          const SizedBox(height: 25),
          
          const Text(
            'Manage Factory Details',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.headerTextDark,
            ),
          ),
        ],
      ),
    );
  }
}

class FactoryOwnerProfileContent extends StatefulWidget {
  final String factoryOwnerUID;
  final VoidCallback? onProfileUpdated;
  final VoidCallback? onDataUpdated;
  final String? factoryLogoUrl;
  final Function(String?)? onLogoUpdated;
  
  const FactoryOwnerProfileContent({
    required this.factoryOwnerUID, 
    this.onProfileUpdated,
    this.onDataUpdated,
    this.factoryLogoUrl,
    this.onLogoUpdated,
    super.key,
  });

  @override
  State<FactoryOwnerProfileContent> createState() => _FactoryOwnerProfileContentState();
}

class _FactoryOwnerProfileContentState extends State<FactoryOwnerProfileContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final ImagePicker _imagePicker = ImagePicker();

  final String _cloudName = "dqeptzlsb";
  final String _uploadPreset = "flutter_ceytrack_upload";

  // Text Controllers
  late TextEditingController _factoryNameController;
  late TextEditingController _addressController;
  late TextEditingController _contactNumberController;
  late TextEditingController _agDivisionController;
  late TextEditingController _gnDivisionController;

  // State variables for FACTORY PHOTOS
  List<XFile> _selectedFactoryPhotos = [];
  List<String> _uploadedFactoryPhotoUrls = [];
  bool _uploadingPhotos = false;
  int _maxPhotos = 5;

  // State variables for FACTORY LOGO
  XFile? _selectedLogoFile;
  String? _uploadedLogoUrl;
  bool _uploadingLogo = false;

  // Other state variables
  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedCropType;
  
  bool _isSaving = false;
  String? _statusMessage;
  bool _isLoading = true;
  Map<String, dynamic>? _loadedData;

  static final Map<String, List<String>> _geoData = _getGeoData();

  @override
  void initState() {
    super.initState();
    _factoryNameController = TextEditingController();
    _addressController = TextEditingController();
    _contactNumberController = TextEditingController();
    _agDivisionController = TextEditingController();
    _gnDivisionController = TextEditingController();
    
    _uploadedLogoUrl = widget.factoryLogoUrl;
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final factoryDoc = await _firestore.collection('factories').doc(widget.factoryOwnerUID).get();

      if (mounted) {
        final factoryData = factoryDoc.data();
        if (factoryData != null) {
          _loadedData = factoryData;
          _populateFormData(factoryData);
          
          if (factoryData['factoryPhotos'] != null && factoryData['factoryPhotos'] is List) {
            _uploadedFactoryPhotoUrls = List<String>.from(factoryData['factoryPhotos']);
          }
          
          _uploadedLogoUrl = factoryData['factoryLogoUrl'] ?? widget.factoryLogoUrl;
        }

        setState(() {
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
          _statusMessage = "Error loading data: $e";
        });
      }
    }
  }

  void _populateFormData(Map<String, dynamic> data) {
    _factoryNameController.text = data['factoryName'] ?? '';
    _addressController.text = data['address'] ?? '';
    _contactNumberController.text = data['contactNumber'] ?? '';
    _agDivisionController.text = data['agDivision'] ?? '';
    _gnDivisionController.text = data['gnDivision'] ?? '';
    
    _selectedProvince = data['province'];
    _selectedDistrict = data['district'];
    _selectedCropType = data['cropType'];

    if (_selectedProvince != null && !_geoData.containsKey(_selectedProvince)) {
      _selectedProvince = null;
    }
    if (_selectedDistrict != null && !(_geoData[_selectedProvince] ?? []).contains(_selectedDistrict)) {
      _selectedDistrict = null;
    }
  }

  @override
  void dispose() {
    _factoryNameController.dispose();
    _addressController.dispose();
    _contactNumberController.dispose();
    _agDivisionController.dispose();
    _gnDivisionController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _selectedFactoryPhotos.clear();
      _selectedLogoFile = null;
    });
    
    await _loadInitialData();
    
    if (mounted) {
      setState(() {
        _statusMessage = "Data refreshed successfully!";
      });
    }
  }

  // Pick Factory Logo Method
  Future<void> _pickFactoryLogo() async {
    try {
      final XFile? pickedFile = await _imagePicker.pickImage(
        source: ImageSource.gallery,
        maxWidth: 800,
        maxHeight: 800,
        imageQuality: 85,
      );

      if (pickedFile != null) {
        final file = File(pickedFile.path);
        if (await file.exists()) {
          final stat = await file.stat();
          final fileSizeMB = stat.size / (1024 * 1024);
          
          if (fileSizeMB > 5) {
            _showStatusMessage('Logo is too large (${fileSizeMB.toStringAsFixed(1)} MB). Max 5MB.');
            return;
          }
          
          setState(() {
            _selectedLogoFile = pickedFile;
          });
          _showStatusMessage('Logo selected. Tap Update to upload.');
        }
      }
    } catch (e) {
      _showStatusMessage('Error selecting logo: ${e.toString()}');
    }
  }

  // Remove selected logo
  void _removeSelectedLogo() {
    setState(() {
      _selectedLogoFile = null;
    });
    _showStatusMessage('Logo removed');
  }

  // Remove uploaded logo
  void _removeUploadedLogo() async {
    try {
      setState(() {
        _uploadingLogo = true;
      });
      
      await _firestore.collection('factories').doc(widget.factoryOwnerUID).update({
        'factoryLogoUrl': FieldValue.delete(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _uploadedLogoUrl = null;
      });
      
      widget.onLogoUpdated?.call(null);
      _showStatusMessage('Logo removed successfully');
    } catch (e) {
      _showStatusMessage('Error removing logo: ${e.toString()}');
    } finally {
      setState(() {
        _uploadingLogo = false;
      });
    }
  }

  // Upload Factory Logo to Cloudinary
  Future<String?> _uploadLogoToCloudinary() async {
    if (_selectedLogoFile == null) return null;
    
    try {
      debugPrint('Uploading factory logo: ${_selectedLogoFile!.name}');
      
      final bytes = await _selectedLogoFile!.readAsBytes();
      final fileSizeMB = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
      
      _showStatusMessage('Uploading logo - $fileSizeMB MB...');

      final url = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
      
      final request = http.MultipartRequest('POST', url)
        ..fields['upload_preset'] = _uploadPreset
        ..files.add(http.MultipartFile.fromBytes(
          'file',
          bytes,
          filename: 'factory_logo_${widget.factoryOwnerUID}_${DateTime.now().millisecondsSinceEpoch}.jpg',
        ));

      final streamedResponse = await request.send().timeout(
        const Duration(seconds: 30),
      );

      final response = await http.Response.fromStream(streamedResponse);
      
      if (response.statusCode == 200) {
        final responseData = json.decode(response.body);
        final imageUrl = responseData['secure_url'];
        debugPrint('✅ Logo uploaded successfully!');
        return imageUrl;
      } else {
        debugPrint('❌ Logo upload failed: ${response.statusCode}');
        _showStatusMessage('Failed to upload logo. Please try again.');
        return null;
      }
    } catch (e) {
      debugPrint('❌ Error uploading logo: $e');
      _showStatusMessage('Error uploading logo. Please try again.');
      return null;
    }
  }

  // Pick Factory Photos Method
  Future<void> _pickFactoryPhotos() async {
    try {
      if (_selectedFactoryPhotos.length >= _maxPhotos) {
        _showStatusMessage('Maximum $_maxPhotos photos allowed');
        return;
      }

      final List<XFile>? pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFiles != null) {
        int availableSlots = _maxPhotos - _selectedFactoryPhotos.length;
        int filesToAdd = pickedFiles.length > availableSlots ? availableSlots : pickedFiles.length;
        
        for (int i = 0; i < filesToAdd; i++) {
          final file = File(pickedFiles[i].path);
          if (await file.exists()) {
            final stat = await file.stat();
            final fileSizeMB = stat.size / (1024 * 1024);
            
            if (fileSizeMB > 10) {
              _showStatusMessage('${pickedFiles[i].name} is too large (${fileSizeMB.toStringAsFixed(1)} MB). Max 10MB per photo.');
              continue;
            }
            
            _selectedFactoryPhotos.add(pickedFiles[i]);
          }
        }
        
        setState(() {});
        _showStatusMessage('Added ${filesToAdd} photo(s). Total: ${_selectedFactoryPhotos.length}/$_maxPhotos');
      }
    } catch (e) {
      _showStatusMessage('Error selecting photos: ${e.toString()}');
    }
  }

  // Remove selected photo
  void _removeSelectedPhoto(int index) {
    setState(() {
      _selectedFactoryPhotos.removeAt(index);
    });
    _showStatusMessage('Photo removed');
  }

  // Remove uploaded photo
  void _removeUploadedPhoto(int index) async {
    try {
      setState(() {
        _uploadingPhotos = true;
      });
      
      final urlToRemove = _uploadedFactoryPhotoUrls[index];
      
      await _firestore.collection('factories').doc(widget.factoryOwnerUID).update({
        'factoryPhotos': FieldValue.arrayRemove([urlToRemove]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _uploadedFactoryPhotoUrls.removeAt(index);
      });
      
      _showStatusMessage('Photo removed successfully');
    } catch (e) {
      _showStatusMessage('Error removing photo: ${e.toString()}');
    } finally {
      setState(() {
        _uploadingPhotos = false;
      });
    }
  }

  // Upload Factory Photos to Cloudinary
  Future<List<String>> _uploadFactoryPhotosToCloudinary() async {
    List<String> uploadedUrls = [];
    
    for (int i = 0; i < _selectedFactoryPhotos.length; i++) {
      final photo = _selectedFactoryPhotos[i];
      try {
        debugPrint('Uploading factory photo ${i + 1}/${_selectedFactoryPhotos.length}: ${photo.name}');
        
        final bytes = await photo.readAsBytes();
        final fileSizeMB = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
        
        _showStatusMessage('Uploading photo ${i + 1} (${photo.name}) - $fileSizeMB MB...');

        final url = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
        
        final request = http.MultipartRequest('POST', url)
          ..fields['upload_preset'] = _uploadPreset
          ..files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'factory_${widget.factoryOwnerUID}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
          ));

        final streamedResponse = await request.send().timeout(
          const Duration(seconds: 45),
        );

        final response = await http.Response.fromStream(streamedResponse);
        
        if (response.statusCode == 200) {
          final responseData = json.decode(response.body);
          final imageUrl = responseData['secure_url'];
          uploadedUrls.add(imageUrl);
          debugPrint('✅ Photo ${i + 1} uploaded successfully!');
        } else {
          debugPrint('❌ Photo upload failed: ${response.statusCode}');
          _showStatusMessage('Failed to upload photo ${i + 1}. Please try again.');
        }
      } catch (e) {
        debugPrint('❌ Error uploading photo ${i + 1}: $e');
        _showStatusMessage('Error uploading photo ${i + 1}. Please try again.');
      }
    }
    
    return uploadedUrls;
  }

  // Factory Logo Widget
  Widget _buildFactoryLogoSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Factory Logo'),
        const SizedBox(height: 8),
        
        Container(
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.accentColor.withOpacity(0.3)),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                // Logo Preview
                Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                  ),
                  child: _buildLogoPreview(),
                ),
                
                const SizedBox(height: 16),
                
                // Upload/Remove Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ElevatedButton.icon(
                      onPressed: _pickFactoryLogo,
                      icon: const Icon(Icons.upload, size: 16),
                      label: const Text('Upload Logo'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primaryBlue,
                        foregroundColor: Colors.white,
                      ),
                    ),
                    
                    const SizedBox(width: 12),
                    
                    if (_uploadedLogoUrl != null || _selectedLogoFile != null)
                      ElevatedButton.icon(
                        onPressed: _uploadedLogoUrl != null 
                          ? _removeUploadedLogo
                          : _removeSelectedLogo,
                        icon: const Icon(Icons.delete, size: 16),
                        label: Text(_uploadedLogoUrl != null ? 'Remove Logo' : 'Cancel'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red,
                          foregroundColor: Colors.white,
                        ),
                      ),
                  ],
                ),
                
                const SizedBox(height: 8),
                
                Text(
                  'Upload a square logo for your factory (Max 5MB)',
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 12,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        
        const SizedBox(height: 20),
      ],
    );
  }

  Widget _buildLogoPreview() {
    if (_selectedLogoFile != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.file(
          File(_selectedLogoFile!.path),
          fit: BoxFit.cover,
        ),
      );
    } else if (_uploadedLogoUrl != null) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Image.network(
          _uploadedLogoUrl!,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                    : null,
                color: AppColors.primaryBlue,
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) {
            return Container(
              color: Colors.grey[200],
              child: const Icon(Icons.broken_image, color: Colors.grey),
            );
          },
        ),
      );
    } else {
      return Container(
        color: Colors.grey[100],
        child: const Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.business, size: 40, color: Colors.grey),
            SizedBox(height: 8),
            Text(
              'No Logo',
              style: TextStyle(
                color: Colors.grey,
                fontSize: 12,
              ),
            ),
          ],
        ),
      );
    }
  }

  // Factory Photos Gallery Widget
  Widget _buildFactoryPhotosGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Factory Photos (Max 5)'),
        const SizedBox(height: 8),
        
        if (_uploadedFactoryPhotoUrls.isNotEmpty) ...[
          const Text(
            'Currently Uploaded Photos:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _uploadedFactoryPhotoUrls.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.primaryBlue.withOpacity(0.3)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.network(
                        _uploadedFactoryPhotoUrls[index],
                        fit: BoxFit.cover,
                        loadingBuilder: (context, child, loadingProgress) {
                          if (loadingProgress == null) return child;
                          return Center(
                            child: CircularProgressIndicator(
                              value: loadingProgress.expectedTotalBytes != null
                                  ? loadingProgress.cumulativeBytesLoaded / loadingProgress.expectedTotalBytes!
                                  : null,
                              color: AppColors.primaryBlue,
                            ),
                          );
                        },
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            color: Colors.grey[200],
                            child: const Icon(Icons.broken_image, color: Colors.grey),
                          );
                        },
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeUploadedPhoto(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        
        if (_selectedFactoryPhotos.isNotEmpty) ...[
          const Text(
            'New Photos to Upload:',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.darkText,
            ),
          ),
          const SizedBox(height: 8),
          GridView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: 8,
              mainAxisSpacing: 8,
              childAspectRatio: 1,
            ),
            itemCount: _selectedFactoryPhotos.length,
            itemBuilder: (context, index) {
              return Stack(
                children: [
                  Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: AppColors.secondaryColor.withOpacity(0.5)),
                    ),
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Image.file(
                        File(_selectedFactoryPhotos[index].path),
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  Positioned(
                    top: 4,
                    right: 4,
                    child: GestureDetector(
                      onTap: () => _removeSelectedPhoto(index),
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.close,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 4,
                    left: 4,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.6),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '${index + 1}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
          const SizedBox(height: 16),
        ],
        
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedFactoryPhotos.length >= _maxPhotos 
                ? Colors.grey 
                : AppColors.primaryBlue.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.photo_camera,
                size: 40,
                color: _selectedFactoryPhotos.length >= _maxPhotos 
                  ? Colors.grey 
                  : AppColors.primaryBlue,
              ),
              const SizedBox(height: 8),
              Text(
                _selectedFactoryPhotos.length >= _maxPhotos
                  ? 'Maximum $_maxPhotos photos reached'
                  : 'Add Factory Photos (${_selectedFactoryPhotos.length}/$_maxPhotos)',
                style: TextStyle(
                  color: _selectedFactoryPhotos.length >= _maxPhotos 
                    ? Colors.grey 
                    : AppColors.darkText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to select photos of your factory',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _selectedFactoryPhotos.length >= _maxPhotos ? null : _pickFactoryPhotos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedFactoryPhotos.length >= _maxPhotos 
                    ? Colors.grey 
                    : AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                child: const Text('Select Photos'),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
      ],
    );
  }

  Future<void> _updateFactoryData() async {
    if (!_formKey.currentState!.validate()) {
      _showStatusMessage("Please correct the errors in the form.");
      return;
    }

    if (_selectedProvince == null || _selectedDistrict == null || _selectedCropType == null) {
      _showStatusMessage("Please ensure all required fields are filled.");
      return;
    }
    
    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      // Upload logo if selected
      String? newLogoUrl;
      if (_selectedLogoFile != null) {
        setState(() {
          _uploadingLogo = true;
        });
        
        newLogoUrl = await _uploadLogoToCloudinary();
        
        setState(() {
          _uploadingLogo = false;
        });
      }

      // Upload photos if selected
      List<String> newPhotoUrls = [];
      if (_selectedFactoryPhotos.isNotEmpty) {
        setState(() {
          _uploadingPhotos = true;
        });
        
        newPhotoUrls = await _uploadFactoryPhotosToCloudinary();
        
        setState(() {
          _uploadingPhotos = false;
        });
      }

      // Prepare update data
      final factoryDataToUpdate = {
        'factoryName': _factoryNameController.text.trim(),
        'address': _addressController.text.trim(),
        'contactNumber': _contactNumberController.text.trim(),
        'cropType': _selectedCropType,
        'country': 'Sri Lanka',
        'province': _selectedProvince,
        'district': _selectedDistrict,
        'agDivision': _agDivisionController.text.trim(),
        'gnDivision': _gnDivisionController.text.trim(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add logo URL if uploaded
      if (newLogoUrl != null) {
        factoryDataToUpdate['factoryLogoUrl'] = newLogoUrl;
        widget.onLogoUpdated?.call(newLogoUrl);
      }

      // Add photo URLs if uploaded
      if (newPhotoUrls.isNotEmpty) {
        factoryDataToUpdate['factoryPhotos'] = FieldValue.arrayUnion(newPhotoUrls);
      }

      // Update Firestore
      await _firestore.collection('factories').doc(widget.factoryOwnerUID).set(
        factoryDataToUpdate,
        SetOptions(merge: true),
      );

      // Update local state
      if (newLogoUrl != null) {
        setState(() {
          _uploadedLogoUrl = newLogoUrl;
          _selectedLogoFile = null;
        });
      }

      if (newPhotoUrls.isNotEmpty) {
        setState(() {
          _uploadedFactoryPhotoUrls.addAll(newPhotoUrls);
          _selectedFactoryPhotos.clear();
        });
      }

      _showStatusMessage("Factory details updated successfully!");
      
      widget.onProfileUpdated?.call();
      widget.onDataUpdated?.call();

      await _refreshDataAutomatically();

    } catch (e) {
      _showStatusMessage("Error updating factory details: $e");
      debugPrint('Update Error: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  Future<void> _refreshDataAutomatically() async {
    await Future.delayed(const Duration(milliseconds: 500));
    
    await _loadInitialData();
    
    if (mounted) {
      setState(() {
        _statusMessage = "Data refreshed successfully!";
      });
    }
  }

  void _showStatusMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 3),
        backgroundColor: message.toLowerCase().contains('success') 
            ? AppColors.secondaryColor 
            : Colors.red,
      ),
    );
    
    setState(() {
      _statusMessage = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.primaryBlue),
            SizedBox(height: 16),
            Text('Loading factory details...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              ElevatedButton.icon(
                onPressed: _refreshData,
                icon: const Icon(Icons.refresh, size: 16),
                label: const Text('Refresh'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryBlue,
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
        
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_statusMessage != null)
                    InfoCard(
                      message: _statusMessage!,
                      color: _statusMessage!.toLowerCase().contains('success') 
                          ? AppColors.secondaryColor 
                          : Colors.red,
                    ),

                  const SizedBox(height: 16),
                  
                  // Factory Logo Section
                  _buildFactoryLogoSection(),
                  
                  // Factory Photos Section
                  _buildFactoryPhotosGallery(),
                  
                  // Factory Information Form
                  _buildInputLabel('Factory Name'),
                  _buildTextField(_factoryNameController, 'Sunshine Tea Factory'),
                                 
                  _buildInputLabel('Contact Number'),
                  _buildTextField(_contactNumberController, '0771234567', TextInputType.phone),

                  _buildInputLabel('Address Line'),
                  _buildTextField(_addressController, 'e.g., Kandy Road'),

                  _buildInputLabel('Crop Type Handled'),
                  _buildCropTypeDropdown(),
                  
                  _buildInputLabel('Country (Fixed)'),
                  const FixedInfoBox(value: 'Sri Lanka'),
                  
                  _buildInputLabel('Province'),
                  _buildProvinceDropdown(),
                  
                  if (_selectedProvince != null) ...[
                    _buildInputLabel('District'),
                    _buildDistrictDropdown(),
                  ],
                  
                  _buildInputLabel('A/G Division'),
                  _buildTextField(
                    _agDivisionController, 
                    'Enter A/G Division (e.g., Kandy Divisional Secretariat)',
                    TextInputType.text,
                    false
                  ),
                  
                  _buildInputLabel('G/N Division'),
                  _buildTextField(
                    _gnDivisionController, 
                    'Enter G/N Division (e.g., Kandy Town)',
                    TextInputType.text,
                    false
                  ),
                  
                  const SizedBox(height: 30),

                  GradientButton(
                    text: _isSaving 
                      ? 'Updating...' 
                      : 'Update Factory Details',
                    onPressed: (_isSaving || _uploadingPhotos || _uploadingLogo) 
                      ? null 
                      : _updateFactoryData,
                    isEnabled: !_isSaving && !_uploadingPhotos && !_uploadingLogo,
                  ),
                  
                  const SizedBox(height: 50),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInputLabel(String text) {
    return Padding(
      padding: const EdgeInsets.only(top: 16.0, bottom: 8.0),
      child: Text(
        text,
        style: const TextStyle(
          color: AppColors.darkText,
          fontWeight: FontWeight.w600,
          fontSize: 16,
        ),
      ),
    );
  }

  Widget _buildTextField(
    TextEditingController controller, 
    String hintText, 
    [TextInputType keyboardType = TextInputType.text,
    bool isRequired = true]
  ) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
      ),
      child: TextFormField(
        controller: controller,
        keyboardType: keyboardType,
        style: const TextStyle(color: AppColors.darkText),
        decoration: InputDecoration(
          hintText: hintText,
          contentPadding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
          border: InputBorder.none,
        ),
        validator: isRequired ? (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required.';
          }
          return null;
        } : null,
      ),
    );
  }

  Widget _buildCropTypeDropdown() {
    return _buildDropdown<String>(
      value: _selectedCropType,
      hint: 'Select Crop Type (Tea, Cinnamon, or Both)',
      items: ['Tea', 'Cinnamon', 'Both'],
      onChanged: (newValue) {
        setState(() {
          _selectedCropType = newValue;
        });
      },
    );
  }

  Widget _buildProvinceDropdown() {
    return _buildDropdown<String>(
      value: _selectedProvince,
      hint: 'Select Province',
      items: _geoData.keys.toList(),
      onChanged: (newValue) {
        setState(() {
          _selectedProvince = newValue;
          _selectedDistrict = null;
        });
      },
    );
  }

  Widget _buildDistrictDropdown() {
    return _buildDropdown<String>(
      value: _selectedDistrict,
      hint: 'Select District',
      items: _geoData[_selectedProvince] ?? [],
      onChanged: (newValue) {
        setState(() {
          _selectedDistrict = newValue;
        });
      },
    );
  }

  Widget _buildDropdown<T>({
    required T? value,
    required String hint,
    required List<T> items,
    required void Function(T?) onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T>(
          value: value,
          hint: Text(hint, style: TextStyle(color: AppColors.darkText.withOpacity(0.5))),
          isExpanded: true,
          icon: const Icon(Icons.arrow_drop_down, color: AppColors.primaryBlue),
          style: const TextStyle(color: AppColors.darkText, fontSize: 16),
          items: items.map<DropdownMenuItem<T>>((T item) {
            return DropdownMenuItem<T>(
              value: item,
              child: Text(item.toString()),
            );
          }).toList(),
          onChanged: onChanged,
        ),
      ),
    );
  }
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

class GradientButton extends StatelessWidget {
  final String text;
  final VoidCallback? onPressed;
  final bool isEnabled;

  const GradientButton({required this.text, required this.onPressed, this.isEnabled = true, super.key});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: isEnabled ? onPressed : null,
      borderRadius: BorderRadius.circular(12),
      child: Opacity(
        opacity: isEnabled ? 1.0 : 0.6,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: isEnabled
              ? const LinearGradient(
                  colors: [AppColors.primaryBlue, Color(0xFF457AED)],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                )
              : LinearGradient(
                  colors: [Colors.grey.shade500, Colors.grey.shade400],
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                ),
            boxShadow: isEnabled
              ? [
                  BoxShadow(
                    color: AppColors.primaryBlue.withOpacity(0.5),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ]
              : null,
          ),
          child: Text(
            text,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 20,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class FixedInfoBox extends StatelessWidget {
  final String value;
  const FixedInfoBox({required this.value, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 20.0),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
      ),
      child: Text(
        value,
        style: TextStyle(
          color: AppColors.darkText.withOpacity(0.7),
          fontSize: 16,
        ),
      ),
    );
  }
}

class InfoCard extends StatelessWidget {
  final String message;
  final Color color;
  const InfoCard({required this.message, required this.color, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      margin: const EdgeInsets.symmetric(vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color, width: 1),
      ),
      child: Text(
        message,
        style: TextStyle(color: color, fontWeight: FontWeight.w500),
      ),
    );
  }
}