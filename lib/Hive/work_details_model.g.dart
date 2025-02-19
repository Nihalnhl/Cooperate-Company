// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_details_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkDetailsAdapter extends TypeAdapter<WorkDetails> {
  @override
  final int typeId = 4;

  @override
  WorkDetails read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkDetails(
      title: fields[0] as String,
      description: fields[1] as String,
      department: fields[2] as String,
      status: fields[3] as String,
      priority: fields[4] as String,
      assignedTo: fields[5] as String,
      startDate: fields[6] as DateTime,
      deadline: fields[7] as DateTime,
      progressUpdates: fields[8] as double,
      uid: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, WorkDetails obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.title)
      ..writeByte(1)
      ..write(obj.description)
      ..writeByte(2)
      ..write(obj.department)
      ..writeByte(3)
      ..write(obj.status)
      ..writeByte(4)
      ..write(obj.priority)
      ..writeByte(5)
      ..write(obj.assignedTo)
      ..writeByte(6)
      ..write(obj.startDate)
      ..writeByte(7)
      ..write(obj.deadline)
      ..writeByte(8)
      ..write(obj.progressUpdates)
      ..writeByte(9)
      ..write(obj.uid);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is WorkDetailsAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
