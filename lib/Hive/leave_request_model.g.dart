// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'leave_request_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LeaveRequestAdapter extends TypeAdapter<LeaveRequest> {
  @override
  final int typeId = 3;

  @override
  LeaveRequest read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LeaveRequest(
      leaveType: fields[0] as String,
      reason: fields[1] as String,
      startDate: fields[2] as DateTime?,
      endDate: fields[3] as DateTime?,
      status: fields[4] as String,
      department: fields[5] as String,
      creatorRole: fields[6] as String?,
      userId: fields[7] as String,
      userName: fields[8] as String,
      Id: fields[9] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LeaveRequest obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.leaveType)
      ..writeByte(1)
      ..write(obj.reason)
      ..writeByte(2)
      ..write(obj.startDate)
      ..writeByte(3)
      ..write(obj.endDate)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.department)
      ..writeByte(6)
      ..write(obj.creatorRole)
      ..writeByte(7)
      ..write(obj.userId)
      ..writeByte(8)
      ..write(obj.userName)
      ..writeByte(9)
      ..write(obj.Id);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LeaveRequestAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
