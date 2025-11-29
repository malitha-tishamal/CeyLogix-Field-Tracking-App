import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'factory_details.dart'; // Import Factory Details page
import 'factory_owner_dashboard.dart'; // Import the Dashboard page
import 'user_profile.dart'; // Import the User Profile page (Contains UserDetails)
import 'developer_info.dart'; // 💡 NEW: Import the Developer Info page

// --- Hardcoded Colors for Simplicity (Replace with AppColors if available) ---
const Color _primaryBlue = Color(0xFF2764E7);
const Color _darkText = Color(0xFF2C2A3A);

class FactoryOwnerDrawer extends StatefulWidget {
  final Function(String route) onNavigate;
  final VoidCallback onLogout;

  const FactoryOwnerDrawer({
    super.key,
    required this.onNavigate,
    required this.onLogout,
  });

  static Map<String, dynamic>? staticCache;

  @override
  State<FactoryOwnerDrawer> createState() => _FactoryOwnerDrawerState();
}

class _FactoryOwnerDrawerState extends State<FactoryOwnerDrawer> {
  late Future<Map<String, dynamic>?> _userFuture;
  String? _error;

  @override
  void initState() {
    super.initState();
    _userFuture = _loadUserData();
  }

  Future<Map<String, dynamic>?> _loadUserData() async {
    if (FactoryOwnerDrawer.staticCache != null) {
      return FactoryOwnerDrawer.staticCache;
    }

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        _error = "User not logged in";
        return null;
      }
      String uid = user.uid;

      DocumentSnapshot snapshot = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get()
          .timeout(const Duration(seconds: 10));

      if (snapshot.exists) {
        final data = snapshot.data() as Map<String, dynamic>?;
        FactoryOwnerDrawer.staticCache = data;
        return data;
      } else {
        _error = "User data not found";
        return null;
      }
    } catch (e) {
      _error = "Failed to load user data: $e";
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      width: MediaQuery.of(context).size.width * 0.65,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.horizontal(right: Radius.circular(30)),
      ),
      child: FutureBuilder<Map<String, dynamic>?>(
        future: _userFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return _buildLoadingState();
          } else if (snapshot.hasError || !snapshot.hasData || _error != null) {
            return _buildErrorState();
          } else {
            return _buildDrawerContent(snapshot.data!);
          }
        },
      ),
    );
  }

  Widget _buildDrawerContent(Map<String, dynamic> user) {
    String name = user['name'] ?? "User";
    String role = user['role'] ?? "Factory Owner";
    String profileUrl = user['profileImageUrl'] ??
        "https://ui-avatars.com/api/?name=$name&background=2764E7&color=fff&bold=true&size=150";

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 50),

        // Header (Logo/Title section)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Row(
            children: [
              Container(
                 width: 60, height: 60,
                 decoration: BoxDecoration(
                   color: _primaryBlue.withOpacity(0.1),
                   borderRadius: BorderRadius.circular(16),
                   boxShadow: [
                     BoxShadow(
                       color: _primaryBlue.withOpacity(0.3),
                       blurRadius: 15, offset: const Offset(0, 5),
                     ),
                   ],
                 ),
                 child: Image.asset(
                   'assets/logo/logo2.png',
                   width: 60, height: 60, fit: BoxFit.contain,
                   errorBuilder: (context, error, stackTrace) => const Icon(Icons.business_rounded, color: _primaryBlue, size: 30),
                 ),
              ),
              const SizedBox(width: 12),
              const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text("CeyLogix", style: TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: _primaryBlue, letterSpacing: -0.8)),
                  SizedBox(height: 2),
                  Text("Factory Management", style: TextStyle(fontSize: 11, fontWeight: FontWeight.w500, color: Color(0xFF666482), letterSpacing: 0.3)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 30),

        // Profile Section
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Colors.white, Color(0xFFF8FAFF)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(
                color: _primaryBlue.withOpacity(0.08),
                blurRadius: 25, offset: const Offset(0, 8),
              ),
            ],
            border: Border.all(color: Colors.white.withOpacity(0.9), width: 1.5),
          ),
          child: Row(
            children: [
              Container(
                width: 65, height: 65,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: _primaryBlue, width: 2.5),
                  boxShadow: [BoxShadow(color: _primaryBlue.withOpacity(0.2), blurRadius: 15, offset: const Offset(0, 4))],
                  gradient: const LinearGradient(colors: [_primaryBlue, Color(0xFF457AED)], begin: Alignment.topLeft, end: Alignment.bottomRight),
                ),
                child: ClipOval(
                  child: Image.network(
                    profileUrl, fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) => Container(decoration: const BoxDecoration(shape: BoxShape.circle, gradient: LinearGradient(colors: [_primaryBlue, Color(0xFF457AED)])), child: const Icon(Icons.person_rounded, color: Colors.white, size: 28)),
                    loadingBuilder: (context, child, loadingProgress) {
                      if (loadingProgress == null) return child;
                      return const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, valueColor: AlwaysStoppedAnimation<Color>(Colors.white))));
                    },
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(name, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: _darkText), maxLines: 1, overflow: TextOverflow.ellipsis),
                    const SizedBox(height: 4),
                    Container(padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4), decoration: BoxDecoration(color: _primaryBlue.withOpacity(0.1), borderRadius: BorderRadius.circular(8), border: Border.all(color: _primaryBlue.withOpacity(0.3))), child: Text(role.toUpperCase(), style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: _primaryBlue, letterSpacing: 0.8))),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 25),
        _buildSectionDivider(),
        const SizedBox(height: 8),

        // Menu Items
        Expanded(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            physics: const BouncingScrollPhysics(),
            children: [
              // 1. Dashboard 
              _buildModernDrawerItem(
                icon: Icons.dashboard_rounded,
                label: "Dashboard",
                description: "Overview & Analytics",
                isActive: true,
                onTap: () {
                  Navigator.of(context).pop(); 
                  Navigator.of(context).pushReplacement( 
                    MaterialPageRoute(builder: (context) => const FactoryOwnerDashboard()), 
                  );
                },
              ),
              
              // 2. Factory Details
              _buildModernDrawerItem(
                icon: Icons.business_center_rounded,
                label: "Factory Details",
                description: "Update company information",
                onTap: () {
                  Navigator.of(context).pop(); 
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (context) => const FactoryDetails()),
                  );
                },
              ),
              
              // 3. My Profile
              _buildModernDrawerItem(
                icon: Icons.person_rounded,
                label: "My Profile",
                description: "Personal settings",
                onTap: () {
                   Navigator.of(context).pop(); 
                   Navigator.of(context).push(
                     MaterialPageRoute(builder: (context) => const UserDetails()),
                   );
                },
              ),
              
              // 4. Production
              _buildModernDrawerItem(icon: Icons.analytics_rounded, label: "Production", description: "Monitor manufacturing", onTap: () => widget.onNavigate("production")),
              
              // 5. Inventory
              _buildModernDrawerItem(icon: Icons.inventory_rounded, label: "Inventory", description: "Stock management", onTap: () => widget.onNavigate("inventory")),
              
              // 6. Developer Info 💡 NEW NAVIGATION
              _buildModernDrawerItem(
  icon: Icons.code_rounded, 
  label: "Developer Info", 
  description: "About the application", 
  onTap: () {
    Navigator.of(context).pop(); // Close drawer
    Navigator.of(context).push(
      MaterialPageRoute(builder: (context) => const DeveloperInfoPage()), // Navigate to DeveloperInfoPage
    );
  },
),
            ],
          ),
        ),

        // Logout Button (Unchanged)
        Container(
          margin: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(colors: [Colors.red.shade50, Colors.red.shade100.withOpacity(0.8)], begin: Alignment.topLeft, end: Alignment.bottomRight),
            borderRadius: BorderRadius.circular(18),
            boxShadow: [BoxShadow(color: Colors.red.withOpacity(0.1), blurRadius: 20, offset: const Offset(0, 5))],
            border: Border.all(color: Colors.red.withOpacity(0.2), width: 1.5),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: widget.onLogout,
              borderRadius: BorderRadius.circular(18),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                child: Row(
                  children: [
                    Container(padding: const EdgeInsets.all(10), decoration: BoxDecoration(color: Colors.red.withOpacity(0.15), shape: BoxShape.circle), child: const Icon(Icons.logout_rounded, color: Colors.red, size: 20)),
                    const SizedBox(width: 14),
                    const Expanded(child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Logout", style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: Colors.red)),
                        SizedBox(height: 2),
                        Text("Secure sign out", style: TextStyle(fontSize: 11, color: Colors.red)),
                      ],
                    )),
                    Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: Colors.red.withOpacity(0.1), shape: BoxShape.circle), child: Icon(Icons.arrow_forward_ios_rounded, color: Colors.red.withOpacity(0.7), size: 12)),
                  ],
                ),
              ),
            ),
          ),
        ),

        // Footer (Unchanged)
        Container(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              Text("v2.1.0", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: _darkText.withOpacity(0.4), letterSpacing: 0.5)),
              const SizedBox(height: 4),
              Text("CeyLogix © 2024", style: TextStyle(fontSize: 10, color: _darkText.withOpacity(0.3))),
            ],
          ),
        ),
      ],
    );
  }

  // --- Helper Widgets (Skipped for brevity, assume they are correct) ---
  Widget _buildModernDrawerItem({
     required IconData icon,
     required String label,
     required String description,
     bool isActive = false,
     required VoidCallback onTap,
   }) {
     // implementation here (unchanged)
     return Container(
       margin: const EdgeInsets.only(bottom: 6),
       child: Material(
         color: Colors.transparent,
         child: InkWell(
           onTap: onTap,
           borderRadius: BorderRadius.circular(16),
           child: Container(
             padding: const EdgeInsets.all(14),
             decoration: BoxDecoration(
               gradient: isActive
                   ? const LinearGradient(
                       colors: [_primaryBlue, Color(0xFF457AED)],
                       begin: Alignment.centerLeft,
                       end: Alignment.centerRight,
                     )
                   : LinearGradient(
                       colors: [
                         Colors.white.withOpacity(0.7),
                         Colors.white.withOpacity(0.4),
                       ],
                       begin: Alignment.topLeft,
                       end: Alignment.bottomRight,
                     ),
               borderRadius: BorderRadius.circular(16),
               boxShadow: isActive
                   ? [
                       BoxShadow(
                         color: _primaryBlue.withOpacity(0.3),
                         blurRadius: 10,
                         offset: const Offset(0, 3),
                       ),
                     ]
                   : [
                       BoxShadow(
                         color: Colors.black.withOpacity(0.03),
                         blurRadius: 10,
                         offset: const Offset(0, 2),
                       ),
                     ],
               border: Border.all(
                 color: isActive
                     ? _primaryBlue.withOpacity(0.3)
                     : Colors.white.withOpacity(0.8),
                 width: 1.2,
               ),
             ),
             child: Row(
               children: [
                 Container(
                   padding: const EdgeInsets.all(8),
                   decoration: BoxDecoration(
                     color: isActive
                         ? Colors.white.withOpacity(0.2)
                         : _primaryBlue.withOpacity(0.1),
                     shape: BoxShape.circle,
                   ),
                   child: Icon(
                     icon,
                     color: isActive ? Colors.white : _primaryBlue,
                     size: 18,
                   ),
                 ),
                 const SizedBox(width: 14),
                 Expanded(
                   child: Column(
                     crossAxisAlignment: CrossAxisAlignment.start,
                     children: [
                       Text(label, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: isActive ? Colors.white : _darkText)),
                       const SizedBox(height: 2),
                       Text(description, style: TextStyle(fontSize: 11, color: isActive ? Colors.white.withOpacity(0.8) : _darkText.withOpacity(0.5))),
                     ],
                   ),
                 ),
                 const SizedBox(width: 10),
                 Icon(
                   Icons.arrow_forward_ios_rounded,
                   color: isActive ? Colors.white.withOpacity(0.7) : _primaryBlue.withOpacity(0.4),
                   size: 14,
                 ),
               ],
             ),
           ),
         ),
       ),
     );
   }

  Widget _buildSectionDivider() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        children: [
          Expanded(child: Divider(color: _primaryBlue.withOpacity(0.2), height: 1)),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 12), child: Text("MENU", style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: _primaryBlue.withOpacity(0.5), letterSpacing: 1.5))),
          Expanded(child: Divider(color: _primaryBlue.withOpacity(0.2), height: 1)),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3, valueColor: AlwaysStoppedAnimation<Color>(_primaryBlue))), SizedBox(height: 16), Text("Loading...", style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: _darkText))],
      ),
    );
  }

  Widget _buildErrorState() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline_rounded, color: _primaryBlue, size: 48),
        const SizedBox(height: 16),
        const Text("Unable to load", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
        if (_error != null) Padding(padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8), child: Text(_error!, style: TextStyle(fontSize: 12, color: Colors.red.shade700, fontWeight: FontWeight.w500), textAlign: TextAlign.center)),
        const SizedBox(height: 12),
        ElevatedButton(
          onPressed: () {
            setState(() {
              _userFuture = _loadUserData();
              _error = null;
            });
          },
          child: const Text("Retry"),
        ),
      ],
    );
  }
}