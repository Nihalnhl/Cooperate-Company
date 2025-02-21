import 'package:hive/hive.dart';

part 'work_details_model.g.dart';

@HiveType(typeId: 5)
class WorkDetails {
  @HiveField(0)
  final String id;

  @HiveField(1)
  final String title;

  @HiveField(2)
  final String description;

  @HiveField(3)
  final String department;

  @HiveField(4)
  final String status;

  @HiveField(5)
  final String priority;

  @HiveField(6)
  final String progressUpdates;

  @HiveField(7)
  final DateTime startDate;

  @HiveField(8)
  final DateTime deadline;

  @HiveField(9)
  final String assignedTo;

  @HiveField(10)
  final String uid;


  WorkDetails({
    required this.id,
    required this.title,
    required this.description,
    required this.department,
    required this.status,
    required this.priority,
    required this.progressUpdates,
    required this.startDate,
    required this.deadline,
    required this.assignedTo,
    required this.uid, String? assignedToUid,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'department': department,
      'status': status,
      'priority': priority,
      'progressUpdates': progressUpdates,
      'startDate': startDate,
      'deadline': deadline,
      'assignedTo': assignedTo,
      'uid': uid,
    };
  }

  factory WorkDetails.fromMap(Map<String, dynamic> map) {
    return WorkDetails(
      id: map['id'],
      title: map['title'],
      description: map['description'],
      department: map['department'],
      status: map['status'],
      priority: map['priority'],
      progressUpdates: map['progressUpdates'],
      startDate: map['startDate'].toDate(),
      deadline: map['deadline'].toDate(),
      assignedTo: map['assignedTo'],
      uid: map['uid'],
    );
  }
}