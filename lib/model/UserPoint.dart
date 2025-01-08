class UserStorePoints {
  final String id;
  final String userId;
  final String storeId;
  final int points;

  UserStorePoints({
    required this.id,
    required this.userId,
    required this.storeId,
    required this.points,
  });

  factory UserStorePoints.fromJson(Map<String, dynamic> json) {
    return UserStorePoints(
      id: json['data']['id'],
      userId: json['data']['user_id'],
      storeId: json['data']['store_id'],
      points: json['data']['points'],
    );
  }
}
