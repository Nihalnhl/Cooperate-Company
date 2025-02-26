import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
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

  final TextEditingController fullNameController = TextEditingController();
  final TextEditingController emailController = TextEditingController();
  final TextEditingController addressController = TextEditingController();
  final TextEditingController phoneController = TextEditingController();

  String? role;
  String? userId;
  bool isEdit = false;

  late Box<UserProfile> profileBox;

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

    connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _checkAndSyncPendingData();
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
        final userProfile = UserProfile(
          name: fullNameController.text,
          email: emailController.text,
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
            const SnackBar(content: Text('Changes saved offline.')),
          );
        }
      }
      setState(() {
        isEdit = false;
      });
    }
  }

  Future<void> _syncProfileWithFirebase(String userId, UserProfile userProfile) async {
    await FirebaseFirestore.instance.collection('user').doc(userId).update({
      'name': userProfile.name,
      'email': userProfile.email,
      'address': userProfile.address,
      'phone': userProfile.phone,
      'url': userProfile.imagePath ?? '',
    });


    final updatedProfile = userProfile.copyWith(isSynced: true);
    await profileBox.put(userId, updatedProfile);
  }

  Future<void> _checkAndSyncPendingData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final userProfile = profileBox.get(user.uid);
      if (userProfile != null && !userProfile.isSynced) {
        if (await _checkConnectivity()) {
          await _syncProfileWithFirebase(user.uid, userProfile);
        }
      }
    }
  }
  StreamSubscription? connectivitySubscription;

  Future<bool> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
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
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final userDataStream = getUserDataStream();
    return StreamBuilder<DocumentSnapshot>(
      stream: userDataStream,
      builder: (context, snapshot) {
        final data = snapshot.data;
        final UserProfile =profileBox.get(userId!);
        if (snapshot.hasData) {
          if (isEdit) {
            return Scaffold(
              backgroundColor: Colors.grey.shade300,
              appBar: AppBar(
                automaticallyImplyLeading: false,
                backgroundColor: Colors.grey.shade300,
                title: const Text(
                  "Edit Profile",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                actions: [
                  IconButton(
                      icon: const Icon(Icons.save),
                      onPressed: (){
                        updateUserProfile();
                        isEdit = false;
                      }
                  ),
                ],
              ),
              body: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    children: [
                      const SizedBox(height: 15),
                      Center(
                        child: GestureDetector(
                          onTap: _pickImage,
                          child: CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 100,
                            backgroundImage: selectedImage != null
                                ? FileImage(selectedImage!)
                                : (data != null && data['url'] != null && data['url'].isNotEmpty
                                ? FileImage(File(data['url']))
                                :  AssetImage('assets/profile.jpeg')) as ImageProvider,
                            child: selectedImage ==null?
                            Center(child:
                           Icon(Icons.person)):
                           null,
                            
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      Text("Edit User Details:",style: TextStyle(fontWeight: FontWeight.bold,fontSize: 20
                      ),),
                      SizedBox(height: 20,),
                      Container(
                        padding: const EdgeInsets.all(8.0),
                        child: Column(
                          children: [
                            TextFormField(
                              controller: fullNameController,
                              decoration: InputDecoration(
                                label: Text("Name"),
                                hintStyle: TextStyle(color: Colors.black45),

                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.brown.shade300, width: 1),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your name';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: emailController,
                              decoration: InputDecoration(
                                labelText: "Email",
                                hintText: "Enter your email",
                                hintStyle: TextStyle(color: Colors.black45),
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.brown.shade300, width: 1),
                                ),
                              ),
                              keyboardType: TextInputType.emailAddress,
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your email';
                                }
                                final emailRegex = RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$');
                                if (!emailRegex.hasMatch(value)) {
                                  return 'Please enter a valid email address';
                                }
                                return null;
                              },
                            ),

                            const SizedBox(height: 15),
                            TextFormField(
                              controller: addressController,
                              decoration: InputDecoration(
                                label: Text("Address"),
                                hintStyle: TextStyle(color: Colors.black45),

                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.brown.shade300, width: 1),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your address';
                                }
                                return null;
                              },
                            ),
                            const SizedBox(height: 15),
                            TextFormField(
                              controller: phoneController,
                              decoration: InputDecoration(
                                label: Text("Phone"),
                                hintStyle: TextStyle(color: Colors.black45),

                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(8),
                                  borderSide: BorderSide(color: Colors.brown.shade300, width: 1),
                                ),
                              ),
                              validator: (value) {
                                if (value == null || value.isEmpty) {
                                  return 'Please enter your phone number';
                                }
                                return null;
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            return Scaffold(
              backgroundColor: Colors.grey.shade300,
              appBar: AppBar(
                backgroundColor: Colors.grey.shade300,
                title: const Text(
                  "Profile",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    const SizedBox(height: 15),
                    Center(
                      child: CircleAvatar(
                        backgroundColor:Colors.white,
                        radius: 100,
                        backgroundImage: selectedImage != null
                            ? FileImage(selectedImage!)
                            : (data != null && data['url'] != null && data['url'].isNotEmpty
                            ? AssetImage('assets/profile.jpeg')
                            : FileImage(File(data?['url'])) ) as ImageProvider,
                        child: selectedImage ==null?
                        Center(child:
                        Image.asset('assets/profile.jpeg'),):
                       null,
                      ),
                    ),
                    SizedBox(height: 20,),
                    Row(children: [
                      SizedBox(width: 150),
                      Center(
                        child: Text(
                          'User Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 85),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _loadProfileData();
                            isEdit = true;
                          });
                        },
                        icon: Icon(Icons.edit),
                      )

                    ]),
                    const SizedBox(height: 30),
                    Container(

                      width: 400,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade200),
                      child: Column(

                        children: <Widget>[
                          ListTile(
                            title: Text('Name:',style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(UserProfile?.name ?? data?["name"],
                            ),
                            leading: Icon(Icons.person_2_outlined),
                          ),
                          Divider(),
                          ListTile(
                            title: Text('Email:',style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(UserProfile?.email ?? data?["email"],
                            ),
                            leading: Icon(Icons.email),
                          ),
                          Divider(),
                          ListTile(
                            title: Text('Address:',style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(UserProfile?.address ?? data?["address"],
                            ),
                            leading: Icon(Icons.location_city),
                          ),
                          Divider(),
                          ListTile(
                            title: Text('Role:',style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(data?['role'],
                            ),
                            leading: Icon(Icons.people),
                          ),  Divider(),
                          ListTile(
                            title: Text('Phone:',style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(UserProfile?.phone ?? data?["phone"],
                            ),
                            leading: Icon(Icons.phone),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        } else {
          return const Center(child: CircularProgressIndicator());
        }
      },
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