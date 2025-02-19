import 'dart:async';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

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
  int _requiredWorkTime = 0;
  bool _isOffline = false;
  late StreamSubscription<ConnectivityResult> _connectivitySubscription;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchWorkTime();
    _fetchRequiredWorkTime();
    _checkConnectivity();
    _connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        setState(() {
          _isOffline = false;
        });
        _fetchWorkTime();
      } else {
        setState(() {
          _isOffline = true;
        });
      }
    });
  }

  Future<void> _checkConnectivity() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult == ConnectivityResult.none) {
      setState(() {
        _isOffline = true;
      });
    } else {
      setState(() {
        _isOffline = false;
      });
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
    setState(() {
      checkInTime = null;
      checkOutTime = null;
      workTime = 0;
    });
    if (_uid == null) return;
    setState(() {
      _isLoading = true;
    });
    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);
    final querySnapshot = await _firestore
        .collection('Attendance')
        .where('UserId', isEqualTo: _uid)
        .where('Date', isEqualTo: formattedDate)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final data = doc.data();
      final int? storedCheckInMillis = data['CheckInTime'];
      final int? storedCheckOutMillis = data['LogoutTime'];
      setState(() {
        _currentAttendanceId = doc.id;
        checkInTime = data['Login'];
        checkOutTime = data['Logout'];
        checkInMillis = storedCheckInMillis;
        workTime = data['WorkTime'] ?? 0;
        _isCheckedIn =
            storedCheckInMillis != null && storedCheckOutMillis == null;
      });
      if (_isCheckedIn) {
        _startTimer();
      }
    }
    setState(() {
      _isLoading = false;
    });
  }

  void _startTimer() {
    if (_isCheckedIn && checkInMillis != null) {
      _timer?.cancel();

      int nowMillis = DateTime.now().millisecondsSinceEpoch;
      setState(() {
        workTime += (nowMillis - checkInMillis!);
        checkInMillis = nowMillis;
      });

      _timer = Timer.periodic(Duration(seconds: 1), (timer) {
        setState(() {
          int nowMillis = DateTime.now().millisecondsSinceEpoch;
          workTime += (nowMillis - checkInMillis!);
          checkInMillis = nowMillis;
        });
      });
    }
  }

  void _stopTimer() {
    _timer?.cancel();
  }

  Future<void> _recordCheckIn() async {
    if (_isOffline) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Network required to check in',
          ),
        ),
      );
      return;
    }

    if (_creatorName == null || _creatorRole == null || _uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User information not found!')),
      );
      return;
    }

    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);
    final formattedTime = DateFormat('hh:mm a').format(now);
    final nowMillis = now.millisecondsSinceEpoch;
    final querySnapshot = await _firestore
        .collection('Attendance')
        .where('UserId', isEqualTo: _uid)
        .where('Date', isEqualTo: formattedDate)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final data = doc.data();

      if (data['CheckInTime'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You have already checked in today.')),
        );
        return;
      }
    }

    final docRef = await _firestore.collection('Attendance').add({
      'UserId': _uid,
      'name': _creatorName,
      'role': _creatorRole,
      'Date': formattedDate,
      'Login': formattedTime,
      'CheckInTime': nowMillis,
      'Logout': null,
      'LogoutTime': null,
      'WorkTime': 0,
    });

    setState(() {
      _currentAttendanceId = docRef.id;
      checkInTime = formattedTime;
      checkOutTime = null;
      checkInMillis = nowMillis;
      workTime = 0;
      _isCheckedIn = true;
    });

    _startTimer();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Checked in at $formattedTime')),
    );
  }


  Future<void> _recordCheckOut() async {
    final now = DateTime.now();
    final formattedTime = DateFormat('hh:mm a').format(now);
    final nowMillis = now.millisecondsSinceEpoch;

    final querySnapshot = await _firestore
        .collection('Attendance')
        .where('UserId', isEqualTo: _uid)
        .where('Date', isEqualTo: DateFormat('yyyy-MM-dd').format(now))
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final data = doc.data();

      if (data['LogoutTime'] != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You have already checked out today.')),
        );
        return;
      }

      int totalWorkTime = workTime;

      await _firestore.collection('Attendance').doc(doc.id).update({
        'Logout': formattedTime,
        'LogoutTime': nowMillis,
        'WorkTime': totalWorkTime,
      });

      _stopTimer();
      setState(() {
        _isCheckedIn = false;
        checkOutTime = formattedTime;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checked out at $formattedTime')),
      );
    }
  }

  String formatDuration(int milliseconds) {
    final duration = Duration(milliseconds: milliseconds);
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    return "${twoDigits(duration.inHours)}:${twoDigits(duration.inMinutes.remainder(60))}:${twoDigits(duration.inSeconds.remainder(60))}";
  }

  @override
  void dispose() {
    _stopTimer();
    _connectivitySubscription.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "CheckIn and CheckOut",
          style: TextStyle(fontWeight: FontWeight.w600, color: Colors.black),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        elevation: 0,
        automaticallyImplyLeading: false,
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
              if (_isLoading) Center(child: CircularProgressIndicator()),
              if (!_isLoading) ...[
                Card(
                  elevation: 10,
                  shadowColor: Colors.blueGrey,
                  margin: EdgeInsets.all(10),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15)),
                  child: Padding(
                    padding: const EdgeInsets.all(20.0),
                    child: Column(
                      children: [
                        _creatorRole == 'employee'
                            ? Text(
                                "Required Work Time: ${(_requiredWorkTime ~/ 60000) ~/ 60} hours",
                                style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w600,
                                    color: Colors.black),
                              )
                            : SizedBox.shrink(),
                        SizedBox(height: 10),
                        Text(
                          "Check-in: ${checkInTime ?? '--:--'}",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 10),
                        Text(
                          "Check-out: ${checkOutTime ?? '--:--'}",
                          style: TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w600),
                        ),
                        SizedBox(height: 10),
                        Container(
                          padding: EdgeInsets.all(50),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            shape: BoxShape.circle,
                          ),
                          child: Column(
                            children: [
                              Text("Work Time:"),
                              Text(
                                formatDuration(workTime),
                                style: TextStyle(
                                  fontSize: 22,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.black,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                SizedBox(height: 20),
                if (!_isCheckedIn)
                  ElevatedButton.icon(
                    onPressed: _recordCheckIn,
                    icon: Icon(Icons.login, color: Colors.white),
                    label:
                        Text('Check-in', style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown.shade300,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
                SizedBox(height: 10),
                if (_isCheckedIn)
                  ElevatedButton.icon(
                    onPressed:
                        workTime >= _requiredWorkTime ? _recordCheckOut : null,
                    icon: Icon(Icons.exit_to_app, color: Colors.white),
                    label: Text('Check-out',
                        style: TextStyle(color: Colors.white)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.brown.shade300,
                      minimumSize: Size(double.infinity, 50),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(15)),
                    ),
                  ),
              ],
            ]
        ),
      ),
    );
  }
}
