import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

class ChangePass extends StatefulWidget {
  const ChangePass({super.key});

  @override
  State<ChangePass> createState() => _ChangePassState();
}

class _ChangePassState extends State<ChangePass> {
  final _formKey = GlobalKey<FormState>();
  TextEditingController oldPass = TextEditingController();
  TextEditingController newPass = TextEditingController();
  bool isLoading = false;

  Future<bool> isOnline() async {
    var connectivityResult = await Connectivity().checkConnectivity();
    return connectivityResult != ConnectivityResult.none;
  }

  void changePassword(String oldPassword, String newPassword) async {
    if (_formKey.currentState?.validate() ?? false) {
      if (!await isOnline()) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("No internet connection. Please try again later."),
          backgroundColor: Colors.red,),
        );
        return;
      }

      User user = FirebaseAuth.instance.currentUser!;
      AuthCredential credential = EmailAuthProvider.credential(
          email: user.email!, password: oldPassword);

      try {
        setState(() {
          isLoading = true;
        });

        await user.reauthenticateWithCredential(credential);
        await user.updatePassword(newPassword);

        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Successfully changed password."),
              backgroundColor: Colors.green,));
        }
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Incorrect password or an error occurred."),
          backgroundColor: Colors.red,),
        );
      } finally {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        backgroundColor: Colors.grey.shade300,
        title: Text("Change Password"),
      ),
      body: Form(
        key: _formKey,
        child: Column(
          children: [
            SizedBox(height: 20),
            Image.asset("assets/passa.png", scale: 3),
            SizedBox(height: 20),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                obscureText: true,
                controller: oldPass,
                decoration: InputDecoration(
                  fillColor: Colors.grey.shade50,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'Enter Current Password',
                ),
              ),
            ),
            SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(
                validator: (value) {
                  if (value == null || value.isEmpty) {
                    return 'Please enter a password';
                  }
                  if (value.length < 6) {
                    return 'Password must be at least 6 characters';
                  }
                  return null;
                },
                obscureText: true,
                controller: newPass,
                decoration: InputDecoration(
                  fillColor: Colors.grey.shade50,
                  filled: true,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'Enter New Password',
                ),
              ),
            ),
            SizedBox(height: 5),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                onPressed: () {
                  changePassword(oldPass.text, newPass.text);
                },
                child: isLoading
                    ? CircularProgressIndicator(color: Colors.blue, strokeWidth: 2)
                    : Text("Change Password", style: TextStyle(color: Colors.blue)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
