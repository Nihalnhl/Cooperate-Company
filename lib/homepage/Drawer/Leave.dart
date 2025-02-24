    import 'package:cloud_firestore/cloud_firestore.dart';
    import 'package:connectivity_plus/connectivity_plus.dart';
    import 'package:firebase_auth/firebase_auth.dart';
    import 'package:flutter/material.dart';
    import 'package:hive/hive.dart';
    import 'package:intl/intl.dart';
    import 'package:uuid/uuid.dart';
    import '../../Hive/leave_request_model.dart';

        class Leave extends StatefulWidget {
          const Leave({super.key});
          @override
          State<Leave> createState() => _LeaveState();
        }

        class _LeaveState extends State<Leave> {
          List<Map<String, dynamic>> currentData = [];
          final FirebaseAuth auth = FirebaseAuth.instance;
          final _formKey = GlobalKey<FormState>();
          final TextEditingController reasonController = TextEditingController();
          TextEditingController searchController = TextEditingController();
          TextEditingController _startDateController = TextEditingController();
          TextEditingController _endDateController = TextEditingController();
          final LeaveRequestService leaveRequestService = LeaveRequestService();
          final ConnectivityService connectivityService = ConnectivityService();

          String searchQuery = '';
          DateTime? filterStartDate;
          DateTime? filterEndDate;
          String? filterStatus  ;
          String? role;
          String? Name;
          DateTime? startDate;
          DateTime? endDate;
          String? leaveType;
          String? reason;
          String? status;
          String? leaveRequestId;
          String? department;
          String? userName;bool isOffline = false;


          @override
          void initState() {
            super.initState();
            initialize();
            getData();
          }


          final FirebaseFirestore firestore = FirebaseFirestore.instance;
          Future<void> storeUserRole(String role) async {
            var box = await Hive.openBox('userBox');
            await box.put('role', role);
          }
          Future<String?> getUserRole() async {
            var box = await Hive.openBox('userBox');
            return box.get('role');
          }

          void initialize() {
            Connectivity().onConnectivityChanged.listen((ConnectivityResult result) async {
              if (result != ConnectivityResult.none) {
                bool isOnline = await checkInternetConnection();
                if (isOnline) {
                  await syncPendingDeletions();
                  await syncOfflineDataToFirestore();
                  await getDataFromFirestore();

                  if (mounted) {
                    setState(() {
                    });
                  }
                }
              }
            });
          }


          Future<void> syncPendingDeletions() async {
            final pendingDeletionsBox = await Hive.openBox<String>('pendingDeletionsBox');
            final pendingDeletions = pendingDeletionsBox.values.toList();

            for (String leaveRequestId in pendingDeletions) {
              try {
                await FirebaseFirestore.instance
                    .collection('leave_records')
                    .doc(leaveRequestId)
                    .delete();
                await pendingDeletionsBox.delete(leaveRequestId);

                print('Successfully deleted leave request with ID: $leaveRequestId');
              } catch (error) {
                print('Failed to delete leave request with ID: $leaveRequestId - $error');
              }
            }
          }

          void getData() async {
            final User? user = auth.currentUser;
            final uid = user?.uid;
            if (uid == null) return;

            bool isOnline = await checkInternetConnection();

            if (isOnline) {
              try {
                final documentSnapshot =
                await FirebaseFirestore.instance.collection('user').doc(uid).get();

                if (documentSnapshot.exists) {
                  final data = documentSnapshot.data() as Map<String, dynamic>?;
                  if (mounted) {
                    setState(() {
                      role = data!['role'];
                      Name = data["name"];
                      storeUserRole(role!);
                      if (role == "employee") {
                        EmployeeQuery(uid);
                      } else if (role == "teamlead") {
                        TeamLeadQuery(uid);
                      }
                    });
                  }
                } else {
                  print('User document does not exist in Firestore.');
                }
              } catch (error) {
                print('Error fetching user data: $error');
              }
            } else {
              role = await getUserRole();
              loadOfflineData();
            }
          }

          Future<bool> checkInternetConnection() async {
            ConnectivityResult result = await Connectivity().checkConnectivity();
            return result != ConnectivityResult.none;
          }

          Future<void> syncOfflineDataToFirestore() async {
            try {
              final leaveRequestBox = await Hive.openBox<LeaveRequest>('leaveRequestsBox');
              final offlineRequests = leaveRequestBox.values.toList();

              for (var leaveRequest in offlineRequests) {
                try {
                  await FirebaseFirestore.instance
                      .collection('leave_records')
                      .doc(leaveRequest.Id)
                      .set({
                    'id': leaveRequest.Id,
                    'leave_type': leaveRequest.leaveType,
                    'reason': leaveRequest.reason,
                    'start_date': leaveRequest.startDate,
                    'end_date': leaveRequest.endDate,
                    'status': leaveRequest.status,
                    'department': leaveRequest.department,
                    'creator_role': leaveRequest.creatorRole,
                    'user_id': leaveRequest.userId,
                    'user_name': leaveRequest.userName,
                  }, SetOptions(merge: true));

                  await leaveRequestBox.delete(leaveRequest.Id);
                } catch (error) {
                  print('Error syncing leave request with ID ${leaveRequest.Id}: $error');
                }
              }
              print('Offline data synced and cleared from Hive.');
              if (mounted) {
                setState(() {
                  getData();
                });
              }
            } catch (error) {
              print('Error during sync operation: $error');
            }
          }

          Future<void> getDataFromFirestore() async {
            final User? user = auth.currentUser;
            final uid = user?.uid;
            if (uid == null) return;

            try {
              final querySnapshot = await FirebaseFirestore.instance
                  .collection('leave_records')
                  .where('user_id', isEqualTo: uid)
                  .get();

              final leaveRequests = querySnapshot.docs.map((doc) {
                return LeaveRequest(
                  Id: doc['id'],
                  leaveType: doc['leave_type'],
                  reason: doc['reason'],
                  startDate: (doc['start_date'] as Timestamp).toDate(),
                  endDate: (doc['end_date'] as Timestamp).toDate(),
                  status: doc['status'],
                  department: doc['department'],
                  creatorRole: doc['creator_role'],
                  userId: doc['user_id'],
                  userName: doc['user_name'],
                );
              }).toList();
              saveToHive(leaveRequests);
              setState(() {
                currentData = querySnapshot.docs.map((doc) => doc.data()).toList();
              });
            } catch (error) {
              print('Failed to fetch leave records from Firestore: $error');
            }
          }

          Future<void> clearBox() async {
            const boxName = 'leaveRequestsBox';

            var box = Hive.isBoxOpen(boxName)
                ? Hive.box(boxName)
                : await Hive.openBox(boxName);

            await box.clear();
            print('Box cleared!');
          }

          void loadOfflineData() async {
            try {
              final leaveRequestBox = await Hive.openBox<LeaveRequest>('leaveRequestsBox');
              final leaveRequests = leaveRequestBox.values.toList();

              setState(() {
                currentData = leaveRequests.map((leaveRequest) {
                  return {
                    'id': leaveRequest.Id,
                    'leave_type': leaveRequest.leaveType,
                    'reason': leaveRequest.reason,
                    'start_date': leaveRequest.startDate,
                    'end_date': leaveRequest.endDate,
                    'status': leaveRequest.status,
                    'department': leaveRequest.department,
                    'creator_role': leaveRequest.creatorRole,
                    'user_id': leaveRequest.userId,
                    'user_name': leaveRequest.userName,
                    'source': 'offline',
                  };
                }).toList();
              });

              print('Offline data loaded successfully: $currentData');
            } catch (e) {
              print('Error loading offline data: $e');
            }
          }

          void EmployeeQuery(String userId) async {
            try {
              final querySnapshot = await FirebaseFirestore.instance
                  .collection('leave_records')
                  .where("user_id", isEqualTo: userId)
              .where("creator_role",isEqualTo: "employee")
                  .orderBy('start_date')
                  .get();

              setState(() {
                currentData = querySnapshot.docs.map((doc) => doc.data()).toList();
              });
            } catch (error) {
              print('Failed to fetch leave records for the employee: $error');
            }
          }

          void TeamLeadQuery(String userId) async {
            try {
              final querySnapshot = await FirebaseFirestore.instance
                  .collection('leave_records')

                  .orderBy('start_date')
                  .where("creator_role",isEqualTo: "employee")
                  .get();
              setState(() {
                currentData = querySnapshot.docs.map((doc) => doc.data()).toList();
              });
            } catch (error) {
              print('Failed to fetch leave requests: $error');
            }
          }

          final Uuid uuid = Uuid();

          void saveLeaveRequest() async {
            final User? user = auth.currentUser;
            final uid = user!.uid;
            if (_formKey.currentState!.validate()) {
              _formKey.currentState!.save();
              FirebaseFirestore.instance.collection('user').doc(uid).get().then((doc) async {
                if (doc.exists) {
                  final userName = doc['name'];

                  final newLeaveRequestId = leaveRequestId ?? uuid.v4();

                  final leaveData = {
                    'id': newLeaveRequestId,
                    'leave_type': leaveType,
                    'reason': reason,
                    'start_date': startDate,
                    'end_date': endDate,
                    'status': status ?? 'Pending',
                    'department': department,
                    'creator_role': role ?? 'employee',
                    'timestamp': FieldValue.serverTimestamp(),
                    'user_id': uid,
                    'user_name': userName,
                  };

                  bool isOnline = await checkInternetConnection();

                  if (isOnline) {
                    if (leaveRequestId == null) {
                      await createLeaveRequest(leaveData);
                    } else {
                      await updateLeaveRequest(leaveRequestId!, leaveData);
                    }
                  } else {

                    final leaveRequest = LeaveRequest(
                      Id: newLeaveRequestId,
                      leaveType: leaveType.toString(),
                      reason: reason.toString(),
                      startDate: startDate!,
                      endDate: endDate!,
                      status: status ?? 'Pending',
                      department: department.toString(),
                      creatorRole: role ?? 'employee',
                      userId: uid,
                      userName: userName,
                    );
                    if (leaveRequestId == null) {
                      await addLeaveRequestToHive(leaveRequest);
                    } else {
                      await updateLeaveRequestInHive(leaveRequest);
                    }
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Leave request saved locally')),
                    );
                  }
                  getData();
                }
              });
            }
          }

          Future<void> saveToHive(List<LeaveRequest> leaveRequests) async {
            final leaveRequestBox = await Hive.openBox<LeaveRequest>('leaveRequestsBox');
            await leaveRequestBox.clear();
            for (var leaveRequest in leaveRequests) {
              await leaveRequestBox.put(leaveRequest.Id, leaveRequest);
            }
            print('Data saved to Hive successfully.');
          }


          Future<void> addLeaveRequestToHive(LeaveRequest leaveRequest) async {
            Navigator.pop(context);

            final leaveRequestBox = await Hive.openBox<LeaveRequest>('leaveRequestsBox');
            await leaveRequestBox.put(leaveRequest.Id, leaveRequest);
          }

          Future<void> updateLeaveRequestInHive(LeaveRequest leaveRequest) async {
            Navigator.pop(context);
            Navigator.pop(context);
            final leaveRequestBox = await Hive.openBox<LeaveRequest>('leaveRequestsBox');
            await leaveRequestBox.put(leaveRequest.Id, leaveRequest);
          }

          Future<void> createLeaveRequest(Map<String, dynamic> leaveData) async {
            Navigator.pop(context);
            try {
              DocumentReference newLeaveRef = await FirebaseFirestore.instance
                  .collection('leave_records')
                  .add(leaveData);
              String newId = newLeaveRef.id;
              leaveData['id'] = newId;
              await newLeaveRef.update({'id': newId});
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Leave request submitted successfully!')),
              );
            } catch (error) {
              print('Error creating leave request: $error');
            }
          }

          Future<void> updateLeaveRequest(
              String leaveRequestId, Map<String, dynamic> leaveData) async {
            Navigator.pop(context);
            Navigator.pop(context);
            try {
              await FirebaseFirestore.instance
                  .collection('leave_records')
                  .doc(leaveRequestId)
                  .update(leaveData);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Leave request updated successfully!')),
              );
            } catch (error) {
              print('Error updating leave request: $error');
            }
          }

      List<Map<String, dynamic>> getFilteredData() {
        List<Map<String, dynamic>> filteredData = currentData;
        if (searchQuery.isNotEmpty) {
          filteredData = filteredData.where((data) {
            final name = data['user_name'].toString().toLowerCase();
            final department = data['department'].toString().toLowerCase();
            final reason = data['reason'].toString().toLowerCase();
            final type = data['leave_type'].toString().toLowerCase();
            final startDate = data['start_date'] != null
                ? (data['start_date'] is Timestamp
                ? (data['start_date'] as Timestamp).toDate()
                : data['start_date'] as DateTime?)
                : null;
            final endDate = data['end_date'] != null
                ? (data['end_date'] is Timestamp
                ? (data['end_date'] as Timestamp).toDate()
                : data['end_date'] as DateTime?)
                : null;
            final startMonth = startDate != null
                ? DateFormat('dd MMM yyyy').format(startDate).toLowerCase()
                : '';
            final endMonth = endDate != null
                ? DateFormat('dd MMM yyyy').format(endDate).toLowerCase()
                : '';

            return name.contains(searchQuery.toLowerCase()) ||
                department.contains(searchQuery.toLowerCase()) ||
                reason.contains(searchQuery.toLowerCase()) ||
                type.contains(searchQuery.toLowerCase()) ||
                (startDate != null &&
                    startDate.toString().toLowerCase().contains(searchQuery.toLowerCase())) ||
                (endDate != null &&
                    endDate.toString().toLowerCase().contains(searchQuery.toLowerCase())) ||
                startMonth.contains(searchQuery.toLowerCase()) ||
                endMonth.contains(searchQuery.toLowerCase());
          }).toList();
        }

        if (filterStartDate != null && filterEndDate != null) {
          filteredData = filteredData.where((data) {
            final startDate = data['start_date'] != null
                ? (data['start_date'] is Timestamp
                ? (data['start_date'] as Timestamp).toDate()
                : data['start_date'] as DateTime?)
                : null;
            return startDate != null &&
                startDate.isAfter(filterStartDate!) &&
                startDate.isBefore(filterEndDate!);
          }).toList();
        }

        if (filterStatus != null) {
          filteredData = filteredData.where((data) {
            return data['status'] == filterStatus;
          }).toList();
        }
        return filteredData;
      }

      void clearFilters() {
        setState(() {
          searchQuery = '';
          filterStartDate = null;
          filterEndDate = null;
          filterStatus = null;
        });
        Navigator.pop(context);
      }

      @override
      Widget build(BuildContext context) {
        final filteredData = getFilteredData();
        return Scaffold(
          appBar: AppBar(
            title: const Text(
              'Leave Records',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            actions: [
              IconButton(onPressed: clearBox, icon: Icon(Icons.clear)),
              IconButton(
                icon: const Icon(Icons.tune),
                onPressed: showFilterDialog,
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(8.0),
                child: TextField(
                  controller: searchController,
                  onChanged: (value) {
                    setState(() {
                      searchQuery = value;
                    });
                  },
                  decoration: InputDecoration(
                    hintText: "Search...",
                    prefixIcon: Icon(Icons.search, color: Colors.black),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30),
                      borderSide: BorderSide.none,
                    ),
                    contentPadding:
                    EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                  ),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    ListView.builder(
                      itemCount: filteredData.length,
                      itemBuilder: (context, index) {
                        filteredData.sort((a, b) {
                          String statusA = a['status'] ?? 'Pending';
                          String statusB = b['status'] ?? 'Pending';
                          if (statusA == 'Pending' && statusB != 'Pending')
                            return -1;
                          if (statusA != 'Pending' && statusB == 'Pending')
                            return 1;
                          if (statusA == 'Approved' && statusB == 'Rejected')
                            return -1;
                          if (statusA == 'Rejected' && statusB == 'Approved')
                            return 1;
                          return 0;
                        });

                        final workDetail = filteredData[index];
                        DateTime? startDate = workDetail['start_date'] != null
                            ? (workDetail['start_date'] is Timestamp
                            ? (workDetail['start_date'] as Timestamp).toDate()
                            : workDetail['start_date'] as DateTime?)
                            : null;

                        DateTime? endDate = workDetail['end_date'] != null
                            ? (workDetail['end_date'] is Timestamp
                            ? (workDetail['end_date'] as Timestamp).toDate()
                            : workDetail['end_date'] as DateTime?)
                            : null;

                        String formattedStartDate = startDate != null
                            ? DateFormat('dd MMM yyyy').format(startDate)
                            : 'No Start Date';

                        String formattedEndDate = endDate != null
                            ? DateFormat('dd MMM yyyy').format(endDate)
                            : 'No End Date';

                        String statusText = workDetail['status'] ?? 'Pending';
                        String  workName = workDetail['user_name'];

                        Color statusColor = statusText == 'Approved'
                            ? Colors.green.shade600
                            : statusText == 'Rejected'
                            ? Colors.red.shade600
                            : Colors.orange.shade600;

                        IconData statusIcon = statusText == 'Approved'
                            ? Icons.check_circle
                            : statusText == 'Rejected'
                            ? Icons.cancel
                            : Icons.hourglass_bottom;

                        return Padding(
                          padding:
                          EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          child: Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                    color: Colors.black12,
                                    blurRadius: 10,
                                    offset: Offset(4, 4)),
                                BoxShadow(
                                    color: Colors.white.withOpacity(0.7),
                                    blurRadius: 5,
                                    offset: Offset(-4, -4)),
                              ],
                              gradient: LinearGradient(
                                colors: [
                                  Colors.white.withOpacity(0.8),
                                  Colors.white.withOpacity(0.6)
                                ],
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                            ),
                            child: ListTile(
                              contentPadding: EdgeInsets.all(20),
                              title: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (role == "teamlead")
                                    Row(
                                      children: [
                                        Icon(Icons.person,
                                            color: Colors.blueGrey, size: 22),
                                        SizedBox(width: 8),
                                        // Text(
                                        //   workName,
                                        //   style: TextStyle(
                                        //       fontSize: 16,
                                        //       fontWeight: FontWeight.bold,
                                        //       color: Colors.black87),
                                        // ),
                                      ],
                                    ),
                                  SizedBox(height: 6),

                                  // Leave Type & Status
                                  Row(
                                    mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        children: [
                                          Icon(Icons.event,
                                              color: Colors.blueGrey, size: 20),
                                          SizedBox(width: 6),
                                          Text(
                                            '${workDetail['leave_type']}',
                                            style: TextStyle(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color: Colors.black87),
                                          ),
                                        ],
                                      ),
                                      Container(
                                        padding: EdgeInsets.symmetric(
                                            horizontal: 12, vertical: 6),
                                        decoration: BoxDecoration(
                                          color: statusColor.withOpacity(0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            Icon(statusIcon,
                                                color: statusColor, size: 18),
                                            SizedBox(width: 6),
                                            Text(
                                              statusText,
                                              style: TextStyle(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.bold,
                                                  color: statusColor),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 6),

                                  // Leave Dates
                                  Row(
                                    children: [
                                      Icon(Icons.date_range,
                                          color: Colors.blueGrey, size: 20),
                                      SizedBox(width: 8),
                                      Text(
                                        '$formattedStartDate → $formattedEndDate',
                                        style: TextStyle(
                                            fontSize: 14, color: Colors.black54),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: 12),
                                  if (role == "teamlead" && statusText == 'Pending')
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        _actionButton(
                                          text: "Approve",
                                          icon: Icons.check,
                                          color: Colors.green,
                                          onPressed: () async {
                                            bool isOnline = await checkInternetConnection();

                                            if (!isOnline) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('No internet connection. Please try again later.'),
                                                  backgroundColor: Colors.orange,
                                                ),
                                              );
                                              return;
                                            }

                                            FirebaseFirestore.instance
                                                .collection('leave_records')
                                                .doc(workDetail['id'])
                                                .update({'status': 'Approved'})
                                                .then((value) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Leave request approved!'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                              getData();
                                            })
                                                .catchError((error) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Failed to approve leave request: $error'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            });
                                          },
                                        ),

                                        SizedBox(
                                          width: 10,
                                        ),
                                        _actionButton(
                                            text: "Reject",
                                            icon: Icons.close,
                                            color: Colors.red,
                                            onPressed: () {
                                              FirebaseFirestore.instance
                                                  .collection('leave_records')
                                                  .doc(workDetail['id'])
                                                  .update({
                                                'status': 'Rejected'
                                              }).then((value) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          'Leave request rejected!'),
                                                      backgroundColor: Colors.red),
                                                );
                                                getData();
                                              }).catchError((error) {
                                                ScaffoldMessenger.of(context)
                                                    .showSnackBar(
                                                  SnackBar(
                                                      content: Text(
                                                          'Failed to reject leave request: $error'),
                                                      backgroundColor: Colors.red),
                                                );
                                              });
                                            })
                                      ],
                                    ),

                                  if ( role == "employee" && statusText == "Pending")
                                    Align(
                                      alignment: Alignment.bottomRight,
                                      child: TextButton.icon(
                                        onPressed: () async {
                                          final leaveRequestId = workDetail['id'];

                                          bool isOnline = await checkInternetConnection();

                                          if (isOnline) {

                                            FirebaseFirestore.instance
                                                .collection('leave_records')
                                                .doc(leaveRequestId)
                                                .delete()
                                                .then((value) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Leave request deleted !'),
                                                  backgroundColor: Colors.green,
                                                ),
                                              );
                                              getData();
                                            }).catchError((error) {
                                              ScaffoldMessenger.of(context).showSnackBar(
                                                SnackBar(
                                                  content: Text('Failed to delete leave request: $error'),
                                                  backgroundColor: Colors.red,
                                                ),
                                              );
                                            });
                                          } else {

                                            final leaveRequestBox = await Hive.openBox<LeaveRequest>('leaveRequestsBox');
                                            final pendingDeletionsBox = await Hive.openBox<String>('pendingDeletionsBox');
                                            await leaveRequestBox.delete(leaveRequestId);
                                            await pendingDeletionsBox.add(leaveRequestId);
                                            ScaffoldMessenger.of(context).showSnackBar(
                                              const SnackBar(
                                                content: Text('Deleted Offline'),
                                                backgroundColor: Colors.red,
                                              ),
                                            );

                                            getData();
                                          }
                                        },
                                        icon: Icon(Icons.delete, color: Colors.redAccent),
                                        label: Text('Cancel Request', style: TextStyle(color: Colors.redAccent)),
                                      ),
                                    ),
                                ],
                              ),
                              onTap: () => showLeaveRequestDetailDialog(workDetail),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            backgroundColor: Colors.white,
            onPressed: showLeaveRequestDialog,
            child: Icon(Icons.add),
          ),
        );
      }
      Future<void> showLeaveRequestDialog(
          [Map<String, dynamic>? workDetail, VoidCallback? onUpdate]) async {
        if (workDetail != null) {
          leaveRequestId = workDetail['id'];
          leaveType = workDetail['leave_type'];
          reason = workDetail['reason'];
          startDate = workDetail['start_date'] is Timestamp
              ? workDetail['start_date'].toDate()
              : workDetail['start_date'];
          endDate = workDetail['end_date'] is Timestamp
              ? workDetail['end_date'].toDate()
              : workDetail['end_date'];
          status = workDetail['status'];
          department = workDetail['department'];
          userName = workDetail['user_name'];

          _startDateController.text = DateFormat('yyyy-MM-dd').format(startDate!);
          _endDateController.text = DateFormat('yyyy-MM-dd').format(endDate!);

          if (status == 'Approved' || status == 'Rejected') {
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text('Leave request cannot be updated as it is $status.'),
            ));
            return;
          }
        } else {
          leaveRequestId = null;
          leaveType = null;
          reason = null;
          startDate = null;
          endDate = null;
          status = null;
          department = null;
          userName = null;
          _startDateController.clear();
          _endDateController.clear();
        }
        if (role == null) {
          role = await getUserRole();
        }
        showDialog(
          context: context,
          builder: (context) {
            return AlertDialog(
              backgroundColor: Colors.grey.shade300,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(15),
              ),
              title: Text(
                workDetail == null ? 'Create Leave Request' : 'Edit Leave Request',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: TextFormField(
                          enabled: false,
                          decoration: InputDecoration(
                            labelText: Name,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: Icon(Icons.person),
                          ),
                          readOnly: true,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: TextFormField(
                          initialValue: reason,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(
                            labelText: 'Reason',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: Icon(Icons.edit),
                          ),
                          onChanged: (value) {
                            reason = value;
                          },
                          onSaved: (value) => reason = value,
                          validator: (value) {
                            if (value == null || value.trim().isEmpty) {
                              return 'Please enter a reason';
                            }
                            return null;
                          },
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: DropdownButtonFormField<String>(
                          value: department,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          items: ['Software', 'Marketing', 'Finance']
                              .map((type) => DropdownMenuItem(
                            child: Text(type),
                            value: type,
                          ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              department = value;
                            });
                          },
                          onSaved: (value) => department = value,
                          decoration: InputDecoration(
                            labelText: 'Department',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            prefixIcon: Icon(Icons.category),
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Please select a department'
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: DropdownButtonFormField<String>(
                          value: leaveType,
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          items: ['Sick Leave', 'Casual Leave', 'Vacation']
                              .map((type) => DropdownMenuItem(
                            child: Text(type),
                            value: type,
                          ))
                              .toList(),
                          onChanged: (value) {
                            setState(() {
                              leaveType = value;
                            });
                          },
                          onSaved: (value) => leaveType = value,
                          decoration: InputDecoration(
                            labelText: 'Leave Type',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(10)),
                            prefixIcon: Icon(Icons.category),
                          ),
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Please select a leave type'
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: TextFormField(
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(
                            labelText: 'Start Date',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: Icon(Icons.calendar_today),
                          ),
                          onTap: () async {
                            final DateTime? selectedDate = await showDatePicker(
                              context: context,
                              initialDate: startDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2101),
                            );
                            if (selectedDate != null) {
                              setState(() {
                                startDate = selectedDate;
                                _startDateController.text =
                                    DateFormat('yyyy-MM-dd').format(startDate!);
                              });
                            }
                          },
                          readOnly: true,
                          controller: _startDateController,
                          validator: (value) => (value == null || value.isEmpty)
                              ? 'Please select a start date'
                              : null,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: TextFormField(
                          autovalidateMode: AutovalidateMode.onUserInteraction,
                          decoration: InputDecoration(
                            labelText: 'End Date',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                            prefixIcon: Icon(Icons.calendar_today_outlined),
                          ),
                          onTap: () async {
                            final DateTime? selectedDate = await showDatePicker(
                              context: context,
                              initialDate: endDate ?? DateTime.now(),
                              firstDate: DateTime.now(),
                              lastDate: DateTime(2101),
                            );
                            if (selectedDate != null) {
                              setState(() {
                                endDate = selectedDate;
                                _endDateController.text =
                                    DateFormat('yyyy-MM-dd').format(endDate!);
                              });
                            }
                          },
                          readOnly: true,
                          controller: _endDateController,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please select an end date';
                            }
                            if (startDate != null &&
                                endDate != null &&
                                endDate!.isBefore(startDate!)) {
                              return 'End Date must be after Start Date';
                            }
                            return null;
                          },
                        ),
                      ),

                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              actions: [
                // _actionButton(
                //   text: workDetail == null ? 'Submit' : 'Update',
                //   icon: Icons.close,
                //   color: Colors.green,
                //   onPressed: () {
                //     if (_formKey.currentState!.validate()) {
                //       _formKey.currentState!.save();
                //       saveLeaveRequest();
                //     }
                //   },
                // ),
                SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        if (_formKey.currentState!.validate()) {
                          _formKey.currentState!.save();
                          saveLeaveRequest();
                        }
                      },
                      icon: Icon(Icons.close, color: Colors.white),
                      label: Text(
                        leaveRequestId == null
                            ? 'Submit Leave Request'
                            : 'Update Leave Request',
                        style: const TextStyle(color: Colors.white),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ))
              ],
            );
          },
        );
      }

      void showFilterDialog() {
        showDialog(
          context: context,
          builder: (context) {
            String? selectedStatus = filterStatus;
            DateTimeRange? selectedDateRange =
            filterStartDate != null && filterEndDate != null
                ? DateTimeRange(start: filterStartDate!, end: filterEndDate!)
                : null;

            TextEditingController dateRangeController = TextEditingController(
                text: selectedDateRange != null
                    ? 'From: ${selectedDateRange.start.toLocal().toString().split(' ')[0]} to ${selectedDateRange.end.toLocal().toString().split(' ')[0]}'
                    : 'Select Date Range');

            return StatefulBuilder(
              builder: (context, setDialogState) {
                return AlertDialog(
                  backgroundColor: Colors.grey.shade200,
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12)),
                  title: Row(
                    children: [
                      const Text('Filter Leave Request',
                          style: TextStyle(fontWeight: FontWeight.bold)),
                      // IconButton(
                      //   onPressed: () {
                      //     Navigator.pop(context);
                      //   },
                      //   icon: Icon(Icons.close),
                      // )
                    ],
                  ),
                  content: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        DropdownButtonFormField<String>(
                          value: selectedStatus,
                          items: const [
                            DropdownMenuItem(
                                value: null, child: Text('All Status')),
                            DropdownMenuItem(
                                value: 'Pending', child: Text('Pending')),
                            DropdownMenuItem(
                                value: 'Approved', child: Text('Approved')),
                            DropdownMenuItem(
                                value: 'Rejected', child: Text('Rejected')),
                          ],
                          onChanged: (value) {
                            setDialogState(() {
                              selectedStatus = value;
                            });
                          },
                          decoration: InputDecoration(
                            labelText: 'Status',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: dateRangeController,
                          readOnly: true,
                          onTap: () async {
                            DateTimeRange? pickedRange = await showDateRangePicker(
                              context: context,
                              firstDate: DateTime(2000),
                              lastDate:
                              DateTime.now().add(const Duration(days: 365)),
                            );
                            if (pickedRange != null) {
                              setDialogState(() {
                                selectedDateRange = pickedRange;
                                dateRangeController.text =
                                'From: ${pickedRange.start.toLocal().toString().split(' ')[0]} to ${pickedRange.end.toLocal().toString().split(' ')[0]}';
                              });
                            }
                          },
                          decoration: InputDecoration(
                            labelText: 'Date Range',
                            hintText: 'Select Date Range',
                            border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8)),
                            contentPadding: const EdgeInsets.symmetric(
                                horizontal: 12, vertical: 10),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                  actions: [
                    _actionButton(
                      text: "Clear",
                      icon: Icons.clear,
                      color: Colors.red,
                      onPressed: clearFilters,
                    ),
                    _actionButton(
                      text: "Apply Filters",
                      icon: Icons.check,
                      color: Colors.green,
                      onPressed: () {
                        setState(() {
                          filterStatus = selectedStatus;
                          if (selectedDateRange != null) {
                            filterStartDate = selectedDateRange!.start;
                            filterEndDate = selectedDateRange!.end;
                          }
                        });
                        Navigator.pop(context);
                      },
                    ),
                  ],
                );
              },
            );
          },
        );
      }

      Future<void> showLeaveRequestDetailDialog(Map<String, dynamic> leaveRequest) async {
        leaveRequestId = leaveRequest['id'];
        reasonController.text = leaveRequest['reason'];
        status = leaveRequest['status'];

        if (role == null) {
          role = await getUserRole();
        }


        if (role == 'employee' ||
            role == "teamlead" ||
            (role == "teamlead" && leaveRequest['creator_role'] == "employee"))
        {
          showDialog(
            context: context,
            builder: (context) {
              return AlertDialog(
                backgroundColor: Colors.grey.shade300,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
                title: Row(
                  children: [
                    const Text(
                      'Leave Request Details',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                    ),
                    const Spacer(),
                    IconButton(
                      onPressed: () {
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                content: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Divider(color: Colors.grey.shade400),
                      _detailRow(
                        title: 'Name',
                        value: leaveRequest['user_name'],
                      ),
                      _detailRow(
                        title: 'Reason',
                        value: leaveRequest['reason'],
                      ),
                      _detailRow(
                        title: 'Department',
                        value: leaveRequest['department'],
                      ),
                      _detailRow(
                        title: 'Start Date',
                        value: DateFormat('yyyy-MM-dd').format(
                          leaveRequest['start_date'] is Timestamp
                              ? (leaveRequest['start_date'] as Timestamp).toDate()
                              : leaveRequest['start_date'],
                        ),
                      ),
                      _detailRow(
                        title: 'End Date',
                        value: DateFormat('yyyy-MM-dd').format(
                          leaveRequest['end_date'] is Timestamp
                              ? (leaveRequest['end_date'] as Timestamp).toDate()
                              : leaveRequest['end_date'],
                        ),
                      ),
                      _statusRow(
                        title: 'Current Status',
                        value: leaveRequest['status'],
                      ),
                    ],
                  ),
                ),
                actionsAlignment: MainAxisAlignment.spaceBetween,
                actions: [
                  if (status == "Pending" && role == "teamlead") ...[
                    _actionButton(
                      text: 'Approve',
                      icon: Icons.check,
                      color: Colors.green,
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);

                        FirebaseFirestore.instance
                            .collection('leave_records')
                            .doc(leaveRequestId)
                            .update({'status': 'Approved'}).then((value) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Leave request approved!'),
                              backgroundColor: Colors.green,
                            ),
                          );
                          getData();
                        }).catchError((error) {
                          messenger.showSnackBar(
                            SnackBar(
                              content:
                              Text('Failed to approve leave request: $error'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }).whenComplete(() {
                          navigator.pop();
                        });
                      },
                    ),
                    _actionButton(
                      text: 'Reject',
                      icon: Icons.close,
                      color: Colors.red,
                      onPressed: () {
                        final navigator = Navigator.of(context);
                        final messenger = ScaffoldMessenger.of(context);

                        FirebaseFirestore.instance
                            .collection('leave_records')
                            .doc(leaveRequestId)
                            .update({'status': 'Rejected'}).then((value) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Leave request rejected!'),
                              backgroundColor: Colors.red,
                            ),
                          );
                          getData();
                        }).catchError((error) {
                          messenger.showSnackBar(
                            SnackBar(
                              content:
                              Text('Failed to reject leave request: $error'),
                              backgroundColor: Colors.red,
                            ),
                          );
                        }).whenComplete(() {
                          navigator.pop();
                        });
                      },
                    ),
                  ],
                  if (role == "employee" &&
                      leaveRequest['creator_role'] == "employee" &&
                      leaveRequest['status'] != 'Approved' &&
                      leaveRequest['status'] != 'Rejected')
                    SizedBox(
                        width: double.infinity,
                        child: ElevatedButton.icon(
                          onPressed: () {
                            showLeaveRequestDialog(leaveRequest, () {});
                          },
                          icon: Icon(Icons.close, color: Colors.white),
                          label: Text(
                            "Update request",
                            style: const TextStyle(color: Colors.white),
                          ),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ))
                ],
              );
            },
          );
        }
      }
      Widget _detailRow({required String title, required String value}) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  '$title:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  value,
                  style: const TextStyle(
                    fontSize: 14,
                    color: Colors.black87,
                  ),
                ),
              ),
            ],
          ),
        );
      }
      Widget _statusRow({required String title, required String value}) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8.0),
          child: Row(
            children: [
              Expanded(
                flex: 2,
                child: Text(
                  '$title:',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Chip(
                  label: Text(
                    value,
                    style: TextStyle(
                      color: value == 'Approved'
                          ? Colors.green
                          : value == 'Rejected'
                          ? Colors.red
                          : Colors.orange,
                    ),
                  ),
                  backgroundColor: Colors.grey.shade200,
                ),
              ),
            ],
          ),
        );
      }
      Widget _actionButton({
        required String text,
        required IconData icon,
        required Color color,
        required VoidCallback onPressed,
      }) {
        return ElevatedButton.icon(
          onPressed: onPressed,
          icon: Icon(icon, color: Colors.white),
          label: Text(
            text,
            style: const TextStyle(color: Colors.white),
          ),
          style: ElevatedButton.styleFrom(
            backgroundColor: color,
            padding: const EdgeInsets.symmetric(horizontal: 25, vertical: 10),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        );
      }
    }
    class ConnectivityService {

    }

    class LeaveRequestService {
      final Box<LeaveRequest> leaveRequestBox = Hive.box<LeaveRequest>('leaveRequestsBox');

      Future<void> addLeaveRequest(LeaveRequest leaveRequest) async {
        await leaveRequestBox.put(leaveRequest.Id, leaveRequest);
      }

      Future<void> updateLeaveRequest(LeaveRequest leaveRequest) async {
        await leaveRequestBox.put(leaveRequest.Id, leaveRequest);
      }

      Future<void> deleteLeaveRequest(String id) async {
        await leaveRequestBox.delete(id);
      }

      List<LeaveRequest> getLeaveRequests() {
        return leaveRequestBox.values.toList();
      }
    }
