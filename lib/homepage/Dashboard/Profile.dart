import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloudinary/cloudinary.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:loginpage/homepage/Dashboard/profileedit.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Hive/user_profile.dart';
import 'CompanyDetails.dart';
import 'Settingspage.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  File? selectedImage;
  late Box<UserProfile> profileBox;
  String? userid;
  bool isOnline = false;
  StreamSubscription? connectivitySubscription;

  @override
  void initState() {
    super.initState();
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? user = auth.currentUser;
    if (user != null) {
      final uid = user.uid;
      setState(() {
        userid = uid;
      });
    }
    profileBox = Hive.box<UserProfile>('profileBox');
    _loadImage();
    _checkConnectivity();
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isOnline = connectivityResult != ConnectivityResult.none;
    });

    connectivitySubscription = Connectivity().onConnectivityChanged.listen((result) {
      setState(() {
        isOnline = result != ConnectivityResult.none;
      });
    });
  }

  Future<void> saveImagePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userid!, path);
  }

  Future<String?> getImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(userid!);
  }

  Future<void> _loadImage() async {
    final path = await getImagePath();
    if (path != null && mounted) {
      setState(() {
        selectedImage = File(path);
      });
    }
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>>? nihal() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return FirebaseFirestore.instance
          .collection('user')
          .doc(user.uid)
          .snapshots();
    }
    return null;
  }

  @override
  void dispose() {
    connectivitySubscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    var userProfile = userid != null ? profileBox.get(userid!) : null;

    return StreamBuilder<DocumentSnapshot>(
      stream: userid != null ? nihal() : null,
      builder: (context, snapshot) {
        final data = snapshot.data;

        return Scaffold(
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: const Text(
              "Profile Page",
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
          body: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                // Profile Header
                Row(
                  children: <Widget>[
                    CircleAvatar(
                      radius: 45,
                      backgroundColor: Colors.white,
                      backgroundImage: (selectedImage != null)
                          ? FileImage(selectedImage!) as ImageProvider
                          : (isOnline && data != null && data['url'] != null && data['url'].isNotEmpty)
                          ? NetworkImage(data['url'])
                          : (userProfile?.imagePath != null)
                          ? FileImage(File(userProfile!.imagePath!)) as ImageProvider
                          : const AssetImage('assets/profile.jpeg') as ImageProvider,
                      child:
                      selectedImage == null ?
                      Center(child: Icon(Icons.person,size: 30,)):
                      SizedBox(),
                    ),
                    const SizedBox(width: 20),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          isOnline
                              ? (data?["name"] ?? "No Name")
                              : (userProfile?.name ?? data?["name"] ?? "No Name"),
                          style: const TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isOnline
                              ? (data?["email"] ?? userProfile?.email ?? "No Email")
                              : (userProfile?.email ?? data?["email"] ?? "No Email"),
                          style: TextStyle(color: Colors.grey[700]),
                        ),
                        const SizedBox(height: 4),
                      ],
                    ),
                    const SizedBox(width: 77),
                  ],
                ),
                const SizedBox(height: 20),
                const Text(
                  'Options',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 10),
                ListView(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  children: <Widget>[
                    ListTile(
                      title: const Text('Profile'),
                      leading: const Icon(Icons.person),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => Profile()),
                        );
                        setState(() {
                          _loadImage();
                          userProfile = userid != null ? profileBox.get(userid!) : null;
                        });
                      },
                    ),
                    ListTile(
                      title: const Text('Company Details'),
                      leading: const Icon(Icons.home_sharp),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => Companydetails()),
                        );
                      },
                    ),
                    ListTile(
                      title: const Text('Settings'),
                      leading: const Icon(Icons.settings),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => Settingspage()),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        );
      },
    );
  }
}


