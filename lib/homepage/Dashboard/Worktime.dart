import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SetWorkTimePage extends StatefulWidget {
  @override
  _SetWorkTimePageState createState() => _SetWorkTimePageState();
}class _SetWorkTimePageState extends State<SetWorkTimePage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth auth = FirebaseAuth.instance;
  final _formKey = GlobalKey<FormState>();
  List<Map<String, dynamic>> employees = [];
  List<FocusNode> _focusNodes = [];

  @override
  void initState() {
    super.initState();
    _fetchEmployees();
  }

  Future<void> _fetchEmployees() async {
    QuerySnapshot snapshot = await _firestore
        .collection('user')
        .where('role', isEqualTo: 'employee')
        .get();

    setState(() {
      employees = snapshot.docs.map((doc) {
        Map<String, dynamic> data = doc.data() as Map<String, dynamic>;

        int requiredWorkTime = data['requiredWorkTime'] != null
            ? data['requiredWorkTime'] is int
            ? data['requiredWorkTime'] as int
            : int.tryParse(data['requiredWorkTime'].toString()) ?? 480000
            : 480000;

        return {
          'id': doc.id,
          'name': data['name'].toString(),
          'requiredWorkTime': requiredWorkTime,
          'controller': TextEditingController(
            text: (requiredWorkTime ~/ 60000 ~/ 60).toString(),
          ),
        };
      }).toList();

      _focusNodes = List.generate(employees.length, (index) => FocusNode());
    });
  }

  Future<void> _saveRequiredWorkTime() async {
    FocusScope.of(context).unfocus();
    if (_formKey.currentState!.validate()) {
      for (var emp in employees) {
        int workTimeInHours = int.parse(emp['controller'].text);
        int requiredWorkTimeInMilliseconds = workTimeInHours * 60 * 60 * 1000;

        await _firestore.collection('user').doc(emp['id']).update({
          'requiredWorkTime': requiredWorkTimeInMilliseconds,
        });
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Required work time updated successfully!'),
          backgroundColor: Colors.green,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Set Work Time')),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Center(
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(15),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Form(
                key: _formKey,
                child: Column(
                  children: [
                    Text(
                      'Edit Work Time',
                      style:
                      TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    SizedBox(height: 20),
                    Expanded(
                      child: ListView.builder(
                        itemCount: employees.length,
                        itemBuilder: (context, index) {
                          Map<String, dynamic> emp = employees[index];
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 8.0),
                            child: Row(
                              children: [
                                Text(
                                  emp['name'],
                                  style: TextStyle(fontSize: 16),
                                ),
                                Spacer(),
                                SizedBox(
                                  width: 101,
                                  child: TextFormField(
                                    focusNode: _focusNodes[index],
                                    controller: emp['controller'],
                                    keyboardType: TextInputType.number,
                                    decoration: InputDecoration(
                                      labelText: 'Time in Hour',
                                      border: OutlineInputBorder(
                                          borderRadius:
                                          BorderRadius.circular(15),
                                          borderSide: BorderSide(
                                              color: Colors.brown.shade300,
                                              width: 1)),
                                    ),
                                    validator: (value) {
                                      if (value == null || value.isEmpty) {
                                        return 'Enter value';
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                    SizedBox(height: 20),
                    ElevatedButton(
                      onPressed: _saveRequiredWorkTime,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.brown.shade300,
                        padding: const EdgeInsets.symmetric(
                            vertical: 15, horizontal: 50),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Save',
                        style: TextStyle(fontSize: 18, color: Colors.white),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    for (var emp in employees) {
      emp['controller'].dispose();
    }
    for (var node in _focusNodes) {
      node.dispose();
    }
    super.dispose();
  }
}
