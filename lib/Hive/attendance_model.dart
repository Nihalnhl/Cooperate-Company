import 'package:hive/hive.dart';

part 'attendance_model.g.dart';

@HiveType(typeId: 1)
class Attendance extends HiveObject {
  @HiveField(0)
  String? id;

  @HiveField(1)
  String userId;

  @HiveField(2)
  String date;

  @HiveField(3)
  String? login;

  @HiveField(4)
  String? logout;

  @HiveField(5)
  int? checkInMillis;

  @HiveField(6)
  int? logoutMillis;

  @HiveField(7)
  int workTime;

  @HiveField(8)
  bool isSynced;

  @HiveField(9)
  final String? name;

  @HiveField(10)
  final String role;





  Attendance({
    this.id,
    required this.userId,
    required this.date,
    this.login,
    this.logout,
    this.checkInMillis,
    this.logoutMillis,
    this.workTime = 0,
    this.isSynced = false, this.name,required this.role,
  });
  Map<String, dynamic> toJson() {
    return {
      "id": id,
      "userId": userId,
      "date": date,
      "loginTime": login,
      "logoutTime": logout,
      "checkInMillis": checkInMillis,
      "logoutMillis": logoutMillis,
      "workTime": workTime,
      "isSynced": isSynced,
      "name":name,
      "role":role
    };
  }

}
