import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class Terms extends StatelessWidget {
  const Terms({super.key});

  @override
  Widget build(BuildContext context) {
    return  Scaffold(
      backgroundColor: Colors.grey.shade300,
      appBar: AppBar(
        title: Text("Terms of Use"),
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
                      color: Colors.grey.shade200),
                  child: Text("Terms of Use for Cooprate Company AppEffective Date: [Insert Date]Welcome to the Cooprate company app. These Terms of Use (“Terms”) govern your access to and use of the Cooprate app and its services. By using the app, you agree to comply with these Terms. If you do not agree, please do not use the app.\n1. Acceptance of TermsBy downloading, installing, or using the Cooprate app, you confirm that you have read, understood, and agree to these Terms.\n2. EligibilityTo use this app, you must:	\n•	Be at least 18 years old or have the legal capacity to enter into binding agreements in your jurisdiction.	\n•	Provide accurate and truthful information during registration or when using the app.\n3. User Account	\n•	You are responsible for maintaining the confidentiality of your account credentials.	\n•	Notify us immediately if you suspect unauthorized access to your account.	\n•	You may not transfer your account to another person without our written consent.\n4. Permitted UseYou agree to use the app only for lawful purposes and in accordance with these Terms. Prohibited activities include:	\n•	Misusing the app to harass, harm, or exploit others.	\n•	Interfering with the app’s operation or attempting to bypass security measures.	•	Using the app for fraudulent purposes or illegal activities.\n5. Intellectual Property	\n•	All content, trademarks, and materials within the app are the property of Cooprate or its licensors.	\n•	You may not copy, distribute, or modify any part of the app without prior written consent.\n6. User Content	\n•	You retain ownership of content you submit through the app. By submitting content, you grant Cooprate a license to use, display, and distribute it for the purpose of providing the app’s services.	•	You are solely responsible for ensuring your content complies with applicable laws and does not infringe on others’ rights.\n7. Fees and PaymentsIf the app includes paid features or subscriptions:	\n•	You agree to pay all applicable fees, as specified at the time of purchase.	\n•	Cooprate reserves the right to modify pricing or add new charges with prior notice.\n8. Termination	\n•	Cooprate reserves the right to suspend or terminate your access to the app if you violate these Terms or engage in unlawful activities.	\n•	You may stop using the app at any time by deleting your account.\n9. Disclaimers	\n•	The app is provided “as is” without any warranties of any kind.	\n•	Cooprate does not guarantee uninterrupted or error-free operation of the app.\n10. Limitation of LiabilityTo the extent permitted by law, Cooprate is not liable for:	\n•	Any direct, indirect, incidental, or consequential damages arising from your use of the app.	\n•	Loss of data, revenue, or profits caused by app-related issues.\n11. Third-Party ServicesThe app may include links or integrations with third-party services. Cooprate is not responsible for the content, functionality, or privacy practices of these services.\n12. Governing LawThese Terms are governed by the laws of [Insert Jurisdiction]. Any disputes will be resolved in courts located in [Insert Jurisdiction].\n13. Changes to the TermsCooprate reserves the right to modify these Terms at any time. Changes will be effective upon posting within the app. Continued use of the app signifies your acceptance of the updated Terms.\n14. Contact UsIf you have questions or concerns about these Terms, contact us at:[Insert Contact Email][Insert Contact Address]"))
            ],
          ),
        ),
      ),
    );
  }
}
