import 'package:hive/hive.dart';

part 'work_details_model.g.dart';

@HiveType(typeId: 5)
class WorkDetails {
  @HiveField(0)
  late final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String Department;

  @HiveField(4)
  final String Status;

  @HiveField(5)
  final String priority;

  @HiveField(6)
  final String Progressupdates;

  @HiveField(7)
  final DateTime startDate;

  @HiveField(8)
  final DateTime deadline;

  @HiveField(9)
  final String AssignedTo;




  WorkDetails({
    required this.id,
    required this.title,
    required this.description,
    required this.Department,
    required this.Status,
    required this.priority,
    required this.Progressupdates,
    required this.startDate,
    required this.deadline,
    required this.AssignedTo,

  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'Department': Department,
      'Status': Status,
      'Priority': priority,
      'Progressupdates': Progressupdates,
      'StartDate': startDate,
      'deadline': deadline,
      'AssignedTo': AssignedTo,

    };
  }

  factory WorkDetails.fromMap(Map<String, dynamic> map) {
    return WorkDetails(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      Department: map['Department'],
      Status: map['Status'],
      priority: map['Priority'],
      Progressupdates: map['Progressupdates'],
      startDate: map['StartDate'].toDate(),
      deadline: map['deadline'].toDate(),
      AssignedTo: map['AssignedTo'],
    );
  }
}