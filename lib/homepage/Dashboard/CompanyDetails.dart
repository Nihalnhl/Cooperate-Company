import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import '../../Hive/company_model.dart';


class Companydetails extends StatefulWidget {
  const Companydetails({super.key});

  @override
  State<Companydetails> createState() => _CompanydetailsState();
}

class _CompanydetailsState extends State<Companydetails> {
  File? selectedImage;
  final picker = ImagePicker();
  Company? companyData;
  bool isOnline = true;
  bool isLoading = true;

  TextEditingController names = TextEditingController();
  TextEditingController Email = TextEditingController();
  TextEditingController Headqua = TextEditingController();
  TextEditingController workinghours = TextEditingController();
  TextEditingController website = TextEditingController();
  TextEditingController phone = TextEditingController();
  TextEditingController industry = TextEditingController();

  String? role;
  String? userid;
  bool isEdit = false;
  final FirebaseAuth auth = FirebaseAuth.instance;

  @override
  void initState() {
    super.initState();
    checkConnectivity();
    getData();
  }

  Future<void> checkConnectivity() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    if (mounted) {
      setState(() {
        isOnline = connectivityResult != ConnectivityResult.none;
      });
    }

    if (isOnline) {
      await fetchFirestoreData();
    } else {
      await fetchHiveData();
    }

    if (mounted) {
      setState(() => isLoading = false);
    }
  }

  Future<void> fetchFirestoreData() async {
    final doc = await FirebaseFirestore.instance.collection('company').doc("dl8VcoHQWvhbyo3UhdT9").get();
    if (doc.exists) {
      Company data = Company.fromMap(doc.data()!);
      if (mounted) {
        setState(() {
          companyData = data;
          if (data.url.isNotEmpty) selectedImage = File(data.url);
        });
      }
      await saveDataToHive(data);
    }
  }


  Future<void> fetchHiveData() async {
    final box = await Hive.openBox<Company>('companyBox');
    if (box.isNotEmpty) {
      Company data = box.getAt(0)!;
      if (mounted) {
        setState(() {
          companyData = data;
          if (data.url.isNotEmpty) selectedImage = File(data.url);
        });
      }
    }
  }


  Future<void> saveDataToHive(Company company) async {
    final box = await Hive.openBox<Company>('companyBox');
    await box.clear();
    await box.add(company);
  }

  Future _pickImage() async {
    final returnedImage = await picker.pickImage(source: ImageSource.gallery);
    if (returnedImage != null) {
      setState(() => selectedImage = File(returnedImage.path));
    }
  }

  Future<void> updateUser() async {
    Company updatedCompany = Company(
      email: Email.text,
      headQua: Headqua.text,
      industry: industry.text,
      name: names.text,
      phone: phone.text,
      website: website.text,
      workingHours: workinghours.text,
      url: selectedImage?.path ?? companyData?.url ?? '',
    );

    if (isOnline) {
      await FirebaseFirestore.instance.collection('company').doc("dl8VcoHQWvhbyo3UhdT9").update(updatedCompany.toMap());
    }
    await saveDataToHive(updatedCompany);
    setState(() {
      companyData = updatedCompany;
      isEdit = false;
    });
  }

  void getData() async {
    User? user = auth.currentUser;
    if (user != null) {
      DocumentSnapshot doc = await FirebaseFirestore.instance.collection('user').doc(user.uid).get();
      if (doc.exists && mounted) {
        setState(() => role = doc['role']);
      }
    }
  }


  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    if (companyData == null) {
      return const Scaffold(body: Center(child: Text('No data available')));
    }

    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade300,
        title: const Text("Company Details", style: TextStyle(fontWeight: FontWeight.bold)),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: updateUser,
            )
          else if (role == 'admin')
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () => setState(() {
                isEdit = true;
                names.text = companyData!.name;
                Email.text = companyData!.email;
                Headqua.text = companyData!.headQua;
                workinghours.text = companyData!.workingHours;
                website.text = companyData!.website;
                phone.text = companyData!.phone;
                industry.text = companyData!.industry;
              }),
            ),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 15),
            Center(
              child: GestureDetector(
                onTap: isEdit ? _pickImage : null,
                child: CircleAvatar(
                  backgroundColor: Colors.white,
                  radius: 100,
                  backgroundImage: selectedImage != null
                      ? FileImage(selectedImage!)
                      : (companyData!.url.isNotEmpty ? FileImage(File(companyData!.url)) : const AssetImage('assets/profile.jpeg')) as ImageProvider,
                  child: selectedImage == null?  Icon(Icons.person, size: 50) : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  color: Colors.grey.shade200,
                ),
                child: Column(
                  children: _buildCompanyDetails(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildCompanyDetails() {
    if (isEdit) {
      return [
        _buildEditableListTile('Name', names, Icons.person),
        _buildEditableListTile('Industry', industry, Icons.business),
        _buildEditableListTile('Headquarters', Headqua, Icons.location_city),
        _buildEditableListTile('Email', Email, Icons.email),
        _buildEditableListTile('Working Hours', workinghours, Icons.timer),
        _buildEditableListTile('Website', website, Icons.web),
        _buildEditableListTile('Phone', phone, Icons.phone),
      ];
    } else {
      return [
        _buildReadOnlyListTile('Name', companyData!.name, Icons.person),
        _buildReadOnlyListTile('Industry', companyData!.industry, Icons.business),
        _buildReadOnlyListTile('Headquarters', companyData!.headQua, Icons.location_city),
        _buildReadOnlyListTile('Email', companyData!.email, Icons.email),
        _buildReadOnlyListTile('Working Hours', companyData!.workingHours, Icons.timer),
        _buildReadOnlyListTile('Website', companyData!.website, Icons.web),
        _buildReadOnlyListTile('Phone', companyData!.phone, Icons.phone),
      ];
    }
  }

  Widget _buildEditableListTile(String title, TextEditingController controller, IconData icon) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: TextField(
            controller: controller,
            decoration: InputDecoration(hintText: 'Enter $title'),
          ),
        ),
        const Divider(),
      ],
    );
  }

  Widget _buildReadOnlyListTile(String title, String value, IconData icon) {
    return Column(
      children: [
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(value.isNotEmpty ? value : 'Not available'),
        ),
        const Divider(),
      ],
    );
  }
}