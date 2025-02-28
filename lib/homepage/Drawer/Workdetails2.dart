import 'dart:async';
import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:uuid/uuid.dart';

import '../../Hive/work_details_model.dart';

class Workdetails2 extends StatefulWidget {
  const Workdetails2({super.key});
  @override
  State<Workdetails2> createState() => _hmmState();
}

class _hmmState extends State<Workdetails2> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  String? role;
  String? userid = "";
  List<String> employees = [];
  List<Map<String, String>> employeeList = [];
  List<String> uids = [];
  Query? query;
  String? tempDepartment = 'All';
  List<String> departments = ['All', 'Software', 'Finance', 'IT', 'Sales'];
  List<Map<String, dynamic>> filteredDocs = [];
  List<Map<String, dynamic>> workDetailsList = [];
  String searchQuery = '';
  String selectedStatus = 'All';
  String selectedDepartment = 'All';
  DateTime? startDate;
  DateTimeRange? selectedDateRange;


  DateTime? endDate;
  bool isOnline = true;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  late Box<WorkDetails> workDetailsBox;

  void getData() async {
    final User? user = auth.currentUser;
    if (user == null) return;
    final uid = user.uid;
    final docusnapshot = await FirebaseFirestore.instance.collection('user')
        .doc(uid)
        .get();
    if (docusnapshot.exists && mounted) {
      final data = docusnapshot.data() as Map<String, dynamic>?;
      setState(() {
        role = data!['role'];
      });
    }

    final snapshot = await FirebaseFirestore.instance.collection('user').get();
    final List<Map<String, String>> employeesWithRoles = snapshot.docs.map((
        doc) {
      return {
        'name': doc['name'] as String,
        'role': doc['role'] as String,
        'uid': doc.id,
      };
    }).toList();

    if (mounted) {
      setState(() {
        employeeList = employeesWithRoles;
      });
    }

    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      fetchFromHive();
    } else {
      final workDetailsSnapshot = await FirebaseFirestore.instance.collection(
          'workDetails').get();
      final fetchedWorkDetails = workDetailsSnapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      if (mounted) {
        setState(() {
          workDetailsList = fetchedWorkDetails;
          filteredDocs = applyFilters(fetchedWorkDetails);
        });
      }
      syncFirestoreToHive(fetchedWorkDetails);
    }
  }

  Future<void> initializeHive() async {
    final dir = await getApplicationDocumentsDirectory();
    Hive.init(dir.path);

    if (!Hive.isAdapterRegistered(WorkDetailsAdapter().typeId)) {
      Hive.registerAdapter(WorkDetailsAdapter());
    }

    workDetailsBox = await Hive.openBox<WorkDetails>('workDetails');
  }

  void fetchFromHive() {
    final hiveData = workDetailsBox.values.map((workDetail) =>
        workDetail.toMap()).toList();

    if (!mounted) return;

    setState(() {
      workDetailsList = hiveData;
      filteredDocs = applyFilters(workDetailsList);
    });
    print("Data from Hive: $workDetailsList");
  }


  void syncFirestoreToHive(List<Map<String, dynamic>> firestoreData) async {
    await workDetailsBox.clear();
    for (var data in firestoreData) {
      final workDetail = WorkDetails.fromMap(data);
      await workDetailsBox.put(workDetail.id, workDetail);
    }
  }

  void clearQuery() {
    setState(() {
      query = FirebaseFirestore.instance.collection('workDetails');
      selectedStatus = 'All';
      selectedDepartment = 'All';
      startDate = null;
      endDate = null;
    });

    FirebaseFirestore.instance.collection('workDetails').get().then((snapshot) {
      List<Map<String, dynamic>> allWorkDetails = snapshot.docs
          .map((doc) => doc.data() as Map<String, dynamic>)
          .toList();

      setState(() {
        filteredDocs = allWorkDetails;
      });
    });
  }

  List<Map<String, dynamic>> applyFilters(List<Map<String, dynamic>> workDocs) {
    return workDocs.where((workDetail) {
      final workTitle = workDetail['title']?.toLowerCase() ?? '';
      final department = workDetail['Department']?.toLowerCase() ?? '';
      final status = workDetail['Status']?.toLowerCase() ?? '';

      final deadline = workDetail['deadline'] != null
          ? (workDetail['deadline'] is Timestamp
          ? (workDetail['deadline'] as Timestamp).toDate()
          : workDetail['deadline'] as DateTime?)
          : null;

      // Search query filtering
      final searchMatch = workTitle.contains(searchQuery.toLowerCase()) ||
          department.contains(searchQuery.toLowerCase()) ||
          status.contains(searchQuery.toLowerCase()) ||
          (deadline != null &&
              DateFormat('yyyy-MM-dd').format(deadline).contains(searchQuery.toLowerCase()));

      // Status filtering
      final statusMatch = selectedStatus == 'All' || status == selectedStatus.toLowerCase();

      // Department filtering
      final departmentMatch = selectedDepartment == 'All' || department == selectedDepartment.toLowerCase();

      // Date range filtering
      final dateMatch = selectedDateRange == null ||
          (deadline != null &&
              deadline.isAfter(selectedDateRange!.start.subtract(Duration(days: 1))) &&
              deadline.isBefore(selectedDateRange!.end.add(Duration(days: 1))));

      return searchMatch && statusMatch && departmentMatch && dateMatch;
    }).toList();
  }


  void applyFiltersAndUpdate() {
    setState(() {
      filteredDocs = applyFilters(workDetailsList);
    });
  }

  void deleteWorkDetail(String workDetailId) async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      await workDetailsBox.delete(workDetailId);
      setState(() {
        workDetailsList.removeWhere((detail) => detail['id'] == workDetailId);
        filteredDocs = applyFilters(workDetailsList);
      });
    } else {
      _firestore.collection('workDetails').doc(workDetailId).delete();
      getData();
    }
  }

  Future<void> saveWorkDetail({Map<String, dynamic>? workDetail}) async {
    final String workId = workDetail != null && workDetail.containsKey("id")
        ? workDetail["id"]
        : Uuid().v4();

    final data = {
      'id': workId,
      'title': titleController.text,
      'description': descriptionController.text,
      'Department': departmentController.text,
      'Status': statusController.text,
      'Priority': priorityController.text,
      'Progressupdates': progressController.text,
      'StartDate': startDate != null ? Timestamp.fromDate(startDate!) : null,
      'deadline': deadline != null ? Timestamp.fromDate(deadline!) : null,
      'AssignedTo': selectedEmployeeName,
      'AssignedtoUid': selectedEmployeeUid,
    };

    try {
      var connectivityResult = await Connectivity().checkConnectivity();
      if (connectivityResult == ConnectivityResult.none) {
        final workDetails = WorkDetails.fromMap(data);
        await workDetailsBox.put(workId, workDetails);
        setState(() {
          workDetailsList.add(workDetails.toMap());
          filteredDocs = applyFilters(workDetailsList);
          fetchFromHive();
          getData();
        });
      } else {
        final workDetailsRef = FirebaseFirestore.instance.collection(
            'workDetails');
        if (workDetail != null) {
          await workDetailsRef.doc(workId).update(data);
        } else {
          await workDetailsRef.doc(workId).set(data);
        }
        getData();
        await syncHiveToFirestore();
        syncFirestoreToHive(workDetailsList);
      }
    } catch (e) {
      print("Error saving work detail: $e");
    }
    Navigator.pop(context);
  }


  Future<void> syncHiveToFirestore() async {
    final workDetailsRef = FirebaseFirestore.instance.collection('workDetails');
    final hiveData = workDetailsBox.values.toList();

    for (var workDetail in hiveData) {
      await workDetailsRef.doc(workDetail.id).set(workDetail.toMap());
    }
    await workDetailsBox.clear();
  }

  void initializeWorkDetail(Map<String, dynamic>? workDetail) {
    titleController.text = workDetail?['title'] ?? '';
    descriptionController.text = workDetail?['description'] ?? '';
    departmentController.text = workDetail?['Department'] ?? '';
    statusController.text = workDetail?['Status'] ?? '';
    priorityController.text = workDetail?['Priority'] ?? '';
    progressController.text = workDetail?['Progressupdates'].toString() ?? '';

    selectedEmployeeUid = workDetail?['AssignedtoUid'];
    selectedEmployeeName = workDetail?['AssignedTo'];

    startDate = workDetail?['StartDate'] is Timestamp
        ? (workDetail?['StartDate'] as Timestamp).toDate()
        : DateTime.now();

    deadline = workDetail?['deadline'] is Timestamp
        ? (workDetail?['deadline'] as Timestamp).toDate()
        : DateTime.now();
  }

  StreamSubscription? connectivitySubscription;

  Future<bool> checkInternetConnection() async {
    ConnectivityResult result = await Connectivity().checkConnectivity();
    return result != ConnectivityResult.none;
  }

  Future<void> queueDeletedData(String workId) async {
    final deletedBox = await Hive.openBox<String>('deletedWorkDetails');
    await deletedBox.put(workId, workId);
  }

  Future<void> syncDeletedData() async {
    bool isOnline = await checkInternetConnection();
    if (!isOnline) return;

    final deletedBox = await Hive.openBox<String>('deletedWorkDetails');
    final workDetailsRef = FirebaseFirestore.instance.collection('workDetails');

    for (var key in deletedBox.keys) {
      try {
        await workDetailsRef.doc(key).delete();
        await deletedBox.delete(key);
      } catch (e) {
        print("Error syncing deleted work detail: $e");
      }
    }
  }

  @override
  void initState() {
    super.initState();
    initializeHive().then((_) {
      fetchFromHive();
      getData();
    });

    clearQuery();
    connectivitySubscription = Connectivity()
        .onConnectivityChanged
        .listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        syncHiveToFirestore();
      }
    });
  }

  @override
  void dispose() {
    titleController.dispose();
    descriptionController.dispose();
    departmentController.dispose();
    statusController.dispose();
    priorityController.dispose();
    progressController.dispose();
    connectivitySubscription?.cancel();
    super.dispose();
  }

  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade300,
        title: Text("Workdetails"),
        actions: [
          IconButton(
            icon: Icon(Icons.filter_list),
            onPressed: showFilterDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: TextField(
              onChanged: (value) {
                setState(() {
                  searchQuery = value;
                });
                applyFiltersAndUpdate();
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
            child: ListView.builder(
              itemCount: filteredDocs.length,
              itemBuilder: (context, index) {
                final workDetail = filteredDocs[index];
                final workTitle = workDetail['title'];
                final Startdate = workDetail['StartDate'];
                final workDeadline = workDetail['deadline'];
                final Department = workDetail['Department'];
                final Status = workDetail['Status'];
                final workId = workDetail['id'];
                final progressUpdates =
                    double.tryParse(workDetail['Progressupdates'].toString()) ??
                        0;
                final progress = progressUpdates > 1.0
                    ? progressUpdates / 100
                    : progressUpdates;
                final formatdated = Startdate != null
                    ? DateFormat("yyyy-MM-dd").format(
                    Startdate is Timestamp ? Startdate.toDate() : Startdate)
                    : "N/A";

                final deadlineformat = workDeadline != null
                    ? DateFormat("yyyy-MM-dd").format(workDeadline is Timestamp
                    ? workDeadline.toDate()
                    : workDeadline)
                    : "N/A";
                return Card(
                  margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                  elevation: 5,
                  child: ListTile(
                    title: Center(
                      child: Text(
                        workTitle,
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(Department ?? ""),
                        Text(
                          "Deadline: $deadlineformat",
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          Status ?? "N/A",
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Status.toLowerCase() == 'completed'
                                ? Colors.green
                                : Colors.red,
                          ),
                        ),
                        SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress,
                          backgroundColor: Colors.grey[300],
                          color: progress >= 1.0 ? Colors.green : Colors.red,
                        ),
                      ],
                    ),
                    trailing: role == 'teamlead' || role == 'admin'
                        ? IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () async {
                        bool isOnline = await checkInternetConnection();
                        String workId = workDetail["id"];

                        if (isOnline) {
                          try {
                            await _firestore
                                .collection('workDetails')
                                .doc(workId)
                                .delete();
                            await workDetailsBox.delete(workId);
                          } catch (e) {
                            print("Error deleting work detail: $e");
                          }
                        } else {
                          await workDetailsBox.delete(workId);
                          await queueDeletedData(workId);
                        }
                        getData();
                        fetchFromHive();
                      },
                    )
                        : null,
                    onTap: () {
                      role == "admin" || role == "teamlead"
                          ? showWorkDetailDialog(
                          workDetail: filteredDocs[index])
                          : Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) =>
                              Formview(
                                title: workDetail['title'] ?? "N/A",
                                Description:
                                workDetail['description'] ?? "N/A",
                                Assignedto: workDetail['AssignedTo'] ?? "N/A",
                                StartDate: formatdated ?? 'N/A',
                                Enddate: deadlineformat ?? 'N/A',
                                ProgressUpdates:
                                workDetail['Progressupdates'] ?? "N/A",
                                Status: workDetail['Status'] ?? 'N/A',
                                Priority: workDetail['Priority'] ?? "N/A",
                                Department: workDetail['Department'] ?? "N/A",
                              ),
                        ),
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: role == "admin" || role == "teamlead"
          ? FloatingActionButton(
        onPressed: () {
          showWorkDetailDialog();
        },
        child: Icon(Icons.add),
      )
          : SizedBox(),
    );
  }

  final TextEditingController titleController = TextEditingController();
  final TextEditingController descriptionController = TextEditingController();
  final TextEditingController departmentController = TextEditingController();
  final TextEditingController statusController = TextEditingController();
  final TextEditingController priorityController = TextEditingController();
  final TextEditingController progressController = TextEditingController();
  String? selectedEmployeeUid;
  String? selectedEmployeeName;
  DateTime? deadline;
  String? workDetailId;

  void showWorkDetailDialog({Map<String, dynamic>? workDetail}) {
    initializeWorkDetail(workDetail);
    showDialog(
      context: context,
      builder: (context) =>
          Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: SingleChildScrollView(
                child: Form(
                  key: _formKey,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        workDetail == null
                            ? "Add Work Detail"
                            : "Update Work Detail",
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _buildTextField(
                        controller: titleController,
                        label: "Title",
                        hint: "Enter the work title",
                        validator: (value) {
                          if (value == null || value
                              .trim()
                              .isEmpty) {
                            return 'Title is required.';
                          }
                          return null;
                        },
                      ),
                      _buildTextField(
                        controller: descriptionController,
                        label: "Description",
                        hint: "Enter a brief description",
                        validator: (value) {
                          if (value == null || value
                              .trim()
                              .isEmpty) {
                            return 'Description is required.';
                          }
                          return null;
                        },
                      ),
                      SizedBox(
                        height: 4,
                      ),
                      DropdownButtonFormField<String>(
                        value: departmentController.text.isNotEmpty
                            ? departmentController.text
                            : null,
                        decoration: InputDecoration(
                          labelText: "Department",
                          labelStyle: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.blue,
                                width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide:
                            BorderSide(color: Colors.grey[300]!, width: 1),
                          ),
                          contentPadding:
                          EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                        items: ["Software", "Finance", "Marketing", "Sales"]
                            .map((department) =>
                            DropdownMenuItem(
                              value: department,
                              child: Text(department),
                            ))
                            .toList(),
                        onChanged: (value) {
                          departmentController.text = value!;
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Department is required.';
                          }
                          return null;
                        },
                      ),
                      SizedBox(
                        height: 15,
                      ),
                      DropdownButtonFormField<String>(
                        value: statusController.text.isNotEmpty
                            ? statusController.text
                            : null,
                        decoration: InputDecoration(
                          labelText: "Status",
                          labelStyle: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.blue,
                                width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide:
                            BorderSide(color: Colors.grey[300]!, width: 1),
                          ),
                          contentPadding:
                          EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                        items: ["Pending", "Completed"]
                            .map((status) =>
                            DropdownMenuItem<String>(
                              value: status,
                              child: Text(status),
                            ))
                            .toList(),
                        onChanged: (newValue) {
                          if (newValue != null) {
                            setState(() {
                              statusController.text = newValue;
                            });
                          }
                        },
                        validator: (value) {
                          if (value == null || value
                              .trim()
                              .isEmpty) {
                            return 'Status is required.';
                          }
                          return null;
                        },
                      ),

                      SizedBox(
                        height: 15,
                      ),
                      DropdownButtonFormField<String>(
                        value: ["High", "Medium", "Low"]
                            .contains(priorityController.text)
                            ? priorityController.text
                            : null,
                        // Ensure the value is valid
                        decoration: InputDecoration(
                          labelText: "Priority",
                          labelStyle: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.blue,
                                width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide:
                            BorderSide(color: Colors.grey[300]!, width: 1),
                          ),
                          contentPadding:
                          EdgeInsets.symmetric(horizontal: 18, vertical: 16),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                        items: ["High", "Medium", "Low"]
                            .map((priority) =>
                            DropdownMenuItem(
                              value: priority,
                              child: Text(priority),
                            ))
                            .toList(),
                        onChanged: (value) {
                          priorityController.text = value!;
                        },
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Priority is required.';
                          }
                          return null;
                        },
                      ),
                      SizedBox(
                        height: 4,
                      ),
                      _buildTextField(
                        controller: progressController,
                        label: "Progress Updates (%)",
                        hint: "Enter the progress (0-100)",
                        keyboardType: TextInputType.number,
                        validator: (value) {
                          if (value == null || value
                              .trim()
                              .isEmpty) {
                            return 'Progress updates are required.';
                          }
                          final progress = double.tryParse(value);
                          if (progress == null || progress < 0 ||
                              progress > 100) {
                            return 'Enter a valid progress value between 0 and 100.';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 4),

                      const SizedBox(height: 8),
                      DropdownButtonFormField<String>(
                        value: selectedEmployeeUid,
                        items: employeeList.map((employee) {
                          return DropdownMenuItem(
                            value: employee['uid'],
                            child: Text(
                                "${employee['name']} (${employee['role']})"),
                          );
                        }).toList(),
                        onChanged: (value) {
                          setState(() {
                            selectedEmployeeUid = value;
                            selectedEmployeeName = employeeList.firstWhere(
                                  (employee) => employee['uid'] == value,
                            )['name'];
                          });
                        },
                        // validator: (value) {
                        //   if (value == null || value.isEmpty) {
                        //     return 'You must assign this work to an employee.';
                        //   }
                        //   return null;
                        // },
                        decoration: InputDecoration(
                          labelText: "Assigned To",
                          labelStyle: TextStyle(
                            color: Colors.grey[600],
                            fontWeight: FontWeight.w500,
                          ),
                          hintText: selectedEmployeeName ??
                              "Select an employee",
                          hintStyle: TextStyle(
                            color: Colors.grey[400],
                          ),
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey[300]!),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.blue,
                                width: 2),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(15),
                            borderSide: BorderSide(color: Colors.grey[300]!,
                                width: 1),
                          ),
                          contentPadding: EdgeInsets.symmetric(
                              horizontal: 18, vertical: 16),
                          filled: true,
                          fillColor: Colors.white,
                          isDense: true,
                        ),
                      ),

                      const SizedBox(height: 14),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildDateSelector(
                            context,
                            "Start Date",
                            startDate,
                                (selectedDate) {
                              setState(() {
                                startDate = selectedDate;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Start Date is required.';
                              }
                              return null;
                            },
                          ),
                          _buildDateSelector(
                            context,
                            "Deadline",
                            deadline,
                                (selectedDate) {
                              setState(() {
                                deadline = selectedDate;
                              });
                            },
                            validator: (value) {
                              if (value == null) {
                                return 'Deadline is required.';
                              } else if (deadline != null &&
                                  deadline!.isBefore(startDate!)) {
                                return 'Deadline must be after the Start Date.';
                              }
                              return null;
                            },
                          ),
                        ],
                      ),
                      const SizedBox(height: 30),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () {
                              Navigator.pop(context);
                            },
                            child: Text(
                              "Cancel",
                              style: TextStyle(color: Colors.black),
                            ),
                          ),
                          ElevatedButton(
                            onPressed: () async {
                              if (_formKey.currentState!.validate()) {
                                saveWorkDetail(workDetail: workDetail);
                              }
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                            ),
                            child: Text(
                              workDetail == null ? "Add" : "Update",
                              style: TextStyle(color: Colors.white),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
    );
  }

  void showFilterDialog() {
    showDialog(
      context: context,
      builder: (context) {
        String tempStatus = selectedStatus;
        String tempDepartment = selectedDepartment;
        DateTimeRange? tempDateRange = selectedDateRange;

        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(
                'Filter Work Details',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              content: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12.0, horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Status Dropdown
                      Text('Status', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      DropdownButton<String>(
                        value: tempStatus,
                        onChanged: (value) => setState(() => tempStatus = value!),
                        items: ['All', 'Completed', 'Pending']
                            .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status, style: TextStyle(color: Colors.black)),
                        ))
                            .toList(),
                        isExpanded: true,
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 16),

                      // Department Selection (ChoiceChip)
                      Text('Department', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Wrap(
                        spacing: 8.0,
                        runSpacing: 4.0,
                        children: departments.map((department) {
                          return ChoiceChip(
                            label: Text(department),
                            selected: tempDepartment == department,
                            onSelected: (selected) {
                              setState(() {
                                tempDepartment = selected ? department : 'All';
                              });
                            },
                            selectedColor: Colors.blue,
                            backgroundColor: Colors.grey[200],
                            labelStyle: TextStyle(
                              color: tempDepartment == department ? Colors.white : Colors.black,
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 16),

                      // Date Range Picker
                      Text('Select Date Range', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      ElevatedButton(
                        onPressed: () async {
                          DateTimeRange? pickedDateRange = await showDateRangePicker(
                            context: context,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            initialDateRange: tempDateRange,
                          );

                          if (pickedDateRange != null) {
                            setState(() {
                              tempDateRange = pickedDateRange;
                            });
                          }
                        },
                        child: Text(tempDateRange == null
                            ? 'Select Date Range'
                            : '${DateFormat('yyyy-MM-dd').format(tempDateRange!.start)} - ${DateFormat('yyyy-MM-dd').format(tempDateRange!.end)}'),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
              actions: [
                // Clear Filters Button
                ElevatedButton.icon(
                  onPressed: () {
                    setState(() {
                      tempStatus = 'All';
                      tempDepartment = 'All';
                      tempDateRange = null;
                    });

                    selectedStatus = 'All';
                    selectedDepartment = 'All';
                    selectedDateRange = null;

                    clearQuery();
                    Navigator.pop(context);
                  },
                  icon: Icon(Icons.clear),
                  label: Text("Clear All"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                // Apply Filters Button
                ElevatedButton(
                  onPressed: () {
                    setState(() {
                      selectedStatus = tempStatus;
                      selectedDepartment = tempDepartment;
                      selectedDateRange = tempDateRange;
                    });
                    applyFiltersAndUpdate();
                    Navigator.pop(context);
                  },
                  child: Text('Apply', style: TextStyle(fontSize: 16, color: Colors.white)),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  ),
                ),
              ],
            );
          },
        );
      },
    );
  }


}

class Formview extends StatelessWidget {
  final String title;
  final String Description;

  final String Assignedto;
  final String StartDate;
  final String Enddate;
  final String ProgressUpdates;

  final String Status;
  final String Priority;
  final String Department;

  const Formview(
      {super.key,
      required this.title,
      required this.Description,
      required this.Assignedto,
      required this.StartDate,
      required this.Enddate,
      required this.ProgressUpdates,
      required this.Status,
      required this.Priority,
      required this.Department});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.grey.shade300,
        title: Text(
          "Project Details",
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 22,
            color: Colors.black87,
          ),
        ),
        elevation: 1,
        actions: [
          IconButton(
              onPressed: () async {
                final pdf = pw.Document();
                pdf.addPage(
                  pw.Page(
                    pageFormat: PdfPageFormat.a4,
                    build: (pw.Context context) {
                      return pw.Padding(
                        padding: pw.EdgeInsets.all(20),
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            pw.Center(
                              child: pw.Text(
                                'Project Overview',
                                style: pw.TextStyle(
                                  fontSize: 28,
                                  fontWeight: pw.FontWeight.bold,
                                  color: PdfColors.black,
                                ),
                              ),
                            ),
                            pw.SizedBox(height: 20),
                            _buildSection(
                              title: 'Project Name',
                              content: title,
                            ),
                            _buildSection(
                              title: 'Description',
                              content: Description,
                            ),
                            _buildSection(
                              title: 'Start Date',
                              content: StartDate,
                            ),
                            _buildSection(
                              title: 'Deadline',
                              content: Enddate,
                            ),
                            _buildSection(
                              title: 'Department',
                              content: Department,
                            ),
                            _buildSection(
                              title: 'Status',
                              content: Status,
                            ),
                            _buildSection(
                              title: 'Priority',
                              content: Priority,
                            ),
                            _buildSection(
                              title: 'Progress Updates',
                              content: ProgressUpdates,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                );

                final output = await getExternalStorageDirectory();
                final file = File("${output!.path}/work_detail.pdf");
                await file.writeAsBytes(await pdf.save());
                Printing.sharePdf(
                    bytes: await pdf.save(), filename: 'work_detail.pdf');
              },
              icon: Icon(Icons.picture_as_pdf)),
        ],
      ),
      backgroundColor: Colors.grey.shade300,
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Card(
                elevation: 4,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _buildDetailRow("Project Name", title),
                      _buildDetailRow("Description", Description),
                      _buildDetailRow("Assigned To", Assignedto),
                      _buildDetailRow("Start Date", StartDate),
                      _buildDetailRow("Deadline", Enddate),
                      _buildDetailRow("Department", Department),
                      _buildDetailRow("Status", Status),
                      _buildDetailRow("Priority", Priority),
                      _buildDetailRow("Progress Updates", ProgressUpdates),
                    ],
                  ),
                ),
              ),
              SizedBox(height: 20),
              // Close Button
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black,
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                  child: Text(
                    "Close",
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
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

Widget _buildDetailRow(String label, String value) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 8.0),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          flex: 3,
          child: Text(
            label,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: Colors.grey[700],
            ),
          ),
        ),
        SizedBox(width: 10),
        Expanded(
          flex: 5,
          child: Text(
            value,
            style: TextStyle(
              fontSize: 14,
              color: Colors.black,
            ),
          ),
        ),
      ],
    ),
  );
}

pw.Widget _buildSection({required String title, required String content}) {
  return pw.Container(
    width: 900,
    margin: pw.EdgeInsets.only(bottom: 12),
    padding: pw.EdgeInsets.all(10),
    decoration: pw.BoxDecoration(
      border: pw.Border.all(color: PdfColors.grey, width: 1),
      borderRadius: pw.BorderRadius.circular(5),
    ),
    child: pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          title,
          style: pw.TextStyle(
            fontSize: 16,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.black,
          ),
        ),
        pw.SizedBox(height: 5),
        pw.Text(
          content,
          style: pw.TextStyle(
            fontSize: 16,
            color: PdfColors.black,
          ),
        ),
      ],
    ),
  );
}

Widget _buildTextField({
  required TextEditingController controller,
  required String label,
  required String hint,
  TextInputType keyboardType = TextInputType.text,
  String? Function(String?)? validator, // New parameter
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: TextFormField(
      controller: controller,
      keyboardType: keyboardType,
      validator: validator, // Pass validator
      decoration: InputDecoration(
        labelText: label,
        hintText: hint,
        labelStyle: TextStyle(
          color: Colors.grey[600],
          fontWeight: FontWeight.w500,
        ),
        hintStyle: TextStyle(
          color: Colors.grey[400],
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[300]!),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.blue, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
        ),
        contentPadding: EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        filled: true,
        fillColor: Colors.white,
        isDense: true,
      ),
    ),
  );
}

Widget _buildDateSelector(
  BuildContext context,
  String label,
  DateTime? selectedDate,
  Function(DateTime) onDateSelected, {
  String? Function(DateTime?)? validator,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(fontWeight: FontWeight.w500, fontSize: 16),
      ),
      GestureDetector(
        onTap: () async {
          final DateTime? pickedDate = await showDatePicker(
            context: context,
            initialDate: selectedDate ?? DateTime.now(), // Show selected date
            firstDate: DateTime.now(), // Disable past dates
            lastDate: DateTime(2100),
            initialEntryMode:
                DatePickerEntryMode.calendarOnly, // Open calendar directly
            helpText: "Select $label", // Show title
            confirmText: "OK",
            cancelText: "Cancel",
          );
          if (pickedDate != null) {
            onDateSelected(pickedDate);
          }
        },
        child: Container(

          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          margin: EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            color: Colors.white,
            border: Border.all(color: Colors.grey[300]!, width: 1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            selectedDate != null
                ? "${selectedDate.day}/${selectedDate.month}/${selectedDate.year}"
                : "Select Date",
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
      ),
      if (validator != null)
        Builder(
          builder: (context) {
            final errorText = validator(selectedDate);
            if (errorText != null) {
              return Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  errorText,
                  style: TextStyle(color: Colors.red, fontSize: 12),
                ),
              );
            }
            return SizedBox.shrink();
          },
        ),
    ],
  );
}
