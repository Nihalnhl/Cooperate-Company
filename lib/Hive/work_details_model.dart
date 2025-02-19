import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'work_details_model.g.dart';

@HiveType(typeId: 4)
class WorkDetails extends HiveObject {
  @HiveField(0)
  String title;

  @HiveField(1)
  String description;

  @HiveField(2)
  String department;

  @HiveField(3)
  String status;

  @HiveField(4)
  String priority;

  @HiveField(5)
  String assignedTo;

  @HiveField(6)
  DateTime startDate;

  @HiveField(7)
  DateTime deadline;

  @HiveField(8)
  double progressUpdates;

  @HiveField(9)
  String uid;

  WorkDetails({
    required this.title,
    required this.description,
    required this.department,
    required this.status,
    required this.priority,
    required this.assignedTo,
    required this.startDate,
    required this.deadline,
    required this.progressUpdates,
    required this.uid,
  });

  factory WorkDetails.fromMap(Map<String, dynamic> map) {
    return WorkDetails(
      title: map['title'],
      description: map['description'],
      department: map['Department'],
      status: map['Status'],
      priority: map['Priority'],
      assignedTo: map['Assignedto'],
      startDate: (map['StartDate'] as Timestamp).toDate(),
      deadline: (map['deadline'] as Timestamp).toDate(),
      progressUpdates: (map['Progressupdates'] as num).toDouble(),
      uid: map['uid'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'description': description,
      'Department': department,
      'Status': status,
      'Priority': priority,
      'Assignedto': assignedTo,
      'StartDate': startDate,
      'deadline': deadline,
      'Progressupdates': progressUpdates,
      'uid': uid,
    };
  }
}
