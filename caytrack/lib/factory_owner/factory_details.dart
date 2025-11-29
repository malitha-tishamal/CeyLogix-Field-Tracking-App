import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'factory_owner_drawer.dart'; // <-- IMPORTANT IMPORT

// --- Placeholder/Utility Imports ---
class AppColors {
  static const Color background = Color(0xFFEEEBFF);
  static const Color darkText = Color(0xFF2C2A3A);
  static const Color primaryBlue = Color(0xFF2764E7);
  static const Color cardBackground = Colors.white;
  static const Color secondaryColor = Color(0xFF6AD96A);
  
  // Custom colors based on the image's gradient header
  static const Color headerGradientStart = Color.from(alpha: 1, red: 0.525, green: 0.643, blue: 0.925); // Light blue top
  static const Color headerGradientEnd = Color(0xFFF7FAFF);   // Very light blue bottom
  static const Color headerTextDark = Color(0xFF333333);
}

// --- Factory Owner Profile Screen (Single Tab Version) ---
class FactoryDetails extends StatefulWidget {
  const FactoryDetails({super.key});

  @override
  State<FactoryDetails> createState() => _FactoryDetailsState();
}

class _FactoryDetailsState extends State<FactoryDetails> {
  final User? currentUser = FirebaseAuth.instance.currentUser;
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  // Placeholder for user data (to match the image's text)
  String _userName = 'Loading';
  String _userRole = 'Factory Owner';

  @override
  void initState() {
    super.initState();
    _fetchUserInfo();
  }

  // Fetch name and role from Firestore/Auth if needed
  void _fetchUserInfo() async {
    final user = currentUser;
    if (user != null) {
      try {
        final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
        if (doc.exists) {
          final data = doc.data();
          setState(() {
            _userName = data?['name'] ?? 'Factory Owner';
            _userRole = data?['role'] ?? 'Factory Owner';
          });
        }
      } catch (e) {
        // Handle error
        print("Error fetching user info: $e");
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (currentUser == null) {
      return const Scaffold(body: Center(child: Text("Error: User not logged in.")));
    }

    // You may need to create a dummy function if your FactoryOwnerDrawer expects the FactoryOwnerDashboard
    void handleDrawerNavigate(String routeName) {
      Navigator.pop(context); // Close drawer first
      // Placeholder for actual navigation logic if not Dashboard
      if (routeName == 'dashboard') {
         // Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (context) => const FactoryOwnerDashboard()));
      }
    }

    return Scaffold(
      key: _scaffoldKey,
      backgroundColor: AppColors.background,
      drawer: FactoryOwnerDrawer(
        onLogout: () {
          // Add your proper logout implementation here
          FirebaseAuth.instance.signOut();
          Navigator.pop(context);
        },
        onNavigate: handleDrawerNavigate, // Use the dummy handler
      ),
      body: Stack( // Use Stack to ensure the Update button stays above the footer text
        children: [
          SafeArea(
            child: Column(
              children: [
                // 1. Header Profile Card (UPDATED)
                _buildProfileHeader(context),
                
                // 2. Main Content - Scrollable Form
                Expanded(
                  child: SingleChildScrollView(
                    child: FactoryOwnerProfileContent(factoryOwnerUID: currentUser!.uid),
                  ),
                ),
                
                // 3. Footer Text (Moved to Stack for better positioning)
                // We'll handle the footer text placement outside the column for the fixed bottom text
              ],
            ),
          ),
          
          // 4. Fixed Footer Text
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
  
  // Custom Profile Header Widget - MATCHING IMAGE STYLE 🌟
  Widget _buildProfileHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 10, left: 20, right: 20, bottom: 20),
      // 1. Gradient Background
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [AppColors.headerGradientStart, AppColors.headerGradientEnd],
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
        ),
        // 2. Rounded Bottom Corners
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(30), // Slightly larger radius looks better
          bottomRight: Radius.circular(30),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x10000000), // Subtle black shadow
            blurRadius: 15,
            offset: Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Row: Menu Icon & Notification Icon
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Menu Button (Hamburger)
              IconButton(
                icon: const Icon(Icons.menu, color: AppColors.headerTextDark, size: 28),
                onPressed: () {
                  _scaffoldKey.currentState?.openDrawer();
                },
              ),
              // Notification Icon
              
            ],
          ),
          
          const SizedBox(height: 10),
          
          // Row: Profile Picture & User Info
          Row(
            children: [
              // Profile Picture (MATCHING BLUE STYLE)
              Container(
                width: 70,
                height: 70,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  // Use a distinct blue gradient for the avatar background
                  gradient: const LinearGradient(
                    colors: [AppColors.primaryBlue, Color(0xFF457AED)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  border: Border.all(color: Colors.white, width: 3),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primaryBlue.withOpacity(0.4),
                      blurRadius: 10,
                      offset: const Offset(0, 3),
                    ),
                  ],
                ),
                child: const Icon(Icons.person, size: 50, color: Colors.white),
              ),
              
              const SizedBox(width: 15),
              
              // User Info (Name and Role)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _userName, // Using fetched/placeholder name
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                      color: AppColors.headerTextDark,
                    ),
                  ),
                  Text(
                    _userRole, // Using fetched/placeholder role
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.headerTextDark.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
            ],
          ),
          
          const SizedBox(height: 25), // Space before the "Manage" text
          
          // "Manage Profile Details" Text
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

// --- Factory Owner Profile Content Widget (Remains the same, just included for completeness) ---
class FactoryOwnerProfileContent extends StatefulWidget {
  final String factoryOwnerUID;
  const FactoryOwnerProfileContent({required this.factoryOwnerUID, super.key});
  // ... (rest of FactoryOwnerProfileContentState code)
// ... (rest of FactoryOwnerProfileContentState code)
  @override
  State<FactoryOwnerProfileContent> createState() => _FactoryOwnerProfileContentState();
}

class _FactoryOwnerProfileContentState extends State<FactoryOwnerProfileContent> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  // Text Controllers
  late TextEditingController _factoryNameController;
  late TextEditingController _addressController;
  late TextEditingController _ownerNameController;
  late TextEditingController _contactNumberController;

  // Dropdown State
  String? _selectedProvince;
  String? _selectedDistrict;
  String? _selectedVillage;
  String? _selectedCropType;
  
  // Utility State
  bool _isSaving = false;
  String? _statusMessage;

  // Geo Data structure
  static final Map<String, Map<String, List<String>>> _geoData = _getGeoData();

  @override
  void initState() {
    super.initState();
    _factoryNameController = TextEditingController();
    _addressController = TextEditingController();
    _ownerNameController = TextEditingController();
    _contactNumberController = TextEditingController();
  }

  @override
  void dispose() {
    _factoryNameController.dispose();
    _addressController.dispose();
    _ownerNameController.dispose();
    _contactNumberController.dispose();
    super.dispose();
  }

  // --- Data Fetching Logic ---
  Future<DocumentSnapshot<Map<String, dynamic>>> _fetchFactoryData() {
    return _firestore.collection('factories').doc(widget.factoryOwnerUID).get();
  }

  // --- Data Update Logic ---
  Future<void> _updateFactoryData() async {
    if (!_formKey.currentState!.validate()) {
      setState(() => _statusMessage = "Please correct the errors in the form.");
      return;
    }

    if (_selectedProvince == null || _selectedDistrict == null || _selectedVillage == null || _selectedCropType == null) {
      setState(() => _statusMessage = "Please ensure all location and crop type fields are selected.");
      return;
    }
    
    setState(() {
      _isSaving = true;
      _statusMessage = null;
    });

    try {
      final dataToUpdate = {
        'factoryName': _factoryNameController.text.trim(),
        'address': _addressController.text.trim(),
        'ownerName': _ownerNameController.text.trim(),
        'contactNumber': _contactNumberController.text.trim(),
        'cropType': _selectedCropType,
        'country': 'Sri Lanka',
        'province': _selectedProvince,
        'district': _selectedDistrict,
        'village': _selectedVillage,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      await _firestore.collection('factories').doc(widget.factoryOwnerUID).set(dataToUpdate, SetOptions(merge: true));

      setState(() {
        _statusMessage = "Profile updated successfully!";
      });

    } catch (e) {
      setState(() {
        _statusMessage = "Error updating profile: $e";
      });
      debugPrint('Update Error: $e');
    } finally {
      setState(() {
        _isSaving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      future: _fetchFactoryData(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator(color: AppColors.primaryBlue));
        }
        if (snapshot.hasError) {
          return Center(child: Text('Error loading data: ${snapshot.error}'));
        }
        
        final data = snapshot.data?.data();
        if (data != null && mounted) {
          _factoryNameController.text = data['factoryName'] ?? '';
          _addressController.text = data['address'] ?? '';
          _ownerNameController.text = data['ownerName'] ?? '';
          _contactNumberController.text = data['contactNumber'] ?? '';
          
          _selectedProvince = data['province'];
          _selectedDistrict = data['district'];
          _selectedVillage = data['village'];
          _selectedCropType = data['cropType'];

          if (_selectedProvince != null && !_geoData.containsKey(_selectedProvince)) {
            _selectedProvince = null;
          }
          if (_selectedDistrict != null && !(_geoData[_selectedProvince] ?? {}).containsKey(_selectedDistrict)) {
            _selectedDistrict = null;
          }
          if (_selectedVillage != null && !(_geoData[_selectedProvince]?[_selectedDistrict] ?? []).contains(_selectedVillage)) {
            _selectedVillage = null;
          }
        }
        
        final bool isNewDocument = snapshot.data?.exists == false;
        
        return Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (isNewDocument)
                  const InfoCard(
                    message: "Welcome! Please enter your factory details below to complete your profile.",
                    color: Colors.orange,
                  ),
                
                if (_statusMessage != null)
                  InfoCard(
                    message: _statusMessage!,
                    color: _statusMessage!.toLowerCase().contains('success') ? AppColors.secondaryColor : Colors.red,
                  ),

                const SizedBox(height: 16),
                
                // Form Fields
                _buildInputLabel('Factory Name'),
                _buildTextField(_factoryNameController, 'Sunshine Tea Factory'),
                
                _buildInputLabel('Owner Name'),
                _buildTextField(_ownerNameController, 'Kamal Perera'),
                
                _buildInputLabel('Contact Number'),
                _buildTextField(_contactNumberController, '0771234567', TextInputType.phone),

                _buildInputLabel('Address Line'),
                _buildTextField(_addressController, 'e.g., Kandy Road'),

                _buildInputLabel('Crop Type Handled'),
                _buildDropdown<String>(
                  value: _selectedCropType,
                  hint: 'Select Crop Type (Tea, Cinnamon, or Both)',
                  items: ['Tea', 'Cinnamon', 'Both'],
                  onChanged: (newValue) {
                    setState(() {
                      _selectedCropType = newValue;
                    });
                  },
                ),
                
                _buildInputLabel('Country (Fixed)'),
                const FixedInfoBox(value: 'Sri Lanka'),
                
                _buildInputLabel('Province'),
                _buildDropdown<String>(
                  value: _selectedProvince,
                  hint: 'Select Province',
                  items: _geoData.keys.toList(),
                  onChanged: (newValue) {
                    setState(() {
                      _selectedProvince = newValue;
                      _selectedDistrict = null;
                      _selectedVillage = null;
                    });
                  },
                ),
                
                if (_selectedProvince != null) ...[
                  _buildInputLabel('District'),
                  _buildDropdown<String>(
                    value: _selectedDistrict,
                    hint: 'Select District',
                    items: _geoData[_selectedProvince]?.keys.toList() ?? [],
                    onChanged: (newValue) {
                      setState(() {
                        _selectedDistrict = newValue;
                        _selectedVillage = null;
                      });
                    },
                  ),
                ],
                
                if (_selectedDistrict != null) ...[
                  _buildInputLabel('Village/Town'),
                  _buildDropdown<String>(
                    value: _selectedVillage,
                    hint: 'Select Village or Town',
                    items: _geoData[_selectedProvince]?[_selectedDistrict] ?? [],
                    onChanged: (newValue) {
                      setState(() {
                        _selectedVillage = newValue;
                      });
                    },
                  ),
                ],
                
                const SizedBox(height: 30),

                // Update Button (Now positioned correctly above the fixed footer text in the Stack)
                GradientButton(
                  text: _isSaving ? 'Updating...' : 'Update Factory Details',
                  onPressed: _isSaving ? null : _updateFactoryData,
                  isEnabled: !_isSaving,
                ),
                
                const SizedBox(height: 50), // Add padding for the fixed footer text
              ],
            ),
          ),
        );
      },
    );
  }

  // --- Helper Widgets (No changes, included for full context) ---

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

  Widget _buildTextField(TextEditingController controller, String hintText, [TextInputType keyboardType = TextInputType.text]) {
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
        validator: (value) {
          if (value == null || value.isEmpty) {
            return 'This field is required.';
          }
          return null;
        },
      ),
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

// --- Geo Data Structure Definition (Remains the same) ---
Map<String, Map<String, List<String>>> _getGeoData() {
  return {
    'Western Province': {
      'Colombo District': ['Colombo City (capital city, urban area)', 'Dehiwala', 'Moratuwa', 'Ratmalana', 'Mount Lavinia', 'Wellawatte', 'Borella', 'Kollupitiya'],
      'Gampaha District': ['Negombo', 'Minuwangoda', 'Gampaha Town', 'Veyangoda', 'Divulapitiya', 'Kandana', 'Katunayake'],
      'Kalutara District': ['Kalutara Town', 'Beruwala', 'Aluthgama', 'Panadura', 'Moragalla', 'Maggona', 'Deniya'],
    },
    'Central Province': {
      'Kandy District': ['Kandy City (capital city, urban area)', 'Peradeniya', 'Gampola', 'Nuwara Eliya', 'Katugastota', 'Hantana', 'Mawanella'],
      'Matale District': ['Matale Town', 'Dambulla', 'Rattota', 'Elkaduwa', 'Naula'],
      'Nuwara Eliya District': ['Nuwara Eliya Town', 'Hakgala', 'Ambewela', 'Radella', 'Ramboda', 'Kotmale'],
    },
    'Southern Province': {
      'Galle District': ['Galle City', 'Unawatuna', 'Habaraduwa', 'Ambalangoda', 'Ahangama', 'Weligama'],
      'Matara District': ['Matara City', 'Mirissa', 'Dikwella', 'Kamburugamuwa', 'Nilwella', 'Weligama', 'Tangalle'],
      'Hambantota District': ['Hambantota Town', 'Tissamaharama', 'Ambalantota', 'Beliatta', 'Kataragama'],
    },
    'Eastern Province': {
      'Trincomalee District': ['Trincomalee City', 'Uppuveli', 'Nilaveli', 'Verugal', 'Kantalai', 'Seruwila'],
      'Batticaloa District': ['Batticaloa City', 'Kaluwanchikudy', 'Valaichchenai', 'Kattankudy', 'Manmunai South'],
      'Ampara District': ['Ampara Town', 'Pottuvil', 'Kalmunai', 'Samanthurai', 'Batticaloa'],
    },
    'Northern Province': {
      'Jaffna District': ['Jaffna City', 'Chavakachcheri', 'Point Pedro', 'Kopay', 'Nallur', 'Karainagar'],
      'Vavuniya District': ['Vavuniya Town', 'Kilinochchi', 'Mannar', 'Thandikulam'],
      'Kilinochchi District': ['Kilinochchi Town', 'Karachchi', 'Pooneryn', 'Ariyalai'],
      'Mannar District': ['Mannar Town', 'Musali', 'Adampan'],
      'Mullaitivu District': ['Mullaitivu Town', 'Puthukudiyiruppu', 'Oddusuddan'],
    },
    'North Western Province': {
      'Kurunegala District': ['Kurunegala City', 'Pannala', 'Dambadeniya', 'Kuliyapitiya', 'Polgahawela'],
      'Puttalam District': ['Puttalam Town', 'Chilaw', 'Mundalama', 'Anamaduwa', 'Marawila'],
    },
    'North Central Province': {
      'Anuradhapura District': ['Anuradhapura City', 'Mihintale', 'Tissawewa', 'Medawachchiya'],
      'Polonnaruwa District': ['Polonnaruwa City', 'Dimbulagala', 'Habarana', 'Kaduruwewa', 'Giritale'],
    },
    'Uva Province': {
      'Badulla District': ['Badulla Town', 'Hali-Ela', 'Mahiyanganaya', 'Ella', 'Passara'],
      'Monaragala District': ['Monaragala Town', 'Bibile', 'Kataragama', 'Wellawaya'],
    },
    'Sabaragamuwa Province': {
      'Ratnapura District': ['Ratnapura City', 'Kiriella', 'Balangoda', 'Godakawela', 'Kuruwita'],
      'Kegalle District': ['Kegalle Town', 'Wewalwatta', 'Mawanella', 'Rambukkana', 'Aranayaka'],
    },
  };
}

// --- Reusable Widgets (Remains the same) ---
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
              fontFamily: 'Inter',
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