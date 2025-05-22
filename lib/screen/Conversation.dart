// screens/conversation_list_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_logamas/services/chat_service.dart';
import 'package:marketplace_logamas/model/chat.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:marketplace_logamas/widget/BottomNavigationBar.dart';
import 'package:marketplace_logamas/widget/ConversationSearchDelegate.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class ConversationListScreen extends StatefulWidget {
  const ConversationListScreen({Key? key}) : super(key: key);

  @override
  _ConversationListScreenState createState() => _ConversationListScreenState();
}

class _ConversationListScreenState extends State<ConversationListScreen> {
  final ChatService _chatService = ChatService();
  List<Conversation> conversations = [];
  bool isLoading = true;
  bool isRefreshing = false;
  String? currentUserId;
  int _selectedIndex = 3;
  StreamSubscription? _conversationUpdateSubscription;

  @override
  void initState() {
    super.initState();
    _initializeConversations();
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });
    navigate(context, index);
  }

  Future<void> _initializeConversations() async {
    try {
      // Get current user ID
      SharedPreferences prefs = await SharedPreferences.getInstance();
      currentUserId = prefs.getString('user_id');

      if (currentUserId == null) {
        // Handle not logged in
        GoRouter.of(context).go('/login');
        return;
      }

      // Initialize chat service
      _chatService.initialize(
        userId: currentUserId!,
        userType: 'user',
      );

      // Listen for conversation updates
      _conversationUpdateSubscription =
          _chatService.conversationUpdateStream.listen((_) {
        if (mounted) {
          _loadConversations(showLoading: false);
        }
      });

      // Load conversations
      await _loadConversations();
    } catch (e) {
      print('Error initializing conversations: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  Future<void> _loadConversations({bool showLoading = true}) async {
    if (showLoading) {
      setState(() {
        isLoading = true;
      });
    }

    try {
      if (currentUserId != null) {
        final loadedConversations =
            await _chatService.getUserConversations(currentUserId!);

        if (mounted) {
          setState(() {
            conversations = loadedConversations;
            isLoading = false;
            isRefreshing = false;
          });
        }
      }
    } catch (e) {
      print('Error loading conversations: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
          isRefreshing = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load conversations'),
            backgroundColor: Colors.red,
            action: SnackBarAction(
              label: 'Retry',
              textColor: Colors.white,
              onPressed: () => _loadConversations(),
            ),
          ),
        );
      }
    }
  }

  Future<void> _refreshConversations() async {
    setState(() {
      isRefreshing = true;
    });
    await _loadConversations(showLoading: false);
  }

  void _openSearch() {
    // Implement search functionality here
    showSearch(
      context: context,
      delegate: ConversationSearchDelegate(conversations: conversations),
    );
  }

  void _navigateToChat(Conversation conversation) {
    context.push(
      '/chat/${conversation.storeId}',
      extra: {
        'storeName': conversation.store?.storeName ?? 'Store',
        'storeLogo': conversation.store?.logo,
      },
    );
  }

  String _formatLastMessageTime(DateTime? dateTime) {
    if (dateTime == null) return '';

    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      if (difference.inDays == 1) {
        return 'Yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
      }
    } else if (difference.inHours > 0) {
      return '${difference.inHours}h ago';
    } else if (difference.inMinutes > 0) {
      return '${difference.inMinutes}m ago';
    } else {
      return 'Just now';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: Color(0xFF31394E),
        elevation: 0,
        title: Text(
          'Messages',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(Icons.refresh, color: Colors.white),
            onPressed: _refreshConversations,
          ),
        ],
      ),
      body: isLoading
          ? _buildLoadingState()
          : conversations.isEmpty
              ? _buildEmptyState()
              : RefreshIndicator(
                  color: Color(0xFFC58189),
                  backgroundColor: Colors.white,
                  onRefresh: _refreshConversations,
                  child: ListView.builder(
                    physics: AlwaysScrollableScrollPhysics(),
                    padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    itemCount: conversations.length,
                    itemBuilder: (context, index) {
                      final conversation = conversations[index];
                      return _buildConversationTile(conversation);
                    },
                  ),
                ),
      bottomNavigationBar: BottomNavBar(
        selectedIndex: _selectedIndex,
        onItemTapped: _onItemTapped,
      ),
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Color(0xFFFBE9E7),
              shape: BoxShape.circle,
            ),
            child: SizedBox(
              width: 40,
              height: 40,
              child: CircularProgressIndicator(
                valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC58189)),
                strokeWidth: 3,
              ),
            ),
          ),
          SizedBox(height: 24),
          Text(
            'Loading conversations...',
            style: TextStyle(
              fontSize: 18,
              color: Color(0xFF31394E),
              fontWeight: FontWeight.w600,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Please wait while we fetch your messages',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            padding: EdgeInsets.all(32),
            decoration: BoxDecoration(
              color: Color(0xFFFBE9E7),
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 80,
              color: Color(0xFFC58189),
            ),
          ),
          SizedBox(height: 32),
          Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Color(0xFF31394E),
            ),
          ),
          SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 40),
            child: Text(
              'Start chatting with stores to see your conversations here. Find amazing products and get instant support!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.5,
              ),
            ),
          ),
          SizedBox(height: 40),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFFE8C4BD), Color(0xFFC58189)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(12),
              boxShadow: [
                BoxShadow(
                  color: Color(0xFFC58189).withOpacity(0.3),
                  blurRadius: 8,
                  offset: Offset(0, 4),
                ),
              ],
            ),
            child: ElevatedButton.icon(
              onPressed: () {
                GoRouter.of(context).go('/');
              },
              icon: Icon(Icons.explore, size: 20, color: Colors.white),
              label: Text(
                'Explore Stores',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.transparent,
                shadowColor: Colors.transparent,
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildConversationTile(Conversation conversation) {
    final lastMessage = conversation.messages?.isNotEmpty == true
        ? conversation.messages!.first
        : null;

    final isFromStore = lastMessage?.senderType == 'store';
    final hasUnreadMessages = false; // You can implement unread logic later

    return Container(
      margin: EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 5,
            offset: Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _navigateToChat(conversation),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Row(
              children: [
                // Store logo/avatar
                Container(
                  width: 50,
                  height: 50,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Colors.white,
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.1),
                        blurRadius: 4,
                        offset: Offset(0, 2),
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: conversation.store?.logo != null
                        ? Image.network(
                            '$apiBaseUrlImage${conversation.store!.logo}',
                            fit: BoxFit.cover,
                            width: 50,
                            height: 50,
                            errorBuilder: (context, error, stackTrace) {
                              return _buildAvatarFallback(
                                  conversation.store?.storeName ?? 'S');
                            },
                          )
                        : _buildAvatarFallback(
                            conversation.store?.storeName ?? 'S'),
                  ),
                ),

                SizedBox(width: 16),

                // Conversation details
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Store name and time
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              conversation.store?.storeName ?? 'Unknown Store',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF31394E),
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (lastMessage != null)
                            Text(
                              _formatLastMessageTime(lastMessage.createdAt),
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[500],
                              ),
                            ),
                        ],
                      ),

                      SizedBox(height: 6),

                      // Last message preview
                      Row(
                        children: [
                          if (lastMessage != null) ...[
                            if (!isFromStore)
                              Container(
                                margin: EdgeInsets.only(right: 4),
                                child: Icon(
                                  Icons.reply,
                                  size: 14,
                                  color: Colors.grey[500],
                                ),
                              ),
                            Expanded(
                              child: Text(
                                lastMessage.content,
                                style: TextStyle(
                                  fontSize: 14,
                                  color: hasUnreadMessages
                                      ? Color(0xFF31394E)
                                      : Colors.grey[600],
                                  fontWeight: hasUnreadMessages
                                      ? FontWeight.w600
                                      : FontWeight.normal,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ] else
                            Expanded(
                              child: Text(
                                'No messages yet',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: Colors.grey[500],
                                  fontStyle: FontStyle.italic,
                                ),
                              ),
                            ),

                          // Unread indicator (placeholder for future implementation)
                          if (hasUnreadMessages)
                            Container(
                              margin: EdgeInsets.only(left: 8),
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: Color(0xFFC58189),
                                shape: BoxShape.circle,
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),

                // Arrow indicator
                Icon(
                  Icons.chevron_right,
                  color: Colors.grey[400],
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarFallback(String storeName) {
    return Container(
      width: 50,
      height: 50,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: Color(0xFFC58189),
        shape: BoxShape.circle,
      ),
      child: Text(
        storeName.isNotEmpty ? storeName.substring(0, 1).toUpperCase() : 'S',
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.bold,
          color: Colors.white,
        ),
      ),
    );
  }

  @override
  void dispose() {
    _conversationUpdateSubscription?.cancel();
    super.dispose();
  }
}
