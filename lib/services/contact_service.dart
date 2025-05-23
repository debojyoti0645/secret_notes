import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

// Contact management service class
class ContactService {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  Future<void> updateContactOnInteraction({
    required String userId,
    required String contactId,
    required String contactName,
    required String contactEmail,
    required bool isSender,
  }) async {
    final userContactRef = _firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .doc(contactId);
    
    final contactData = await userContactRef.get();
    
    // Determine direction based on existing data and current interaction
    String direction;
    if (contactData.exists) {
      final existingDirection = contactData.data()!['direction'];
      if (existingDirection == 'both') {
        direction = 'both';
      } else if (isSender && existingDirection == 'received') {
        direction = 'both';
      } else if (!isSender && existingDirection == 'sent') {
        direction = 'both';
      } else {
        direction = isSender ? 'sent' : 'received';
      }
    } else {
      direction = isSender ? 'sent' : 'received';
    }

    // Update or create contact document
    await userContactRef.set({
      'userId': contactId,
      'inAppName': contactName,
      'email': contactEmail,
      'lastInteraction': FieldValue.serverTimestamp(),
      'direction': direction,
    }, SetOptions(merge: true));
  }

  // Get recent contacts
  Future<List<Map<String, dynamic>>> getRecentContacts(String userId) async {
    final snapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .orderBy('lastInteraction', descending: true)
        .limit(10)
        .get();

    return snapshot.docs
        .map((doc) => {
              'uid': doc.data()['userId'],
              'inAppName': doc.data()['inAppName'],
              'email': doc.data()['email'],
              'direction': doc.data()['direction'],
            })
        .toList();
  }

  // Get uncontacted users
  Future<List<Map<String, dynamic>>> getUncontactedUsers(String userId) async {
    // Get all contacted user IDs
    final contactedSnapshot = await _firestore
        .collection('users')
        .doc(userId)
        .collection('contacts')
        .get();
    
    final contactedIds = contactedSnapshot.docs.map((doc) => doc.data()['userId']).toList();
    
    // Query users not in contacted list
    final uncontactedSnapshot = await _firestore
        .collection('users')
        .where(FieldPath.documentId, whereNotIn: [userId, ...contactedIds])
        .get();

    return uncontactedSnapshot.docs
        .map((doc) => {
              'uid': doc.id,
              'inAppName': doc.data()['inAppName'],
              'email': doc.data()['email'],
            })
        .toList();
  }

  // Search users
  Future<List<Map<String, dynamic>>> searchUsers(String userId, String query) async {
    // Convert query to lowercase for case-insensitive search
    final searchQuery = query.toLowerCase();
    
    try {
      // Query both contacts and all users simultaneously
      final contactsQuery = _firestore
          .collection('users')
          .doc(userId)
          .collection('contacts')
          .orderBy('inAppName')
          .startAt([searchQuery])
          .endAt([searchQuery + '\uf8ff'])
          .get();

      final usersQuery = _firestore
          .collection('users')
          .orderBy('inAppName')
          .startAt([searchQuery])
          .endAt([searchQuery + '\uf8ff'])
          .get();

      // Execute both queries simultaneously
      final results = await Future.wait([contactsQuery, usersQuery]);
      final contactDocs = results[0].docs;
      final userDocs = results[1].docs;

      // Process contacts
      final contactResults = contactDocs.map((doc) => {
            'uid': doc.data()['userId'],
            'inAppName': doc.data()['inAppName'],
            'email': doc.data()['email'],
            'isContact': true,
            'direction': doc.data()['direction'],
          }).toList();

      // Process users
      final userResults = userDocs
          .where((doc) => doc.id != userId) // Exclude current user
          .map((doc) => {
                'uid': doc.id,
                'inAppName': doc.data()['inAppName'],
                'email': doc.data()['email'],
                'isContact': false,
              }).toList();

      // Merge and remove duplicates
      final Map<String, Map<String, dynamic>> mergedMap = {};
      
      for (var contact in contactResults) {
        mergedMap[contact['uid']] = contact;
      }
      
      for (var user in userResults) {
        if (!mergedMap.containsKey(user['uid'])) {
          mergedMap[user['uid']] = user;
        }
      }

      return mergedMap.values.toList();
    } catch (e) {
      debugPrint('Error searching users: $e');
      return [];
    }
  }
}