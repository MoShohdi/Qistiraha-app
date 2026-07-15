// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'installment.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class InstallmentAdapter extends TypeAdapter<Installment> {
  @override
  final int typeId = 0;

  @override
  Installment read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Installment(
      id: fields[0] as String,
      amount: fields[1] as double,
      merchantName: fields[2] as String,
      dueDate: fields[3] as DateTime,
      totalMonths: fields[4] as int,
      paidMonths: fields[5] as int,
      status: fields[6] as String,
      monthlyPayment: fields[7] as double,
      itemDescription: fields[8] as String,
      downPayment: fields[9] as double,
      interestRate: fields[10] as double,
      category: fields[11] as String,
      lender: fields[12] == null ? 'Other' : fields[12] as String,
      pastPayments:
          fields[13] == null ? [] : (fields[13] as List).cast<double>(),
      warrantyImagePath: fields[14] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, Installment obj) {
    writer
      ..writeByte(15)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.amount)
      ..writeByte(2)
      ..write(obj.merchantName)
      ..writeByte(3)
      ..write(obj.dueDate)
      ..writeByte(4)
      ..write(obj.totalMonths)
      ..writeByte(5)
      ..write(obj.paidMonths)
      ..writeByte(6)
      ..write(obj.status)
      ..writeByte(7)
      ..write(obj.monthlyPayment)
      ..writeByte(8)
      ..write(obj.itemDescription)
      ..writeByte(9)
      ..write(obj.downPayment)
      ..writeByte(10)
      ..write(obj.interestRate)
      ..writeByte(11)
      ..write(obj.category)
      ..writeByte(12)
      ..write(obj.lender)
      ..writeByte(13)
      ..write(obj.pastPayments)
      ..writeByte(14)
      ..write(obj.warrantyImagePath);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is InstallmentAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
