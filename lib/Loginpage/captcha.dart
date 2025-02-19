import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import '../homepage/Dashboard/homepage.dart';

class captcha extends StatefulWidget {
  const captcha({super.key});

  @override
  State<captcha> createState() => _mainpageState();
}

class _mainpageState extends State<captcha> {
  String randomString = "";
  String verificationText = "";
  bool isVerifieed = false;
  bool showVerificationIcon = false;
  TextEditingController verify = TextEditingController();
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();

  void initSate() {
    super.initState();
    buildCaptha();
  }

  void buildCaptha() {
    const letters =
        "abcdefgghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890";
    const length = 6;
    final random = Random();
    randomString = String.fromCharCodes(List.generate(
        length, (index) => letters.codeUnitAt(random.nextInt(letters.length))));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 40,
              decoration: BoxDecoration(
                  border: Border.all(width: 1),
                  borderRadius: BorderRadius.circular(12),
                  color: Colors.white),
              child: Center(
                  child: Text(
                randomString,
                style: TextStyle(fontWeight: FontWeight.bold),
              )),
            ),
            SizedBox(
              height: 10,
            ),
            IconButton(
                onPressed: () {
                  buildCaptha();
                },
                icon: Icon(Icons.refresh)),
            Container(
              margin: EdgeInsets.all(12),
              child: TextFormField(
                onChanged: (value) {
                  setState(() {
                    isVerifieed = false;
                  });
                },
                decoration: InputDecoration(
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12)),
                  hintText: "Enter Captcha",
                  labelText: "Enter captcha",
                  filled: true,
                  fillColor: Colors.white,
                ),
                controller: verify,
              ),
            ),
            SizedBox(
              height: 10,
            ),
            ElevatedButton(
                onPressed: () {
                  isVerifieed = verify.text == randomString;

                  if (isVerifieed) {
                    verificationText = "verified!";
                    showVerificationIcon = true;
                    Navigator.pushReplacement(context,
                        (MaterialPageRoute(builder: (context) => HomePage())));
                  } else {
                    verificationText = "please enter correct text";
                    showVerificationIcon = false;
                  }
                  setState(() {});
                },
                child: Text("check")),
            Visibility(
                visible: showVerificationIcon, child: Icon(Icons.verified)),
            Text(verificationText),
          ],
        ),
      ),
    );
  }
}
