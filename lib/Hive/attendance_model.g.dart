// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'attendance_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AttendanceAdapter extends TypeAdapter<Attendance> {
  @override
  final int typeId = 1;

  @override
  Attendance read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Attendance(
      id: fields[0] as String?,
      userId: fields[1] as String,
      date: fields[2] as String,
      login: fields[3] as String?,
      logout: fields[4] as String?,
      checkInMillis: fields[5] as int?,
      logoutMillis: fields[6] as int?,
      workTime: fields[7] as int,
      isSynced: fields[8] as bool,
      name: fields[9] as String?,
      role: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, Attendance obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.userId)
      ..writeByte(2)
      ..write(obj.date)
      ..writeByte(3)
      ..write(obj.login)
      ..writeByte(4)
      ..write(obj.logout)
      ..writeByte(5)
      ..write(obj.checkInMillis)
      ..writeByte(6)
      ..write(obj.logoutMillis)
      ..writeByte(7)
      ..write(obj.workTime)
      ..writeByte(8)
      ..write(obj.isSynced)
      ..writeByte(9)
      ..write(obj.name)
      ..writeByte(10)
      ..write(obj.role);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AttendanceAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
