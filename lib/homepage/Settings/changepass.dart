import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class changePass extends StatefulWidget {
  const changePass({super.key});

  @override
  State<changePass> createState() => _changePassState();
}
bool isLoad=false;

class _changePassState extends State<changePass> {

  final _formKey = GlobalKey<FormState>();
  TextEditingController oldpass = TextEditingController();
  TextEditingController newpass = TextEditingController();
  void Pass(String oldpass, String newpass) async {
    if (_formKey.currentState?.validate() ?? false) {
      User user = FirebaseAuth.instance.currentUser!;
      AuthCredential cred =
      EmailAuthProvider.credential(email: user.email!, password: oldpass);


      try {
        setState(() {
          isLoad = true;
        });
        await user!.reauthenticateWithCredential(cred);
        await user.updatePassword(newpass);
        if (mounted) {
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text("Succesfully Changed")));
        }
        setState(() {
          isLoad = false;
        });

        return null;
      } catch (e) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text("incorrect Password")));
        print(e);
        setState(() {
          isLoad = false;
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
        key:   _formKey,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.start,
          children: [
            SizedBox(
              height: 20,
            ),
            Image.asset(
              "assets/passa.png",
              scale: 3,
            ),
            SizedBox(
              height: 20,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: TextFormField(

                obscureText: true,
                controller: oldpass,
                decoration: InputDecoration(
                  fillColor: Colors.grey.shade50,
                  filled: true,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'Enter Current Password',
                ),
              ),
            ),
            SizedBox(
              height: 5,
            ),
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
                controller: newpass,
                decoration: InputDecoration(
                  fillColor: Colors.grey.shade50,
                  filled: true,
                  border:
                      OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                  hintText: 'Enter New Password',

                ),

              ),
            ),
            SizedBox(
              height: 5,
            ),
            Padding(
              padding: const EdgeInsets.all(8.0),
              child: ElevatedButton(
                  onPressed: () {
                    Pass(oldpass.text, newpass.text);
                  },
                  child: isLoad? Container(
                    child: CircularProgressIndicator(
                      color: Colors.blue,
                      strokeWidth: 2,
                    ),
                  ):Text(
                    "Change Password",
                    style: TextStyle(color: Colors.blue),
                  )),
            )
          ],
        ),
      ),
    );
  }
}
