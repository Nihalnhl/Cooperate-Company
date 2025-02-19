import 'package:hive/hive.dart';

part 'attendance_model.g.dart';

@HiveType(typeId: 0)
class Attendance extends HiveObject {
  @HiveField(0)
  String name;

  @HiveField(1)
  String login;

  @HiveField(2)
  String logout;

  @HiveField(3)
  String date;

  Attendance({required this.name, required this.login, required this.logout, required this.date});
}


