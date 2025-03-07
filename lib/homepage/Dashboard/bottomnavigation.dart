import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../Drawer/Attendance.dart';
import 'Attendancemark.dart';
import 'Profile.dart';
import 'homepage.dart';



class Bar extends StatefulWidget {
  const Bar({super.key});

  @override
  State<Bar> createState() => _BarState();
}

class _BarState extends State<Bar> {
  String? role;
  final FirebaseAuth auth = FirebaseAuth.instance;
  @override
  @override
  void initState() {
    super.initState();
    final controller = Get.put(NavigationController());
    controller.selectedIndex.value = 0;
    getData();
  }


  void getData() {
    final User? user = auth.currentUser;
    final uid = user!.uid;

    FirebaseFirestore.instance
        .collection('user')
        .doc(uid)
        .get()
        .then((DocumentSnapshot docusnapshot) {
      if (docusnapshot.exists) {
        final data = docusnapshot.data() as Map<String, dynamic>?;
        if (mounted) {
          setState(() {
            role = data!['role'];

          });
        }
      } else {
        print('Document does not exist in database');
      }
    });
  }
  @override
  Widget build(BuildContext context) {
    final controller = Get.put(NavigationController());


    return Scaffold(
      body: role == 'employee' ? Obx(() => controller.Screens[controller.selectedIndex.value]):
      Obx(() => controller.Screen2[controller.selectedIndex.value]),
      bottomNavigationBar: Obx(
            () => Container(
          margin: EdgeInsets.all(15),
          height: 70,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(35),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 10,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildNavItem(
                icon: Icons.dashboard_outlined,
                label: 'Dashboard',
                index: 0,
                controller: controller,
              ),
              _buildNavItem(
                icon: Icons.person_pin_outlined,
                label: 'Attendance',
                index: 1,
                controller: controller,
              ),
              _buildNavItem(
                icon: Icons.person,
                label: 'Profile',
                index: 2,
                controller: controller,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildNavItem({
    required IconData icon,
    required String label,
    required int index,
    required NavigationController controller,
  }) {
    bool isSelected = controller.selectedIndex.value == index;
    return GestureDetector(
      onTap: () => controller.selectedIndex.value = index,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            padding: EdgeInsets.all(isSelected ? 12 : 8),
            decoration: BoxDecoration(
              color: isSelected ? Colors.brown.shade300 : Colors.transparent,
              shape: BoxShape.circle,
            ),
            child: Icon(
              icon,
              color: isSelected ? Colors.white : Colors.grey.shade600,
              size: 23,
            ),
          ),
          SizedBox(height: 1),
          AnimatedContainer(
            duration: Duration(milliseconds: 300),
            height: 4,
            width: isSelected ? 20 : 0,
            decoration: BoxDecoration(
              color: Colors.brown.shade300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          SizedBox(height: 1),
          Text(
            label,
            style: TextStyle(
              color: isSelected ? Colors.brown.shade600 : Colors.grey.shade600,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
class NavigationController extends GetxController {
  final Rx<int> selectedIndex = 0.obs;
  final Screens = [HomePage(), CheckInOutPage1(), ProfileScreen()];
  final Screen2 = [HomePage(), LoginLogoutScreen1(), ProfileScreen()];
}