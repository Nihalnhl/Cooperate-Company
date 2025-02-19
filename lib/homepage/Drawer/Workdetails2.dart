import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

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

  void getData() {
    final User? user = auth.currentUser;
    final uid = user!.uid;

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
            if (role == "admin" || role == "teamlead") {
              fetchAllWorkDetails();
            } else {
              fetchEmployeeWorkDetails();
            }
          });
        }
      } else {
        print('Document does not exist in database');
      }
    });

    FirebaseFirestore.instance.collection('Employees').get().then((snapshot) {
      final employeeNames =
          snapshot.docs.map((doc) => doc['Name'].toString()).toSet().toList();
      final uid =
          snapshot.docs.map((doc) => doc['uid'].toString()).toSet().toList();
      setState(() {
        employees = employeeNames;
        uids = uid;
      });
    });
    FirebaseFirestore.instance.collection('workDetails').get().then((snapshot) {
      setState(() {
        workDetailsList = snapshot.docs
            .map((doc) => doc.data() as Map<String, dynamic>)
            .toList();
      });
      applyFiltersAndUpdate();
    });
  }

  void fetchAllWorkDetails() {
    FirebaseFirestore.instance
        .collection('workDetails')
        .get()
        .then((snapshot) async {
      List<Map<String, dynamic>> workDetailsList = snapshot.docs.map((doc) {
        final workDetail =
            WorkDetails.fromMap(doc.data() as Map<String, dynamic>);
        return workDetail.toMap();
      }).toList();
      var box = await Hive.openBox('workDetailsBox');
      await box.clear();
      await box.addAll(workDetailsList);

      setState(() {
        this.workDetailsList = workDetailsList;
      });
    });
  }

  void fetchEmployeeWorkDetails() {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    FirebaseFirestore.instance
        .collection('workDetails')
        .where('uid', isEqualTo: uid)
        .get()
        .then((snapshot) async {
      List<Map<String, dynamic>> workDetailsList = snapshot.docs.map((doc) {
        final workDetail =
            WorkDetails.fromMap(doc.data() as Map<String, dynamic>);
        return workDetail.toMap();
      }).toList();

      var box = await Hive.openBox('workDetailsBox');
      await box.clear();
      await box.addAll(workDetailsList);

      setState(() {
        this.workDetailsList = workDetailsList;
      });
    });
  }

  void fetchFromHive() async {
    var box = await Hive.openBox('workDetailsBox');
    List<Map<String, dynamic>> hiveData =
        box.values.cast<Map<String, dynamic>>().toList();

    setState(() {
      workDetailsList = hiveData;
    });
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

  @override
  void initState() {
    if (mounted) {
      setState(() {});
    }
    super.initState();
    getData();
    clearQuery();
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

    String? selectedEmployee = workDetail?['Assignedto'];
    DateTime? startDate = workDetail != null
        ? (workDetail['StartDate'] as Timestamp).toDate()
        : DateTime.now();
    DateTime? deadline = workDetail != null
        ? (workDetail['deadline'] as Timestamp).toDate()
        : DateTime.now();
    String? uid = workDetail?['uid'];

    showDialog(
      context: context,
      builder: (context) => Dialog(
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(15),
        ),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SingleChildScrollView(
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
                ),
                _buildTextField(
                  controller: descriptionController,
                  label: "Description",
                  hint: "Enter a brief description",
                ),
                _buildTextField(
                  controller: departmentController,
                  label: "Department",
                  hint: "Enter the department name",
                ),
                _buildTextField(
                  controller: statusController,
                  label: "Status",
                  hint: "Enter the status (e.g., 'Pending', 'Completed')",
                ),
                _buildTextField(
                  controller: priorityController,
                  label: "Priority",
                  hint: "Enter the priority (e.g., 'High', 'Medium', 'Low')",
                ),
                _buildTextField(
                  controller: progressController,
                  label: "Progress Updates (%)",
                  hint: "Enter the progress (0-100)",
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
                  value: selectedEmployee,
                  items: employees.map((employee) {
                    return DropdownMenuItem(
                      value: employee,
                      child: Text(employee),
                    );
                  }).toList(),
                  onChanged: (value) {
                    setState(() {
                      selectedEmployee = value;
                    });
                  },
                  decoration: InputDecoration(
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(15),
                      borderSide: BorderSide(color: Colors.grey[300]!),
                    ),
                    contentPadding:
                        EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                        final data = {
                          'title': titleController.text,
                          'description': descriptionController.text,
                          'Department': departmentController.text,
                          'Status': statusController.text,
                          'Priority': priorityController.text,
                          'Progressupdates': double.tryParse(progressController.text).toString().toString() ?? 0.0,
                          'StartDate': Timestamp.fromDate(startDate!),
                          'deadline': Timestamp.fromDate(deadline!),
                          'Assignedto': selectedEmployee,
                          'uid': uid,
                        };

                        try {
                          if (workDetail == null) {
                            DocumentReference docRef = await _firestore.collection('workDetails').add(data);
                            await docRef.update({'id': docRef.id});
                          } else {

                            await _firestore.collection('workDetails').doc(workDetail['id']).update(data);
                          }
                          getData();
                          Navigator.pop(context);
                        } catch (e) {
                          print('Error updating or adding work details: $e');
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
    );
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
                            onPressed: () => deleteWorkDetail(workId),
                          )
                        : null,
                    onTap: () {
                      role == "admin"
                          ? showWorkDetailDialog(
                              workDetail: filteredDocs[index])
                          : Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (context) => Formview(
                                  title: workDetail['title'],
                                  Description: workDetail['description'],
                                  Assignedto: workDetail['Assignedto'],
                                  StartDate: formatdated,
                                  Enddate: deadlineformar,
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
}) {
  return Padding(
    padding: const EdgeInsets.symmetric(vertical: 12),
    child: TextField(
      controller: controller,
      keyboardType: keyboardType,
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
        filled: true, // Fill the background
        fillColor: Colors.white,

        isDense: true,
      ),
    ),
  );
}

Widget _buildDateSelector(BuildContext context, String label,
    DateTime? selectedDate, Function(DateTime) onDateSelected) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: TextStyle(
          fontWeight: FontWeight.w600,
          color: Colors.grey[800],
          fontSize: 16,
        ),
      ),
      const SizedBox(height: 8),
      ElevatedButton(
        onPressed: () async {
          final pickedDate = await showDatePicker(
            context: context,
            initialDate: selectedDate ?? DateTime.now(),
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
          );
          if (pickedDate != null) {
            onDateSelected(pickedDate);
          }
        },
        style: ElevatedButton.styleFrom(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          backgroundColor: Colors.grey,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ), // Button color
          shadowColor: Colors.grey.withOpacity(0.3),
          elevation: 4,
        ),
        child: Text(
          selectedDate == null
              ? 'Select $label'
              : DateFormat('yyyy-MM-dd').format(selectedDate),
          style: TextStyle(
            color: selectedDate == null ? Colors.white60 : Colors.white,
            fontWeight: FontWeight.w500,
            fontSize: 16,
          ),
        ),
      ),
    ],
  );
}
