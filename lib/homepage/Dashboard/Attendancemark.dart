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
  int _requiredWorkTime = 8 * 60 * 60 * 1000;
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
  double get _progressValue {
    return (workTime / _requiredWorkTime).clamp(0.0, 1.0);
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
            children: [
              SizedBox(
                height: 15,
              ),
              if (_isOffline)
                Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.wifi_off, color: Colors.red[700], size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'You are currently offline. Check-in/out requires network connectivity.',
                          style: TextStyle(color: Colors.red[700]),
                        ),
                      ),
                    ],
                  ),
                ),
              if (_isLoading)
                const Center(child: CircularProgressIndicator())
              else
                Expanded(
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
                                        valueColor: AlwaysStoppedAnimation<Color>(
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
                                    onPressed: !_isOffline
                                        ? (_isCheckedIn
                                        ? (workTime >= _requiredWorkTime
                                        ? _recordCheckOut
                                        : null)
                                        : _recordCheckIn)
                                        : null,
                                    icon: Icon(
                                      _isCheckedIn ? Icons.logout : Icons.login,
                                      color: Colors.white,
                                    ),
                                    label: Text(
                                      _isCheckedIn ? 'Check-out' : 'Check-in',
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
                                        borderRadius: BorderRadius.circular(12),
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
                                    valueColor: AlwaysStoppedAnimation<Color>(
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