import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'dart:io';
import 'dart:async';

class AppColors {
  static const Color background = Color(0xFFEEEBFF);
  static const Color darkText = Color(0xFF2C2A3A);
  static const Color primaryBlue = Color(0xFF2764E7);
  static const Color cardBackground = Colors.white;
  static const Color secondaryColor = Color(0xFF6AD96A);
  static const Color headerGradientStart = Color.fromARGB(255, 134, 164, 236);
  static const Color headerGradientEnd = Color(0xFFF7FAFF);
  static const Color headerTextDark = Color(0xFF333333);
}

class LandDetails extends StatefulWidget {
  const LandDetails({super.key});

  @override
  State<LandDetails> createState() => _LandDetailsState();
}

class _LandDetailsState extends State<LandDetails> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  String _userName = 'Loading';
  String _userRole = 'Land Owner';
  String? _profileImageUrl;

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
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
              _userName = data?['name'] ?? 'Land Owner';
              _userRole = data?['role'] ?? 'Land Owner';
              _profileImageUrl = data?['profileImageUrl'];
            });
          }
        }
      } catch (e) {
        print("Error fetching user info: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Error: User not logged in.")));
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      body: Column(
        children: [
          // Fixed Header
          _buildProfileHeader(context),
          
          // Scrollable Content with Footer
          Expanded(
            child: Column(
              children: [
                Expanded(
                  child: LandOwnerProfileContent(
                    key: ValueKey(currentUser!.uid),
                    landOwnerUID: currentUser!.uid,
                    onProfileUpdated: _fetchUserInfo,
                  ),
                ),
                
                // Footer (Fixed at bottom of content area)
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
          ),
        ],
      ),
    );
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
                icon: const Icon(Icons.arrow_back, color: AppColors.headerTextDark, size: 28),
                onPressed: () {
                  Navigator.pop(context);
                },
              ),
              Text(
                'Land Details',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.headerTextDark,
                ),
              ),
              const SizedBox(width: 48), // For balance
            ],
          ),
          
          const SizedBox(height: 10),
          
          Row(
            children: [
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: _profileImageUrl == null 
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
                  image: _profileImageUrl != null 
                    ? DecorationImage(
                        image: NetworkImage(_profileImageUrl!),
                        fit: BoxFit.cover,
                      )
                    : null,
                ),
                child: _profileImageUrl == null
                    ? const Icon(Icons.person, size: 40, color: Colors.white)
                    : null,
              ),
              
              const SizedBox(width: 15),
              
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                  Text(
                    _userRole,
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.headerTextDark.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 25),
          
          const Text(
            'Manage Your Land Information',
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

class LandOwnerProfileContent extends StatefulWidget {
  final String landOwnerUID;
  final VoidCallback? onProfileUpdated;
  
  const LandOwnerProfileContent({
    required this.landOwnerUID, 
    this.onProfileUpdated,
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

  // Text Controllers
  late TextEditingController _landNameController;
  late TextEditingController _addressController;
  late TextEditingController _landSizeController;
  late TextEditingController _agDivisionController;
  late TextEditingController _gnDivisionController;
  late TextEditingController _villageController;

  // State variables for LAND PHOTOS
  List<XFile> _selectedLandPhotos = [];
  List<String> _uploadedLandPhotoUrls = [];
  bool _uploadingPhotos = false;
  int _maxPhotos = 5;

  // Other state variables
  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedCropType;
  List<String> _selectedFactoryIds = [];
  List<Map<String, dynamic>> _availableFactories = [];
  
  bool _isSaving = false;
  String? _statusMessage;
  bool _isLoading = true;
  Map<String, dynamic>? _loadedData;

  static final Map<String, List<String>> _geoData = _getGeoData();

  @override
  void initState() {
    super.initState();
    _landNameController = TextEditingController();
    _addressController = TextEditingController();
    _landSizeController = TextEditingController();
    _agDivisionController = TextEditingController();
    _gnDivisionController = TextEditingController();
    _villageController = TextEditingController();
    
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    setState(() {
      _isLoading = true;
    });

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
          
          // Load existing land photos
          if (landData['landPhotos'] != null && landData['landPhotos'] is List) {
            _uploadedLandPhotoUrls = List<String>.from(landData['landPhotos']);
          }
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
    _landNameController.text = data['landName'] ?? '';
    _addressController.text = data['address'] ?? '';
    _landSizeController.text = data['landSize'] ?? '';
    _villageController.text = data['village'] ?? '';
    _agDivisionController.text = data['agDivision'] ?? '';
    _gnDivisionController.text = data['gnDivision'] ?? '';
    
    _selectedProvince = data['province'];
    _selectedDistrict = data['district'];
    _selectedCropType = data['cropType'];
    _selectedFactoryIds = List<String>.from(data['factoryIds'] ?? []);

    if (_selectedProvince != null && !_geoData.containsKey(_selectedProvince)) {
      _selectedProvince = null;
    }
    if (_selectedDistrict != null && !(_geoData[_selectedProvince] ?? []).contains(_selectedDistrict)) {
      _selectedDistrict = null;
    }
  }

  @override
  void dispose() {
    _landNameController.dispose();
    _addressController.dispose();
    _landSizeController.dispose();
    _agDivisionController.dispose();
    _gnDivisionController.dispose();
    _villageController.dispose();
    super.dispose();
  }

  Future<void> _refreshData() async {
    setState(() {
      _isLoading = true;
      _statusMessage = null;
      _selectedLandPhotos.clear();
    });
    
    await _loadInitialData();
    
    if (mounted) {
      setState(() {
        _statusMessage = "Data refreshed successfully!";
      });
    }
  }

  // Pick Land Photos Method
  Future<void> _pickLandPhotos() async {
    try {
      if (_selectedLandPhotos.length >= _maxPhotos) {
        _showStatusMessage('Maximum $_maxPhotos photos allowed');
        return;
      }

      final List<XFile>? pickedFiles = await _imagePicker.pickMultiImage(
        maxWidth: 1200,
        maxHeight: 1200,
        imageQuality: 85,
      );

      if (pickedFiles != null) {
        int availableSlots = _maxPhotos - _selectedLandPhotos.length;
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
            
            _selectedLandPhotos.add(pickedFiles[i]);
          }
        }
        
        setState(() {});
        _showStatusMessage('Added ${filesToAdd} photo(s). Total: ${_selectedLandPhotos.length}/$_maxPhotos');
      }
    } catch (e) {
      _showStatusMessage('Error selecting photos: ${e.toString()}');
    }
  }

  // Remove selected photo
  void _removeSelectedPhoto(int index) {
    setState(() {
      _selectedLandPhotos.removeAt(index);
    });
    _showStatusMessage('Photo removed');
  }

  // Remove uploaded photo
  void _removeUploadedPhoto(int index) async {
    try {
      setState(() {
        _uploadingPhotos = true;
      });
      
      final urlToRemove = _uploadedLandPhotoUrls[index];
      
      // Remove from Firestore
      await _firestore.collection('lands').doc(widget.landOwnerUID).update({
        'landPhotos': FieldValue.arrayRemove([urlToRemove]),
        'updatedAt': FieldValue.serverTimestamp(),
      });
      
      setState(() {
        _uploadedLandPhotoUrls.removeAt(index);
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

  // Upload Land Photos to Cloudinary
  Future<List<String>> _uploadLandPhotosToCloudinary() async {
    List<String> uploadedUrls = [];
    
    for (int i = 0; i < _selectedLandPhotos.length; i++) {
      final photo = _selectedLandPhotos[i];
      try {
        debugPrint('Uploading land photo ${i + 1}/${_selectedLandPhotos.length}: ${photo.name}');
        
        final bytes = await photo.readAsBytes();
        final fileSizeMB = (bytes.length / (1024 * 1024)).toStringAsFixed(2);
        
        _showStatusMessage('Uploading photo ${i + 1} (${photo.name}) - $fileSizeMB MB...');

        final url = Uri.parse("https://api.cloudinary.com/v1_1/$_cloudName/image/upload");
        
        final request = http.MultipartRequest('POST', url)
          ..fields['upload_preset'] = _uploadPreset
          ..files.add(http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: 'land_${widget.landOwnerUID}_${DateTime.now().millisecondsSinceEpoch}_$i.jpg',
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

  // Land Photos Gallery Widget
  Widget _buildLandPhotosGallery() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Land Photos (Max 5)'),
        const SizedBox(height: 8),
        
        // Uploaded Photos Grid
        if (_uploadedLandPhotoUrls.isNotEmpty) ...[
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
            itemCount: _uploadedLandPhotoUrls.length,
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
                        _uploadedLandPhotoUrls[index],
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
        
        // Selected Photos Grid
        if (_selectedLandPhotos.isNotEmpty) ...[
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
            itemCount: _selectedLandPhotos.length,
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
                        File(_selectedLandPhotos[index].path),
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
        
        // Add Photos Button
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: _selectedLandPhotos.length >= _maxPhotos 
                ? Colors.grey 
                : AppColors.primaryBlue.withOpacity(0.3),
            ),
          ),
          child: Column(
            children: [
              Icon(
                Icons.photo_camera,
                size: 40,
                color: _selectedLandPhotos.length >= _maxPhotos 
                  ? Colors.grey 
                  : AppColors.primaryBlue,
              ),
              const SizedBox(height: 8),
              Text(
                _selectedLandPhotos.length >= _maxPhotos
                  ? 'Maximum $_maxPhotos photos reached'
                  : 'Add Land Photos (${_selectedLandPhotos.length}/$_maxPhotos)',
                style: TextStyle(
                  color: _selectedLandPhotos.length >= _maxPhotos 
                    ? Colors.grey 
                    : AppColors.darkText,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap to select photos of your land',
                style: TextStyle(
                  color: Colors.grey[600],
                  fontSize: 12,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                onPressed: _selectedLandPhotos.length >= _maxPhotos ? null : _pickLandPhotos,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _selectedLandPhotos.length >= _maxPhotos 
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

  Future<void> _updateLandData() async {
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
      // Upload new land photos if any
      List<String> newPhotoUrls = [];
      if (_selectedLandPhotos.isNotEmpty) {
        setState(() {
          _uploadingPhotos = true;
        });
        
        newPhotoUrls = await _uploadLandPhotosToCloudinary();
        
        setState(() {
          _uploadingPhotos = false;
        });
      }

      // Prepare update data
      final landDataToUpdate = {
        'landName': _landNameController.text.trim(),
        'address': _addressController.text.trim(),
        'landSize': _landSizeController.text.trim(),
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

      // Add new photos to existing ones
      if (newPhotoUrls.isNotEmpty) {
        landDataToUpdate['landPhotos'] = FieldValue.arrayUnion(newPhotoUrls);
      }

      // Update Firestore
      await _firestore.collection('lands').doc(widget.landOwnerUID).set(
        landDataToUpdate,
        SetOptions(merge: true),
      );

      // Update local state
      if (newPhotoUrls.isNotEmpty) {
        setState(() {
          _uploadedLandPhotoUrls.addAll(newPhotoUrls);
          _selectedLandPhotos.clear();
        });
      }

      _showStatusMessage("Land details updated successfully!");
      widget.onProfileUpdated?.call();

      // Refresh data
      await _loadInitialData();

    } catch (e) {
      _showStatusMessage("Error updating land details: $e");
      debugPrint('Update Error: $e');
    } finally {
      setState(() {
        _isSaving = false;
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
            Text('Loading land details...'),
          ],
        ),
      );
    }

    return Column(
      children: [
        // Refresh Button
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
        
        // Form Content
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Status Message
                  if (_statusMessage != null)
                    InfoCard(
                      message: _statusMessage!,
                      color: _statusMessage!.toLowerCase().contains('success') 
                          ? AppColors.secondaryColor 
                          : Colors.red,
                    ),

                  const SizedBox(height: 16),
                  
                  // Land Photos Section
                  _buildLandPhotosGallery(),
                  
                  // Land Information Form
                  _buildInputLabel('Land Name'),
                  _buildTextField(_landNameController, 'Green Valley Plantation'),
                                 
                  _buildInputLabel('Land Size'),
                  _buildTextField(_landSizeController, '5 Acres'),

                  _buildInputLabel('Village'),
                  _buildTextField(_villageController, 'e.g., Peradeniya'),

                  _buildInputLabel('Address Line'),
                  _buildTextField(_addressController, 'e.g., Kandy Road'),

                  _buildInputLabel('Crop Type'),
                  _buildCropTypeDropdown(),
                  
                  _buildFactorySelection(),
                  
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

                  // Update Button
                  GradientButton(
                    text: _isSaving ? 'Updating...' : 'Update Land Details',
                    onPressed: (_isSaving || _uploadingPhotos) ? null : _updateLandData,
                    isEnabled: !_isSaving && !_uploadingPhotos,
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

  Widget _buildFactorySelection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildInputLabel('Associated Factories'),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primaryBlue.withOpacity(0.2)),
          ),
          child: _availableFactories.isEmpty
              ? const Text(
                  'No factories available',
                  style: TextStyle(color: Colors.grey),
                )
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Select factories you supply to:',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.darkText,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: _availableFactories.map((factory) {
                        final isSelected = _selectedFactoryIds.contains(factory['id']);
                        return FilterChip(
                          label: Text(factory['factoryName']),
                          selected: isSelected,
                          onSelected: (selected) {
                            setState(() {
                              if (selected) {
                                _selectedFactoryIds.add(factory['id']);
                              } else {
                                _selectedFactoryIds.remove(factory['id']);
                              }
                            });
                          },
                          selectedColor: AppColors.primaryBlue.withOpacity(0.2),
                          checkmarkColor: AppColors.primaryBlue,
                          labelStyle: TextStyle(
                            color: isSelected ? AppColors.primaryBlue : AppColors.darkText,
                          ),
                        );
                      }).toList(),
                    ),
                    if (_selectedFactoryIds.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Text(
                        'Selected: ${_selectedFactoryIds.length} factory(ies)',
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.darkText.withOpacity(0.6),
                        ),
                      ),
                    ],
                  ],
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

// Helper functions and widgets
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