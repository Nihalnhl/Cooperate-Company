// import 'dart:io';
//
// import 'package:cloud_firestore/cloud_firestore.dart';
// import 'package:firebase_auth/firebase_auth.dart';
// import 'package:firebase_pagination/firebase_pagination.dart';
// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:path_provider/path_provider.dart';
// import 'package:pdf/pdf.dart';
//
// import 'package:pdf/widgets.dart' as pw;
// import 'package:printing/printing.dart';
// import 'package:syncfusion_flutter_datepicker/datepicker.dart';
//
// class WorkDetailsPage extends StatefulWidget {
//   @override
//   _WorkDetailsPageState createState() => _WorkDetailsPageState();
// }
//
// class _WorkDetailsPageState extends State<WorkDetailsPage> {
//   final FirebaseFirestore _firestore = FirebaseFirestore.instance;
//   final FirebaseAuth auth = FirebaseAuth.instance;
//   String? selectedEmployee;
//   List<String> employees = [];
//   List<String> uids = [];
//   String? role;
//   String? userid = "";
//   bool isEdit = false;
//   String? editingWorkDetailId = "";
//   String searchQuery = '';
//   String selectedStatus1 = '';
//   String selectedDepartment = '';
//   String selectedDate = '';
//   DateTime startDate = DateTime.now();
//   DateTime endDate = DateTime.now().add(Duration(days: 300));
//   DateTime _selectedStartDate = DateTime.now();
//   DateTime _selectedEndDate = DateTime.now();
//   String _dateCount = '';
//   String _range = '';
//   String _rangeCount = '';
//   String? selectedname;
//   String _selectedDate = "";
//   Query? query;
//   Query? query1;
//   List filteredDocs = [];
//   List<QueryDocumentSnapshot> alldocs = [];
//   TextEditingController workTitleController = TextEditingController();
//   TextEditingController workDescriptionController = TextEditingController();
//   TextEditingController workAssignedto = TextEditingController();
//   TextEditingController Department = TextEditingController();
//   TextEditingController Startdate = TextEditingController();
//   TextEditingController Enddate = TextEditingController();
//   TextEditingController Priority = TextEditingController();
//   TextEditingController ProgressUpdates = TextEditingController();
//   TextEditingController searchController = TextEditingController();
//   TextEditingController Feedback = TextEditingController();
//   TextEditingController Status = TextEditingController();
//
//   void getData() {
//     final User? user = auth.currentUser;
//     final uid = user!.uid;
//
//     FirebaseFirestore.instance
//         .collection('user')
//         .doc(uid)
//         .get()
//         .then((DocumentSnapshot docusnapshot) {
//       if (docusnapshot.exists) {
//         final data = docusnapshot.data() as Map<String, dynamic>?;
//         if (mounted) {
//           setState(() {
//             role = data!['role'];
//             if (data!['role']=="admin"||data!['role']=="teamlead"){
//               print("helllllo");
//               clearQuery();
//             }else{ print("hiiiiii");
//               Employeequery(uid);
//             }
//           });
//
//         }
//       } else {
//         print('Document does not exist in database');
//       }
//
//     });
//
//     FirebaseFirestore.instance.collection('Employees').get().then((snapshot) {
//       final employeeNames =
//           snapshot.docs.map((doc) => doc['Name'].toString()).toSet().toList();
//       final uid =
//           snapshot.docs.map((doc) => doc['uid'].toString()).toSet().toList();
//       setState(() {
//         employees = employeeNames;
//         uids = uid;
//       });
//     });
//   }
//   void Employeequery(String uid) {
//     setState(() {
//       query = FirebaseFirestore.instance.collection('workDetails').where('uid',isEqualTo: uid);
//
//     });
//   }
//
//   void clearQuery() {
//     setState(() {
//       query = FirebaseFirestore.instance.collection('workDetails');
//     });
//   }
//
//   void saveWorkDetail() {
//     if (workTitleController.text.isNotEmpty &&
//         workDescriptionController.text.isNotEmpty &&
//         _selectedEndDate != null &&
//         selectedEmployee != null) {
//       Timestamp startDateTimestamp = Timestamp.fromDate(_selectedStartDate);
//       Timestamp endDateTimestamp = Timestamp.fromDate(_selectedEndDate);
//
//       String? selectedUid;
//       if (selectedEmployee != null) {
//         int index = employees.indexOf(selectedEmployee!);
//         if (index != -1) {
//           selectedUid = uids[index];
//         }
//       }
//
//       if (editingWorkDetailId != null) {
//         _firestore.collection('workDetails').doc(editingWorkDetailId).update({
//           'title': workTitleController.text,
//           'description': workDescriptionController.text,
//           'Assignedto': selectedEmployee,
//           'StartDate': startDateTimestamp,
//           'deadline': endDateTimestamp,
//           'Department': Department.text,
//           'Status': Status.text,
//           'Priority': Priority.text,
//           'Progressupdates': ProgressUpdates.text,
//           'Feedback': Feedback.text,
//           'uid': selectedUid,
//         });
//       } else {
//         _firestore.collection('workDetails').add({
//           'title': workTitleController.text,
//           'description': workDescriptionController.text,
//           'Assignedto': selectedEmployee,
//           'StartDate': startDateTimestamp,
//           'deadline': endDateTimestamp,
//           'Department': Department.text,
//           'Status': Status.text,
//           'Priority': Priority.text,
//           'Progressupdates': ProgressUpdates.text,
//           'Feedback': Feedback.text,
//           'uid': selectedUid,
//         });
//       }
//
//       _clearFields();
//       editingWorkDetailId = null;
//       selectedEmployee = null;
//     } else {
//       print("Please fill in all required fields and select an employee.");
//     }
//   }
//
//
//   void editWorkDetail(String workDetailId, String startDate, String endDate) {
//     setState(() {
//       editingWorkDetailId = workDetailId;
//     });
//     _firestore.collection('workDetails').doc(workDetailId).get().then((doc) {
//       workTitleController.text = doc['title'];
//       workDescriptionController.text = doc['description'];
//
//       workAssignedto.text = doc['Assignedto'];
//       Startdate.text = startDate;
//       Enddate.text = endDate;
//       Department.text = doc['Department'];
//       Status.text = doc['Status'];
//       Priority.text = doc['Priority'];
//       ProgressUpdates.text = doc['Progressupdates'];
//       Feedback.text = doc['Feedback'];
//     });
//     showWorkDetailDialog(isEdit: true);
//   }
//
//   void deleteWorkDetail(String workDetailId) {
//     _firestore.collection('workDetails').doc(workDetailId).delete();
//   }
//
//   void _filterWorkDetails(List<QueryDocumentSnapshot> workDocs) {
//     filteredDocs = workDocs.where((work) {
//       final query = searchQuery.toLowerCase();
//       final title = work['title'].toString().toLowerCase();
//       final status = work['Status'].toString().toLowerCase();
//       final department = work['Department'].toString().toLowerCase();
//       final assignedTo = work['Assignedto'].toString().toLowerCase();
//       final description = work['description'].toString().toLowerCase();
//       final startDate = (work['StartDate'] as Timestamp).toDate();
//       final deadline = (work['deadline'] as Timestamp).toDate();
//       final startDateString =
//           DateFormat("yyyy-MM-dd").format(startDate).toLowerCase();
//       final deadlineString =
//           DateFormat("yyyy-MM-dd").format(deadline).toLowerCase();
//       final matchesTitle = title.contains(query);
//       final matchesStatus = status.contains(query);
//       final matchesDepartment = department.contains(query);
//
//       final matchesAssignedTo = assignedTo.contains(query);
//       final matchesDescription = description.contains(query);
//       final matchesStartDate = startDateString.contains(query);
//       final matchesDeadline = deadlineString.contains(query);
//
//       final matchesSelectedStatus = selectedStatus1.isEmpty ||
//           selectedStatus1 == 'All' ||
//           status == selectedStatus1.toLowerCase();
//       final matchesSelectedDepartment = selectedDepartment.isEmpty ||
//           selectedDepartment == 'All' ||
//           department == selectedDepartment.toLowerCase();
//       return (matchesTitle ||
//               matchesStatus ||
//               matchesDepartment ||
//               matchesAssignedTo ||
//               matchesDescription ||
//               matchesStartDate ||
//               matchesDeadline) &&
//           matchesSelectedStatus &&
//           matchesSelectedDepartment;
//     }).toList();
//   }
//
//   void _onSelectionChanged(DateRangePickerSelectionChangedArgs args) {
//     setState(() {
//       if (args.value is PickerDateRange) {
//         startDate = args.value.startDate;
//
//         endDate = args.value.endDate ?? args.value.startDate;
//         fetcclearquery(startDate, endDate);
//         print('${startDate}-${endDate}');
//       } else if (args.value is DateTime) {
//         _selectedDate = args.value.toString();
//       } else if (args.value is List<DateTime>) {
//         _dateCount = args.value.length.toString();
//       } else {
//         _rangeCount = args.value.length.toString();
//       }
//     });
//   }
//
//   void fetcclearquery(DateTime start, DateTime end) {
//     setState(() {print("hello");
//       query = FirebaseFirestore.instance
//           .collection('workDetails')
//           .where('deadline', isGreaterThanOrEqualTo: startDate)
//           .where('deadline', isLessThanOrEqualTo: endDate);
//     });
//   }
//
//
//   void _showFilterDialog() {
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return Dialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(20),
//           ),
//           child: Padding(
//             padding: const EdgeInsets.all(16.0),
//             child: SingleChildScrollView(
//               child: Column(
//                 crossAxisAlignment: CrossAxisAlignment.start,
//                 children: [
//                   SizedBox(height: 20),
//
//                   Text(
//                     "Filter by Status",
//                     style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                           fontWeight: FontWeight.bold,
//                         ),
//                   ),
//                   SizedBox(height: 10),
//
//                   DropdownButtonFormField<String>(
//                     value: selectedStatus1.isEmpty ? null : selectedStatus1,
//                     decoration: InputDecoration(
//                       labelText: 'Status',
//                       border: OutlineInputBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                     items: <String>['All', 'Completed', 'Pending']
//                         .map((status) => DropdownMenuItem(
//                               value: status,
//                               child: Text(status),
//                             ))
//                         .toList(),
//                     onChanged: (value) {
//                       setState(() {
//                         selectedStatus1 = value ?? '';
//                       });
//                     },
//                   ),
//                   SizedBox(height: 10),
//
//                   Text(
//                     "Filter by Department",
//                     style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                           fontWeight: FontWeight.bold,
//                         ),
//                   ),
//                   SizedBox(height: 10),
//                   Wrap(
//                     spacing: 8.0,
//                     children: <String>[
//                       'All',
//                       'Software',
//                       'Finance',
//                       'Marketing'
//                     ].map((department) {
//                       final isSelected = selectedDepartment == department;
//                       return ChoiceChip(
//                         label: Text(department),
//                         selected: selectedDepartment == "All",
//                         onSelected: (selected) {
//                           setState(() {
//                             selectedDepartment = selected ? department : '';
//                           });
//                         },
//                         selectedColor: Colors.blueAccent,
//                         backgroundColor: Colors.grey[200],
//                         labelStyle: TextStyle(
//                           color: isSelected ? Colors.white : Colors.black,
//                         ),
//                       );
//                     }).toList(),
//                   ),
//                   SizedBox(height: 20),
//                   // Date Range Selection
//                   Text(
//                     "Select Date Range",
//                     style: Theme.of(context).textTheme.titleLarge?.copyWith(
//                           fontWeight: FontWeight.bold,
//                         ),
//                   ),
//                   SizedBox(height: 10),
//                   Container(
//                     child: ExpansionTile(
//                       title: Text("Filter by Date Range"),
//                       children: [
//                         SfDateRangePicker(
//                           onSelectionChanged: _onSelectionChanged,
//                           selectionMode: DateRangePickerSelectionMode.range,
//                           initialSelectedRange: PickerDateRange(
//                             DateTime.now().subtract(const Duration(days: 1)),
//                             DateTime.now().add(const Duration(days: 1)),
//                           ),
//                         ),
//                       ],
//                     ),
//                   ),
//                   SizedBox(height: 30),
//                   Row(
//                     mainAxisAlignment: MainAxisAlignment.spaceBetween,
//                     children: [
//                       ElevatedButton.icon(
//                         onPressed: () {
//                           clearQuery();
//                           selectedStatus1 = 'All';
//                           selectedDepartment = 'All';
//                         },
//                         icon: Icon(Icons.clear),
//                         label: Text("Clear All"),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Colors.black,
//                           foregroundColor: Colors.white,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                         ),
//                       ),
//                       ElevatedButton.icon(
//                         onPressed: () {
//                           Navigator.pop(context);
//                           setState(() {});
//                         },
//                         icon: Icon(Icons.check),
//                         label: Text('Apply Filters'),
//                         style: ElevatedButton.styleFrom(
//                           backgroundColor: Theme.of(context).primaryColor,
//                           foregroundColor: Colors.white,
//                           shape: RoundedRectangleBorder(
//                             borderRadius: BorderRadius.circular(12),
//                           ),
//                         ),
//                       ),
//                     ],
//                   ),
//                 ],
//               ),
//             ),
//           ),
//         );
//       },
//     );
//   }
//
//   void showWorkDetailDialog({bool isEdit = false}) {
//
//
//
//     showDialog(
//       context: context,
//       builder: (BuildContext context) {
//         return Dialog(
//           shape: RoundedRectangleBorder(
//             borderRadius: BorderRadius.circular(16.0),
//           ),
//           child: Container(
//             width: MediaQuery.of(context).size.width * 0.7,
//             height: MediaQuery.of(context).size.height * 0.8,
//             padding: const EdgeInsets.all(16.0),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   isEdit ? 'Update Work Detail' : 'Create Work Detail',
//                   style: const TextStyle(
//                     fontSize: 20,
//                     fontWeight: FontWeight.bold,
//                   ),
//                 ),
//                 const SizedBox(height: 10),
//                 const Divider(),
//                 Expanded(
//                   child: SingleChildScrollView(
//                     child: Column(
//                       children: [
//                         _buildTextField(
//                             controller: workTitleController,
//                             label: 'Work Title'),
//                         _buildTextField(
//                             controller: workDescriptionController,
//                             label: 'Work Description'),
//
//                         SizedBox(
//                           height: 10,
//                         ),
//                         DropdownButton<String>(
//                           hint: Text(selectedEmployee ?? "Assigned To"),
//                           value: selectedEmployee,
//                           onChanged: (String? newValue) {
//                             setState(() {
//                               selectedEmployee = newValue;
//                             });
//                           },
//                           items: employees
//                               .map<DropdownMenuItem<String>>((String value) {
//                             return DropdownMenuItem<String>(
//                               value: value,
//                               child: Text(value),
//                             );
//                           }).toList(),
//                         ),
//
//                         SizedBox(height: 0),
//                         // if (selectedEmployee != null)
//                         //   Text('Selected Employee: $selectedEmployee'),
//                         SizedBox(
//                           height: 10,
//                         ),
//                         _buildDatePicker(
//                           label: 'Start Date',
//                           selectedDate: _selectedStartDate,
//                           onDateSelected: (pickedDate) {
//                             setState(() {
//                               _selectedStartDate = pickedDate;
//                             });
//                           },
//                         ),
//                         _buildDatePicker(
//                           label: 'Deadline',
//                           selectedDate: _selectedEndDate,
//                           onDateSelected: (pickedDate) {
//                             setState(() {
//                               _selectedEndDate = pickedDate;
//                             });
//                           },
//                         ),
//
//                         _buildTextField(
//                             controller: Department, label: 'Department'),
//                         _buildTextField(controller: Status, label: 'Status'),
//                         _buildTextField(
//                             controller: Priority, label: 'Priority'),
//                         _buildTextField(
//                             controller: ProgressUpdates,
//                             label: 'Progress Updates'),
//                         _buildTextField(
//                             controller: Feedback, label: 'Feedback'),
//                       ],
//                     ),
//                   ),
//                 ),
//                 const Divider(),
//                 Row(
//                   mainAxisAlignment: MainAxisAlignment.end,
//                   children: [
//                     TextButton(
//                       onPressed: () {
//                         Navigator.of(context).pop();
//                         _clearFields();
//                       },
//                       child: const Text('Cancel'),
//                     ),
//                     const SizedBox(width: 8),
//                     ElevatedButton(
//                       onPressed: () {
//                         saveWorkDetail();
//                         Navigator.of(context).pop();
//                       },
//                       child: Text(isEdit ? 'Update' : 'Create'),
//                     ),
//                   ],
//                 ),
//               ],
//             ),
//           ),
//         );
//       },
//     );
//   }
//   Widget _buildDatePicker({
//     required String label,
//     required DateTime selectedDate,
//     required ValueChanged<DateTime> onDateSelected,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 15.0),
//       child: InkWell(
//         onTap: () async {
//           DateTime? pickedDate = await showDatePicker(
//             context: context,
//             initialDate: selectedDate,
//             firstDate: DateTime(2000),
//             lastDate: DateTime(2100),
//           );
//           if (pickedDate != null) {
//             onDateSelected(pickedDate);
//           }
//         },
//         child: InputDecorator(
//           decoration: InputDecoration(
//             labelText: label,
//             labelStyle: TextStyle(color: Colors.grey),
//             floatingLabelBehavior: FloatingLabelBehavior.auto,
//             border: OutlineInputBorder(
//               borderRadius: BorderRadius.circular(12.0),
//               borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
//             ),
//             contentPadding:
//             const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//           ),
//           child: Text(
//             DateFormat("yyyy-MM-dd").format(selectedDate),
//             style: TextStyle(fontSize: 16, color: Colors.black),
//           ),
//         ),
//       ),
//     );
//   }
//
//
//   Widget _buildTextField({
//     required TextEditingController controller,
//     required String label,
//     IconData? icon,
//   }) {
//     return Padding(
//       padding: const EdgeInsets.only(bottom: 15.0),
//       child: TextField(
//         controller: controller,
//         decoration: InputDecoration(
//           prefixIcon: icon != null ? Icon(icon, color: Colors.grey) : null,
//           labelText: label,
//           labelStyle: TextStyle(color: Colors.grey),
//           floatingLabelBehavior: FloatingLabelBehavior.auto,
//           hintText: 'Enter $label',
//           hintStyle: TextStyle(color: Colors.grey.shade500),
//           focusedBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12.0),
//             borderSide: BorderSide(color: Colors.blue, width: 2),
//           ),
//           enabledBorder: OutlineInputBorder(
//             borderRadius: BorderRadius.circular(12.0),
//             borderSide: BorderSide(color: Colors.grey.shade300, width: 2),
//           ),
//           contentPadding:
//               const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
//         ),
//       ),
//     );
//   }
//
//   void _clearFields() {
//     workTitleController.clear();
//     workDescriptionController.clear();
//
//     workAssignedto.clear();
//     Startdate.clear();
//     Enddate.clear();
//     Department.clear();
//     Status.clear();
//     Priority.clear();
//     ProgressUpdates.clear();
//     Feedback.clear();
//   }
//
//   String? data = "";
//   String currentfilter = 'None';
//   @override
//   void initState() {
//     if (mounted) {
//       setState(() {
//
//       });
//     }
//     super.initState();
//     getData();
// clearQuery();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       backgroundColor: Colors.grey.shade200,
//       appBar: AppBar(
//         title: Text(
//           "Work Details",
//           style: TextStyle(fontWeight: FontWeight.bold),
//         ),
//         backgroundColor: Colors.grey.shade300,
//         actions: [
//           IconButton(
//               onPressed: _showFilterDialog
//               // SideSheet.left(
//               //   sheetBorderRadius: 6,
//               //   body: Padding(
//               //     padding: const EdgeInsets.all(16.0),
//               //     child: SingleChildScrollView(
//               //       child: Column(
//               //         mainAxisSize: MainAxisSize.min,
//               //         crossAxisAlignment: CrossAxisAlignment.start,
//               //         children: [
//               //
//               //           SizedBox(height: 20),
//               //           Text(
//               //             "Filters",
//               //             style: Theme.of(context).textTheme.titleLarge?.copyWith(
//               //               fontWeight: FontWeight.bold,
//               //             ),
//               //           ),
//               //           SizedBox(height: 10),
//               //           DropdownButtonFormField<String>(
//               //             value: selectedStatus1.isEmpty ? null : selectedStatus1,
//               //             decoration: InputDecoration(
//               //               labelText: 'Filter by Status',
//               //               border: OutlineInputBorder(
//               //                 borderRadius: BorderRadius.circular(12),
//               //               ),
//               //             ),
//               //             items: <String>['All', 'Completed', 'Pending']
//               //                 .map((status) => DropdownMenuItem(
//               //               value: status,
//               //               child: Text(status),
//               //             ))
//               //                 .toList(),
//               //             onChanged: (value) {
//               //               setState(() {
//               //                 selectedStatus1 = value ?? '';
//               //               });
//               //             },
//               //           ),
//               //           SizedBox(height: 10),
//               //           DropdownButtonFormField<String>(
//               //             value: selectedDepartment.isEmpty ? null : selectedDepartment,
//               //             decoration: InputDecoration(
//               //               labelText: 'Filter by Department',
//               //               border: OutlineInputBorder(
//               //                 borderRadius: BorderRadius.circular(12),
//               //               ),
//               //             ),
//               //             items: <String>['All', 'Software', 'Marketing', 'Finance']
//               //                 .map((department) => DropdownMenuItem(
//               //               value: department,
//               //               child: Text(department),
//               //             ))
//               //                 .toList(),
//               //             onChanged: (value) {
//               //               setState(() {
//               //                 selectedDepartment = value ?? '';
//               //               });
//               //             },
//               //           ),
//               //           SizedBox(height: 20),
//               //           Text(
//               //             "Select Date Range",
//               //             style: Theme.of(context).textTheme.titleMedium?.copyWith(
//               //               fontWeight: FontWeight.w600,
//               //             ),
//               //           ),
//               //           SizedBox(height: 10),
//               //           Container(
//               //             decoration: BoxDecoration(
//               //               borderRadius: BorderRadius.circular(12),
//               //               color: Colors.grey[200],
//               //               boxShadow: [
//               //                 BoxShadow(
//               //                   color: Colors.black12,
//               //                   blurRadius: 6,
//               //                   offset: Offset(0, 3),
//               //                 ),
//               //               ],
//               //             ),
//               //             padding: const EdgeInsets.all(8.0),
//               //             child: SfDateRangePicker(
//               //               onSelectionChanged: _onSelectionChanged,
//               //               selectionMode: DateRangePickerSelectionMode.range,
//               //               initialSelectedRange: PickerDateRange(
//               //                 DateTime.now().subtract(const Duration(days: 1)),
//               //                 DateTime.now().add(const Duration(days: 1)),
//               //               ),
//               //             ),
//               //           ),
//               //           SizedBox(height: 30),
//               //           Row(
//               //             mainAxisAlignment: MainAxisAlignment.spaceBetween,
//               //             children: [
//               //               ElevatedButton.icon(
//               //                 onPressed: () {
//               //                   clearQuery();
//               //                   selectedStatus1 = 'All';
//               //                   selectedDepartment = 'All';
//               //                 },
//               //                 icon: Icon(Icons.clear),
//               //                 label: Text("Clear"),
//               //                 style: ElevatedButton.styleFrom(
//               //                   backgroundColor: Colors.black,
//               //                   foregroundColor: Colors.white,
//               //                   shape: RoundedRectangleBorder(
//               //                     borderRadius: BorderRadius.circular(12),
//               //                   ),
//               //                 ),
//               //               ),
//               //               ElevatedButton.icon(
//               //                 onPressed: () {
//               //                   Navigator.pop(context);
//               //                   setState(() {});
//               //                 },
//               //                 icon: Icon(Icons.check),
//               //                 label: Text('Apply Filters'),
//               //                 style: ElevatedButton.styleFrom(
//               //                   backgroundColor: Theme.of(context).primaryColor,
//               //                   foregroundColor: Colors.white,
//               //                   shape: RoundedRectangleBorder(
//               //                     borderRadius: BorderRadius.circular(12),
//               //                   ),
//               //                 ),
//               //               ),
//               //             ],
//               //           ),
//               //         ],
//               //       ),
//               //     ),
//               //   )
//               // , context: context);
//
//               ,
//               icon: Icon(Icons.filter_list)),
//         ],
//       ),
//       body: Column(
//         children: [
//           SizedBox(
//             height: 5,
//           ),
//           Row(
//             mainAxisAlignment: MainAxisAlignment.end,
//             children: [
//               if (role == 'teamlead' || role == 'admin') ...[
//                 Padding(
//                   padding: const EdgeInsets.all(8.0),
//                   child: ElevatedButton.icon(
//                     onPressed: showWorkDetailDialog,
//                     label: Text('Create New'),
//                     style: ElevatedButton.styleFrom(
//                       backgroundColor: Colors.black,
//                       foregroundColor: Colors.white,
//                       shape: RoundedRectangleBorder(
//                         borderRadius: BorderRadius.circular(12),
//                       ),
//                     ),
//                   ),
//                 ),
//               ],
//             ],
//           ),
//           Padding(
//             padding:
//                 const EdgeInsets.symmetric(vertical: 8.0, horizontal: 12.0),
//             child: TextField(
//               controller: searchController,
//               onChanged: (query) {
//                 setState(() {
//                   searchQuery = query;
//                   _filterWorkDetails(alldocs);
//                 });
//               },
//               decoration: InputDecoration(
//                 hintText: "Search...",
//                 prefixIcon: Icon(Icons.search, color: Colors.black),
//                 filled: true,
//                 fillColor: Colors.white,
//                 border: OutlineInputBorder(
//                   borderRadius: BorderRadius.circular(30),
//                   borderSide: BorderSide.none,
//                 ),
//                 contentPadding:
//                     EdgeInsets.symmetric(horizontal: 20, vertical: 15),
//               ),
//             ),
//           ),
//           Expanded(
//             child: StreamBuilder(
//               stream: query!.snapshots(),
//               builder: (context, snapshot) {
//                 if (snapshot.connectionState == ConnectionState.waiting) {
//                   return Center(child: CircularProgressIndicator());
//                 }
//                 if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
//                   return Center(child: Text('No work details available.'));
//                 }
//
//                 alldocs = snapshot.data!.docs;
//                 _filterWorkDetails(alldocs);
//
//                 return ListView.builder(
//                   itemCount: filteredDocs.length,
//                   itemBuilder: (context, index) {
//                     final workDetail = filteredDocs[index];
//                     final workTitle = workDetail['title'];
//                     final Startdate = workDetail['StartDate'];
//                     final workDeadline = workDetail['deadline'];
//                     final Department = workDetail['Department'];
//                     final Status = workDetail['Status'];
//                     final workId = workDetail.id;
//                     final progressUpdates = double.tryParse(
//                             workDetail['Progressupdates'].toString()) ??
//                         0;
//                     final progress = progressUpdates > 1.0
//                         ? progressUpdates / 100
//                         : progressUpdates;
//                     final formatdated =
//                         DateFormat("yyyy-MM-dd").format(Startdate.toDate());
//                     final deadlineformar =
//                         DateFormat("yyyy-MM-dd").format(workDeadline.toDate());
//
//                     return Card(
//                       margin: EdgeInsets.symmetric(vertical: 8, horizontal: 12),
//                       elevation: 5,
//                       child: ListTile(
//                         title: Center(
//                           child: Text(
//                             workTitle,
//                             style: TextStyle(fontWeight: FontWeight.bold),
//                           ),
//                         ),
//                         subtitle: Column(
//                           crossAxisAlignment: CrossAxisAlignment.start,
//                           children: [
//                             Text(Department),
//                             Text(
//                               "Deadline: $deadlineformar",
//                               style: TextStyle(fontSize: 12),
//                             ),
//                             Text(
//                               Status,
//                               style: TextStyle(
//                                 fontWeight: FontWeight.bold,
//                                 color: Status.toLowerCase() == 'completed'
//                                     ? Colors.green
//                                     : Colors.red,
//                               ),
//                             ),
//                             SizedBox(height: 8),
//                             LinearProgressIndicator(
//                               value: progress,
//                               backgroundColor: Colors.grey[300],
//                               color:
//                                   progress >= 1.0 ? Colors.green : Colors.red,
//                             ),
//                           ],
//                         ),
//                         trailing: role == 'teamlead' || role == 'admin'
//                             ? IconButton(
//                                 icon: Icon(Icons.delete),
//                                 onPressed: () => deleteWorkDetail(workId),
//                               )
//                             : null,
//                         onTap: () {
//                           if (role == 'teamlead' || role == 'admin') {
//                             editWorkDetail(workId, formatdated, deadlineformar);
//                           } else {
//                             Navigator.push(
//                               context,
//                               MaterialPageRoute(
//                                 builder: (context) => Formview(
//                                   title: workDetail['title'],
//                                   Description: workDetail['description'],
//                                   Assignedto: workDetail['Assignedto'],
//                                   StartDate: formatdated,
//                                   Enddate: deadlineformar,
//                                   ProgressUpdates:
//                                       workDetail['Progressupdates'],
//                                   Feedback: workDetail['Feedback'],
//                                   Status: workDetail['Status'],
//                                   Priority: workDetail['Priority'],
//                                   Department: workDetail['Department'],
//                                 ),
//                               ),
//                             );
//                           }
//                         },
//                       ),
//                     );
//                   },
//                 );
//               },
//             ),
//           ),
//         ],
//       ),
//     );
//   }
// }
//
// class Formview extends StatelessWidget {
//   final String title;
//   final String Description;
//
//   final String Assignedto;
//   final String StartDate;
//   final String Enddate;
//   final String ProgressUpdates;
//   final String Feedback;
//   final String Status;
//   final String Priority;
//   final String Department;
//
//   const Formview(
//       {super.key,
//       required this.title,
//       required this.Description,
//       required this.Assignedto,
//       required this.StartDate,
//       required this.Enddate,
//       required this.ProgressUpdates,
//       required this.Feedback,
//       required this.Status,
//       required this.Priority,
//       required this.Department});
//
//   @override
//   Widget build(BuildContext context) {
//     return Scaffold(
//       appBar: AppBar(
//         backgroundColor: Colors.grey.shade300,
//         title: Text(
//           "Project Details",
//           style: TextStyle(
//             fontWeight: FontWeight.bold,
//             fontSize: 22,
//             color: Colors.black87,
//           ),
//         ),
//         elevation: 1,
//         actions: [
//           IconButton(
//               onPressed: () async {
//                 final pdf = pw.Document();
//                 pdf.addPage(
//                   pw.Page(
//                     pageFormat: PdfPageFormat.a4,
//                     build: (pw.Context context) {
//                       return pw.Padding(
//                         padding: pw.EdgeInsets.all(20),
//                         child: pw.Column(
//                           crossAxisAlignment: pw.CrossAxisAlignment.start,
//                           children: [
//                             pw.Center(
//                               child: pw.Text(
//                                 'Project Overview',
//                                 style: pw.TextStyle(
//                                   fontSize: 28,
//                                   fontWeight: pw.FontWeight.bold,
//                                   color: PdfColors.black,
//                                 ),
//                               ),
//                             ),
//                             pw.SizedBox(height: 20),
//                             _buildSection(
//                               title: 'Project Name',
//                               content: title,
//                             ),
//                             _buildSection(
//                               title: 'Description',
//                               content: Description,
//                             ),
//                             _buildSection(
//                               title: 'Start Date',
//                               content: StartDate,
//                             ),
//                             _buildSection(
//                               title: 'Deadline',
//                               content: Enddate,
//                             ),
//                             _buildSection(
//                               title: 'Department',
//                               content: Department,
//                             ),
//                             _buildSection(
//                               title: 'Status',
//                               content: Status,
//                             ),
//                             _buildSection(
//                               title: 'Priority',
//                               content: Priority,
//                             ),
//                             _buildSection(
//                               title: 'Progress Updates',
//                               content: ProgressUpdates,
//                             ),
//                             _buildSection(
//                               title: 'Feedback',
//                               content: Feedback,
//                             ),
//                           ],
//                         ),
//                       );
//                     },
//                   ),
//                 );
//
//                 final output = await getExternalStorageDirectory();
//                 final file = File("${output!.path}/work_detail.pdf");
//                 await file.writeAsBytes(await pdf.save());
//                 Printing.sharePdf(
//                     bytes: await pdf.save(), filename: 'work_detail.pdf');
//               },
//               icon: Icon(Icons.picture_as_pdf)),
//         ],
//       ),
//       backgroundColor: Colors.grey.shade300,
//       body: Padding(
//         padding: const EdgeInsets.all(16.0),
//         child: SingleChildScrollView(
//           child: Column(
//             crossAxisAlignment: CrossAxisAlignment.start,
//             children: [
//               Card(
//                 elevation: 4,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(12),
//                 ),
//                 child: Padding(
//                   padding: const EdgeInsets.all(16.0),
//                   child: Column(
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       _buildDetailRow("Project Name", title),
//                       _buildDetailRow("Description", Description),
//                       _buildDetailRow("Assigned To", Assignedto),
//                       _buildDetailRow("Start Date", StartDate),
//                       _buildDetailRow("Deadline", Enddate),
//                       _buildDetailRow("Department", Department),
//                       _buildDetailRow("Status", Status),
//                       _buildDetailRow("Priority", Priority),
//                       _buildDetailRow("Progress Updates", ProgressUpdates),
//                       _buildDetailRow("Feedback", Feedback),
//                     ],
//                   ),
//                 ),
//               ),
//               SizedBox(height: 20),
//               // Close Button
//               SizedBox(
//                 width: double.infinity,
//                 child: ElevatedButton(
//                   style: ElevatedButton.styleFrom(
//                     foregroundColor: Colors.white,
//                     backgroundColor: Colors.black,
//                     elevation: 10,
//                     shape: RoundedRectangleBorder(
//                       borderRadius: BorderRadius.circular(12),
//                     ),
//                     padding: EdgeInsets.symmetric(vertical: 16),
//                   ),
//                   onPressed: () {
//                     Navigator.pop(context);
//                   },
//                   child: Text(
//                     "Close",
//                     style: TextStyle(
//                       fontWeight: FontWeight.bold,
//                       fontSize: 16,
//                     ),
//                   ),
//                 ),
//               ),
//             ],
//           ),
//         ),
//       ),
//     );
//   }
// }
//
// Widget _buildDetailRow(String label, String value) {
//   return Padding(
//     padding: const EdgeInsets.symmetric(vertical: 8.0),
//     child: Row(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         Expanded(
//           flex: 3,
//           child: Text(
//             label,
//             style: TextStyle(
//               fontWeight: FontWeight.w600,
//               fontSize: 14,
//               color: Colors.grey[700],
//             ),
//           ),
//         ),
//         SizedBox(width: 10),
//         Expanded(
//           flex: 5,
//           child: Text(
//             value,
//             style: TextStyle(
//               fontSize: 14,
//               color: Colors.black,
//             ),
//           ),
//         ),
//       ],
//     ),
//   );
// }
//
// pw.Widget _buildSection({required String title, required String content}) {
//   return pw.Container(
//     width: 900,
//     margin: pw.EdgeInsets.only(bottom: 12),
//     padding: pw.EdgeInsets.all(10),
//     decoration: pw.BoxDecoration(
//       border: pw.Border.all(color: PdfColors.grey, width: 1),
//       borderRadius: pw.BorderRadius.circular(5),
//     ),
//     child: pw.Column(
//       crossAxisAlignment: pw.CrossAxisAlignment.start,
//       children: [
//         pw.Text(
//           title,
//           style: pw.TextStyle(
//             fontSize: 16,
//             fontWeight: pw.FontWeight.bold,
//             color: PdfColors.black,
//           ),
//         ),
//         pw.SizedBox(height: 5),
//         pw.Text(
//           content,
//           style: pw.TextStyle(
//             fontSize: 16,
//             color: PdfColors.black,
//           ),
//         ),
//       ],
//     ),
//   );
// }
