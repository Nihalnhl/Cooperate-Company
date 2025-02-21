import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:local_auth/local_auth.dart';
import 'package:loginpage/Hive/attendance_model.dart';
import 'package:loginpage/Loginpage/Signup.dart';
import 'package:loginpage/homepage/Dashboard/bottomnavigation.dart';

import '../Hive/leave_request_model.dart';
import '../Hive/user_profile.dart';
import '../Hive/work_details_model.dart';


class BiometricLoginPage extends StatefulWidget {
  @override
  _BiometricLoginPageState createState() => _BiometricLoginPageState();
}

class _BiometricLoginPageState extends State<BiometricLoginPage> {
  final LocalAuthentication myauthentication = LocalAuthentication();
  bool authState = false;
  bool isLoading = false;
  String? role;

  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passController = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  @override
  void initState() {
    super.initState();
    myauthentication.isDeviceSupported().then((bool isSupported) {
      if (mounted) {
        setState(() {
          authState = isSupported;
        });
      }
    });
    _checkUserRole();
  }
  List<Map<String, dynamic>> currentData = [];

  Future<void> storeUserRole(String role) async {
    var box = await Hive.openBox('userBox');
    await box.put('role', role);
  }

  void _submitForm() async {
    print('Login started...');
    if (_formKey.currentState?.validate() ?? false) {
      setState(() {
        isLoading = true;
      });

      final email = _emailController.text;
      final password = _passController.text;

      try {
        final userCredential = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: email,
          password: password,
        );

        await Future.delayed(Duration(seconds: 2));
        final User? user = FirebaseAuth.instance.currentUser;

        if (user != null) {
          print('User logged in: ${user.uid}');

          final role = await _fetchUserRoleFromFirestore(user.uid);
          await storeUserRole(role);
          await fetchAndStoreLeaveRecords();
          await fetchAndStoreAttendance();
          await fetchAndStoreUserProfile(user.uid);
          await fetchAndStoreWorkDetails();

          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (context) => Bar()),
          );
        } else {
          print('User not found after login.');
        }
      } catch (e) {
        print('Error during login: $e');
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  Future<String> _fetchUserRoleFromFirestore(String userId) async {
    final userDoc = await FirebaseFirestore.instance.collection('user').doc(userId).get();
    final role = userDoc['role'];
    return role;
  }
  Future<void> fetchAndStoreLeaveRecords() async {
    try {

      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        print('No authenticated user. Aborting fetchAndStoreLeaveRecords.');
        return;
      }
      final leaveRequestBox = await Hive.openBox<LeaveRequest>('leaveRequestsBox');
      final querySnapshot = await FirebaseFirestore.instance.collection('leave_records').get();
      await leaveRequestBox.clear();
      for (var doc in querySnapshot.docs) {

        final leaveRequest = LeaveRequest.fromMap({
          ...doc.data(),
          'id': doc.id,
        });
        await leaveRequestBox.put(doc.id, leaveRequest);
      }
      print('Leave records successfully fetched and stored in Hive.');
    } catch (e) {
      print('Error fetching or storing leave records: $e');
    }
  }
  Future<String?> getUserRole() async {
    var box = await Hive.openBox('userBox');
    return box.get('role');
  }
  void _checkUserRole() async {
    final role = await getUserRole();
    if (role != null) {
      print('User role fetched from Hive: $role');
    } else {
      print('No role found in Hive, please ensure the user is logged in');
    }
  }

  Future<void> fetchAndStoreUserProfile(String userId) async {
      try {
        final DocumentSnapshot userDoc = await FirebaseFirestore.instance
            .collection('user')
            .doc(userId)
            .get();

        if (userDoc.exists) {
          final Box<UserProfile> profileBox = await Hive.openBox<UserProfile>('profileBox');
          final UserProfile userProfile = UserProfile(
            name: userDoc['name'],
            email: userDoc['email'],
            address: userDoc['address'],
            phone: userDoc['phone'],
            role: userDoc['role'],
            imagePath: userDoc['url'],
            isSynced: true,
          );

          await profileBox.put(userId, userProfile);
          print("User profile data fetched and stored in Hive");
        }
      } catch (error) {
        print('Failed to fetch and store user profile: $error');
      }
    }
  Future<void> fetchAndStoreWorkDetails() async {
    try {

      final workDetailsSnapshot = await FirebaseFirestore.instance.collection('workDetails').get();

      final List<WorkDetails> workDetailsList = workDetailsSnapshot.docs.map((doc) {
        return WorkDetails.fromMap(doc.data());
      }).toList();
      final box = await Hive.openBox<WorkDetails>('workDetails');

      for (var workDetail in workDetailsList) {
        box.put(workDetail.id, workDetail);
      }

      print('WorkDetails saved to Hive successfully!');
    } catch (e) {
      print('Error fetching and storing workDetails: $e');
    }
  }

  Future<void> fetchAndStoreAttendance() async {
    try {
      final QuerySnapshot snapshot = await FirebaseFirestore.instance
          .collection('Attendance')
          .orderBy('Date', descending: false)
          .get();

      final Box<Attendance> attendanceBox = await Hive.openBox<Attendance>('attendanceBox');
      attendanceBox.clear();
      for (var doc in snapshot.docs) {
        attendanceBox.add(Attendance(
          name: doc['name'],
          date: doc['Date'],
          login: doc['Login'],
          logout: doc['Logout'],
        ));
      }
      print("Attendance data fetched and stored in Hive.");
    } catch (error) {
      print('Failed to fetch and store Attendance records: $error');
    }
  }

  Future<void> authentication() async {
    try {
      bool authenticated = await myauthentication.authenticate(
        localizedReason: "Authenticate to proceed",
        options: AuthenticationOptions(stickyAuth: true, biometricOnly: true),
      );
      if (authenticated) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (context) => Bar()));
      }
    } on PlatformException catch (e) {
      print(e);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              SizedBox(height: 80),
              Text(
                "Welcome Back",
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              SizedBox(height: 10),
              Text(
                "Log in to continue",
                style: TextStyle(fontSize: 16, color: Colors.black54),
              ),
              SizedBox(height: 40),
              Image.asset("assets/log.png", height: 150),
              SizedBox(height: 30),
              Form(
                key: _formKey,
                child: Column(
                  children: [
                    buildTextField("Email", Icons.mail, _emailController, false),
                    SizedBox(height: 20),
                    buildTextField("Password", Icons.lock, _passController, true),
                    SizedBox(height: 30),
                    isLoading
                        ? CircularProgressIndicator(color: Colors.blueAccent)
                        : buildLoginButton(),
                    SizedBox(height: 20),
                    TextButton(
                      onPressed: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (context) => SignUpPage()),
                      ),
                      child: Text(
                        "Don't have an account? Sign up",
                        style: TextStyle(color: Colors.brown.shade300, fontSize: 16),
                      ),
                    ),
                    SizedBox(height: 20),
                    buildBiometricButton(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget buildTextField(String hint, IconData icon, TextEditingController controller, bool obscure) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      style: TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.black45),
        prefixIcon: Icon(icon, color: Colors.brown.shade300),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.brown.shade300, width: 1),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter $hint';
        if (hint == "Email" && !RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        if (hint == "Password" && value.length < 6) return 'Password must be at least 6 characters';
        return null;
      },
    );
  }

  Widget buildLoginButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.brown.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 5,
        ),
        onPressed: _submitForm,
        child: Text("Login", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }

  Widget buildBiometricButton() {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.green.shade600,
        padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        elevation: 5,
      ),
      onPressed: authentication,
      icon: Icon(Icons.fingerprint, size: 28, color: Colors.white),
      label: Text("Login with Biometrics", style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
    );
  }
}
