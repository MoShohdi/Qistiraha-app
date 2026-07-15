// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'late_fee_rule.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LateFeeRuleAdapter extends TypeAdapter<LateFeeRule> {
  @override
  final int typeId = 4;

  @override
  LateFeeRule read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LateFeeRule(
      vendorName: fields[0] as String,
      feeType: fields[1] as FeeType,
      fixedAmount: fields[2] as double,
      percentage: fields[3] as double,
    );
  }

  @override
  void write(BinaryWriter writer, LateFeeRule obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.vendorName)
      ..writeByte(1)
      ..write(obj.feeType)
      ..writeByte(2)
      ..write(obj.fixedAmount)
      ..writeByte(3)
      ..write(obj.percentage);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LateFeeRuleAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class FeeTypeAdapter extends TypeAdapter<FeeType> {
  @override
  final int typeId = 3;

  @override
  FeeType read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return FeeType.fixed;
      case 1:
        return FeeType.percentage;
      case 2:
        return FeeType.mixed;
      default:
        return FeeType.fixed;
    }
  }

  @override
  void write(BinaryWriter writer, FeeType obj) {
    switch (obj) {
      case FeeType.fixed:
        writer.writeByte(0);
        break;
      case FeeType.percentage:
        writer.writeByte(1);
        break;
      case FeeType.mixed:
        writer.writeByte(2);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FeeTypeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
