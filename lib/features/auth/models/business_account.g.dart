// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'business_account.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BusinessAccountAdapter extends TypeAdapter<BusinessAccount> {
  @override
  final int typeId = 2;

  @override
  BusinessAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BusinessAccount(
      businessName: fields[0] as String,
      category: fields[1] as String,
      sentQists: (fields[2] as HiveList?)?.castHiveList(),
    );
  }

  @override
  void write(BinaryWriter writer, BusinessAccount obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.businessName)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.sentQists);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BusinessAccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
