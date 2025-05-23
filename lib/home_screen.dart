import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:secret_notes/compo/chat_page.dart';

import '../services/contact_service.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final TextEditingController _searchController = TextEditingController();
  final _auth = FirebaseAuth.instance;
  final _firestore = FirebaseFirestore.instance;
  final ContactService _contactService = ContactService();
  String _currentUserName = '';
  List<Map<String, dynamic>> recentContacts = [];
  bool _isLoading = true;
  Timer? _debounceTimer;

  @override
  void initState() {
    super.initState();
    _loadUserData();
    _loadRecentContacts();
    _searchController.addListener(_onSearchChanged);
  }

  Future<void> _loadUserData() async {
    final user = _auth.currentUser;
    if (user != null) {
      final userData = await _firestore.collection('users').doc(user.uid).get();
      if (userData.exists) {
        setState(() {
          _currentUserName = userData.data()?['inAppName'] ?? '';
        });
      }
    }
  }

  Future<void> _loadRecentContacts() async {
    setState(() => _isLoading = true);
    try {
      final user = _auth.currentUser;
      if (user != null) {
        final contacts = await _contactService.getRecentContacts(user.uid);
        setState(() {
          recentContacts = contacts;
        });
      }
    } catch (e) {
      debugPrint('Error loading contacts: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _onSearchChanged() {
    if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 500), () {
      searchUser(_searchController.text);
    });
  }

  // Update the searchUser method
  Future<void> searchUser(String query) async {

    try {
      final currentUser = _auth.currentUser;
      if (currentUser == null) {
        return;
      }

      if (query.isEmpty) {
        await _loadRecentContacts();
        return;
      }

      final results = await _contactService.searchUsers(currentUser.uid, query);
      
      if (mounted) {
        setState(() {
          recentContacts = results;
        });
      }
    } catch (e) {
      debugPrint('Error searching users: $e');
    }
  }

  void openChat(String uid, String username) {
    final currentUser = _auth.currentUser;
    if (currentUser != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ChatPage(
            currentUser: currentUser.uid,
            otherUser: uid,
          ),
        ),
      );
    }
  }

  Future<void> _signOut() async {
    try {
      await _auth.signOut();
      if (mounted) {
        Navigator.of(context).pushReplacementNamed('/login');
      }
    } catch (e) {
      debugPrint('Error signing out: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              Colors.white,
              Theme.of(context).primaryColor.withOpacity(0.05),
              Colors.white,
            ],
          ),
        ),
        child: Stack(
          children: [
            // Decorative Elements
            Positioned(
              top: -50,
              right: -30,
              child: Container(
                width: 150,
                height: 150,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.2),
                      Theme.of(context).primaryColor.withOpacity(0.1),
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -60,
              left: -40,
              child: Container(
                width: 180,
                height: 180,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    colors: [
                      Theme.of(context).primaryColor.withOpacity(0.1),
                      Theme.of(context).primaryColor.withOpacity(0.05),
                    ],
                  ),
                ),
              ),
            ),
            // Main Content
            SafeArea(
              child: Column(
                children: [
                  // Compact Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Welcome back,',
                              style: TextStyle(
                                color: Colors.grey[600],
                                fontSize: 14,
                              ),
                            ),
                            Text(
                              _currentUserName.isEmpty ? 'Loading...' : _currentUserName,
                              style: const TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                        CircleAvatar(
                          backgroundColor: Theme.of(context).primaryColor,
                          child: IconButton(
                            icon: const Icon(Icons.logout, color: Colors.white),
                            onPressed: _signOut,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Enhanced Search Bar
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(15),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.grey.withOpacity(0.1),
                            blurRadius: 10,
                            offset: const Offset(0, 5),
                          ),
                        ],
                      ),
                      child: TextField(
                        controller: _searchController,
                        decoration: InputDecoration(
                          hintText: 'Search users...',
                          hintStyle: TextStyle(color: Colors.grey[400]),
                          prefixIcon: Icon(Icons.search, color: Theme.of(context).primaryColor),
                          suffixIcon: _searchController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear),
                                onPressed: () {
                                  _searchController.clear();
                                  _loadRecentContacts();
                                },
                              )
                            : null,
                          border: InputBorder.none,
                          contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                        ),
                        onChanged: (value) {
                          if (_debounceTimer?.isActive ?? false) _debounceTimer!.cancel();
                          _debounceTimer = Timer(const Duration(milliseconds: 500), () {
                            searchUser(value);
                          });
                        },
                      ),
                    ),
                  ),

                  // Contacts List Header
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          'Recent Contacts',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.grey[800],
                          ),
                        ),
                        Text(
                          '${recentContacts.length} users',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Enhanced Contacts List
                  Expanded(
                    child: _isLoading
                        ? Center(
                            child: CircularProgressIndicator(
                              color: Theme.of(context).primaryColor,
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 20),
                            itemCount: recentContacts.length,
                            itemBuilder: (context, index) {
                              final user = recentContacts[index];
                              final bool isContact = user['isContact'] ?? false;

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 0,
                                color: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: ListTile(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 15,
                                    vertical: 8,
                                  ),
                                  leading: CircleAvatar(
                                    radius: 25,
                                    backgroundColor: isContact
                                        ? Theme.of(context).primaryColor.withOpacity(0.1)
                                        : Colors.grey.withOpacity(0.1),
                                    child: Text(
                                      user['inAppName'][0].toUpperCase(),
                                      style: TextStyle(
                                        color: isContact
                                            ? Theme.of(context).primaryColor
                                            : Colors.grey[600],
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                  title: Text(
                                    user['inAppName'],
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 16,
                                    ),
                                  ),
                                  subtitle: Text(
                                    user['email'],
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 13,
                                    ),
                                  ),
                                  trailing: ElevatedButton(
                                    onPressed: () => openChat(
                                      user['uid'],
                                      user['inAppName'],
                                    ),
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isContact
                                          ? Theme.of(context).primaryColor
                                          : Colors.grey[200],
                                      elevation: 0,
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 15,
                                        vertical: 8,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                    ),
                                    child: Text(
                                      isContact ? 'Message' : 'Chat',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: isContact ? Colors.white : Colors.grey[800],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
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

  void dispose() {
    _searchController.removeListener(_onSearchChanged);
    _debounceTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }
}
