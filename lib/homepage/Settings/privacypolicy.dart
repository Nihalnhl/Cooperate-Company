import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Privacypolicy extends StatelessWidget {
  const Privacypolicy({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        title: Text("Privacy Policy"),
        backgroundColor: Colors.grey.shade300,
      ),
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Column(
            children: [
              Container(
                  decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      color: Colors.grey.shade200),child: Text("Privacy Policy for Cooprate Company AppEffective Date: 09/10/2021 At Cooprate, \n we prioritize your privacy and are committed to protecting the personal information you share with us. This Privacy Policy explains how we collect, use, and safeguard your information when you use the Cooprate company app. \n1. Information We CollectWe may collect the following types of information:	\n•	Personal Information: Name, email address, phone number, and other identifiable details provided during registration.	\n•	Usage Data: Details about how you use the app, including access times, features used, and device information.	\n•	Location Data: If enabled, we may collect your location to enhance app functionality.	\n•	Other Data: Any additional information you provide via support requests or feedback forms2. How We Use Your InformationThe information collected may be used for:	\n•	Improving app functionality and user experience.	\n•	Sending notifications, updates, and promotional materials (with your consent).	\n•	Ensuring the security of our app and services.	\n•	Complying with legal obligations.\n3. How We Protect Your InformationWe implement industry-standard measures to secure your data, including encryption and access controls. However, no method of data transmission or storage is 100% secure.\n4. Sharing Your InformationWe do not sell your personal information. However, we may share data with:	\n•	Service providers assisting with app functionality (e.g., cloud hosting).	\n•	Legal authorities, if required by law or to protect rights5. Your Right Depending on your location, you may have the following rights:	\n•	Access and update your data.	\n•	Request data deletion.	\n•	Opt-out of data collection or marketing communications.	\n•	Submit complaints to a data protection authority.\n6. Cookies and Tracking TechnologiesThe app may use cookies or similar technologies to enhance user experience. You can manage cookies through your device settings.\n7. Third-Party ServicesThe app may integrate with third-party services. We are not responsible for their privacy practices, so we encourage you to review their policies.\n8. Children’s PrivacyThe app is not intended for users under the age of 13, and we do not knowingly collect information from children.\n9. Changes to This Privacy PolicyWe may update this policy periodically. The latest version will be available in the app, and significant changes will be communicated to users.\n10. Contact UsFor questions or concerns about this Privacy Policy, contact us at:Cybrosys.in"))
            ],
          ),
        ),
      ),
    );
  }
}
