import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:loginpage/Hive/user_profile.dart';
import '../../Hive/attendance_model.dart';

class CheckInOutPage1 extends StatefulWidget {
  CheckInOutPage1({super.key});
  @override
  _CheckInOutPageState createState() => _CheckInOutPageState();
}

class _CheckInOutPageState extends State<CheckInOutPage1> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  String? _currentAttendanceId;
  String? _creatorName;
  String? _creatorRole;
  String? _uid;
  String? checkInTime;
  String? checkOutTime;
  int workTime = 0;
  int? checkInMillis;
  Timer? _timer;
  bool _isLoading = false;
  bool _isCheckedIn = false;
  int _requiredWorkTime = 8 * 60 * 60 * 1000;

  @override
  void initState() {
    super.initState();
    _initializeData();
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        _syncDataToFirestore();
      }
    });
  }

  Future<void> _initializeData() async {
    setState(() => _isLoading = true);
    await Future.wait([
      _fetchUserData(),
      _fetchWorkTime(),
      _fetchRequiredWorkTime(),
      _fetchHiveData(),
    ]);
    setState(() => _isLoading = false);
  }

  Future<void> _fetchHiveData() async {
    var box = Hive.box<Attendance>('attendanceBox');
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);
    Attendance? attendance = box.get(formattedDate);

    if (attendance != null) {
      setState(() {
        checkInTime = attendance.Login;
        checkOutTime = attendance.Logout;
        checkInMillis = attendance.checkInMillis;
        workTime = attendance.workTime;
        _isCheckedIn =
            attendance.checkInMillis != null && attendance.logoutMillis == null;
      });

      if (_isCheckedIn) {
        _startTimer();
      }
    }
  }

  Future<void> _fetchUserData() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      setState(() {
        _uid = user.uid;
      });
      final userDoc = await _firestore.collection('user').doc(_uid).get();
      if (userDoc.exists) {
        final data = userDoc.data() as Map<String, dynamic>;
        setState(() {
          _creatorName = data['name'];
          _creatorRole = data['role'];
        });
      }
    }
  }

  Future<void> _fetchRequiredWorkTime() async {
    final User? user = _auth.currentUser;
    if (user != null) {
      final doc = await _firestore.collection('user').doc(_uid).get();
      if (doc.exists) {
        setState(() {
          _requiredWorkTime = doc.data()!['requiredWorkTime'] ?? 0;
        });
      }
    }
  }

  Future<void> _fetchWorkTime() async {
    if (!mounted) return;
    setState(() {
      checkInTime = null;
      checkOutTime = null;
      workTime = 0;
    });

    if (_uid == null) return;

    if (!mounted) return;
    setState(() {});

    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);

    final querySnapshot = await _firestore
        .collection('Attendance')
        .where('UserId', isEqualTo: _uid)
        .where('Date', isEqualTo: formattedDate)
        .get();

    if (!mounted) return;

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final data = doc.data();
      final int? storedCheckInMillis = data['CheckInTime'];
      final int? storedCheckOutMillis = data['LogoutTime'];

      if (mounted) {
        setState(() {
          _currentAttendanceId = doc.id;
          checkInTime = data['Login'];
          checkOutTime = data['Logout'];
          checkInMillis = storedCheckInMillis;
          workTime = data['WorkTime'] ?? 0;
          _isCheckedIn =
              storedCheckInMillis != null && storedCheckOutMillis == null;
        });
      }

      if (_isCheckedIn) {
        _startTimer();
      }
    }
  }

  void _startTimer() {
    _timer?.cancel();
    if (_isCheckedIn && checkInMillis != null) {
      _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
        if (mounted) {
          setState(() {
            int nowMillis = DateTime.now().millisecondsSinceEpoch;
            workTime = nowMillis - checkInMillis!;
          });
        }
      });
    }
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  Future<void> _recordCheckIn() async {
    if (_creatorName == null || _creatorRole == null || _uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User information not found!')),
      );
      return;
    }

    setState(() {
      _isLoading = true;
    });

    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);
    final formattedTime = DateFormat('hh:mm a').format(now);
    final nowMillis = now.millisecondsSinceEpoch;

    var attendanceBox = Hive.box<Attendance>('attendanceBox');

    var querySnapshot = await _firestore
        .collection('Attendance')
        .where('UserId', isEqualTo: _uid)
        .where('Date', isEqualTo: formattedDate)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('You have already checked in today.'),
            backgroundColor: Colors.red),
      );
      return;
    }
    setState(() {
      checkInTime = formattedTime;
      checkOutTime = null;
      checkInMillis = nowMillis;
      workTime = 0;
      _isCheckedIn = true;
      _isLoading = false;
    });

    _startTimer();

    var box = Hive.box<UserProfile>('profileBox');
    UserProfile? userProfile = box.get(_uid);

    if (userProfile == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User profile not found!')),
      );
      return;
    }

    Attendance attendance = Attendance(
      UserId: _uid!,
      Date: formattedDate,
      Login: formattedTime,
      checkInMillis: nowMillis,
      workTime: 0,
      isSynced: false,
      name: userProfile.name,
      role: userProfile.role,
    );

    attendanceBox.put(formattedDate, attendance);
    print("Check-in data saved to Hive: ${attendance.toJson()}");

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
          content: Text('Checked in at $formattedTime'),
          backgroundColor: Colors.green),
    );

    Future.delayed(Duration(seconds: 2), () {
      _syncDataToFirestore();
    });
  }

  Future<void> _syncDataToFirestore() async {
    if (_uid == null) return;
    var box = Hive.box<Attendance>('attendanceBox');

    for (var key in box.keys) {
      Attendance attendance = box.get(key)!;

      if (!attendance.isSynced) {
        try {
          var querySnapshot = await _firestore
              .collection('Attendance')
              .where('UserId', isEqualTo: _uid)
              .where('Date', isEqualTo: attendance.Date)
              .get();

          if (querySnapshot.docs.isNotEmpty) {
            await _firestore
                .collection('Attendance')
                .doc(querySnapshot.docs.first.id)
                .update({
              'Logout': attendance.Logout,
              'LogoutTime': attendance.logoutMillis,
              'WorkTime': attendance.workTime,
              'name': attendance.name,
              'role': attendance.role,
            });
          } else {
            await _firestore.collection('Attendance').add({
              'UserId': attendance.UserId,
              'Date': attendance.Date,
              'Login': attendance.Login,
              'CheckInTime': attendance.checkInMillis,
              'Logout': attendance.Logout,
              'LogoutTime': attendance.logoutMillis,
              'WorkTime': attendance.workTime,
              'name': attendance.name,
              'role': attendance.role,
            });
          }

          attendance.isSynced = true;
          attendance.save();
          print("Synced data to Firestore");
        } catch (e) {
          print("Error syncing data: $e");
        }
      }
    }
    _clearHiveData();
  }

  Future<void> _clearHiveData() async {
    var box = Hive.box<Attendance>('attendanceBox');
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);
    await box.delete(formattedDate);
    print("Hive data cleared for date: $formattedDate");
  }

  Future<void> _recordCheckOut() async {
    setState(() {
      _isLoading = true;
    });
    final now = DateTime.now();
    final formattedTime = DateFormat('hh:mm a').format(now);
    final nowMillis = now.millisecondsSinceEpoch;
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);
    final querySnapshot = await _firestore
        .collection('Attendance')
        .where('UserId', isEqualTo: _uid)
        .where('Date', isEqualTo: formattedDate)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final data = doc.data();

      if (data['LogoutTime'] != null) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('You have already checked out today.'),
            backgroundColor: Colors.red,
          ),
        );
        return;
      }

      var box = Hive.box<Attendance>('attendanceBox');
      Attendance? attendance = box.get(formattedDate);

      if (attendance != null) {
        attendance.Logout = formattedTime;
        attendance.logoutMillis = nowMillis;
        attendance.workTime = workTime;
        attendance.isSynced = false;
        attendance.save();
        print("Check-out data saved to Hive: ${attendance.toJson()}");
      } else {
        print("Error: No check-in record found for today in Hive.");
      }
      _stopTimer();
      try {
        await _firestore.collection('Attendance').doc(doc.id).update({
          'Logout': formattedTime,
          'LogoutTime': nowMillis,
          'WorkTime': workTime,
        });
        print("Check-out data updated in Firestore.");
      } catch (e) {
        print("Error updating Firestore: $e");
      }

      setState(() {
        checkOutTime = formattedTime;
        _isCheckedIn = false;
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Checked out at $formattedTime'),
          backgroundColor: Colors.red,
        ),
      );
      _syncDataToFirestore();
    } else {
      setState(() => _isLoading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('No check-in record found for today.'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  String formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  double get _progressValue {
    return (workTime / _requiredWorkTime).clamp(0.0, 1.0);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text(
          "Attendance",
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        automaticallyImplyLeading: false,
        centerTitle: true,
        elevation: 0,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              SizedBox(
                height: 15,
              ),
              _isLoading
                  ? Center(
                      child: SpinKitFadingCircle(
                        color: Colors.brown,
                        size: 50.0,
                      ),
                    )
                  : Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          children: [
                            Card(
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: _TimeCard(
                                            title: 'Check-in',
                                            time: checkInTime ?? '--:--',
                                            icon: Icons.login,
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Expanded(
                                          child: _TimeCard(
                                            title: 'Check-out',
                                            time: checkOutTime ?? '--:--',
                                            icon: Icons.logout,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      height: 200,
                                      width: 200,
                                      child: Stack(
                                        fit: StackFit.expand,
                                        children: [
                                          CircularProgressIndicator(
                                            value: _progressValue,
                                            strokeWidth: 12,
                                            backgroundColor: Colors.grey[200],
                                            valueColor:
                                                AlwaysStoppedAnimation<Color>(
                                              Colors.brown[400]!,
                                            ),
                                          ),
                                          Center(
                                            child: Column(
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                const Icon(
                                                  Icons.timer,
                                                  size: 24,
                                                  color: Colors.grey,
                                                ),
                                                const SizedBox(height: 8),
                                                Text(
                                                  formatDuration(workTime),
                                                  style: const TextStyle(
                                                    fontSize: 24,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const Text(
                                                  'Work Time',
                                                  style: TextStyle(
                                                    color: Colors.grey,
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_creatorRole == 'employee') ...[
                                      const SizedBox(height: 12),
                                      Text(
                                        'Required: ${formatDuration(_requiredWorkTime)}',
                                        style: const TextStyle(
                                          color: Colors.grey,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                    const SizedBox(height: 24),
                                    SizedBox(
                                      width: double.infinity,
                                      child: ElevatedButton.icon(
                                        onPressed: _isCheckedIn
                                            ? (workTime >= _requiredWorkTime
                                                ? _recordCheckOut
                                                : null)
                                            : _recordCheckIn,
                                        icon: Icon(
                                          _isCheckedIn
                                              ? Icons.logout
                                              : Icons.login,
                                          color: Colors.white,
                                        ),
                                        label: Text(
                                          _isCheckedIn
                                              ? 'Check-out'
                                              : 'Check-in',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 16,
                                          ),
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: Colors.brown[400],
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 16,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(12),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            const SizedBox(height: 16),
                            Card(
                              elevation: 1,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(16.0),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: const [
                                        Icon(Icons.calendar_today,
                                            size: 16, color: Colors.grey),
                                        SizedBox(width: 8),
                                        Text(
                                          "Today's Progress",
                                          style: TextStyle(
                                            color: Colors.grey,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 12),
                                    ClipRRect(
                                      borderRadius: BorderRadius.circular(4),
                                      child: LinearProgressIndicator(
                                        value: _progressValue,
                                        backgroundColor: Colors.grey[200],
                                        valueColor:
                                            AlwaysStoppedAnimation<Color>(
                                          Colors.brown[400]!,
                                        ),
                                        minHeight: 8,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
            ],
          ),
        ),
      ),
    );
  }
}

class _TimeCard extends StatelessWidget {
  final String title;
  final String time;
  final IconData icon;

  const _TimeCard({
    required this.title,
    required this.time,
    required this.icon,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: Colors.grey),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(
                  color: Colors.grey,
                  fontSize: 14,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            time,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}
