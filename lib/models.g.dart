// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'models.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class StaffAdapter extends TypeAdapter<Staff> {
  @override
  final int typeId = 0;

  @override
  Staff read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Staff(
      name: fields[0] as String,
      notes: fields[1] as String?,
      orderIndex: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, Staff obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.notes)
      ..writeByte(2)
      ..write(obj.orderIndex);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is StaffAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SiteAdapter extends TypeAdapter<Site> {
  @override
  final int typeId = 1;

  @override
  Site read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Site(
      name: fields[0] as String,
      address: fields[1] as String?,
      notes: fields[2] as String?,
      colorValue: fields[3] as int,
      orderIndex: fields[4] as int,
      groupName: fields[5] as String?,
      presetStartTime: fields[6] as String?,
      presetFinishTime: fields[7] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Site obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.address)
      ..writeByte(2)
      ..write(obj.notes)
      ..writeByte(3)
      ..write(obj.colorValue)
      ..writeByte(4)
      ..write(obj.orderIndex)
      ..writeByte(5)
      ..write(obj.groupName)
      ..writeByte(6)
      ..write(obj.presetStartTime)
      ..writeByte(7)
      ..write(obj.presetFinishTime);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SiteAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class ScheduleEntryAdapter extends TypeAdapter<ScheduleEntry> {
  @override
  final int typeId = 2;

  @override
  ScheduleEntry read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return ScheduleEntry(
      date: fields[0] as DateTime,
      staffKey: fields[1] as int,
      siteKey: fields[2] as int,
      startTime: fields[3] as DateTime,
      finishTime: fields[4] as DateTime,
      notes: fields[5] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, ScheduleEntry obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.date)
      ..writeByte(1)
      ..write(obj.staffKey)
      ..writeByte(2)
      ..write(obj.siteKey)
      ..writeByte(3)
      ..write(obj.startTime)
      ..writeByte(4)
      ..write(obj.finishTime)
      ..writeByte(5)
      ..write(obj.notes);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ScheduleEntryAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class SiteProjectionAdapter extends TypeAdapter<SiteProjection> {
  @override
  final int typeId = 3;

  @override
  SiteProjection read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return SiteProjection(
      siteKey: fields[0] as String,
      projectedHours: fields[1] as double,
      weekStartDate: fields[2] as DateTime,
    );
  }

  @override
  void write(BinaryWriter writer, SiteProjection obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.siteKey)
      ..writeByte(1)
      ..write(obj.projectedHours)
      ..writeByte(2)
      ..write(obj.weekStartDate);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SiteProjectionAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
