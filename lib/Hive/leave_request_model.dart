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
   String status;

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
      Id: map['id'] ?? '',
      leaveType: map['leave_type'] ?? '',
      reason: map['reason'] ?? '',
      startDate: map['start_date'] != null ? (map['start_date'] is Timestamp ? map['start_date'].toDate() : DateTime.tryParse(map['start_date'])) : null,
      endDate: map['end_date'] != null ? (map['end_date'] is Timestamp ? map['end_date'].toDate() : DateTime.tryParse(map['end_date'])) : null,
      status: map['status'] ?? 'Pending',
      department: map['department'] ?? '',
      creatorRole: map['creator_role'],
      userId: map['user_id'] ?? '',
      userName: map['user_name'] ?? '',

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

