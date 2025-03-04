import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:dropdown_search/dropdown_search.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:syncfusion_flutter_datepicker/datepicker.dart';

import '../../Hive/attendance_model.dart';

class LoginLogoutScreen1 extends StatefulWidget {
  @override
  _LoginLogoutScreenState createState() => _LoginLogoutScreenState();
}

class _LoginLogoutScreenState extends State<LoginLogoutScreen1> {
  FocusNode focus = FocusNode();
  String searchText = "";
  String? selectedDate;
  List<String>? selectedEmployee;
  int index = 1;
  Query? query;
  List<Map<String, dynamic>>? searchResults;
  final FirebaseAuth auth = FirebaseAuth.instance;
  String? role;
  String? userid;
  List<String> employees = [];
  DocumentSnapshot? lastDocument;
  bool isLoading = true;
  bool isLoadingMore = false;
  bool hasMoreData = true;
  final int itemsPerPage = 20;
  List<Map<String, dynamic>> currentData = [];
  ScrollController _scrollController = ScrollController();
  TextEditingController searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    checkConnectivity();
    Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      setState(() {
        isOnline = result != ConnectivityResult.none;
      });
      getData();
    });
    _scrollController.addListener(() {
      if (_scrollController.position.pixels ==
          _scrollController.position.maxScrollExtent &&
          !isLoadingMore) {
        if (hasMoreData) {
          loadMoreData();
        }
      }
    });
    getData();
  }
  bool isOnline = true;
  Future<void> checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    setState(() {
      isOnline = connectivityResult != ConnectivityResult.none;
    });
  }
  void loadMoreData() async {
    if (!hasMoreData || isLoadingMore) return;
    setState(() {
      isLoadingMore = true;
    });
    await Future.delayed(Duration(seconds: 3));
    Query baseQuery = FirebaseFirestore.instance
        .collection('Attendance')
        .orderBy('Date')
        .limit(itemsPerPage);
    if (lastDocument != null) {
      baseQuery = baseQuery.startAfterDocument(lastDocument!);
    }
    final snapshot = await baseQuery.get();
    if (snapshot.docs.isNotEmpty) {
      setState(() {
        currentData.addAll(snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList());
        lastDocument = snapshot.docs.last;
      });
    } else {
      setState(() {
        hasMoreData = false;
      });
    }
    setState(() {
      isLoadingMore = false;
    });
  }

  Future<void> getData() async {

    final Box<Attendance> attendanceBox = await Hive.openBox<Attendance>('attendanceBox');
    final List<Attendance> offlineData = attendanceBox.values.toList();

    if (mounted) {
      setState(() {
        currentData = offlineData.map((attendance) => attendance.toJson()).toList();
        isLoading = false;
        print("Hive Data: $currentData");
      });
    }
    var connectivityResult = await Connectivity().checkConnectivity();
    if (connectivityResult != ConnectivityResult.none) {
      try {

        final User? user = auth.currentUser;
        final uid = user!.uid;
        final userDoc = await FirebaseFirestore.instance.collection('user').doc(uid).get();
        if (userDoc.exists) {
          final data = userDoc.data() as Map<String, dynamic>?;
          if (mounted) {
            setState(() {
              role = data!['role'];
            });
          }
        } else {
          print('User document does not exist in database');
        }

        final attendanceSnapshot = await FirebaseFirestore.instance.collection('Attendance').get();
        final employeeNames = attendanceSnapshot.docs.map((doc) => doc['name'].toString()).toSet().toList();
        if (mounted) {
          setState(() {
            employees = employeeNames;
          });
        }

        final snapshot = await FirebaseFirestore.instance
            .collection('Attendance')
            .orderBy('Date')
            .limit(itemsPerPage)
            .get();

        if (mounted) {
          setState(() {
            currentData = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
            lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
          });
        }

        await attendanceBox.clear();
        for (var doc in snapshot.docs) {
          final data = doc.data() as Map<String, dynamic>;
          final attendance = Attendance(
            id: doc.id,
            UserId: data['UserId'],
            Date: data['Date'],
            Login: data['Login'],
            Logout: data['Logout'],
            name: data['name'],
            role: data['role'],
          );
          await attendanceBox.add(attendance);
        }
        print("Firestore Data stored in Hive");
      } catch (error) {

        print("Error fetching Firestore data: $error");
      }
    }
  }

  void updateQuery() {
    Query baseQuery = FirebaseFirestore.instance.collection('Attendance');

    if (selectedDate != null && selectedDate!.contains(" to ")) {
      final dateRange = selectedDate!.split(' to ');
      final startDate = dateRange[0];
      final endDate = dateRange[1];

      baseQuery = baseQuery
          .where('Date', isGreaterThanOrEqualTo: startDate)
          .where('Date', isLessThanOrEqualTo: endDate);
    } else if (selectedDate != null) {
      baseQuery = baseQuery.where('Date', isEqualTo: selectedDate);
    }

    if (selectedEmployee != null && selectedEmployee!.isNotEmpty) {
      baseQuery = baseQuery.where('name', whereIn: selectedEmployee);
    }

    baseQuery = baseQuery.orderBy('Date', descending: false);

    baseQuery.get().then((snapshot) {
      setState(() {
        currentData = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList();
        searchResults = searchText.isNotEmpty
            ? currentData.where((data) {
          final name = data['name'].toString().toLowerCase();
          final date = data['Date'].toString().toLowerCase();
          final login = data['Login'].toString().toLowerCase();
          final logout = data['Logout'].toString().toLowerCase();
          return name.contains(searchText) ||
              date.contains(searchText) ||
              login.contains(searchText) ||
              logout.contains(searchText);
        }).toList()
            : currentData;
        hasMoreData = snapshot.docs.length == itemsPerPage;
        lastDocument = snapshot.docs.isNotEmpty ? snapshot.docs.last : null;
      });
    }).catchError((error) {
      print("Error in query: $error");
    });
  }

  void searchAndFilter(String value) {
    setState(() {
      searchText = value.toLowerCase();
    });
    Query baseQuery = FirebaseFirestore.instance.collection('Attendance');
    if (selectedDate != null && selectedDate!.contains(" to ")) {
      final dateRange = selectedDate!.split(' to ');
      final startDate = dateRange[0];
      final endDate = dateRange[1];

      baseQuery = baseQuery
          .where('Date', isGreaterThanOrEqualTo: startDate)
          .where('Date', isLessThanOrEqualTo: endDate);
    } else if (selectedDate != null) {
      baseQuery = baseQuery.where('Date', isEqualTo: selectedDate);
    }
    if (selectedEmployee != null && selectedEmployee!.isNotEmpty) {
      baseQuery = baseQuery.where('name', whereIn: selectedEmployee);
    }
    baseQuery = baseQuery.orderBy('Date', descending: false);
    baseQuery.get().then((snapshot) {
      setState(() {
        searchResults = snapshot.docs.map((doc) => doc.data() as Map<String, dynamic>).toList().where((data) {
          final name = data['name'].toString().toLowerCase();
          final date = data['Date'].toString().toLowerCase();
          final login = data['Login'].toString().toLowerCase();
          final logout = data['Logout'].toString().toLowerCase();
          return name.contains(searchText) ||
              date.contains(searchText) ||
              login.contains(searchText) ||
              logout.contains(searchText);
        }).toList();
      });
    }).catchError((error) {
      print("Error fetching data: $error");
    });
  }

  void preprocessFirestoreData() async {
    final attendanceDocs =
    await FirebaseFirestore.instance.collection('Attendance').get();
    for (var doc in attendanceDocs.docs) {
      final name = doc['name'] as String;
      final login = doc['Login'] as String;
      final logout = doc['Logout'] as String;
      final keywords = [
        ...name.toLowerCase().split(' '),
        login.toLowerCase(),
        logout.toLowerCase(),
      ].where((word) => word.isNotEmpty).toList();
      FirebaseFirestore.instance
          .collection('Attendance')
          .doc(doc.id)
          .update({'searchKeywords': keywords});
    }
  }

  void clearQuery() {
    setState(() {
      selectedDate = null;
      selectedEmployee = null;
    });

    if (searchText.isNotEmpty) {
      searchAndFilter(searchText);
    } else {
      updateQuery();
    }
  }

  void showFilterDialog() {
    String? tempSelectedDateRange = selectedDate;
    List<String>? tempSelectedEmployees = selectedEmployee;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              backgroundColor: Colors.grey.shade300,
              title: Text(
                "Filter Options",
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              content: Container(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        "Select a Date Range",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      SizedBox(height: 8),
                      SizedBox(
                        child: ExpansionTile(
                            title: Text(tempSelectedDateRange ?? "Pick a Date"),
                            children: [
                              SfDateRangePicker(
                                selectionMode:
                                DateRangePickerSelectionMode.range,
                                onSelectionChanged:
                                    (DateRangePickerSelectionChangedArgs args) {
                                  if (args.value is PickerDateRange) {
                                    PickerDateRange range = args.value;
                                    String formattedStartDate =
                                        "${range.startDate!.year}-${range.startDate!.month.toString().padLeft(2, '0')}-${range.startDate!.day.toString().padLeft(2, '0')}";
                                    String formattedEndDate = range.endDate !=
                                        null
                                        ? "${range.endDate!.year}-${range.endDate!.month.toString().padLeft(2, '0')}-${range.endDate!.day.toString().padLeft(2, '0')}"
                                        : "";
                                    setState(() {
                                      tempSelectedDateRange = formattedEndDate
                                          .isNotEmpty
                                          ? "$formattedStartDate to $formattedEndDate"
                                          : formattedStartDate;
                                    });
                                  }
                                },
                              ),
                            ]),
                      ),
                      SizedBox(height: 16),
                      (role == "admin" || role == "teamlead")
                          ? Text(
                        "Select an Employee",
                        style: TextStyle(
                            fontWeight: FontWeight.bold, fontSize: 16),
                      )
                          : SizedBox(),
                      SizedBox(height: 8),
                      (role == "admin" || role == "teamlead")
                          ? DropdownSearch<String>.multiSelection(
                        popupProps: PopupPropsMultiSelection.menu(
                          showSearchBox: true,
                          searchFieldProps: TextFieldProps(
                            decoration: InputDecoration(
                              hintText: "Search Employees",
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                              ),
                              contentPadding: EdgeInsets.symmetric(
                                  horizontal: 12, vertical: 10),
                            ),
                          ),
                        ),
                        items: (filter, infiniteScrollProps) => employees,
                        selectedItems: tempSelectedEmployees ?? [],
                        decoratorProps: DropDownDecoratorProps(
                          decoration: InputDecoration(
                            labelText: "Select Employees",
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                        onChanged: (List<String> selectedValues) {
                          setState(() {
                            tempSelectedEmployees = selectedValues;
                          });
                        },
                      )
                          : SizedBox(),
                    ],
                  ),
                ),
              ),
              actions: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    ElevatedButton.icon(
                      onPressed: () {
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
                    SizedBox(width: 10),
                    ElevatedButton.icon(
                      onPressed: () {
                        setState(() {
                          selectedDate = tempSelectedDateRange;
                          selectedEmployee = tempSelectedEmployees;
                        });
                        updateQuery();
                        Navigator.pop(context);
                      },
                      icon: Icon(Icons.check),
                      label: Text('Apply Filters'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Theme.of(context).primaryColor,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }
  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Schedule and Attendance",
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
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
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              focusNode: focus,
              onTapOutside: (_) => focus.unfocus(),
              onChanged: (value) {
                setState(() {
                  searchText = value.toLowerCase();
                });
                if (searchText.isNotEmpty) {
                  searchAndFilter(value);
                } else {
                  updateQuery();
                }
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
            child: searchResults != null
                ? (searchResults!.isEmpty
                ? Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Image.asset(
                  'assets/Noresult.png',
                ),
              ],
            )
                : ListView.builder(
              controller: _scrollController,
              itemCount:
              searchResults!.length + (isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < searchResults!.length) {
                  final workDetail = searchResults![index];
                  return buildCard(workDetail);
                } else {
                  return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ));
                }
              },
            ))
                : ListView.builder(
              controller: _scrollController,
              itemCount: currentData.length + (isLoadingMore ? 1 : 0),
              itemBuilder: (context, index) {
                if (index < currentData.length) {
                  final workDetail = currentData[index];
                  return buildCard(workDetail);
                } else {
                  return Center(
                      child: Padding(
                        padding: const EdgeInsets.all(8.0),
                        child: CircularProgressIndicator(),
                      ));
                }
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget buildCard(Map<String, dynamic> workDetail) {
    final name = workDetail['name'] ?? 'N/A';
    final login = workDetail['Login'] ?? 'N/A';
    final logout = workDetail['Logout'] ?? 'N/A';
    final date = workDetail['Date'] ?? 'N/A';

    return Card(
      elevation: 8,
      margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
      ),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
        ),
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 8.0),
                child: Text(
                  name,
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                    color: Colors.black87,
                  ),
                ),
              ),
              Row(
                children: [
                  Icon(
                      Icons.calendar_today, size: 20, color: Colors.blueAccent),
                  SizedBox(width: 8),
                  Text(
                    "Date: $date",
                    style: TextStyle(fontSize: 16, color: Colors.black54),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.login, size: 20, color: Colors.green),
                  SizedBox(width: 8),
                  Text(
                    "Login: $login",
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ],
              ),
              SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.logout, size: 20, color: Colors.redAccent),
                  SizedBox(width: 8),
                  Text(
                    "Logout: $logout",
                    style: TextStyle(fontSize: 16, color: Colors.black87),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }}