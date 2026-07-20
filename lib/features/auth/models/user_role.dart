/// The two account kinds Qistiraha supports. Stored as a raw string on
/// [UserAccount.role] (see enums.dart for the same pattern used elsewhere).
enum UserRole {
  consumer,
  merchant;

  String get raw {
    switch (this) {
      case UserRole.consumer:
        return 'consumer';
      case UserRole.merchant:
        return 'merchant';
    }
  }

  static UserRole fromRaw(String? s) {
    return s == 'merchant' ? UserRole.merchant : UserRole.consumer;
  }
}
