  import 'dart:async';
  import 'dart:io';
  import 'package:cloud_firestore/cloud_firestore.dart';
  import 'package:connectivity_plus/connectivity_plus.dart';
  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:flutter/cupertino.dart';
  import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
  import 'package:hive/hive.dart';
  import 'package:image_picker/image_picker.dart';
  import 'package:shared_preferences/shared_preferences.dart';
  import '../../Hive/user_profile.dart';

  class Profile extends StatefulWidget {
    const Profile({super.key});

    @override
    State<Profile> createState() => _ProfileState();
  }

  class _ProfileState extends State<Profile> {
    File? selectedImage;
    final picker = ImagePicker();
    final _formKey = GlobalKey<FormState>();
    TextEditingController passwordController = TextEditingController();
    final TextEditingController fullNameController = TextEditingController();
    final TextEditingController emailController = TextEditingController();
    final TextEditingController addressController = TextEditingController();
    final TextEditingController phoneController = TextEditingController();

    String? role;
    String? userId;
    bool isEdit = false;
  bool isOnline =true;
    late Box<UserProfile> profileBox;
    StreamSubscription<User?>? _authSubscription;
    @override
    void initState() {
      super.initState();
      profileBox = Hive.box<UserProfile>('profileBox');
      final User? user = FirebaseAuth.instance.currentUser;
      final uid = user?.uid;

      setState(() {
        userId = uid;
      });
      _loadImage();
      _loadProfileData();
      _checkAndSyncPendingData();
      checkConnectivity();

      connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
        if (result != ConnectivityResult.none) {
          _checkAndSyncPendingData();
        }
      });
      _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
        if (user != null && user.emailVerified) {
          setState(() {
            emailController.text = user.email ?? '';
          });
        }
      });
    }

    Future<void> _loadProfileData() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userProfile = profileBox.get(user.uid);
        if (userProfile != null) {
          setState(() {
            fullNameController.text = userProfile.name;
            emailController.text = userProfile.email;
            addressController.text = userProfile.address;
            phoneController.text = userProfile.phone;
            role = userProfile.role;
            if (userProfile.imagePath != null) {
              selectedImage = File(userProfile.imagePath!);
            }
          });
        } else {
          final docSnapshot = await FirebaseFirestore.instance
              .collection('user')
              .doc(user.uid)
              .get();
          if (docSnapshot.exists) {
            final data = docSnapshot.data();
            if (data != null) {
              setState(() {
                fullNameController.text = data['name'] ?? '';
                emailController.text = data['email'] ?? '';
                addressController.text = data['address'] ?? '';
                phoneController.text = data['phone'] ?? '';
                role = data['role'] ?? '';
                if (data['url'] != null && data['url'].isNotEmpty) {
                  selectedImage = File(data['url']);
                }
              });
            }
          }
        }
      }
    }

    Future<void> _pickImage() async {
      final returnedImage = await ImagePicker().pickImage(source: ImageSource.gallery);
      if (returnedImage != null) {
        final imagePath = returnedImage.path;
        setState(() {
          selectedImage = File(imagePath);
        });
        await saveImagePath(imagePath);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image selected.')),
        );
      }
    }

    Future<void> saveImagePath(String path) async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(userId!, path);
    }

    Future<String?> getImagePath() async {
      final prefs = await SharedPreferences.getInstance();
      return prefs.getString(userId!);
    }

    Future<void> updateUserProfile() async {
      if (_formKey.currentState!.validate()) {
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          try {
            String newEmail = emailController.text;
            bool emailConfirmed = true;

            if (newEmail != user.email) {
              emailConfirmed = await _showPasswordDialog(user);
              if (!emailConfirmed) {
                newEmail = user.email!;
              }
            }

            final userProfile = UserProfile(
              name: fullNameController.text,
              email: newEmail,
              address: addressController.text,
              phone: phoneController.text,
              role: role ?? '',
              imagePath: selectedImage?.path,
              isSynced: false,
            );

            await profileBox.put(user.uid, userProfile);

            if (await _checkConnectivity()) {
              await _syncProfileWithFirebase(user.uid, userProfile);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Changes saved offline.'),
                backgroundColor: Colors.green,),
              );
            }
          } catch (e) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Error updating profile: $e')),
            );
          }
        }
        setState(() {
          isEdit = false;
        });
      }
    }


    Future<bool> _showPasswordDialog(User user) async {
      TextEditingController passwordController = TextEditingController();
      bool isPasswordVisible = false;

      return await showDialog(
        context: context,
        builder: (context) {
          return StatefulBuilder(
            builder: (context, setState) {
              return AlertDialog(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'Enter Current Password',
                  style: TextStyle(fontWeight: FontWeight.bold),
                  textAlign: TextAlign.center,
                ),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextField(
                      controller: passwordController,
                      obscureText: !isPasswordVisible,
                      decoration: InputDecoration(
                        hintText: 'Current Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            isPasswordVisible ? Icons.visibility : Icons.visibility_off,
                          ),
                          onPressed: () {
                            setState(() {
                              isPasswordVisible = !isPasswordVisible;
                            });
                          },
                        ),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context, false),
                    child: const Text(
                      'Cancel',
                      style: TextStyle(color: Colors.red),
                    ),
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown.shade300,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    onPressed: () async {
                      final password = passwordController.text;
                      if (password.isNotEmpty) {
                        Navigator.pop(context, true);
                        await _storePassword(password);
                        await _updateUserEmail(user, password);
                      } else {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Please enter your current password.'),
                          backgroundColor: Colors.green,),
                        );
                      }
                    },
                    child: const Text('Confirm',style: TextStyle(color: Colors.black),),
                  ),
                ],
              );
            },
          );
        },
      ) ?? false;
    }
    Future<void> _updateUserEmail(User user, String currentPassword) async {
      try {
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: currentPassword,
        );
        await user.reauthenticateWithCredential(credential);

        await user.verifyBeforeUpdateEmail(emailController.text);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A verification email has been sent. Please verify before updating your email.'),
          backgroundColor: Colors.green,),
        );
        _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
          if (user != null && user.emailVerified) {
            setState(() {
              emailController.text = user.email ?? '';
            });
          }
        });

      } on FirebaseAuthException catch (e) {
        // ScaffoldMessenger.of(context).showSnackBar(
        //   SnackBar(content: Text('Failed to update email: ${e.message}')),
        // );
        print('Failed to update email: ${e.message}');
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('An error occurred: $e'),
          ),
        );
      }
    }

    Future<void> _syncProfileWithFirebase(String userId, UserProfile userProfile) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        await FirebaseFirestore.instance.collection('user').doc(userId).update({
          'name': userProfile.name,
          'email': userProfile.email,
          'address': userProfile.address,
          'phone': userProfile.phone,
          'url': userProfile.imagePath ?? '',
        });

        if (userProfile.email != user.email) {
          await _sendVerificationEmail(userProfile.email!);
        }

        final updatedProfile = userProfile.copyWith(isSynced: true);
        await profileBox.put(userId, updatedProfile);
      } catch (e) {
        print('Failed to sync profile: $e');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error syncing profile: $e')),
        );
      }
    }


    Future<void> _checkAndSyncPendingData() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final userProfile = profileBox.get(user.uid);
        if (userProfile != null && !userProfile.isSynced) {
          if (await _checkConnectivity()) {
            await _syncProfileWithFirebase(user.uid, userProfile);
            if (userProfile.email != user.email) {
              await _sendVerificationEmail(userProfile.email!,);
            }
          }
        }
      }
    }
    final FlutterSecureStorage storage = FlutterSecureStorage();

    Future<void> _storePassword(String password) async {
      final storage = FlutterSecureStorage();
      await storage.write(key: 'user_password', value: password);
    }

    Future<String?> _getStoredPassword() async {
      final storage = FlutterSecureStorage();
      return await storage.read(key: 'user_password');
    }

    Future<void> _sendVerificationEmail(String newEmail) async {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) return;

      try {
        final password = await _getStoredPassword();

        if (password == null || password.isEmpty) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Failed to update email: Missing password.')),
          );
          return;
        }
        final credential = EmailAuthProvider.credential(
          email: user.email!,
          password: password,
        );
        await user.reauthenticateWithCredential(credential);
        await user.verifyBeforeUpdateEmail(newEmail);

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verification email sent. Please check your inbox.'),
          backgroundColor: Colors.green,),
        );
        _authSubscription = FirebaseAuth.instance.authStateChanges().listen((user) {
          if (user != null && user.emailVerified) {
            setState(() {
              emailController.text = user.email ?? '';
            });
          }
        });

      } on FirebaseAuthException catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to update email: ${e.message}')),
        );
        print('Failed to update email: ${e.message}');
      }
    }


    StreamSubscription? connectivitySubscription;

    Future<bool> _checkConnectivity() async {
      final connectivityResult = await Connectivity().checkConnectivity();
      return connectivityResult != ConnectivityResult.none;
    }
    Future<void> checkConnectivity() async {
      final connectivityResult = await Connectivity().checkConnectivity();
      setState(() {
        isOnline = connectivityResult != ConnectivityResult.none;
      });
    }
    Stream<DocumentSnapshot<Map<String, dynamic>>>? getUserDataStream() {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        return FirebaseFirestore.instance
            .collection('user')
            .doc(user.uid)
            .snapshots();
      }
      _loadImage();
      return null;
    }

    Future<void> _loadImage() async {
      final path = await getImagePath();
      if (path != null && mounted) {
        setState(() {
          selectedImage = File(path);
        });
      }
    }

    @override
    void dispose() {
      connectivitySubscription?.cancel();
      _authSubscription?.cancel();

      super.dispose();
    }
    @override
    Widget build(BuildContext context) {
      final userDataStream = getUserDataStream();

      return StreamBuilder<DocumentSnapshot>(
        stream: userDataStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }

          final data = snapshot.data;
          final userProfile = profileBox.get(userId!);

          return Scaffold(
            backgroundColor: Colors.grey[50],
            appBar: AppBar(
              elevation: 0,
              backgroundColor: Colors.grey[50],
              title: Text(
                isEdit ? "Edit Profile" : "My Profile",
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 24,
                  color: Colors.black87,
                ),
              ),
              automaticallyImplyLeading: false,
              actions: isEdit
                  ? [
                IconButton(
                  icon: const Icon(Icons.check, color: Colors.green),
                  onPressed: () {
                    updateUserProfile();
                    setState(() => isEdit = false);
                  },
                ),
              ]
                  : null,
            ),
            body: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    const SizedBox(height: 20),
                    _buildProfileAvatar(data),
                    const SizedBox(height: 30),
                    Text(
                      isEdit ? "Update Your Details" : "Your Information",
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w600,
                        color: Colors.black87,
                      ),
                    ),
                    const SizedBox(height: 20),
                    isEdit
                        ? _buildEditForm()
                        : _buildProfileDetails(userProfile, data),
                  ],
                ),
              ),
            ),
          );
        },
      );
    }

    Widget _buildProfileAvatar(DocumentSnapshot? data) {
      return GestureDetector(
        onTap: isEdit ? _pickImage : null,
        child: Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              colors: [Colors.brown[300]!, Colors.brown[100]!],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: CircleAvatar(
            radius: 70,
            backgroundColor: Colors.white,
            backgroundImage: selectedImage != null
                ? FileImage(selectedImage!)
                : (data?['url']?.isNotEmpty == true
                ? FileImage(File(data!['url']))
                : const AssetImage('assets/profile.jpeg')) as ImageProvider,
            child: selectedImage == null && data?['url']?.isEmpty != false
                ? const Icon(Icons.person_outline, size: 50, color: Colors.grey)
                : null,
          ),
        ),
      );
    }

    Widget _buildEditForm() {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              _buildTextField(fullNameController, "Full Name", Icons.person_outline),
              const SizedBox(height: 20),
              _buildTextField(emailController, "Email", Icons.email_outlined,
                  type: TextInputType.emailAddress),
              const SizedBox(height: 20),
              _buildTextField(addressController, "Address", Icons.location_on_outlined),
              const SizedBox(height: 20),
              _buildTextField(phoneController, "Phone", Icons.phone_outlined,
                  type: TextInputType.phone),
            ],
          ),
        ),
      );
    }

    Widget _buildTextField(TextEditingController controller, String label, IconData icon,
        {TextInputType? type}) {
      return TextFormField(
        controller: controller,
        keyboardType: type,
        decoration: InputDecoration(
          prefixIcon: Icon(icon, color: Colors.brown[400]),
          labelText: label,
          labelStyle: TextStyle(color: Colors.grey[700]),
          filled: true,
          fillColor: Colors.grey[100],
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
          ),
        ),
        validator: (value) =>
        value?.isEmpty == true ? 'Please enter your $label' : null,
      );
    }

    Widget _buildProfileDetails(UserProfile? profile, DocumentSnapshot? data) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withOpacity(0.1),
              spreadRadius: 2,
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildDetailTile("Name", profile?.name ?? data?["name"], Icons.person_outline),
            const SizedBox(height: 16),
            _buildDetailTile("Email", profile?.email ?? data?["email"], Icons.email_outlined),
            const SizedBox(height: 16),
            _buildDetailTile("Address", profile?.address ?? data?["address"], Icons.location_on_outlined),
            const SizedBox(height: 16),
            _buildDetailTile("Phone", profile?.phone ?? data?["phone"], Icons.phone_outlined),
            const SizedBox(height: 16),
            _buildDetailTile("Role", data?['role'], Icons.work_outline),
            const SizedBox(height: 20),
            Align(
              alignment: Alignment.centerRight,
              child: ElevatedButton.icon(
                onPressed: () {
                  setState(() {
                    _loadProfileData();
                    isEdit = true;
                  });
                },
                icon: const Icon(Icons.edit, size: 18),
                label: const Text("Edit"),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.brown[400],
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildDetailTile(String title, String? subtitle, IconData icon) {
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Colors.brown[400], size: 24),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: Colors.grey[700],
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle ?? "Not provided",
                  style: const TextStyle(fontSize: 16),
                ),
              ],
            ),
          ),
        ],
      );
    }
  }


  class ConnectivityService {
    static final ConnectivityService _instance = ConnectivityService._internal();
    factory ConnectivityService() => _instance;
    ConnectivityService._internal();

    StreamSubscription? _connectivitySubscription;

    void initialize() {
      _checkConnectivity();
    }

    Future<void> _checkConnectivity() async {
      final connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult != ConnectivityResult.none) {
        await _syncPendingData();
      }

      _connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) async {
        if (result != ConnectivityResult.none) {
          await _syncPendingData();
        }
      });
    }
    Future<void> _syncPendingData() async {
      final user = FirebaseAuth.instance.currentUser;
      if (user != null) {
        final profileBox = Hive.box<UserProfile>('profileBox');
        final userProfile = profileBox.get(user.uid);

        if (userProfile != null && !userProfile.isSynced) {
          await FirebaseFirestore.instance.collection('user').doc(user.uid).update({
            'name': userProfile.name,
            'email': userProfile.email,
            'address': userProfile.address,
            'phone': userProfile.phone,
            'url': userProfile.imagePath ?? '',
          });

          final updatedProfile = userProfile.copyWith(isSynced: true);
          await profileBox.put(user.uid, updatedProfile);
        }
      }
    }
    void dispose() {
      _connectivitySubscription?.cancel();
    }
  }