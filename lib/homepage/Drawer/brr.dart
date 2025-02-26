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
  DateTime? endDate;
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  bool isOnline =true;


  void getData() async {
    final User? user = auth.currentUser;
    final uid = user!.uid;


    final docusnapshot = await FirebaseFirestore.instance.collection('user').doc(uid).get();
    if (docusnapshot.exists) {
      final data = docusnapshot.data() as Map<String, dynamic>?;
      if (mounted) {
        setState(() {
          role = data!['role'];
          // if (role == "admin" || role == "teamlead") {
          //   fetchAllWorkDetails();
          // } else {
          //   fetchEmployeeWorkDetails();
          // }
        });
      }
    } else {
      print('Document does not exist in database');
    }


    final snapshot = await FirebaseFirestore.instance.collection('user').get();
    final List<Map<String, String>> employeesWithRoles = snapshot.docs.map((doc) {
      return {
        'name': doc['name'] as String,
        'role': doc['role'] as String,
        'uid': doc.id,
      };
    }).toList();
    setState(() {
      employeeList = employeesWithRoles;
    });

    final workDetailsSnapshot = await FirebaseFirestore.instance.collection('workDetails').get();
    setState(() {
      workDetailsList = workDetailsSnapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
    });
    applyFiltersAndUpdate();
  }


  void fetchAllWorkDetails() async {
    final snapshot = await FirebaseFirestore.instance.collection('workDetails').get();
    List<Map<String, dynamic>> workDetailsList = snapshot.docs.map((doc) {
      final workDetail = WorkDetails.fromMap(doc.data() as Map<String, dynamic>);
      return workDetail.toMap();
    }).toList();


    setState(() {
      this.workDetailsList = workDetailsList;
    });
  }

  void fetchEmployeeWorkDetails() async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final snapshot = await FirebaseFirestore.instance.collection('workDetails').get();
    List<Map<String, dynamic>> workDetailsList = snapshot.docs.map((doc) {
      final workDetail = WorkDetails.fromMap(doc.data() as Map<String, dynamic>);
      return workDetail.toMap();
    }).toList();


    setState(() {
      this.workDetailsList = workDetailsList;
    });
  }

  void fetchFromHive() async {
    var box = await Hive.openBox('workDetails');
    List<Map<String, dynamic>> hiveData = box.values.cast<Map<String, dynamic>>().toList();

    setState(() {
      workDetailsList = hiveData;
    });
    print("Data from hive: $workDetailsList");
  }

  void addWorkDetailsOnline(Map<String, dynamic> workDetail) async {
    try {
      await _firestore.collection('workDetails').add(workDetail);
      print("Work details added to Firestore");
    } catch (e) {
      print("Error adding work details to Firestore: $e");
    }
  }
  void addWorkDetailsOffline(Map<String, dynamic> workDetail) async {
    try {
      var box = await Hive.openBox<WorkDetails>('workDetails');
      if (!workDetail.containsKey('id')) {
        workDetail['id'] = Uuid().v4(); // Ensure ID exists
      }
      final workDetails = WorkDetails.fromMap(workDetail);
      await box.put(workDetail['id'], workDetails);
      print("Work details added to Hive with ID: ${workDetail['id']}");
    } catch (e) {
      print("Error adding work details to Hive: $e");
    }
  }

  void updateWorkDetailsOnline(String workDetailId, Map<String, dynamic> updatedData) async {
    try {
      await _firestore.collection('workDetails').doc(workDetailId).update(updatedData);
      print("Work details updated in Firestore");
    } catch (e) {
      print("Error updating work details in Firestore: $e");
    }
  }
  void updateWorkDetailsOffline(String workDetailId, Map<String, dynamic> updatedData) async {
    try {
      var box = await Hive.openBox<WorkDetails>('workDetails');
      final workDetails = box.values.firstWhere((element) => element.id == workDetailId);
      final updatedWorkDetails = WorkDetails.fromMap({...workDetails.toMap(), ...updatedData});
      await box.put(workDetailId, updatedWorkDetails);
      print("Work details updated in Hive");
    } catch (e) {
      print("Error updating work details in Hive: $e");
    }
  }
  void deleteWorkDetailsOnline(String workDetailId) async {
    try {
      await _firestore.collection('workDetails').doc(workDetailId).delete();
      print("Work details deleted from Firestore");
    } catch (e) {
      print("Error deleting work details from Firestore: $e");
    }
  }
  void deleteWorkDetailsOffline(String workDetailId) async {
    try {
      var box = await Hive.openBox<WorkDetails>('workDetails');
      final workDetailsKey = box.keys.firstWhere((key) {
        final workDetails = box.get(key);
        return workDetails != null && workDetails.id == workDetailId;
      });
      await box.delete(workDetailsKey);
      print("Work details deleted from Hive");
    } catch (e) {
      print("Error deleting work details from Hive: $e");
    }
  }
  void handleDelete(String workDetailId, bool isOnline) async {
    if (isOnline) {
      deleteWorkDetailsOnline(workDetailId);
    } else {
      deleteWorkDetailsOffline(workDetailId);
    }
  }

  void syncLocalDataWithFirestore() async {
    try {
      var box = await Hive.openBox<WorkDetails>('workDetails');
      final localWorkDetails = box.values.toList();

      for (var workDetail in localWorkDetails) {
        final workDetailMap = workDetail.toMap();
        final workDetailId = workDetailMap['id'];
        final docSnapshot = await _firestore.collection('workDetails').doc(workDetailId).get();

        if (docSnapshot.exists) {
          await _firestore.collection('workDetails').doc(workDetailId).update(workDetailMap);
        } else {
          await _firestore.collection('workDetails').doc(workDetailId).set(workDetailMap);
        }
      }

      await box.clear();
      print("Local data synced with Firestore");
    } catch (e) {
      print("Error syncing local data with Firestore: $e");
    }
  }
  void addOrUpdateWorkDetails(Map<String, dynamic> workDetail, {String? workDetailId}) async {
    try {
      if (workDetailId == null) {
        String newId = Uuid().v4();
        workDetail['id'] = newId;
        await _firestore.collection('workDetails').doc(newId).set(workDetail);
      } else {
        await _firestore.collection('workDetails').doc(workDetailId).update(workDetail);
      }
    } catch (e) {
      print("Network error, saving data locally: $e");
      if (workDetailId == null) {
        workDetailId = Uuid().v4();
        workDetail['id'] = workDetailId;
        addWorkDetailsOffline(workDetail);
      } else {
        updateWorkDetailsOffline(workDetailId, workDetail);
      }
    }
  }
  void fetchWorkDetails() async {
    try {

      final snapshot = await _firestore.collection('workDetails').get();
      List<Map<String, dynamic>> firestoreData = snapshot.docs.map((doc) => doc.data()).toList();
      var box = await Hive.openBox<WorkDetails>('workDetails');
      List<Map<String, dynamic>> hiveData = box.values.map((workDetail) => workDetail.toMap()).toList();


      List<Map<String, dynamic>> combinedData = [...firestoreData, ...hiveData];

      setState(() {
        workDetailsList = combinedData;
      });
    } catch (e) {
      print("Error fetching work details: $e");
    }
  }

  void checkNetworkAndSync() async {
    var connectivityResult = await (Connectivity().checkConnectivity());
    if (connectivityResult != ConnectivityResult.none) {

      syncLocalDataWithFirestore();
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
      final deadline = (workDetail['deadline'] as Timestamp?)?.toDate();

      final searchMatch = workTitle.contains(searchQuery.toLowerCase()) ||
          department.contains(searchQuery.toLowerCase()) ||
          status.contains(searchQuery.toLowerCase()) ||
          (deadline != null &&
              DateFormat('yyyy-MM-dd')
                  .format(deadline)
                  .contains(searchQuery.toLowerCase()));

      final departmentMatch = selectedDepartment == 'All' ||
          department == selectedDepartment.toLowerCase();
      final statusMatch =
          selectedStatus == 'All' || status == selectedStatus.toLowerCase();
      final startDateMatch = startDate == null ||
          (deadline != null && deadline.isAfter(startDate!));
      final endDateMatch =
          endDate == null || (deadline != null && deadline.isBefore(endDate!));

      return searchMatch &&
          departmentMatch &&
          statusMatch &&
          startDateMatch &&
          endDateMatch;
    }).toList();
  }

  void applyFiltersAndUpdate() {
    setState(() {
      filteredDocs = applyFilters(workDetailsList);
    });
  }

  void deleteWorkDetail(String workDetailId) {
    _firestore.collection('workDetails').doc(workDetailId).delete();
    getData();
  }

  @override
  void initState() {
    super.initState();
    initializeHive();
    getData();
    checkNetworkAndSync();
    clearQuery();
  }

  void initializeHive() async {
    if (!Hive.isAdapterRegistered(WorkDetailsAdapter().typeId)) {
      Hive.registerAdapter(WorkDetailsAdapter());
    }
    await Hive.openBox<WorkDetails>('workDetails');
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
                final formatdated =
                DateFormat("yyyy-MM-dd").format(Startdate.toDate());
                final deadlineformar =
                DateFormat("yyyy-MM-dd").format(workDeadline.toDate());

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
                        Text(Department),
                        Text(
                          "Deadline: $deadlineformar",
                          style: TextStyle(fontSize: 12),
                        ),
                        Text(
                          Status,
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
                        Navigator.of(context).pop(); // Close dialog
                        handleDelete(workId, isOnline);
                      },
                    )
                        : null,
                    onTap: () {
                      role == "admin" || role =="teamlead"
                          ? showWorkDetailDialog(
                          workDetail: filteredDocs[index])
                          : Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => Formview(
                            title: workDetail['title'],
                            Description: workDetail['description'],
                            Assignedto: workDetail['Assignedto'],
                            StartDate: formatdated ?? 'N/A',
                            Enddate: deadlineformar ?? 'N/A',
                            ProgressUpdates:
                            workDetail['Progressupdates'],
                            Status: workDetail['Status'],
                            Priority: workDetail['Priority'],
                            Department: workDetail['Department'],
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



  void showWorkDetailDialog({Map<String, dynamic>? workDetail}) {
    final TextEditingController titleController =
    TextEditingController(text: workDetail?['title'] ?? '');
    final TextEditingController descriptionController =
    TextEditingController(text: workDetail?['description'] ?? '');
    final TextEditingController departmentController =
    TextEditingController(text: workDetail?['Department'] ?? '');
    final TextEditingController statusController =
    TextEditingController(text: workDetail?['Status'] ?? '');
    final TextEditingController priorityController =
    TextEditingController(text: workDetail?['Priority'] ?? '');

    final TextEditingController progressController = TextEditingController(
        text: workDetail?['Progressupdates'].toString() ?? '');


    String? selectedEmployeeUid = workDetail?['AssignedtoUid'];
    String? selectedEmployeeName = workDetail?['Assignedto'];
    DateTime? startDate = workDetail != null
        ? (workDetail['StartDate'] as Timestamp).toDate()
        : DateTime.now();
    DateTime? deadline = workDetail != null
        ? (workDetail['deadline'] as Timestamp).toDate()
        : DateTime.now();
    String? uid = workDetail?['uid'];
    String? workDetailId = workDetail?['id'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
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
                    workDetail == null ? "Add Work Detail" : "Update Work Detail",
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
                      if (value == null || value.trim().isEmpty) {
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
                      if (value == null || value.trim().isEmpty) {
                        return 'Description is required.';
                      }
                      return null;
                    },
                  ),

                  _buildTextField(
                    controller: departmentController,
                    label: "Department",
                    hint: "Enter the department name",
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Department is required.';
                      }
                      return null;
                    },
                  ),

                  _buildTextField(
                    controller: statusController,
                    label: "Status",
                    hint: "Enter the status (e.g., 'Pending', 'Completed')",
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Status is required.';
                      }
                      return null;
                    },
                  ),

                  _buildTextField(
                    controller: priorityController,
                    label: "Priority",
                    hint: "Enter the priority (e.g., 'High', 'Medium', 'Low')",
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Priority is required.';
                      }
                      return null;
                    },
                  ),

                  _buildTextField(
                    controller: progressController,
                    label: "Progress Updates (%)",
                    hint: "Enter the progress (0-100)",
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'Progress updates are required.';
                      }
                      final progress = double.tryParse(value);
                      if (progress == null || progress < 0 || progress > 100) {
                        return 'Enter a valid progress value between 0 and 100.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),
                  Text(
                    "Assigned To",
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: Colors.grey[800],
                    ),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: selectedEmployeeUid,
                    items: employeeList.map((employee) {
                      return DropdownMenuItem(
                        value: employee['uid'],
                        child: Text("${employee['name']} (${employee['role']})"),
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
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'You must assign this work to an employee.';
                      }
                      return null;
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(15),
                        borderSide: BorderSide(color: Colors.grey[300]!),
                      ),
                      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    ),
                    hint: Text("Select an employee"),
                  ),
                  const SizedBox(height: 20),
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
                          } else if (deadline != null && deadline!.isBefore(startDate!)) {
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
                            final data = {
                              'id': workDetailId ?? Uuid().v4(),
                              'title': titleController.text,
                              'description': descriptionController.text,
                              'Department': departmentController.text,
                              'Status': statusController.text,
                              'Priority': priorityController.text,
                              'Progressupdates': progressController.text,
                              'StartDate': Timestamp.fromDate(startDate!),
                              'deadline': Timestamp.fromDate(deadline!),
                              'Assignedto': selectedEmployeeName,
                              'AssignedtoUid': selectedEmployeeUid,
                            };

                            try {
                              if (workDetail == null) {
                                addOrUpdateWorkDetails(data);
                              } else {
                                addOrUpdateWorkDetails(data, workDetailId: workDetailId);
                              }

                              getData();
                              Navigator.pop(context);
                            } catch (e) {
                              print('Error saving work details: $e');
                            }
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
        DateTime? tempStartDate = startDate;
        DateTime? tempEndDate = endDate;

        return AlertDialog(
          title: Text('Filter Work Details',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
          content: StatefulBuilder(
            builder: (context, setState) {
              return SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                      vertical: 12.0, horizontal: 16.0),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Status',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      DropdownButton<String>(
                        value: tempStatus,
                        onChanged: (value) =>
                            setState(() => tempStatus = value!),
                        items: ['All', 'Completed', 'Pending']
                            .map((status) => DropdownMenuItem(
                          value: status,
                          child: Text(status,
                              style: TextStyle(color: Colors.black)),
                        ))
                            .toList(),
                        isExpanded: true,
                        style: TextStyle(fontSize: 16),
                      ),
                      SizedBox(height: 16),
                      Text('Department',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
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
                                tempDepartment =
                                (selected ? department : null)!;
                              });
                            },
                            selectedColor: Colors.blue,
                            backgroundColor: Colors.grey[200],
                            labelStyle: TextStyle(
                              color: tempDepartment == department
                                  ? Colors.white
                                  : Colors.black,
                            ),
                          );
                        }).toList(),
                      ),
                      SizedBox(height: 20),
                      Text('Selected Department: $tempDepartment',
                          style: TextStyle(fontSize: 16)),
                      SizedBox(height: 16),
                      Text('Start Date',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 20),
                          SizedBox(width: 8),
                          Text(
                            tempStartDate != null
                                ? DateFormat('yyyy-MM-dd')
                                .format(tempStartDate!)
                                : 'Any',
                            style: TextStyle(fontSize: 16),
                          ),
                          Spacer(),
                          IconButton(
                            icon: Icon(Icons.edit, size: 20),
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              setState(() => tempStartDate = pickedDate);
                            },
                          ),
                        ],
                      ),
                      SizedBox(height: 16),
                      Text('End Date',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.w600)),
                      SizedBox(height: 8),
                      Row(
                        children: [
                          Icon(Icons.calendar_today, size: 20),
                          SizedBox(width: 8),
                          Text(
                            tempEndDate != null
                                ? DateFormat('yyyy-MM-dd').format(tempEndDate!)
                                : 'Any',
                            style: TextStyle(fontSize: 16),
                          ),
                          Spacer(),
                          IconButton(
                            icon: Icon(Icons.edit, size: 20),
                            onPressed: () async {
                              final pickedDate = await showDatePicker(
                                context: context,
                                initialDate: DateTime.now(),
                                firstDate: DateTime(2000),
                                lastDate: DateTime(2100),
                              );
                              setState(() => tempEndDate = pickedDate);
                            },
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
          actions: [
            ElevatedButton.icon(
              onPressed: () {
                setState(() {
                  tempStatus = 'All';
                  tempDepartment = 'All';
                  tempStartDate = null;
                  tempEndDate = null;
                });
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
            ElevatedButton(
              onPressed: () {
                setState(() {
                  selectedStatus = tempStatus;
                  selectedDepartment = tempDepartment;
                  startDate = tempStartDate;
                  endDate = tempEndDate;
                });
                applyFiltersAndUpdate();
                Navigator.pop(context);
              },
              child: Text('Apply',
                  style: TextStyle(fontSize: 16, color: Colors.white)),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.black,
                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
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
    DateTime? initialDate,
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
            initialDate: initialDate ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (pickedDate != null) {
            onDateSelected(pickedDate);
          }
        },
        child: Container(
          padding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
          margin: EdgeInsets.only(top: 8),
          decoration: BoxDecoration(
            border: Border.all(color: Colors.grey[300]!, width: 1),
            borderRadius: BorderRadius.circular(15),
          ),
          child: Text(
            initialDate != null
                ? "${initialDate.day}/${initialDate.month}/${initialDate.year}"
                : "Select Date",
            style: TextStyle(fontSize: 14, color: Colors.grey[600]),
          ),
        ),
      ),
      if (validator != null)
        Builder(
          builder: (context) {
            final errorText = validator(initialDate);
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