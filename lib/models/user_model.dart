// lib/models/user_model.dart

class UserModel {
  final int? id;
  final String? email;
  final String? firstName;
  final String? lastName;
  final String? phone;
  final String? businessName;
  final String? birthday;
  final String? bio;
  final String? address;
  final String? address2;
  final String? city;
  final String? country;
  final String? zipCode;
  final String? avatarUrl;
  final int? avatarId;
  final String? createdAt;
  final String? updatedAt;

  UserModel({
    this.id,
    this.email,
    this.firstName,
    this.lastName,
    this.phone,
    this.businessName,
    this.birthday,
    this.bio,
    this.address,
    this.address2,
    this.city,
    this.country,
    this.zipCode,
    this.avatarUrl,
    this.avatarId,
    this.createdAt,
    this.updatedAt,
  });

  // Get full name
  String get fullName {
    if (firstName == null && lastName == null) return 'User';
    return '${firstName ?? ''} ${lastName ?? ''}'.trim();
  }

  // From JSON
  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      email: json['email'],
      firstName: json['first_name'],
      lastName: json['last_name'],
      phone: json['phone'],
      businessName: json['business_name'],
      birthday: json['birthday'],
      bio: json['bio'],
      address: json['address'],
      address2: json['address2'],
      city: json['city'],
      country: json['country'],
      zipCode: json['zip_code'],
      avatarUrl: json['avatar_url'],
      avatarId: json['avatar_id'],
      createdAt: json['created_at'],
      updatedAt: json['updated_at'],
    );
  }

  // To JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'first_name': firstName,
      'last_name': lastName,
      'phone': phone,
      'business_name': businessName,
      'birthday': birthday,
      'bio': bio,
      'address': address,
      'address2': address2,
      'city': city,
      'country': country,
      'zip_code': zipCode,
      'avatar_id': avatarId,
    };
  }

  // Copy with
  UserModel copyWith({
    int? id,
    String? email,
    String? firstName,
    String? lastName,
    String? phone,
    String? businessName,
    String? birthday,
    String? bio,
    String? address,
    String? address2,
    String? city,
    String? country,
    String? zipCode,
    String? avatarUrl,
    int? avatarId,
    String? createdAt,
    String? updatedAt,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      firstName: firstName ?? this.firstName,
      lastName: lastName ?? this.lastName,
      phone: phone ?? this.phone,
      businessName: businessName ?? this.businessName,
      birthday: birthday ?? this.birthday,
      bio: bio ?? this.bio,
      address: address ?? this.address,
      address2: address2 ?? this.address2,
      city: city ?? this.city,
      country: country ?? this.country,
      zipCode: zipCode ?? this.zipCode,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      avatarId: avatarId ?? this.avatarId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Auth Response Model
class AuthResponse {
  final bool status;
  final String? accessToken;
  final String? tokenType;
  final int? expiresIn;
  final UserModel? user;
  final String? message;
  final Map<String, dynamic>? errors;

  AuthResponse({
    required this.status,
    this.accessToken,
    this.tokenType,
    this.expiresIn,
    this.user,
    this.message,
    this.errors,
  });

  factory AuthResponse.fromJson(Map<String, dynamic> json) {
    print('Parsing AuthResponse from: $json');
    
    // Handle different status formats
    bool status = false;
    if (json['status'] != null) {
      if (json['status'] is int) {
        status = json['status'] == 1;
      } else if (json['status'] is bool) {
        status = json['status'];
      } else {
        status = json['status'].toString() == '1' || 
                 json['status'].toString().toLowerCase() == 'true';
      }
    }
    
    // Get error message from errors object
    String? errorMessage;
    if (json['errors'] != null && json['errors'] is Map) {
      final errors = json['errors'] as Map;
      if (errors.isNotEmpty) {
        // Get first error message
        final firstError = errors.values.first;
        if (firstError is List && firstError.isNotEmpty) {
          errorMessage = firstError[0].toString();
        } else {
          errorMessage = firstError.toString();
        }
      }
    }
    
    return AuthResponse(
      status: status,
      accessToken: json['access_token']?.toString(),
      tokenType: json['token_type']?.toString(),
      expiresIn: json['expires_in'] is int 
          ? json['expires_in'] 
          : int.tryParse(json['expires_in']?.toString() ?? '0'),
      user: json['user'] != null ? UserModel.fromJson(json['user']) : null,
      message: errorMessage ?? json['message']?.toString(),
      errors: json['errors'],
    );
  }
}