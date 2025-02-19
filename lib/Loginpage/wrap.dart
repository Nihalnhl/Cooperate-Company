  import 'package:firebase_auth/firebase_auth.dart';
  import 'package:flutter/cupertino.dart';
  import 'package:flutter/material.dart';
  import 'package:loginpage/Loginpage/loginpage.dart';
  import 'package:loginpage/homepage/Dashboard/bottomnavigation.dart';
  import '../homepage/Dashboard/homepage.dart';

  class wrapper extends StatefulWidget {
    const wrapper({super.key});

    @override
    State<wrapper> createState() => _wrapperState();
  }

  class _wrapperState extends State<wrapper> {
    @override
    Widget build(BuildContext context) {
      return Scaffold(
        body: StreamBuilder(
            stream: FirebaseAuth.instance.authStateChanges(),
            builder: (context, snapshot) {
              if (snapshot.hasData) {
                return Bar();
              } else {
                return BiometricLoginPage();
              }
            }),
      );
    }
  }
