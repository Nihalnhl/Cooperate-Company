import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:loginpage/Loginpage/loginpage.dart';

class SignUpPage extends StatefulWidget {
  @override
  _SignUpPageState createState() => _SignUpPageState();
}

class _SignUpPageState extends State<SignUpPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passController = TextEditingController();
  final _addressController = TextEditingController();
  final _phoneController = TextEditingController();
  String? url;
  bool isLoading = false;


  void _submitForm() async {
    if (_formKey.currentState?.validate() ?? false) {
      final name = _nameController;

      final email = _emailController.text;

      final password = _passController.text;
      final address=_phoneController.text;
      final phone =_addressController.text;

      final credential = await FirebaseAuth.instance
          .createUserWithEmailAndPassword(
          email: _emailController.text, password: _passController.text);
      const String defaultProfileImageUrl = '/data/user/0/com.example.loginpage/cache/8d91c28c-5937-46bc-8cc4-21499788d019/1000000034.jpg';
      await FirebaseFirestore.instance
          .collection('user')
          .doc(credential.user!.uid)
          .set({
        'email': _emailController.text,
        "name": _nameController.text,
        'phone':_phoneController.text,
        'address':_addressController.text,
        "url":defaultProfileImageUrl,
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
            content: Text('Succesfully Signed up, $email! You are signed up.'),
        backgroundColor: Colors.green,),

      );
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (context) => BiometricLoginPage()),
      );

      _emailController.clear();
      _passController.clear();
      _phoneController.clear();
      _addressController.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            SizedBox(height: 60),
            Text(
              "Create Account",
              style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            SizedBox(height: 10),
            Text(
              "Sign up to get started",
              style: TextStyle(fontSize: 16, color: Colors.black54),
            ),
            SizedBox(height: 40),
            Image.asset("assets/signin.jpeg", height: 120),
            SizedBox(height: 30),
            Form(
              key: _formKey,
              child: Column(
                children: [
                  buildTextField("Full Name", Icons.person, _nameController, false),
                  SizedBox(height: 16),
                  buildTextField("Email", Icons.mail, _emailController, false),
                  SizedBox(height: 16),
                  buildTextField("Password", Icons.lock, _passController, true),
                  SizedBox(height: 16),
                  buildTextField("Address", Icons.home, _addressController, false),
                  SizedBox(height: 16),
                  buildTextField("Phone", Icons.phone, _phoneController, false, isPhone: true),
                  SizedBox(height: 24),
                  isLoading
                      ? CircularProgressIndicator(color: Colors.blueAccent)
                      : buildSignUpButton(),
                  SizedBox(height: 20),
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (context) => BiometricLoginPage()),
                    ),
                    child: Text(
                      "Already have an account? Log in",
                      style: TextStyle(color: Colors.brown.shade300, fontSize: 16),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget buildTextField(String hint, IconData icon, TextEditingController controller, bool obscure, {bool isPhone = false}) {
    return TextFormField(
      controller: controller,
      obscureText: obscure,
      keyboardType: isPhone ? TextInputType.phone : TextInputType.text,
      style: TextStyle(color: Colors.black87),
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.black45),
        prefixIcon: Icon(icon, color: Colors.brown.shade300),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(15),
          borderSide: BorderSide(color: Colors.brown.shade300, width: 1),
        ),
      ),
      validator: (value) {
        if (value == null || value.isEmpty) return 'Please enter $hint';
        if (hint == "Email" && !RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(value)) {
          return 'Please enter a valid email';
        }
        if (hint == "Password" && value.length < 6) return 'Password must be at least 6 characters';
        if (hint == "Phone" && !RegExp(r'^\d{10,}$').hasMatch(value)) return 'Enter a valid phone number';
        return null;
      },
    );
  }

  Widget buildSignUpButton() {
    return SizedBox(
      width: double.infinity,
      height: 50,
      child: ElevatedButton(
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.brown.shade300,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          elevation: 5,
        ),
        onPressed: _submitForm,
        child: Text("Sign Up", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
      ),
    );
  }
}
