import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../services/contact_service.dart';
import '../services/encryption_service.dart';

class ChatPage extends StatefulWidget {
  final String currentUser;
  final String otherUser;

  const ChatPage({super.key, required this.currentUser, required this.otherUser});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  final ContactService _contactService = ContactService();
  String _otherUserName = '';

  // Add these variables
  bool _isDisappearingNote = false;
  int _disappearAfter = 30; // Default 30 seconds
  final Map<String, Timer> _disappearingTimers = {};

  late String _encryptionKey;

  // Add this field to the state class
  bool _isOtherUserOnline = false;

  // Add this field
  Timestamp? _lastSeen;

  @override
  void initState() {
    super.initState();
    _loadOtherUserName();
    _encryptionKey = EncryptionService.generateKey(widget.currentUser, widget.otherUser);
    _listenToUserStatus(); // <-- Start listening to user status
  }

  Future<void> _loadOtherUserName() async {
    final userData = await FirebaseFirestore.instance
        .collection('users')
        .doc(widget.otherUser)
        .get();
    
    if (mounted && userData.exists) {
      setState(() {
        _otherUserName = userData.data()?['inAppName'] ?? '';
        _isOtherUserOnline = userData.data()?['isOnline'] ?? false; // <-- Load online status
      });
    }
  }

  // Add this method to handle disappearing messages
  void _startDisappearingTimer(String messageId, int seconds) {
    _disappearingTimers[messageId]?.cancel();
    _disappearingTimers[messageId] = Timer(Duration(seconds: seconds), () {
      FirebaseFirestore.instance
          .collection('chats')
          .doc(messageId)
          .delete();
    });
  }

  // Add a method to handle message deletion
  void _deleteMessage(String messageId) {
    if (!mounted) return; // Check if widget is still mounted
    FirebaseFirestore.instance
        .collection('chats')
        .doc(messageId)
        .delete();
  }

  // Modify how we handle disappearing messages
  void _startMessageTimer(DocumentSnapshot message) {
    if (!mounted) return;
    
    final String messageId = message.id;
    final timestamp = (message['timestamp'] as Timestamp?)?.toDate();
    final disappearAfter = message['disappearAfter'] as int?;
    
    if (timestamp != null && disappearAfter != null) {
      final expiryTime = timestamp.add(Duration(seconds: disappearAfter));
      final remaining = expiryTime.difference(DateTime.now());
      
      if (remaining.isNegative) {
        _deleteMessage(messageId);
      } else {
        _disappearingTimers[messageId]?.cancel(); // Cancel existing timer if any
        _disappearingTimers[messageId] = Timer(remaining, () {
          if (mounted) { // Check if widget is still mounted
            _deleteMessage(messageId);
          }
        });
      }
    }
  }

  Future<void> sendMessage() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    try {
      // Encrypt the message
      final encryptedMessage = EncryptionService.encryptMessage(text, _encryptionKey);

      // Add encrypted message to chats collection
      final messageRef = await FirebaseFirestore.instance.collection('chats').add({
        'sender': widget.currentUser,
        'receiver': widget.otherUser,
        'message': encryptedMessage, // Store encrypted message
        'timestamp': FieldValue.serverTimestamp(),
        'isDisappearing': _isDisappearingNote,
        'disappearAfter': _isDisappearingNote ? _disappearAfter : null,
      });

      // If it's a disappearing note, start the timer
      if (_isDisappearingNote) {
        _startDisappearingTimer(messageRef.id, _disappearAfter);
      }

      // Update contact records for both users
      final senderData = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.currentUser)
          .get();
      
      final receiverData = await FirebaseFirestore.instance
          .collection('users')
          .doc(widget.otherUser)
          .get();

      await _contactService.updateContactOnInteraction(
        userId: widget.currentUser,
        contactId: widget.otherUser,
        contactName: receiverData.data()?['inAppName'] ?? '',
        contactEmail: receiverData.data()?['email'] ?? '',
        isSender: true,
      );

      await _contactService.updateContactOnInteraction(
        userId: widget.otherUser,
        contactId: widget.currentUser,
        contactName: senderData.data()?['inAppName'] ?? '',
        contactEmail: senderData.data()?['email'] ?? '',
        isSender: false,
      );

      _controller.clear();
      
      // Scroll to bottom
      if (_scrollController.hasClients) {
        await _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 100,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }

      // Reset disappearing note mode
      setState(() {
        _isDisappearingNote = false;
      });
    } catch (e) {
      debugPrint('Error sending message: $e');
    }
  }

  // Add this method for the timer picker
  void _showDisappearingOptions() {
    showModalBottomSheet(
      context: context,
      builder: (context) => Container(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Set Disappearing Time',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _timeButton(30, '30s'),
                _timeButton(60, '1m'),
                _timeButton(300, '5m'),
                _timeButton(3600, '1h'),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _timeButton(int seconds, String label) {
    return ElevatedButton(
      onPressed: () {
        setState(() {
          _isDisappearingNote = true;
          _disappearAfter = seconds;
        });
        Navigator.pop(context);
      },
      child: Text(label),
    );
  }

  // Update the build method with this modernized UI
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Theme.of(context).primaryColor,
        title: Row(
          children: [
            CircleAvatar(
              backgroundColor: Colors.white,
              child: Text(
                _otherUserName.isNotEmpty ? _otherUserName[0].toUpperCase() : '?',
                style: TextStyle(color: Theme.of(context).primaryColor),
              ),
            ),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _otherUserName.isEmpty ? 'Chat' : _otherUserName,
                  style: const TextStyle(color: Colors.white, fontSize: 18),
                ),
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.only(right: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isOtherUserOnline ? Colors.green : Colors.grey,
                      ),
                    ),
                    Text(
                      _isOtherUserOnline 
                        ? 'Online'
                        : _lastSeen != null 
                          ? 'Last seen ${_formatLastSeen(_lastSeen!)}'
                          : 'Offline',
                      style: const TextStyle(color: Colors.white70, fontSize: 12),
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.more_vert, color: Colors.white),
            onPressed: () {
              // Add menu options here
            },
          ),
        ],
      ),
      body: Container(
        decoration: BoxDecoration(
          // Add a subtle background pattern
          color: Colors.grey[100],
          image: DecorationImage(
            image: const AssetImage('assets/chat_bg.png'), // Add a subtle background image
            fit: BoxFit.cover,
            colorFilter: ColorFilter.mode(
              Colors.white.withOpacity(0.1),
              BlendMode.dstATop,
            ),
          ),
        ),
        child: Column(
          children: [
            if (_isDisappearingNote)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                color: Colors.amber.withOpacity(0.2),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.timer, color: Colors.amber),
                    const SizedBox(width: 8),
                    Text(
                      'Disappearing note: ${_disappearAfter}s',
                      style: const TextStyle(
                        color: Colors.amber,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.amber),
                      onPressed: () => setState(() => _isDisappearingNote = false),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: StreamBuilder(
                stream: FirebaseFirestore.instance
                    .collection('chats')
                    .orderBy('timestamp')
                    .snapshots(),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final messages = snapshot.data!.docs.where((doc) {
                    final sender = doc['sender'];
                    final receiver = doc['receiver'];
                    
                    // Check if message should be visible
                    final isDisappearing = doc['isDisappearing'] ?? false;
                    if (isDisappearing) {
                      final timestamp = doc['timestamp'];
                      final disappearAfter = doc['disappearAfter'] as int?;
                      
                      // Add null check for timestamp
                      if (timestamp != null && disappearAfter != null) {
                        try {
                          final messageTime = (timestamp as Timestamp).toDate();
                          final expiryTime = messageTime.add(Duration(seconds: disappearAfter));
                          if (DateTime.now().isAfter(expiryTime)) {
                            // Delete expired message
                            FirebaseFirestore.instance
                                .collection('chats')
                                .doc(doc.id)
                                .delete();
                            return false;
                          }
                        } catch (e) {
                          debugPrint('Error processing message timestamp: $e');
                          return false;
                        }
                      }
                    }
                    
                    return (sender == widget.currentUser && receiver == widget.otherUser) ||
                           (sender == widget.otherUser && receiver == widget.currentUser);
                  }).toList();

                  return ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.all(16),
                    itemCount: messages.length,
                    itemBuilder: (context, index) {
                      final msg = messages[index];
                      final isMe = msg['sender'] == widget.currentUser;
                      final isDisappearing = msg['isDisappearing'] ?? false;
                      
                      return _buildMessageBubble(context, msg, isMe);
                    },
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 5,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: SafeArea(
                child: Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        color: _isDisappearingNote
                            ? Colors.amber.withOpacity(0.1)
                            : Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: IconButton(
                        icon: Icon(
                          Icons.timer,
                          color: _isDisappearingNote
                              ? Colors.amber
                              : Theme.of(context).primaryColor,
                        ),
                        onPressed: _showDisappearingOptions,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.grey[100],
                          borderRadius: BorderRadius.circular(25),
                        ),
                        child: TextField(
                          controller: _controller,
                          decoration: InputDecoration(
                            hintText: _isDisappearingNote
                                ? 'Type a disappearing note...'
                                : 'Type a message...',
                            hintStyle: TextStyle(color: Colors.grey[400]),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 12,
                            ),
                          ),
                          maxLines: null,
                          textCapitalization: TextCapitalization.sentences,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: _isDisappearingNote
                              ? [Colors.amber, Colors.orange]
                              : [
                                  Theme.of(context).primaryColor,
                                  Theme.of(context).primaryColor.withOpacity(0.8),
                                ],
                        ),
                        borderRadius: BorderRadius.circular(25),
                      ),
                      child: IconButton(
                        icon: const Icon(Icons.send, color: Colors.white),
                        onPressed: sendMessage,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Update the message bubble style in the ListView.builder
  Widget _buildMessageBubble(BuildContext context, DocumentSnapshot msg, bool isMe) {
    final isDisappearing = msg['isDisappearing'] ?? false;
    
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.only(
          top: 4,
          bottom: 4,
          left: isMe ? 64 : 8,
          right: isMe ? 8 : 64,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 10,
        ),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: isDisappearing
                ? [Colors.amber, Colors.orange.shade300]
                : isMe
                    ? [
                        Theme.of(context).primaryColor,
                        Theme.of(context).primaryColor.withOpacity(0.8),
                      ]
                    : [Colors.white, Colors.grey.shade50],
          ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMe ? 16 : 4),
            bottomRight: Radius.circular(isMe ? 4 : 16),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.1),
              blurRadius: 3,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              EncryptionService.decryptMessage(msg['message'], _encryptionKey),
              style: TextStyle(
                color: isDisappearing
                    ? Colors.black87
                    : (isMe ? Colors.white : Colors.black87),
                fontSize: 16,
              ),
            ),
            if (isDisappearing)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: const [
                    Icon(
                      Icons.timer,
                      size: 12,
                      color: Colors.black54,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'Disappearing',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }

  // Add this method in the _ChatPageState class
  void _listenToUserStatus() {
    FirebaseFirestore.instance
        .collection('users')
        .doc(widget.otherUser)
        .snapshots()
        .listen((snapshot) {
      if (mounted && snapshot.exists) {
        setState(() {
          _isOtherUserOnline = snapshot.data()?['isOnline'] ?? false;
          _lastSeen = snapshot.data()?['lastSeen'];
        });
      }
    });
  }

  String _formatLastSeen(Timestamp lastSeen) {
    final now = DateTime.now();
    final lastSeenDate = lastSeen.toDate();
    final difference = now.difference(lastSeenDate);

    if (difference.inSeconds < 60) {
      return 'just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${lastSeenDate.day}/${lastSeenDate.month}/${lastSeenDate.year}';
    }
  }

  @override
  void dispose() {
    // Cancel all timers when disposing
    _disappearingTimers.clear();
    _controller.dispose();
    super.dispose();
  }
}
