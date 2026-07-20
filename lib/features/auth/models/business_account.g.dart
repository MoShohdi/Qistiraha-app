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
      id: fields[3] == null ? '' : fields[3] as String,
    );
  }

  @override
  void write(BinaryWriter writer, BusinessAccount obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.businessName)
      ..writeByte(1)
      ..write(obj.category)
      ..writeByte(2)
      ..write(obj.sentQists)
      ..writeByte(3)
      ..write(obj.id);
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
