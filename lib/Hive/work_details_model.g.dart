// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'work_details_model.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class WorkDetailsAdapter extends TypeAdapter<WorkDetails> {
  @override
  final int typeId = 5;

  @override
  WorkDetails read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return WorkDetails(
      id: fields[0] as String,
      title: fields[1] as String,
      description: fields[2] as String,
      department: fields[3] as String,
      status: fields[4] as String,
      priority: fields[5] as String,
      progressUpdates: fields[6] as String,
      startDate: fields[7] as DateTime,
      deadline: fields[8] as DateTime,
      assignedTo: fields[9] as String,
      uid: fields[10] as String,
    );
  }

  @override
  void write(BinaryWriter writer, WorkDetails obj) {
    writer
      ..writeByte(11)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.department)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.priority)
      ..writeByte(6)
      ..write(obj.progressUpdates)
      ..writeByte(7)
      ..write(obj.startDate)
      ..writeByte(8)
      ..write(obj.deadline)
      ..writeByte(9)
      ..write(obj.assignedTo)
      ..writeByte(10)
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
