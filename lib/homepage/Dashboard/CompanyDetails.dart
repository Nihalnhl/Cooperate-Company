import 'dart:io';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../Hive/company_model.dart';

class Companydetails extends StatefulWidget {
  const Companydetails({super.key});

  @override
  State<Companydetails> createState() => _CompanydetailsState();
}

class _CompanydetailsState extends State<Companydetails> {
  File? selectedImage;
  final picker = ImagePicker();

  Future _pickImage() async {
    final returnedImage =
    await ImagePicker().pickImage(source: ImageSource.gallery);
    if (returnedImage != null) {
      final imagePath = returnedImage.path;
      setState(() {
        selectedImage = File(returnedImage.path);
      });
      await saveImagePath(imagePath);
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No image selected.')),
      );
    }
  }
  Stream<DocumentSnapshot<Map<String, dynamic>>>? nihal() {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      return FirebaseFirestore.instance
          .collection('company')
          .doc("dl8VcoHQWvhbyo3UhdT9")
          .snapshots();
    }
_loadimage();
    return null;
  }

  TextEditingController names = TextEditingController();
  TextEditingController Email = TextEditingController();
  TextEditingController Headqua = TextEditingController();

  TextEditingController workinghours = TextEditingController();
  TextEditingController website = TextEditingController();
  TextEditingController phone = TextEditingController();
  TextEditingController industry = TextEditingController();

  String? role;
  String? name;

  String? userid;
  Map? userdata;
  bool isEdit = false;
  final FirebaseAuth auth = FirebaseAuth.instance;
  void getData() {
    final User? user = auth.currentUser;
    final uid = user!.uid;

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

            print('roles:$role');
          });
        }
      } else {
        print('Document does not exist in database');
      }
    });
  }
  Future<void> saveImagePath(String path) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("dl8VcoHQWvhbyo3UhdT9", path);
  }

  Future<String?> getImagePath() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString("dl8VcoHQWvhbyo3UhdT9");
  }
  Future<void> _loadimage() async {

    final path = await getImagePath();
    if (path != null && mounted) {
      setState(() {
        selectedImage = File(path);
      });
    }
  }
  Future<List<Company>> getCompanyDataFromHive() async {
    final box = await Hive.openBox<Company>('companyBox');
    return box.values.toList();
  }

  @override
  void initState() {
    final FirebaseAuth auth = FirebaseAuth.instance;
    final User? user = auth.currentUser;
    final uid = user!.uid;

    setState(() {
      userid = uid;
    });
    super.initState();
    getData();
    _loadimage();
  }

  CollectionReference users = FirebaseFirestore.instance.collection('company');

  Future<void> updateUser() async {
    return users.doc('dl8VcoHQWvhbyo3UhdT9').update({
      'Name': names.text,
      'Phone': phone.text,
      'Industry': industry.text,
      'Email': Email.text,
      'Working Hours': workinghours.text,
      'Website': website.text,
      'HeadQua': Headqua.text,
      'url':selectedImage != null?selectedImage!.path:'null',
    });
  }

  @override
  Widget build(BuildContext context) {
    final profile = nihal();
    return StreamBuilder<DocumentSnapshot>(
      stream: profile,
      builder: (context, snapshot) {
        final data = snapshot.data;
        print(data);
        if (snapshot.hasData) {
          if (isEdit) {
            names.text = data!['Name'];
            Email.text = data['Email'];
            industry.text = data['Industry'];

            website.text = data['Website'];
            phone.text = data['Phone'];
            workinghours.text = data['Working Hours'];
            Headqua.text = data['HeadQua'];

            return Scaffold(resizeToAvoidBottomInset: true,
              backgroundColor: Colors.grey.shade300,
              appBar: AppBar(
                automaticallyImplyLeading: false,

                backgroundColor: Colors.grey.shade300,
                title: Text(
                  "Company Details",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                actions: [
                  IconButton(
                    icon: Icon(Icons.save),
                    onPressed: () {
                      updateUser();
                      setState(() {
                        isEdit = false;
                      });
                    },
                  ),
                ],
              ),
              body: ListView(
                children: [
                  SizedBox(height: 15),
                  Center(
                    child: GestureDetector(
                      onTap:  _pickImage,
                      child: CircleAvatar(
                        backgroundColor: Colors.grey.shade300,
                        radius: 100,
                        backgroundImage: selectedImage != null
                            ? FileImage(selectedImage!)
                            :  FileImage(File(data!['url']))
                        as ImageProvider,
                        child: selectedImage == null ?
                        Center(child: Icon(Icons.person),):
                        SizedBox(),
                      ),
                    ),
                  ),

                  SizedBox(height: 20),

                  // Settings Section
                  Row(
                    children: [
                      SizedBox(width: 150),
                      Text(
                        'Edit Options',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      SizedBox(width: 95),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            isEdit = true;
                          });
                        },
                        icon: Icon(Icons.edit),
                      )
                    ],
                  ),
                  SizedBox(height: 10),
                Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade200),
                  child: Column(
                    children: [
                      ListTile(
                        title: Text('Name:'),
                        subtitle: TextField(
                          controller: names,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter Name',
                          ),
                        ),
                        leading: Icon(Icons.person_2_outlined),
                      ),
                      Divider(),
                      ListTile(
                        title: Text('Enter Industry:'),
                        subtitle: TextField(
                          controller: industry,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter Industry',
                          ),
                        ),
                        leading: Icon(Icons.reduce_capacity),
                      ),
                      Divider(),
                      ListTile(
                        title: Text('Enter HeadQuarters:'),
                        subtitle: TextField(
                          controller: Headqua,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter HeadQuaters',
                          ),
                        ),
                        leading: Icon(Icons.location_city),
                      ),
                      Divider(),
                      ListTile(
                        title: Text('Enter Email:'),
                        subtitle: TextField(
                          controller: Email,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter Email',
                          ),
                        ),

                        leading: Icon(Icons.email),
                      ),
                      Divider(),
                      ListTile(
                        title: Text('Working hours:'),
                        subtitle: TextField(
                          controller: workinghours,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter Working Hour',
                          ),
                        ),
                        leading: Icon(Icons.timer),
                      ),
                      Divider(),
                      ListTile(
                        title: Text('Website'),
                        subtitle: TextField(
                          controller: website,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter Web',
                          ),
                        ),
                        leading: Icon(Icons.web),
                      ),
                      Divider(),
                      ListTile(
                        title: Text('Phone'),
                        subtitle: TextField(
                          controller: phone,
                          decoration: InputDecoration(
                            border: InputBorder.none,
                            hintText: 'Enter Phone',
                          ),
                        ),
                        leading: Icon(Icons.phone),
                      ),
                    ],
                  ),
                )
                ],
              ),
            );
          } else {
            return Scaffold(
              backgroundColor: Colors.grey.shade300,
              appBar: AppBar(
                automaticallyImplyLeading: true,
                backgroundColor: Colors.grey.shade300,
                title: Text(
                  "Company Details",
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
              body: SingleChildScrollView(
                child: Column(
                  children: [
                    SizedBox(height: 15),
                    Center(
                      child: CircleAvatar(
                        backgroundColor: Colors.white,
                        radius: 100,
                        backgroundImage: selectedImage != null
                            ? FileImage(selectedImage!)
                            : FileImage(File(data!['url']))
                        as ImageProvider,
                        child: selectedImage == null ?
                        Center(child: Icon(Icons.photo,size: 50,),):
                        SizedBox(),
                      ),
                    ),
                
                    SizedBox(height: 20),

                    Row(children: [
                      SizedBox(width: 132),
                      Center(
                        child: Text(
                          'Company details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      SizedBox(width: 85),
                      role == 'admin'
                          ? IconButton(
                              onPressed: () {
                                setState(() {
                                  isEdit = true;
                                });
                              },
                              icon: Icon(Icons.edit),
                            )
                          : SizedBox()
                    ]),
                    SizedBox(height: 10),
                    Container(

                      width: 400,
                      decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: Colors.grey.shade200),
                      child: Column(
                
                        children: <Widget>[
                          ListTile(
                            title: Text('Name:',style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(data!['Name'],
                                ),
                            leading: Icon(Icons.person_2_outlined),
                          ),
                          Divider(),
                          ListTile(
                            title: Text('Industry:',style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(data['Industry'],
                                ),
                            leading: Icon(Icons.reduce_capacity_outlined),
                          ),
                          Divider(),
                          ListTile(
                            title: Text('HeadQuaters:',style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(data['HeadQua'],
                               ),
                            leading: Icon(Icons.location_city),
                          ),
                          Divider(),
                          ListTile(
                            title: Text('Email:',style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(data['Email'],
                                ),
                            leading: Icon(Icons.email),
                          ),Divider(),
                          ListTile(
                            title: Text('Working Hours:',style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(data['Working Hours'],
                                ),
                            leading: Icon(Icons.timer),
                          ),
                          Divider(),
                          ListTile(
                            title: Text('Website:',style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(data['Website'],
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            leading: Icon(Icons.web),
                          ),
                          Divider(),
                          ListTile(
                            title: Text('Phone:',style: TextStyle(fontWeight: FontWeight.bold)),
                            subtitle: Text(data['Phone'],
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            leading: Icon(Icons.phone),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            );
          }
        } else {
          return Column(
            children: [
              Center(child: CircularProgressIndicator()),
            ],
          );
        }
      },
    );
  }
}
