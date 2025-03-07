import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:image_picker/image_picker.dart';
import 'package:shimmer/shimmer.dart';
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
      return Scaffold(
        body: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const SizedBox(height: 40),
              _buildShimmerBox(height: 20, width: 200),
              const SizedBox(height: 20),
              Center(child: _buildShimmerCircle(140)),
              const SizedBox(height: 20),
              _buildShimmerBox(height: 20, width: 250),
              const SizedBox(height: 10),
              _buildShimmerBox(height: 15, width: double.infinity),
              const SizedBox(height: 10),
              _buildShimmerBox(height: 15, width: double.infinity),
              const SizedBox(height: 10),
              _buildShimmerBox(height: 15, width: double.infinity),
            ],
          ),
        ),
      );
    }

    if (companyData == null) {
      return const Scaffold(body: Center(child: Text('No data available')));
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Colors.grey[50],
        title: const Text("Company Details", style: TextStyle(fontWeight: FontWeight.bold)),
        actions: [
          if (isEdit)
            IconButton(
              icon: const Icon(Icons.save),
              onPressed: updateUser,
            ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              const SizedBox(height: 20),
              Center(
                child: GestureDetector(
                  onTap: isEdit ? _pickImage : null,
                  child: Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [Colors.brown[300]!, Colors.brown[100]!],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                    ),
                    child: CircleAvatar(
                      backgroundColor: Colors.white,
                      radius: 70,
                      backgroundImage: selectedImage != null
                          ? FileImage(selectedImage!)
                         : FileImage(File(companyData!.url)) as ImageProvider,
                      child: selectedImage == null ? const Icon(Icons.image, size: 50,color: Colors.grey,) : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 15),
              Text(
                isEdit ? "Update Details:" : "Company  Information :",
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w600,
                  color: Colors.black87,
                ),
              ),
              const SizedBox(height: 10),
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: _buildCompanyDetails(),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _buildCompanyDetails() {
    if (isEdit) {
      return [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildTextField('Name', names, Icons.person),  const SizedBox(height: 20),
              _buildTextField('Industry', industry, Icons.business),  const SizedBox(height: 20),
              _buildTextField('Headquarters', Headqua, Icons.location_city),  const SizedBox(height: 20),
              _buildTextField('Email', Email, Icons.email),  const SizedBox(height: 20),
              _buildTextField('Working Hours', workinghours, Icons.timer),  const SizedBox(height: 20),
              _buildTextField('Website', website, Icons.web),  const SizedBox(height: 20),
              _buildTextField('Phone', phone, Icons.phone),  const SizedBox(height: 20),
            ],
          ),
        )

      ];
    } else {
      return [
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [
              BoxShadow(
                color: Colors.grey.withOpacity(0.1),
                spreadRadius: 2,
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildDetailTile('Name:', companyData!.name, Icons.person),
              const SizedBox(height: 16),
              _buildDetailTile ('Industry:', companyData!.industry, Icons.business),
              const SizedBox(height: 16),
              _buildDetailTile('Headquarters:', companyData!.headQua, Icons.location_city),const SizedBox(height: 16),
              _buildDetailTile('Email:', companyData!.email, Icons.email),const SizedBox(height: 16),
              _buildDetailTile('Working Hours:', companyData!.workingHours, Icons.timer),const SizedBox(height: 16),
              _buildDetailTile('Website:', companyData!.website, Icons.web),const SizedBox(height: 16),
              _buildDetailTile('Phone:', companyData!.phone, Icons.phone),const SizedBox(height: 16),
              Align(
                alignment: Alignment.centerRight,
                child: role == "admin" ?ElevatedButton.icon(
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
                  icon: const Icon(Icons.edit, size: 18),
                  label: const Text("Edit"),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.brown[400],
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ): SizedBox(),
              ),
            ],
          ),
        )

      ];
    }
  }
  Widget _buildShimmerBox({required double height, required double width}) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        height: height,
        width: width,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(8),
        ),
      ),
    );
  }

  Widget _buildShimmerCircle(double size) {
    return Shimmer.fromColors(
      baseColor: Colors.grey[300]!,
      highlightColor: Colors.grey[100]!,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: Colors.white,
          shape: BoxShape.circle,
        ),
      ),
    );
  }

  Widget _buildTextField(String title,TextEditingController controller,  IconData icon,
      {TextInputType? type}) {
    return TextFormField(
      controller: controller,
      keyboardType: type,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: Colors.brown[400]),
        labelText: title,
        labelStyle: TextStyle(color: Colors.grey[700]),
        filled: true,
        fillColor: Colors.grey[100],
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: Colors.blue[400]!, width: 2),
        ),
      ),
      validator: (value) =>
      value?.isEmpty == true ? 'Please enter your $title' : null,
    );
  }

  Widget _buildDetailTile(String title, String? subtitle, IconData icon) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: Colors.brown[400], size: 24),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle ?? "Not provided",
                style: const TextStyle(fontSize: 16),
              ),
            ],
          ),
        ),
      ],
    );
  }
}