import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:loginpage/homepage/Drawer/Leave.dart';
import 'package:loginpage/homepage/Drawer/Workdetails2.dart';
import 'package:loginpage/homepage/Drawer/Leave2.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import '../../Hive/user_profile.dart';
import '../../Loginpage/loginpage.dart';
import '../Drawer/Attendance.dart';

class HomePage extends StatefulWidget {
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  final FirebaseAuth auth = FirebaseAuth.instance;
  int index = 1;
  File? selectedImage;
  String? id;
  String? userid;
  List<ChartData4> chartData = [];
  bool isLoading = true;
  String? role;
  String currentUser = '';
  String? name;
  String? uid;
  final int totalEmployees = 120;
  final int totalTeamLeads = 10;
  final int totalwork = 100;
  List<ProgressData> progressData = [];
  int leavesTaken = 0;
  double workDonePercentage = 0.0;
  double workPendingPercentage = 0.0;
  int pending = 0;
  int totalEmployees1 = 0;
  int TotalTLS = 0;
  bool isOnline = false;
  StreamSubscription? connectivitySubscription;
  late Box<UserProfile> profileBox;

  Future<void> saveImagePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(userid!, path);
  }

  Future<String?> getImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(userid!);
  }

  signout() async {
    await FirebaseAuth.instance.signOut();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('profileImagePath');
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (context) => BiometricLoginPage()),
    );
  }

  final List<ChartData1> chartData1 = [
    ChartData1(2019, 38),
    ChartData1(2020, 20),
    ChartData1(2021, 60),
    ChartData1(2022, 50)
  ];
  final List<ChartData2> chartData2 = [
    ChartData2('Monday', 85),
    ChartData2('Tuesday', 80),
    ChartData2('Wednesday', 95),
    ChartData2('Thursday', 75),
    ChartData2('Friday', 80)
  ];

  Future<void> _fetchLeaveData() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('leave_records')
          .where("creator_role", isEqualTo: "employee")
          .where("user_id", isEqualTo: userid)
          .orderBy('start_date')
          .get();

      final List<Map<String, dynamic>> leaveData =
      querySnapshot.docs.map((doc) => doc.data()).toList();

      Map<String, int> statusCounts = {};
      int approvedLeaves = 0;

      for (var leave in leaveData) {
        String status = leave['status'] ?? 'Unknown';
        statusCounts[status] = (statusCounts[status] ?? 0) + 1;
        if (status == "Approved") {
          approvedLeaves++;
        }
      }

      if (!mounted) return;

      setState(() {
        chartData = statusCounts.entries
            .map((entry) => ChartData4(entry.key, entry.value))
            .toList();
        leavesTaken = approvedLeaves;
        isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        isLoading = false;
      });
      print("Error fetching leave records: $e");
    }
}

  void getData() {
    final User? user = auth.currentUser;
    var uid = user!.uid;
    setState(() {
      id = uid;
    });
    FirebaseFirestore.instance
        .collection('user')
        .doc(uid)
        .get()
        .then((DocumentSnapshot docusnapshot) {
      if (docusnapshot.exists) {
        print('Document data: ${docusnapshot.data()}');
        final data = docusnapshot.data() as Map<String, dynamic>?;
        if (mounted) {
          setState(() {
            role = data!['role'];
            name = data['name'];

            print('roles:$role');
            print("name:$name");
          });
          if (role == 'employee') {
            FirebaseFirestore.instance.collection("Employees").doc(uid).set({
              "Name": name,
              'uid': uid,
            });
          }
          if (role == 'teamlead') {
            FirebaseFirestore.instance.collection("Teamleads").doc(uid).set({
              'uid': id,
              "Name": name,
            });
          }
        }
      } else {
        print('Document does not exist in database');
      }
    });
  }

  Future<void> fetchTotalEmployees() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('user')
          .where('role', isEqualTo: 'employee')
          .get();

      setState(() {
        totalEmployees1 = querySnapshot.docs.length;
      });
    } catch (e) {
      print('Error fetching total employees: $e');
    }
  }

  Future<void> fetchTLs() async {
    try {
      final querySnapshot = await FirebaseFirestore.instance
          .collection('user')
          .where('role', isEqualTo: 'teamlead')
          .get();

      setState(() {
        TotalTLS = querySnapshot.docs.length;
      });
    } catch (e) {
      print('Error fetching total employees: $e');
    }
  }

  int totalwork1 = 0;
  int completedwork = 0;

  void fetchWorkDetails() async {
    final QuerySnapshot snapshot =
    await FirebaseFirestore.instance.collection('workDetails').get();

    if (!mounted) return;

    final List<QueryDocumentSnapshot> documents = snapshot.docs;
    int completedCount = 0;
    int pendingCount = 0;

    for (var doc in documents) {
      final data = doc.data() as Map<String, dynamic>;
      if (data['Status'] == 'Completed') {
        completedCount++;
      } else if (data['Status'] == 'Pending') {
        pendingCount++;
      }
    }
    final totalCount = completedCount + pendingCount;

    if (!mounted) return;

    setState(() {
      workDonePercentage = (completedCount / totalCount) * 100;
      workPendingPercentage = (pendingCount / totalCount) * 100;
      pending = pendingCount;
      totalwork1 = totalCount;
      completedwork = completedCount;
    });

    List<ProgressData> tempData = [];
    for (var doc in documents) {
      final data = doc.data() as Map<String, dynamic>;
      final progressUpdates =
          double.tryParse(data['Progressupdates'].toString()) ?? 0;

      tempData.add(ProgressData(
        data['AssignedTo'] ?? 'Unknown',
        progressUpdates,
      ));
    }

    if (!mounted) return;

    setState(() {
      progressData = tempData;
    });
  }

  Future<void> loadImagehome() async {
    final path = await getImagePath();
    if (path != null && mounted) {
      setState(() {
        selectedImage = File(path);
      });
    }
  }

  Future<void> _checkConnectivity() async {
    final connectivityResult = await Connectivity().checkConnectivity();
    if (!mounted) return;

    setState(() {
      isOnline = connectivityResult != ConnectivityResult.none;
    });

    connectivitySubscription =
        Connectivity().onConnectivityChanged.listen((result) {
          if (!mounted) return;
          setState(() {
            isOnline = result != ConnectivityResult.none;
          });
        });
  }



  @override
  void initState() {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? user = auth.currentUser;
    final uid = user!.uid;

    setState(() {
      userid = uid;
    });
    // TODO: implement initState
    super.initState();
    getData();
    profileBox = Hive.box<UserProfile>('profileBox');
    print(currentUser);
    loadImagehome();
    fetchWorkDetails();
    _fetchLeaveData();
    fetchTotalEmployees();
    fetchTLs();
    _checkConnectivity();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
    connectivitySubscription?.cancel();
  }


  Widget build(BuildContext context) {
    loadImagehome();
    var userProfile = userid != null ? profileBox.get(userid!) : null;
    return StreamBuilder(
        stream:
        FirebaseFirestore.instance.collection('user').doc(id).snapshots(),
        builder: (context, snapshots) {
          final data = snapshots.data;
          if (snapshots.hasData) {
            if (data!['role'] == 'teamlead') {
              return Scaffold(
                appBar: AppBar(
                  title: Text('Team Lead ',
                      style:
                      TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                  actions: [
                    IconButton(
                        onPressed: () {}, icon: Icon(Icons.notifications)),
                    // IconButton(
                    //     onPressed: () {
                    //       Navigator.push(
                    //           context,
                    //           MaterialPageRoute(
                    //               builder: (context) => ProfileScreen(
                    //
                    //                   )));
                    //     },
                    //     icon: Container(
                    //       height: 30,
                    //       width: 30,
                    //       decoration: BoxDecoration(
                    //           shape: BoxShape.circle,
                    //           image: DecorationImage(
                    //             fit: BoxFit.fill,
                    //             image: FileImage(File(data!['url']))
                    //                 as ImageProvider,
                    //           )),
                    //     )),
                  ],
                ),
                drawer: Drawer(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      DrawerHeader(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 40,

                              backgroundImage: (selectedImage != null)
                                  ? FileImage(selectedImage!) as ImageProvider
                                  : (isOnline && data['url'] != null &&
                                  data['url'].isNotEmpty)
                                  ? NetworkImage(data['url'])
                                  : (userProfile?.imagePath != null)
                                  ? FileImage(File(
                                  userProfile!.imagePath!)) as ImageProvider
                                  : const AssetImage(
                                  'assets/profile.jpeg') as ImageProvider,
                            ),
                            SizedBox(height: 5),
                            Text(
                              isOnline
                                  ? (data?["name"] ?? "No Name")
                                  : (userProfile?.name ?? data?["name"] ?? "No Name"),
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              data!["email"],
                              style: TextStyle(color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.dashboard_outlined),
                        title: Text('Work Details'),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => Workdetails2()));
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.people_outline),
                        title: Text('Schedule and Attendence'),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => LoginLogoutScreen1()));
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.person_off_outlined),
                        title: Text('Employee Leaves'),
                        onTap: () {
                          Navigator.push(context,
                              MaterialPageRoute(builder: (context) => Leave()));
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.person_3_rounded),
                        title: Text('My Leaves'),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => Leave1()));
                        },
                      ),
                    ],
                  ),
                ),
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 50),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  'Total Employees',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                Text(
                                  "$totalEmployees1",
                                  style: TextStyle(
                                    fontSize: 24,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.pinkAccent.shade200,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Card(
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12)),
                          color: Colors.blue.shade50,
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Work Done by Employees',
                                  style: TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                SizedBox(height: 10),
                                LinearProgressIndicator(
                                  value: (workDonePercentage / 100).toDouble(),
                                  minHeight: 10,
                                  color: Colors.brown.shade300,
                                  backgroundColor: Colors.blue.shade100,
                                ),
                                SizedBox(height: 10),
                                Text(
                                  '${workDonePercentage.toStringAsFixed(
                                      0)}% of the tasks have been completed.',
                                  style: TextStyle(fontSize: 16),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      SizedBox(height: 20),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          height: 300,
                          decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              color: Colors.blue.shade50,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black,
                                  blurRadius: 2.0,
                                ),
                              ]),
                          child: SfCartesianChart(
                            title: ChartTitle(text: 'Work Progress Updates'),
                            legend: Legend(isVisible: true),
                            primaryXAxis: CategoryAxis(),
                            primaryYAxis: NumericAxis(
                                minimum: 0, maximum: 100, interval: 10),
                            series: <CartesianSeries>[
                              BarSeries<ProgressData, String>(
                                dataSource: progressData,
                                xValueMapper: (ProgressData data, _) =>
                                data.assignedTo,
                                yValueMapper: (ProgressData data, _) =>
                                data.progress,
                                dataLabelSettings:
                                DataLabelSettings(isVisible: true),
                                markerSettings: MarkerSettings(isVisible: true),
                                color: Colors.brown.shade300,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else if (data!['role'] == 'admin') {
              return Scaffold(
                appBar: AppBar(
                  title: Text('Admin Dashboard',
                      style:
                      TextStyle(fontSize: 25, fontWeight: FontWeight.bold)),
                  actions: [
                    IconButton(
                        onPressed: () {}, icon: Icon(Icons.notifications)),
                    // IconButton(
                    //     onPressed: () {
                    //       Navigator.push(
                    //           context,
                    //           MaterialPageRoute(
                    //               builder: (context) =>
                    //                   ProfileScreen()));
                    //     },
                    //     icon: Container(
                    //       height: 30,
                    //       width: 30,
                    //       decoration: BoxDecoration(
                    //           shape: BoxShape.circle,
                    //           image: DecorationImage(
                    //               fit: BoxFit.fill,
                    //               image: FileImage(File(data!['url']))
                    //                   as ImageProvider)),
                    //     )),
                  ],
                ),
                drawer: Drawer(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      DrawerHeader(
                        decoration: BoxDecoration(
                          color: Colors.grey.shade300,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundImage: FileImage(File(data!['url'])),
                            ),
                            SizedBox(height: 5),
                            Text(
                              data["name"],
                              style: TextStyle(
                                  color: Colors.black,
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold),
                            ),
                            Text(
                              data["email"],
                              style: TextStyle(color: Colors.black),
                            ),
                          ],
                        ),
                      ),
                      ListTile(
                        leading: Icon(Icons.dashboard_outlined),
                        title: Text('Work Details'),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => Workdetails2()));
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.people_outline),
                        title: Text('Schedule and Attendence'),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => LoginLogoutScreen1()));
                        },
                      ),
                      ListTile(
                        leading: Icon(Icons.person_off_outlined),
                        title: Text('Leaves'),
                        onTap: () {
                          Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (context) => Leave1()));
                        },
                      ),
                    ],
                  ),
                ),
                body: SingleChildScrollView(
                  child: Column(
                    children: [
                      SizedBox(height: 50),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Card(
                          color: Colors.blue.shade50,
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Total Employees",
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(height: 5),
                                    Text("$totalEmployees1",
                                        style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.pinkAccent.shade200)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Total Team Leads",
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(height: 5),
                                    Text("$TotalTLS",
                                        style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.pinkAccent.shade200)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(10.0),
                        child: Card(
                          color: Colors.blue.shade50,
                          elevation: 5,
                          shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10)),
                          child: Padding(
                            padding: const EdgeInsets.all(15.0),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Total Work",
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(height: 5),
                                    Text("$totalwork1",
                                        style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.pinkAccent.shade200)),
                                  ],
                                ),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text("Work Completed",
                                        style: TextStyle(
                                            fontSize: 18,
                                            fontWeight: FontWeight.bold)),
                                    SizedBox(height: 5),
                                    Text("$completedwork",
                                        style: TextStyle(
                                            fontSize: 22,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.pinkAccent.shade200)),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: Container(
                          height: 363,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            color: Colors.blue.shade50,
                          ),
                          child: Column(
                            children: [
                              SizedBox(height: 5),
                              Text(
                                "Performance Evaluation",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 16),
                              ),
                              SizedBox(height: 15),
                              SfCartesianChart(
                                primaryXAxis: CategoryAxis(),
                                series: <CartesianSeries<ChartData2, String>>[
                                  ColumnSeries<ChartData2, String>(
                                    dataSource: chartData2,
                                    xValueMapper:
                                        (ChartData2 data, int index) => data.x,
                                    yValueMapper:
                                        (ChartData2 data, int index) => data.y,
                                    color: Colors.pinkAccent.shade200,
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              );
            } else if (data!['role'] == 'employee') {
              return Scaffold(
                appBar: AppBar(
                  elevation: 0,
                  title: Text(
                    'Dashboard',
                    style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                  ),
                  actions: [
                    IconButton(
                      icon: Icon(Icons.notifications_outlined, size: 28),
                      onPressed: () {},
                    ),
                  ],
                ),
                drawer: Drawer(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      DrawerHeader(
                        decoration: BoxDecoration(
                          color: Colors.brown.shade300,
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            CircleAvatar(
                              radius: 40,
                              backgroundImage: (selectedImage != null)
                                  ? FileImage(selectedImage!) as ImageProvider
                                  : (isOnline && data['url'] != null &&
                                  data['url'].isNotEmpty)
                                  ? NetworkImage(data['url'])
                                  : (userProfile?.imagePath != null)
                                  ? FileImage(File(
                                  userProfile!.imagePath!)) as ImageProvider
                                  : const AssetImage(
                                  'assets/profile.jpeg') as ImageProvider,
                            ),
                            Text(
                              isOnline
                                  ? (data?["name"] ?? "No Name")
                                  : (userProfile?.name ?? data?["name"] ?? "No Name"),
                              style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white),
                            ),
                            Text(
                              isOnline
                                  ? (data?["email"] ?? userProfile?.email ?? "No Email")
                                  : (userProfile?.email ?? data?["email"] ?? "No Email"),
                              style: TextStyle(
                                  fontSize: 14, color: Colors.white70),
                            ),
                          ],
                        ),
                      ),
                      buildDrawerItem(
                          icon: Icons.dashboard_outlined,
                          label: "Work Details",
                          onTap: () =>
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => Workdetails2()))),
                      buildDrawerItem(
                          icon: Icons.people_outline,
                          label: "Schedule & Attendance",
                          onTap: () =>
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) =>
                                          LoginLogoutScreen1()))),
                      buildDrawerItem(
                          icon: Icons.person_off_outlined,
                          label: "Leaves",
                          onTap: () =>
                              Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                      builder: (context) => Leave()))),

                    ],
                  ),
                ),
                body: SingleChildScrollView(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16.0, vertical: 20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        SfCircularChart(
                          title: ChartTitle(
                              text: 'Leave Status Breakdown',
                              textStyle:
                              TextStyle(fontWeight: FontWeight.bold)),
                          legend: Legend(
                              isVisible: true,
                              overflowMode: LegendItemOverflowMode.wrap),
                          series: <CircularSeries>[
                            PieSeries<ChartData4, String>(
                              dataSource: chartData,
                              xValueMapper: (ChartData4 data, _) =>
                              data.status,
                              yValueMapper: (ChartData4 data, _) =>
                              data.count,
                              dataLabelMapper: (ChartData4 data, _) =>
                              '${data.status}: ${data.count}',
                              dataLabelSettings:
                              DataLabelSettings(isVisible: true),
                            ),
                          ],
                        ),
                        buildSectionHeader("Work Progress"),
                        SizedBox(height: 10),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            _buildStatCard(
                              "Work Pending",
                              "${workPendingPercentage.toStringAsFixed(0)}%",
                              Colors.redAccent,
                            ),
                            _buildStatCard(
                              "Work Done",
                              "${workDonePercentage.toStringAsFixed(0)}%",
                              Colors.greenAccent,
                            ),
                          ],
                        ),
                        SizedBox(height: 20),
                        buildSectionHeader("General Stats"),
                        SizedBox(height: 10),
                        buildInfoCard(
                          title: "Leaves Taken: $leavesTaken",
                          subtitle: "Performance: Good",
                        ),
                        SizedBox(height: 10),
                        buildInfoCard(
                          title: "Pending Projects: $pending",
                          subtitle: "Focus Needed",
                        ),
                      ],
                    ),
                  ),
                ),
              );
            } else {
              return Center(
                child: Container(
                  color: Colors.grey.shade300,
                  child: Icon(Icons.cached_rounded),
                ),
              );
            }
          } else {
            return Center(
              child: Container(
                color: Colors.grey.shade300,
                child: Icon(Icons.cached_rounded),
              ),
            );
          }
        });
  }

  // Improved drawer item with hover effect
  Widget buildDrawerItem({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    bool isSelected = false,
  }) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: isSelected ? Colors.brown.shade50 : Colors.transparent,
      ),
      child: ListTile(
        leading: Icon(
          icon,
          color: isSelected ? Colors.brown : Colors.brown.shade300,
        ),
        title: Text(
          label,
          style: TextStyle(
            fontSize: 15,
            fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
            color: isSelected ? Colors.brown.shade700 : Colors.black87,
          ),
        ),
        onTap: onTap,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        dense: true,
      ),
    );
  }

  Widget buildSectionHeader(String title) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: Text(
            title,
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
              letterSpacing: 0.5,
            ),
          ),
        ),
        Container(
          width: 40,
          height: 3,
          decoration: BoxDecoration(
            color: Colors.brown.shade300,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildStatCard(String title, String percentage, Color color) {
    return Container(
      height: 150,
      width: 160,
      padding: EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade300,
            spreadRadius: 2,
            blurRadius: 5,
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            percentage,
            style: TextStyle(
                fontSize: 28, fontWeight: FontWeight.bold, color: color),
          ),
          SizedBox(height: 10),
          Text(
            title,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w500),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget buildInfoCard({
    required String title,
    required String subtitle,
    IconData? icon,
  }) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.symmetric(vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.grey.shade100,
            offset: const Offset(0, 4),
            spreadRadius: 2,
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.brown.shade300, size: 20),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: TextStyle(
              fontSize: 14,
              height: 1.5,
              color: Colors.grey.shade700,
            ),
          ),
        ],
      ),
    );
  }
}

class ChartData2 {
  ChartData2(this.x, this.y);

  final String x;
  final double y;
}

class ChartData1 {
  ChartData1(this.x, this.y);

  final num x;
  final num y;
}

class ChartData4 {
  final String status;
  final int count;

  ChartData4(this.status, this.count);
}

class ProgressData {
  final String assignedTo;
  final double progress;

  ProgressData(this.assignedTo, this.progress);
}
