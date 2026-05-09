import 'dart:typed_data';

class PhoneContactModel {
  final String name;
  final String? phone;
  final String? email;
  final Uint8List? photo;

  const PhoneContactModel({
    required this.name,
    this.phone,
    this.email,
    this.photo,
  });
}
