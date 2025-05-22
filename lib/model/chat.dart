// models/chat_models.dart
class Conversation {
  final String id;
  final String userId;
  final String storeId;
  final DateTime createdAt;
  final DateTime updatedAt;
  final User? user;
  final Store? store;
  final List<Message>? messages;

  Conversation({
    required this.id,
    required this.userId,
    required this.storeId,
    required this.createdAt,
    required this.updatedAt,
    this.user,
    this.store,
    this.messages,
  });

  factory Conversation.fromJson(Map<String, dynamic> json) {
    try {
      final conversationId = json['id']?.toString() ?? '';
      final userId = json['user_id']?.toString() ?? '';

      return Conversation(
        id: conversationId,
        userId: userId,
        storeId: json['store_id']?.toString() ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'].toString())
            : DateTime.now(),
        updatedAt: json['updated_at'] != null
            ? DateTime.parse(json['updated_at'].toString())
            : DateTime.now(),
        user: json['user'] != null ? User.fromJson(json['user']) : null,
        store: json['store'] != null ? Store.fromJson(json['store']) : null,
        messages: json['messages'] != null
            ? (json['messages'] as List)
                .map((m) => Message.fromJson(
                      m,
                      fallbackConversationId: conversationId,
                      fallbackSenderId:
                          userId, // Assuming messages in conversation list are from user
                    ))
                .toList()
            : null,
      );
    } catch (e) {
      print('Error parsing Conversation: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
}

class Message {
  final String id;
  final String conversationId;
  final String senderId;
  final String senderType;
  final String content;
  final DateTime createdAt;

  Message({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderType,
    required this.content,
    required this.createdAt,
  });

  factory Message.fromJson(Map<String, dynamic> json,
      {String? fallbackConversationId, String? fallbackSenderId}) {
    try {
      return Message(
        id: json['id']?.toString() ?? '',
        conversationId:
            json['conversation_id']?.toString() ?? fallbackConversationId ?? '',
        senderId: json['sender_id']?.toString() ?? fallbackSenderId ?? '',
        senderType: json['sender_type']?.toString() ?? 'user',
        content: json['content']?.toString() ?? '',
        createdAt: json['created_at'] != null
            ? DateTime.parse(json['created_at'].toString())
            : DateTime.now(),
      );
    } catch (e) {
      print('Error parsing Message: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
}

class User {
  final String id;
  final String name;
  final String email;

  User({required this.id, required this.name, required this.email});

  factory User.fromJson(Map<String, dynamic> json) {
    try {
      return User(
        id: json['id']?.toString() ?? '',
        name: json['name']?.toString() ?? 'Unknown User',
        email: json['email']?.toString() ?? '',
      );
    } catch (e) {
      print('Error parsing User: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
}

class Store {
  final String storeId;
  final String storeName;
  final String? imageUrl;
  final String? logo;

  Store({
    required this.storeId,
    required this.storeName,
    this.imageUrl,
    this.logo,
  });

  factory Store.fromJson(Map<String, dynamic> json) {
    try {
      return Store(
        storeId: json['store_id']?.toString() ?? '',
        storeName: json['store_name']?.toString() ?? 'Unknown Store',
        imageUrl: json['image_url']?.toString(),
        logo: json['logo']?.toString(),
      );
    } catch (e) {
      print('Error parsing Store: $e');
      print('JSON data: $json');
      rethrow;
    }
  }
}
