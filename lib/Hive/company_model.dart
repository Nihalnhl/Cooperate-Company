import 'package:hive/hive.dart';

part 'company_model.g.dart';

@HiveType(typeId: 6)
class Company extends HiveObject {
  @HiveField(0)
  String email;

  @HiveField(1)
  String headQua;

  @HiveField(2)
  String industry;

  @HiveField(3)
  String name;

  @HiveField(4)
  String phone;

  @HiveField(5)
  String website;

  @HiveField(6)
  String workingHours;

  @HiveField(7)
  String url;

  Company({
    required this.email,
    required this.headQua,
    required this.industry,
    required this.name,
    required this.phone,
    required this.website,
    required this.workingHours,
    required this.url,
  });

  factory Company.fromMap(Map<String, dynamic> map) {
    return Company(
      email: map['Email'] ?? '',
      headQua: map['HeadQua'] ?? '',
      industry: map['Industry'] ?? '',
      name: map['Name'] ?? '',
      phone: map['Phone'] ?? '',
      website: map['Website'] ?? '',
      workingHours: map['Working Hours'] ?? '',
      url: map['url'] ?? '',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'Email': email,
      'HeadQua': headQua,
      'Industry': industry,
      'Name': name,
      'Phone': phone,
      'Website': website,
      'Working Hours': workingHours,
      'url': url,
    };
  }
}
