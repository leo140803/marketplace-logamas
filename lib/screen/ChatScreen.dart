// screens/chat_screen.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:marketplace_logamas/services/chat_service.dart';
import 'package:marketplace_logamas/model/chat.dart';
import 'package:marketplace_logamas/function/Utils.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:async';

class ChatScreen extends StatefulWidget {
  final String storeId;
  final String storeName;
  final String? storeLogo;

  const ChatScreen({
    Key? key,
    required this.storeId,
    required this.storeName,
    this.storeLogo,
  }) : super(key: key);

  @override
  _ChatScreenState createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final ChatService _chatService = ChatService();
  final TextEditingController _messageController = TextEditingController();
  final ScrollController _scrollController = ScrollController();
  StreamSubscription? _conversationUpdateSubscription;

  List<Message> messages = [];
  bool isLoading = true;
  bool isSending = false;
  String? currentUserId;
  StreamSubscription? _messageSubscription;

  @override
  void initState() {
    super.initState();
    _initializeChat();
  }

  void _initializeChat() async {
    try {
      // Get current user ID
      SharedPreferences prefs = await SharedPreferences.getInstance();
      currentUserId = prefs.getString('user_id');

      if (currentUserId == null) {
        // Handle not logged in
        GoRouter.of(context).pop();
        return;
      }

      // Initialize chat service
      _chatService.initialize(
        userId: currentUserId!,
        userType: 'user',
      );

      // Join chat room
      _chatService.joinChat(currentUserId!, widget.storeId);

      _conversationUpdateSubscription =
          _chatService.conversationUpdateStream.listen((message) {
        if (message is Message) {
          if (mounted) {
            setState(() {
              messages.add(message);
            });
            _scrollToBottom();
          }
        } else {
          // Jika yang dikirim bukan Message, bisa reload seluruh pesan atau ignore
          _reloadMessages();
        }
      });

      // Listen for new messages
      _messageSubscription = _chatService.messageStream.listen((message) {
        if (mounted) {
          setState(() {
            messages.add(message);
          });
          _scrollToBottom();
        }
      });

      // Load existing messages
      await _loadMessages();
    } catch (e) {
      print('Error initializing chat: $e');
      setState(() {
        isLoading = false;
      });
    }
  }

  void _reloadMessages() async {
    final loadedMessages =
        await _chatService.getMessages(currentUserId!, widget.storeId);
    if (mounted) {
      setState(() {
        messages = loadedMessages;
      });
      _scrollToBottom();
    }
  }

  Future<void> _loadMessages() async {
    try {
      final loadedMessages =
          await _chatService.getMessages(currentUserId!, widget.storeId);

      if (mounted) {
        setState(() {
          messages = loadedMessages;
          isLoading = false;
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error loading messages: $e');
      if (mounted) {
        setState(() {
          isLoading = false;
        });
      }
    }
  }

  void _sendMessage() async {
    if (_messageController.text.trim().isEmpty || isSending) return;

    final messageText = _messageController.text.trim();
    _messageController.clear();

    setState(() {
      isSending = true;
    });

    try {
      final message = await _chatService.sendMessage(
        userId: currentUserId!,
        storeId: widget.storeId,
        senderId: currentUserId!,
        senderType: 'user',
        content: messageText,
      );

      if (message != null && mounted) {
        setState(() {
          messages.add(message);
        });
        _scrollToBottom();
      }
    } catch (e) {
      print('Error sending message: $e');
      // Show error message to user
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to send message'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          isSending = false;
        });
      }
    }
  }

  void _scrollToBottom() {
    Future.delayed(Duration(milliseconds: 100), () {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  String _formatMessageTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inDays > 0) {
      return '${dateTime.day}/${dateTime.month}/${dateTime.year}';
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
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        backgroundColor: Color(0xFF31394E),
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => GoRouter.of(context).pop(),
        ),
        title: Row(
          children: [
            // Store logo
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
              ),
              child: ClipOval(
                child: widget.storeLogo != null
                    ? Image.network(
                        '$apiBaseUrlImage${widget.storeLogo}',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: Color(0xFFC58189),
                            ),
                            child: Text(
                              widget.storeName.substring(0, 1).toUpperCase(),
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          );
                        },
                      )
                    : Container(
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Color(0xFFC58189),
                        ),
                        child: Text(
                          widget.storeName.substring(0, 1).toUpperCase(),
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
              ),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    widget.storeName,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                  Text(
                    'Chat with store',
                    style: TextStyle(
                      fontSize: 12,
                      color: Colors.white70,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Messages list
          Expanded(
            child: isLoading
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(
                          color: Color(0xFFC58189),
                        ),
                        SizedBox(height: 16),
                        Text(
                          'Loading messages...',
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  )
                : messages.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Container(
                              padding: EdgeInsets.all(20),
                              decoration: BoxDecoration(
                                color: Colors.grey[200],
                                shape: BoxShape.circle,
                              ),
                              child: Icon(
                                Icons.chat_bubble_outline,
                                size: 48,
                                color: Colors.grey[400],
                              ),
                            ),
                            SizedBox(height: 16),
                            Text(
                              'No messages yet',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: Colors.grey[600],
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Start a conversation with ${widget.storeName}',
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[500],
                              ),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scrollController,
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        itemCount: messages.length,
                        itemBuilder: (context, index) {
                          final message = messages[index];
                          final isMyMessage = message.senderId == currentUserId;

                          return _buildMessageBubble(message, isMyMessage);
                        },
                      ),
          ),

          // Message input
          Container(
            padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 5,
                  offset: Offset(0, -2),
                ),
              ],
            ),
            child: SafeArea(
              child: Row(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.grey[100],
                        borderRadius: BorderRadius.circular(25),
                        border: Border.all(color: Colors.grey[300]!),
                      ),
                      child: TextField(
                        controller: _messageController,
                        decoration: InputDecoration(
                          hintText: 'Type a message...',
                          hintStyle: TextStyle(color: Colors.grey[500]),
                          border: InputBorder.none,
                          contentPadding: EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 12,
                          ),
                        ),
                        maxLines: null,
                        onSubmitted: (_) => _sendMessage(),
                      ),
                    ),
                  ),
                  SizedBox(width: 8),
                  Container(
                    decoration: BoxDecoration(
                      color: Color(0xFFC58189),
                      shape: BoxShape.circle,
                    ),
                    child: IconButton(
                      icon: isSending
                          ? SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 20,
                            ),
                      onPressed: isSending ? null : _sendMessage,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMessageBubble(Message message, bool isMyMessage) {
    return Align(
      alignment: isMyMessage ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: EdgeInsets.symmetric(vertical: 4),
        padding: EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.75,
        ),
        decoration: BoxDecoration(
          color: isMyMessage ? Color(0xFFC58189) : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(18),
            topRight: Radius.circular(18),
            bottomLeft: isMyMessage ? Radius.circular(18) : Radius.circular(4),
            bottomRight: isMyMessage ? Radius.circular(4) : Radius.circular(18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 5,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message.content,
              style: TextStyle(
                fontSize: 14,
                color: isMyMessage ? Colors.white : Colors.black87,
                height: 1.3,
              ),
            ),
            SizedBox(height: 4),
            Text(
              _formatMessageTime(message.createdAt),
              style: TextStyle(
                fontSize: 10,
                color: isMyMessage ? Colors.white70 : Colors.grey[500],
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    _messageSubscription?.cancel();
    _conversationUpdateSubscription?.cancel();
    _chatService.leaveChat(currentUserId ?? '', widget.storeId);
    _messageController.dispose();
    _scrollController.dispose();
    super.dispose();
  }
}
