// widgets/conversation_search_delegate.dart
import 'package:flutter/material.dart';
import 'package:marketplace_logamas/model/chat.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:go_router/go_router.dart';

class ConversationSearchDelegate extends SearchDelegate<Conversation?> {
  final List<Conversation> conversations;

  ConversationSearchDelegate({required this.conversations});

  @override
  String get searchFieldLabel => 'Search conversations...';

  @override
  ThemeData appBarTheme(BuildContext context) {
    return Theme.of(context).copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: Color(0xFF31394E),
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      inputDecorationTheme: InputDecorationTheme(
        hintStyle: TextStyle(color: Colors.white70),
      ),
    );
  }

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      IconButton(
        icon: Icon(Icons.clear, color: Colors.white),
        onPressed: () {
          query = '';
          showSuggestions(context);
        },
      ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: Icon(Icons.arrow_back, color: Colors.white),
      onPressed: () {
        close(context, null);
      },
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults();
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return _buildRecentChats();
    }
    return _buildSearchResults();
  }

  Widget _buildRecentChats() {
    final recentConversations = conversations.take(5).toList();

    return Container(
      color: Colors.grey[100],
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (recentConversations.isNotEmpty) ...[
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Text(
                'Recent Conversations',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF31394E),
                ),
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: recentConversations.length,
                itemBuilder: (context, index) {
                  final conversation = recentConversations[index];
                  return _buildConversationSearchTile(conversation, context);
                },
              ),
            ),
          ] else
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(height: 80),
                  Icon(
                    Icons.chat_bubble_outline,
                    size: 64,
                    color: Colors.grey[400],
                  ),
                  SizedBox(height: 16),
                  Text(
                    'No conversations yet',
                    style: TextStyle(
                      fontSize: 16,
                      color: Colors.grey[600],
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildSearchResults() {
    final filteredConversations = conversations.where((conversation) {
      final storeName = conversation.store?.storeName?.toLowerCase() ?? '';
      final lastMessage = conversation.messages?.isNotEmpty == true
          ? conversation.messages!.first.content.toLowerCase()
          : '';
      final searchQuery = query.toLowerCase();

      return storeName.contains(searchQuery) ||
          lastMessage.contains(searchQuery);
    }).toList();

    if (filteredConversations.isEmpty) {
      return Container(
        color: Colors.grey[100],
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.search_off,
                size: 64,
                color: Colors.grey[400],
              ),
              SizedBox(height: 16),
              Text(
                'No conversations found',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF31394E),
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Try searching with different keywords',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Container(
      color: Colors.grey[100],
      child: ListView.builder(
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        itemCount: filteredConversations.length,
        itemBuilder: (context, index) {
          final conversation = filteredConversations[index];
          return _buildConversationSearchTile(conversation, context);
        },
      ),
    );
  }

  Widget _buildConversationSearchTile(
      Conversation conversation, BuildContext context) {
    final lastMessage = conversation.messages?.isNotEmpty == true
        ? conversation.messages!.first
        : null;

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
      child: ListTile(
        contentPadding: EdgeInsets.all(16),
        leading: Container(
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
                : _buildAvatarFallback(conversation.store?.storeName ?? 'S'),
          ),
        ),
        title: Text(
          conversation.store?.storeName ?? 'Unknown Store',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.bold,
            color: Color(0xFF31394E),
          ),
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: lastMessage != null
            ? Padding(
                padding: EdgeInsets.only(top: 4),
                child: Text(
                  lastMessage.content,
                  style: TextStyle(
                    fontSize: 14,
                    color: Colors.grey[600],
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              )
            : Text(
                'No messages yet',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.grey[500],
                  fontStyle: FontStyle.italic,
                ),
              ),
        trailing: Icon(
          Icons.chevron_right,
          color: Colors.grey[400],
          size: 20,
        ),
        onTap: () {
          close(context, conversation);
          // Navigate to chat
          context.push(
            '/chat/${conversation.storeId}',
            extra: {
              'storeName': conversation.store?.storeName ?? 'Store',
              'storeLogo': conversation.store?.logo,
            },
          );
        },
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
}
