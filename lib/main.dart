import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_easyloading/flutter_easyloading.dart';
import 'package:get/get.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:loginpage/Hive/user_profile.dart';
import 'package:loginpage/Loginpage/wrap.dart';
import 'package:loginpage/Splashscreen.dart';

import 'Hive/attendance_model.dart';
import 'Hive/company_model.dart';
import 'Hive/leave_request_model.dart';
import 'Hive/work_details_model.dart';
import 'homepage/Dashboard/Attendancemark.dart';
import 'homepage/Dashboard/bottomnavigation.dart';
import 'homepage/Dashboard/profileedit.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  await Hive.initFlutter();
  Get.put(NavigationController());
  FirebaseFirestore.instance.settings = Settings(persistenceEnabled: true);

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(UserProfileAdapter());
  }
  await Hive.openBox<UserProfile>('profileBox');

  if (!Hive.isAdapterRegistered(1)) {
    Hive.registerAdapter(AttendanceAdapter());
  }
  await Hive.openBox<Attendance>('attendanceBox');
  if (!Hive.isAdapterRegistered(5)) {
    Hive.registerAdapter(WorkDetailsAdapter());
  }
    await Hive.openBox<WorkDetails>('workDetails');

  if (!Hive.isAdapterRegistered(3)) {
    Hive.registerAdapter(LeaveRequestAdapter());
  }
  await Hive.openBox<LeaveRequest>('leaveRequestsBox');
  if (!Hive.isAdapterRegistered(6)) {
    Hive.registerAdapter(CompanyAdapter());
  }
  await Hive.openBox<Company>('companyBox');
  final connectivityService = ConnectivityService();
  connectivityService.initialize();

  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Biometric Login',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: SplashScreen(),
      builder: EasyLoading.init(),
      debugShowCheckedModeBanner: false,
    );
  }
}
