import 'package:hive/hive.dart';

part 'models.g.dart';

@HiveType(typeId: 0)
class Staff extends HiveObject {
  @HiveField(0)
  late String name;
  @HiveField(1)
  String? notes;
  @HiveField(2)
  late int orderIndex;

  Staff({
    required this.name,
    this.notes,
    required this.orderIndex,
  });
}

@HiveType(typeId: 1)
class Site extends HiveObject {
  @HiveField(0)
  late String name;
  @HiveField(1)
  String? address;
  @HiveField(2)
  String? notes;
  @HiveField(3)
  late int colorValue;
  @HiveField(4)
  late int orderIndex;
  @HiveField(5)
  String? groupName;
  // *** NEW: Fields for preset shift times ***
  @HiveField(6)
  String? presetStartTime; // Stored as "HH:mm"
  @HiveField(7)
  String? presetFinishTime; // Stored as "HH:mm"

  Site({
    required this.name,
    this.address,
    this.notes,
    required this.colorValue,
    required this.orderIndex,
    this.groupName,
    this.presetStartTime,
    this.presetFinishTime,
  });
}

@HiveType(typeId: 2)
class ScheduleEntry extends HiveObject {
  @HiveField(0)
  late DateTime date;
  @HiveField(1)
  late int staffKey;
  @HiveField(2)
  late int siteKey;
  @HiveField(3)
  late DateTime startTime;
  @HiveField(4)
  late DateTime finishTime;
  @HiveField(5)
  String? notes;

  ScheduleEntry({
    required this.date,
    required this.staffKey,
    required this.siteKey,
    required this.startTime,
    required this.finishTime,
    this.notes,
  });
}

@HiveType(typeId: 3)
class SiteProjection extends HiveObject {
  @HiveField(0)
  late String siteKey;
  @HiveField(1)
  late double projectedHours;
  @HiveField(2)
  late DateTime weekStartDate;

  SiteProjection({
    required this.siteKey,
    required this.projectedHours,
    required this.weekStartDate,
  });
}