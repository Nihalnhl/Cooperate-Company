import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:hive/hive.dart';

part 'leave_request_model.g.dart';

@HiveType(typeId: 3)
class LeaveRequest {
  @HiveField(0)
  final String leaveType;

  @HiveField(1)
  final String reason;

  @HiveField(2)
  final DateTime? startDate;

  @HiveField(3)
  final DateTime? endDate;

  @HiveField(4)
  final String status;

  @HiveField(5)
  final String department;

  @HiveField(6)
  final String? creatorRole;

  @HiveField(7)
  final String userId;

  @HiveField(8)
  final String userName;

  @HiveField(9)
  String? Id;



  LeaveRequest( {
    required this.leaveType,
    required this.reason,
    required this.startDate,
    required this.endDate,
    required this.status,
    required this.department,
    required this.creatorRole,
    required this.userId,
    required this.userName,
    required this.Id,
  });
  factory LeaveRequest.fromMap(Map<String, dynamic> map) {
    return LeaveRequest(
      Id: map['id'] ?? '', // Default empty string if null
      leaveType: map['leave_type'] ?? '', // Default empty string if null
      reason: map['reason'] ?? '', // Default empty string if null
      startDate: map['start_date'] != null ? (map['start_date'] is Timestamp ? map['start_date'].toDate() : DateTime.tryParse(map['start_date'])) : null,
      endDate: map['end_date'] != null ? (map['end_date'] is Timestamp ? map['end_date'].toDate() : DateTime.tryParse(map['end_date'])) : null,
      status: map['status'] ?? 'Pending', // Default to 'Pending'
      department: map['department'] ?? '', // Default empty string if null
      creatorRole: map['creator_role'],
      userId: map['user_id'] ?? '', // Default empty string if null
      userName: map['user_name'] ?? '', // Default empty string if null

    );
  }

  Map<String, dynamic> toMap() {
    return {
      'leaveType': leaveType,
      'reason': reason,
      'startDate': startDate?.toIso8601String(),
      'endDate': endDate?.toIso8601String(),
      'status': status,
      'department': department,
      'creatorRole': creatorRole,
      'userId': userId,
      'user_name': userName,
      'Id': Id,
    };
  }
}

