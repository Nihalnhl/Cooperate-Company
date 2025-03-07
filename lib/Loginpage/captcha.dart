import 'dart:math';
import 'package:flutter/material.dart';
import 'package:loginpage/homepage/Dashboard/bottomnavigation.dart';

class Captcha extends StatefulWidget {
  const Captcha({super.key});

  @override
  State<Captcha> createState() => _CaptchaState();
}

class _CaptchaState extends State<Captcha> {
  String randomString = "";
  String verificationText = "";
  bool isVerified = false;
  bool showVerificationIcon = false;
  TextEditingController verify = TextEditingController();

  @override
  void initState() {
    super.initState();
    buildCaptcha();
  }

  void buildCaptcha() {
    const letters =
        "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ1234567890";
    const length = 6;
    final random = Random();
    setState(() {
      randomString = String.fromCharCodes(List.generate(
          length, (index) => letters.codeUnitAt(random.nextInt(letters.length))));
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // appBar: AppBar(
      //   title: Text("CAPTCHA VERIFICATION"),
      // ),
      backgroundColor: Colors.grey.shade100,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            elevation: 4,
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    "Verify You're Human",
                    style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                  SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          border: Border.all(color: Colors.grey.shade400),
                          borderRadius: BorderRadius.circular(12),
                          color: Colors.white,
                        ),
                        child: Text(
                          randomString,
                          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
                        ),
                      ),
                      SizedBox(width: 10),
                      IconButton(
                        onPressed: buildCaptcha,
                        icon: Icon(Icons.refresh, color: Colors.blue),
                        tooltip: "Refresh Captcha",
                      ),
                    ],
                  ),

                  SizedBox(height: 20),

                  // Input Field
                  TextFormField(
                    controller: verify,
                    onChanged: (value) {
                      setState(() {
                        isVerified = false;
                      });
                    },
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      hintText: "Enter Captcha",
                      labelText: "Enter Captcha",
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),

                  SizedBox(height: 20),

                  ElevatedButton(
                    onPressed: () {
                      setState(() {
                        isVerified = verify.text == randomString;
                      });

                      if (isVerified) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text("CAPTCHA Verified!"),
                            backgroundColor: Colors.green,
                            duration: Duration(seconds: 3),
                          ),
                        );
                        Navigator.push(
                          context,
                          MaterialPageRoute(builder: (context) => Bar()),
                        );
                      } else {
                        setState(() {
                          verificationText = "Incorrect, please try again.";
                          showVerificationIcon = false;
                        });
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      padding: EdgeInsets.symmetric(horizontal: 30, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    child: Text("Verify"),
                  ),


                  SizedBox(height: 10),
                  Visibility(
                    visible: verificationText.isNotEmpty,
                    child: Column(
                      children: [
                        SizedBox(height: 10),
                        Icon(
                          showVerificationIcon ? Icons.verified : Icons.error_outline,
                          color: showVerificationIcon ? Colors.green : Colors.red,
                          size: 28,
                        ),
                        SizedBox(height: 5),
                        Text(
                          verificationText,
                          style: TextStyle(
                            color: showVerificationIcon ? Colors.green : Colors.red,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
