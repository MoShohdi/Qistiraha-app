// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'user_account.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class UserAccountAdapter extends TypeAdapter<UserAccount> {
  @override
  final int typeId = 1;

  @override
  UserAccount read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return UserAccount(
      name: fields[0] as String,
      monthlyIncome: fields[1] as double,
      installments: (fields[2] as HiveList?)?.castHiveList(),
      salaryDay: fields[3] == null ? 1 : fields[3] as int,
    );
  }

  @override
  void write(BinaryWriter writer, UserAccount obj) {
    writer
      ..writeByte(4)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.monthlyIncome)
      ..writeByte(2)
      ..write(obj.installments)
      ..writeByte(3)
      ..write(obj.salaryDay);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserAccountAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
