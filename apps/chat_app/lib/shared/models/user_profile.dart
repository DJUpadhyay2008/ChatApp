class UserProfile {
  final String id;
  final String displayName;
  final bool isApproved;
  final bool isAdmin;
  final String? email;

  const UserProfile({
    required this.id,
    required this.displayName,
    required this.isApproved,
    required this.isAdmin,
    this.email,
  });

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      id: json['user_id'] ?? json['id'] ?? '',
      displayName: json['display_name'] ?? 'Member',
      isApproved: json['is_approved'] ?? false,
      isAdmin: json['is_admin'] ?? false,
      email: json['email'],
    );
  }
}
