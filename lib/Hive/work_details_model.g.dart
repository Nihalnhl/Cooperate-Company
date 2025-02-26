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
      Department: fields[3] as String,
      Status: fields[4] as String,
      priority: fields[5] as String,
      Progressupdates: fields[6] as String,
      startDate: fields[7] as DateTime,
      deadline: fields[8] as DateTime,
      AssignedTo: fields[9] as String,
    );
  }

  @override
  void write(BinaryWriter writer, WorkDetails obj) {
    writer
      ..writeByte(10)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.Department)
      ..writeByte(4)
      ..write(obj.Status)
      ..writeByte(5)
      ..write(obj.priority)
      ..writeByte(6)
      ..write(obj.Progressupdates)
      ..writeByte(7)
      ..write(obj.startDate)
      ..writeByte(8)
      ..write(obj.deadline)
      ..writeByte(9)
      ..write(obj.AssignedTo);
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
