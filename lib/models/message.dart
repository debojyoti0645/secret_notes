import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String sender;
  final String receiver;
  final String message;
  final DateTime timestamp;
  final bool isDisappearing;
  final int? disappearAfter; // in seconds

  Message({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.message,
    required this.timestamp,
    this.isDisappearing = false,
    this.disappearAfter,
  });

  factory Message.fromMap(Map<String, dynamic> map, String id) {
    return Message(
      id: id,
      sender: map['sender'],
      receiver: map['receiver'],
      message: map['message'],
      timestamp: (map['timestamp'] as Timestamp).toDate(),
      isDisappearing: map['isDisappearing'] ?? false,
      disappearAfter: map['disappearAfter'],
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sender': sender,
      'receiver': receiver,
      'message': message,
      'timestamp': timestamp,
      'isDisappearing': isDisappearing,
      'disappearAfter': disappearAfter,
    };
  }

  bool shouldBeDeleted() {
    if (!isDisappearing || disappearAfter == null) return false;

    final timestamp = this.timestamp;
    final expiryTime = timestamp.add(Duration(seconds: disappearAfter!));
    return DateTime.now().isAfter(expiryTime);
  }
}