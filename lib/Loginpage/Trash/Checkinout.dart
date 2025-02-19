import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import 'dart:async';

class CheckInOutPage extends StatefulWidget {
  CheckInOutPage({super.key});

  @override
  _CheckInOutPageState createState() => _CheckInOutPageState();
}
class _CheckInOutPageState extends State<CheckInOutPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  Duration _elapsedTimeSinceCheckIn = Duration.zero;
  String? _creatorName;
  String? _creatorRole;
  String? _uid;
  String? _checkInTime;
  String? _checkOutTime;
  final Stopwatch _stopwatch = Stopwatch();
  Timer? _timer;
  DateTime? _checkInDateTime;
  String? _workedTime;

  @override
  void initState() {
    super.initState();
    _fetchUserData();
    _fetchLastCheckIn();
  }

  String _formatElapsedTimeSinceCheckIn() {
    final hours = _elapsedTimeSinceCheckIn.inHours;
    final minutes = _elapsedTimeSinceCheckIn.inMinutes % 60;
    final seconds = _elapsedTimeSinceCheckIn.inSeconds % 60;
    return '$hours hrs $minutes min $seconds sec';
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

  Future<void> _fetchLastCheckIn() async {
    if (_uid == null) return;

    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);

    final querySnapshot = await _firestore
        .collection('Attendance')
        .where('UserId', isEqualTo: _uid)
        .where('Date', isEqualTo: formattedDate)
        .orderBy('Login', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final loginTime = doc['Login'];
      final logoutTime = doc['Logout'];
      final workedTime = doc['WorkedTime'];

      setState(() {
        _checkInTime = loginTime;
        _checkOutTime = logoutTime;
        _workedTime = workedTime;
      });

      if (logoutTime == null) {
        final checkInTime = DateFormat('hh:mm a').parse(loginTime);
        _checkInDateTime = DateTime(now.year, now.month, now.day, checkInTime.hour, checkInTime.minute);

        final elapsedTime = now.difference(_checkInDateTime!);

        _stopwatch.reset();
        _stopwatch.start();
        _elapsedTimeSinceCheckIn = elapsedTime;
        _startStopwatch();
      }
    }
  }

  void _startStopwatch() {
    _stopwatch.start();
    _timer = Timer.periodic(Duration(seconds: 1), (timer) {
      setState(() {
        _elapsedTimeSinceCheckIn = DateTime.now().difference(_checkInDateTime!);
      });
    });
  }

  void _stopStopwatch() {
    _stopwatch.stop();
    _timer?.cancel();
  }

  Future<void> _recordCheckIn() async {
    if (_creatorName == null || _creatorRole == null || _uid == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('User information not found!')),
      );
      return;
    }

    final now = DateTime.now();
    final formattedDate = DateFormat('yyyy-MM-dd').format(now);
    final formattedTime = DateFormat('hh:mm a').format(now);

    await _firestore.collection('Attendance').add({
      'UserId': _uid,
      'name': _creatorName,
      'role': _creatorRole,
      'Date': formattedDate,
      'Login': formattedTime,
      'LoginTimestamp': FieldValue.serverTimestamp(),
      'Logout': null,
      'LogoutTimestamp': null,
      'WorkedTime': null, // Initialize worked time as null
    });

    setState(() {
      _checkInTime = formattedTime;
      _checkOutTime = null;
      _workedTime = null; // Reset worked time
      _stopwatch.reset();
    });
    _checkInDateTime = now;

    _startStopwatch();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Checked in at $formattedTime')),
    );
  }

  Future<void> _recordCheckOut() async {
    if (_uid == null || _checkInTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No active check-in found!')),
      );
      return;
    }

    final now = DateTime.now();
    final formattedTime = DateFormat('hh:mm a').format(now);

    final querySnapshot = await _firestore
        .collection('Attendance')
        .where('UserId', isEqualTo: _uid)
        .where('Date', isEqualTo: DateFormat('yyyy-MM-dd').format(now))
        .where('Logout', isEqualTo: null)
        .orderBy('Login', descending: true)
        .limit(1)
        .get();

    if (querySnapshot.docs.isNotEmpty) {
      final doc = querySnapshot.docs.first;
      final workedTime = _formatElapsedTimeSinceCheckIn();

      await _firestore.collection('Attendance').doc(doc.id).update({
        'Logout': formattedTime,
        'LogoutTimestamp': FieldValue.serverTimestamp(),
        'WorkedTime': workedTime, // Save worked time
      });

      _stopStopwatch();

      setState(() {
        _checkOutTime = formattedTime;
        _workedTime = workedTime;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Checked out at $formattedTime')),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('No active check-in record found!')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        title: Text('Check-in/Check-out'),
        centerTitle: true,
        backgroundColor: Colors.grey.shade300,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_checkInTime != null)
              Card(
                elevation: 5,
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      Text(
                        'Check-in: $_checkInTime',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      SizedBox(height: 10),
                      if (_checkOutTime != null)
                        Text(
                          'Check-out: $_checkOutTime',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                      SizedBox(height: 10),
                      Text(
                        'Worked Time: ${_workedTime ?? _formatElapsedTimeSinceCheckIn()}',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.blue),
                      ),
                    ],
                  ),
                ),
              ),
            SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _recordCheckIn,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.green,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('Check-in', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
            SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _recordCheckOut,
                style: ElevatedButton.styleFrom(
                  padding: EdgeInsets.symmetric(vertical: 16),
                  backgroundColor: Colors.red,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text('Check-out', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}