import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class Leave1 extends StatefulWidget {
  const Leave1({super.key});

  @override
  State<Leave1> createState() => _LeaveState();
}

class _LeaveState extends State<Leave1> {
  List<QueryDocumentSnapshot> currentData = [];
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  String? role;
  String? Name;
  bool isLoading = true;
  String searchQuery = '';
  String? userid;
  Query? query;
  DateTime? startDate;
  DateTime? endDate;
  String? leaveType;
  String? reason;
  String? status;
  String? leaveRequestId;
  String? department;
  String? userName;
  DateTime? filterStartDate;
  DateTime? filterEndDate;
  String? filterStatus;
  TextEditingController searchController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final TextEditingController reasonController = TextEditingController();

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
                  IconButton(
                    onPressed: () {
                      Navigator.pop(context);
                    },
                    icon: Icon(Icons.close),
                  )
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
                                ' ${pickedRange.start.toLocal().toString().split(' ')[0]} to ${pickedRange.end.toLocal().toString().split(' ')[0]}';
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

  List<QueryDocumentSnapshot> getFilteredData() {
    List<QueryDocumentSnapshot> filteredData = currentData;
    if (searchQuery.isNotEmpty) {
      filteredData = filteredData.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final name = data['user_name'].toString().toLowerCase();
        final department = data['department'].toString().toLowerCase();
        final reason = data['reason'].toString().toLowerCase();
        final type = data['leave_type'].toString().toLowerCase();

        final startDate = data['start_date'] != null
            ? (data['start_date'] as Timestamp).toDate()
            : null;
        final endDate = data['end_date'] != null
            ? (data['end_date'] as Timestamp).toDate()
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
                startDate
                    .toString()
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase())) ||
            (endDate != null &&
                endDate
                    .toString()
                    .toLowerCase()
                    .contains(searchQuery.toLowerCase())) ||
            startMonth.contains(searchQuery.toLowerCase()) ||
            endMonth.contains(searchQuery.toLowerCase());
      }).toList();
    }

    if (filterStartDate != null && filterEndDate != null) {
      filteredData = filteredData.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
        final startDate = (data['start_date'] as Timestamp).toDate();
        return startDate.isAfter(filterStartDate!) &&
            startDate.isBefore(filterEndDate!);
      }).toList();
    }

    if (filterStatus != null) {
      filteredData = filteredData.where((doc) {
        final data = doc.data() as Map<String, dynamic>;
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

  void getData() {
    final User? user = auth.currentUser;
    final uid = user!.uid;

    setState(() {});
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
            Name = data["name"];
          });

          if (role == "admin") {
            AdminQuery();
          } else if (role == "teamlead") {
            TeamLeadQuery(uid);
          }
        }
      } else {
        print('Document does not exist in database');
      }
    }).catchError((error) {
      print('Failed to fetch user data: $error');
      setState(() {});
    });
  }

  void TeamLeadQuery(String userId) {
    FirebaseFirestore.instance
        .collection('leave_records')
        .where('creator_role', whereIn: ['teamlead'])
        .orderBy('start_date')
        .get()
        .then((querySnapshot) {
          setState(() {
            currentData = querySnapshot.docs;
          });
        })
        .catchError((error) {
          print('Failed to fetch leave requests: $error');
          setState(() {});
        });
  }

  void AdminQuery() {
    FirebaseFirestore.instance
        .collection('leave_records')
        .where("creator_role", isEqualTo: 'teamlead')
        .orderBy('start_date')
        .get()
        .then((querySnapshot) {
      setState(() {
        currentData = querySnapshot.docs;
      });
    }).catchError((error) {
      print('Failed to fetch leave requests: $error');
    });
  }

  void saveLeaveRequest() {
    Navigator.pop(context);

    final User? user = auth.currentUser;
    final uid = user!.uid;

    if (_formKey.currentState!.validate()) {
      _formKey.currentState!.save();
      FirebaseFirestore.instance.collection('user').doc(uid).get().then((doc) {
        if (doc.exists) {
          final userName = doc['name'];

          final leaveData = {
            'leave_type': leaveType,
            'reason': reason,
            'start_date': startDate,
            'end_date': endDate,
            'status': status ?? 'Pending',
            'department': department,
            'creator_role': role,
            'timestamp': FieldValue.serverTimestamp(),
            'user_id': uid,
            'user_name': userName,
          };

          if (leaveRequestId == null) {
            FirebaseFirestore.instance
                .collection('leave_records')
                .add(leaveData)
                .then((value) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Leave request submitted successfully!')),
              );
              getData();
            }).catchError((error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Failed to submit leave request: $error')),
              );
            });
          } else {
            FirebaseFirestore.instance
                .collection('leave_records')
                .doc(leaveRequestId)
                .update({
              'leave_type': leaveType,
              'reason': reason,
              'start_date': startDate,
              'end_date': endDate,
              'status': status ?? 'Pending',
              'department': department,
              'user_name': userName,
            }).then((value) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Leave request updated successfully!')),
              );
              getData();

              FirebaseFirestore.instance
                  .collection('leave_records')
                  .doc(leaveRequestId)
                  .get()
                  .then((updatedDoc) {
                if (updatedDoc.exists) {
                  Navigator.pop(context);
                  showLeaveRequestDetailDialog(updatedDoc);
                }
              });
              Navigator.pop(context);
            }).catchError((error) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Failed to update leave request: $error')),
              );
            });
          }
        }
      });
    }
  }

  @override
  void initState() {
    super.initState();
    getData();
  }

  void showLeaveRequestDetailDialog(DocumentSnapshot leaveRequest) {
    leaveRequestId = leaveRequest.id;
    reasonController.text = leaveRequest['reason'];
    status = leaveRequest['status'];

    if (role == 'admin' ||
        role == "teamlead" ||
        (role == "teamlead" && leaveRequest['creator_role'] == "teamlead")) {
      showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            backgroundColor: Colors.grey.shade300,
            title: Row(
              children: [
                Text(
                  'Leave Request Details',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 20),
                ),
                SizedBox(width: 5),
                IconButton(
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.close),
                )
              ],
            ),
            content: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
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
                    value: DateFormat('yyyy-MM-dd')
                        .format(leaveRequest['start_date'].toDate()),
                  ),
                  _detailRow(
                    title: 'End Date',
                    value: DateFormat('yyyy-MM-dd')
                        .format(leaveRequest['end_date'].toDate()),
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
              if (status == "Pending" && role == "admin") ...[
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
                      getData(); // Refresh data
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
                      getData(); // Refresh data
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
              if (role == "teamlead" &&
                  leaveRequest['creator_role'] == "teamlead" &&
                  leaveRequest['status'] != 'Approved' &&
                  leaveRequest['status'] != 'Rejected')
                _actionButton(
                  text: "Update Request",
                  icon: Icons.close,
                  color: Colors.red,
                  onPressed: () {
                    showLeaveRequestDialog(leaveRequest, () {
                      FirebaseFirestore.instance
                          .collection('leave_records')
                          .doc(leaveRequestId)
                          .get()
                          .then((updatedDoc) {
                        if (updatedDoc.exists) {
                          showLeaveRequestDetailDialog(updatedDoc);
                        }
                      });
                    });
                  },
                )
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }

  TextEditingController _startDateController = TextEditingController();
  TextEditingController _endDateController = TextEditingController();

  void showLeaveRequestDialog(
      [DocumentSnapshot? workDetail, VoidCallback? onUpdate]) {
    if (workDetail != null) {
      leaveRequestId = workDetail.id;
      leaveType = workDetail['leave_type'];
      reason = workDetail['reason'];
      startDate = workDetail['start_date'].toDate();
      endDate = workDetail['end_date'].toDate();
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
                      decoration: InputDecoration(
                        labelText: 'Reason ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.edit),
                      ),
                      onSaved: (value) => reason = value,
                      onChanged: (value) {
                        reason = value;
                      },
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
                      items: [
                        'Software',
                        'Marketing',
                        'Finance',
                      ]
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
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                      items: [
                        'Sick Leave',
                        'Casual Leave',
                        'Vacation',
                      ]
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
                          borderRadius: BorderRadius.circular(10),
                        ),
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
                      decoration: InputDecoration(
                        labelText: 'Start Date ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.calendar_today),
                      ),
                      onTap: () async {
                        final DateTime? selectedDate = await showDatePicker(
                          context: context,
                          initialDate: startDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
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
                      decoration: InputDecoration(
                        labelText: 'End Date ',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      onTap: () async {
                        final DateTime? selectedDate = await showDatePicker(
                          context: context,
                          initialDate: endDate ?? DateTime.now(),
                          firstDate: DateTime(2000),
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
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _actionButton(
                        text: workDetail == null ? 'Submit' : 'Update',
                        icon: Icons.close,
                        color: Colors.green,
                        onPressed: () {
                          if (_formKey.currentState!.validate()) {
                            _formKey.currentState!.save();
                            saveLeaveRequest();
                            if (onUpdate != null) {
                              onUpdate();
                            }
                          }
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final filteredData = getFilteredData();
    return Scaffold(
      appBar: AppBar(
        title: role == 'teamlead'
            ? Text(
                'My Leave Records',
                style: TextStyle(fontWeight: FontWeight.bold),
              )
            : Text(
                "Leave Records",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
        actions: [
          IconButton(onPressed: showFilterDialog, icon: Icon(Icons.tune))
        ],
      ),
      body: Column(
        children: [
          // Search Bar
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
                    DateTime startDate = workDetail['start_date'].toDate();
                    DateTime endDate = workDetail['end_date'].toDate();
                    String formattedStartDate =
                        DateFormat('dd MMM yyyy').format(startDate);
                    String formattedEndDate =
                        DateFormat('dd MMM yyyy').format(endDate);
                    String statusText = workDetail['status'] ?? 'Pending';
                    String workName = workDetail['user_name'];

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
                              if (role == "admin")
                                Row(
                                  children: [
                                    Icon(Icons.person,
                                        color: Colors.blueGrey, size: 22),
                                    SizedBox(width: 8),
                                    Text(
                                      workName,
                                      style: TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.black87),
                                    ),
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

                              if (role == "admin" && statusText == 'Pending')
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    _actionButton(
                                        text: "Approve",
                                        icon: Icons.check,
                                        color: Colors.green,
                                        onPressed: () {
                                          FirebaseFirestore.instance
                                              .collection('leave_records')
                                              .doc(workDetail.id)
                                              .update({
                                            'status': 'Approved'
                                          }).then((value) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Leave request approved!'),
                                                  backgroundColor:
                                                      Colors.green),
                                            );
                                            getData();
                                          }).catchError((error) {
                                            ScaffoldMessenger.of(context)
                                                .showSnackBar(
                                              SnackBar(
                                                  content: Text(
                                                      'Failed to approve leave request: $error'),
                                                  backgroundColor: Colors.red),
                                            );
                                          });
                                        }),
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
                                              .doc(workDetail.id)
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
                              if (role == "employee" && statusText == "Pending")
                                Align(
                                  alignment: Alignment.bottomRight,
                                  child: TextButton.icon(
                                    onPressed: () {
                                      FirebaseFirestore.instance
                                          .collection('leave_records')
                                          .doc(workDetail.id)
                                          .delete()
                                          .then((value) {
                                        getData();
                                      });
                                    },
                                    icon: Icon(Icons.delete,
                                        color: Colors.redAccent),
                                    label: Text('Cancel Request',
                                        style:
                                            TextStyle(color: Colors.redAccent)),
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
      floatingActionButton: role == 'teamlead'
          ? FloatingActionButton(
              backgroundColor: Colors.white,
              onPressed: showLeaveRequestDialog,
              child: Icon(Icons.add),
            )
          : SizedBox(),
    );
  }
}
