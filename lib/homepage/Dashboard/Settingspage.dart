import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:loginpage/homepage/Dashboard/Worktime.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../Loginpage/loginpage.dart';
import '../Settings/changepass.dart';
import '../Settings/privacypolicy.dart';
import '../Settings/terms.dart';

class Settingspage extends StatefulWidget {
  const Settingspage({super.key});

  @override
  State<Settingspage> createState() => _SettingspageState();
}

class _SettingspageState extends State<Settingspage> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  String? role;
  String userid = '';
  final FlutterSecureStorage storage = FlutterSecureStorage();
  Future<void> signout() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No internet connection. Please try again later.'),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 3),
        ),
      );
      return;
    }

    try {
      await FirebaseAuth.instance.signOut();
      // await storage.delete(key: 'email');
      // await storage.delete(key: 'password');
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('profileImagePath');

      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BiometricLoginPage()),
      );
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Successfully Sign out'),
          backgroundColor: Colors.green,
          duration: Duration(seconds: 3),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error logging out: $e'),
          duration: Duration(seconds: 3),
        ),
      );
    }
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  void getData() {
    final User? user = auth.currentUser;
    final uid = user!.uid;

    FirebaseFirestore.instance
        .collection('user')
        .doc(uid)
        .get()
        .then((DocumentSnapshot docusnapshot) {
      if (docusnapshot.exists) {
        final data = docusnapshot.data() as Map<String, dynamic>?;
        if (mounted) {
          setState(() {
            role = data!['role'];
          });
        }
      } else {
        print('Document does not exist in database');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Settings"),
      ),
      body: Column(
        children: [
          ListView(
            shrinkWrap: true,
            physics: NeverScrollableScrollPhysics(),
            children: [
              ListTile(
                title: Text('Change Password'),
                leading: Icon(Icons.password),
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => ChangePass()));
                },
              ),
              ListTile(
                title: Text('Privacy Policy'),
                leading: Icon(Icons.policy),
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => Privacypolicy()));
                },
              ),
              ListTile(
                title: Text('Terms of use'),
                leading: Icon(Icons.insert_page_break_rounded),
                onTap: () {
                  Navigator.push(context,
                      MaterialPageRoute(builder: (context) => Terms()));
                },
              ),
              role == 'teamlead' || role == 'admin'
                  ? ListTile(
                title: Text('Work Time'),
                leading: Icon(Icons.policy),
                onTap: () {
                  Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (context) => SetWorkTimePage()));
                },
              )
                  : SizedBox(),
              ListTile(
                title: Text('Logout'),
                leading: Icon(Icons.logout),
                onTap: signout,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
