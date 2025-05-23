import 'package:cloud_firestore/cloud_firestore.dart';

class Message {
  final String id;
  final String sender;
  final String receiver;
  final String message;
  final DateTime timestamp;
  final bool isDisappearing;
  final int? disappearAfter;
  final bool isSeen;  // Add this field
  final DateTime? seenAt;  // Add this field

  Message({
    required this.id,
    required this.sender,
    required this.receiver,
    required this.message,
    required this.timestamp,
    this.isDisappearing = false,
    this.disappearAfter,
    this.isSeen = false,  // Initialize as false
    this.seenAt,
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
      isSeen: map['isSeen'] ?? false,
      seenAt: map['seenAt'] != null ? (map['seenAt'] as Timestamp).toDate() : null,
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
      'isSeen': isSeen,
      'seenAt': seenAt,
    };
  }

  bool shouldBeDeleted() {
    if (!isDisappearing || disappearAfter == null || !isSeen) return false;
    
    final startTime = seenAt ?? timestamp;
    final expiryTime = startTime.add(Duration(seconds: disappearAfter!));
    return DateTime.now().isAfter(expiryTime);
  }
}