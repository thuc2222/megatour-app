import 'package:flutter/material.dart';

// --- Model cho từng Item dịch vụ (Hotel, Tour, Car, Space) ---
class ServiceModel {
  final int id;
  final String title;
  final String? objectModel;
  final String? price;
  final String? salePrice;
  final String? image;
  final int isFeatured;
  final String? locationName;
  final String? address;  // Sửa lỗi: Thiếu address
  final String? content;  // Sửa lỗi: Thiếu content
  final String? reviewScore; 
  final int? reviewCount;

  ServiceModel({
    required this.id,
    required this.title,
    this.objectModel,
    this.price,
    this.salePrice,
    this.image,
    required this.isFeatured,
    this.locationName,
    this.address,
    this.content,
    this.reviewScore,
    this.reviewCount,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    return ServiceModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'No Title',
      objectModel: json['object_model'],
      price: json['price']?.toString(),
      salePrice: json['sale_price']?.toString(),
      image: json['image'],
      isFeatured: json['is_featured'] is int 
          ? json['is_featured'] 
          : (int.tryParse(json['is_featured']?.toString() ?? '0') ?? 0),
      locationName: json['location']?['name'],
      // Nếu address null thì lấy tạm location name để không bị trống giao diện
      address: json['address'] ?? json['location']?['name'], 
      content: json['content'],
      reviewScore: json['review_score']?['score_total']?.toString(),
      reviewCount: json['review_score']?['total_review'],
    );
  }
}

// --- Model cho phản hồi tìm kiếm và phân trang ---
class SearchResponse {
  final List<ServiceModel> data;
  final int total;
  final int currentPage; // Sửa lỗi: Thiếu currentPage cho SearchProvider
  final int lastPage;    // Sửa lỗi: Thiếu lastPage cho SearchProvider

  SearchResponse({
    required this.data, 
    required this.total,
    required this.currentPage,
    required this.lastPage,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    var list = json['data'] as List? ?? [];
    return SearchResponse(
      data: list.map((i) => ServiceModel.fromJson(i)).toList(),
      total: json['total'] ?? 0,
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
    );
  }
}

// --- Model cho địa điểm ---
class LocationModel {
  final int id;
  final String title;
  final String? image;

  LocationModel({required this.id, required this.title, this.image});

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['name'] ?? '',
      image: json['image'],
    );
  }
}

// Model cho phần Banner và Search Form
class HomeBannerModel {
  final String title;
  final String subTitle;
  final String bgImageUrl;
  final List<String> serviceTypes;

  HomeBannerModel({
    required this.title,
    required this.subTitle,
    required this.bgImageUrl,
    required this.serviceTypes,
  });

  factory HomeBannerModel.fromJson(Map<String, dynamic> json) {
    final model = json['model'] ?? {};
    return HomeBannerModel(
      title: model['title'] ?? '',
      subTitle: model['sub_title'] ?? '',
      bgImageUrl: model['bg_image_url'] ?? '',
      serviceTypes: List<String>.from(model['service_types'] ?? []),
    );
  }
}

// Model for individual offer items
class OfferItemModel {
  final String title;
  final String desc;
  final String? link;
  final String? thumbImage; // Changed from 'icon' to 'thumbImage'

  OfferItemModel({
    required this.title, 
    required this.desc, 
    this.link, 
    this.thumbImage, // Matches the field name above
  });

  factory OfferItemModel.fromJson(Map<String, dynamic> json) {
    return OfferItemModel(
      title: json['title'] ?? '',
      desc: json['desc'] ?? '',
      link: json['link'],
      thumbImage: json['thumb_image'] ?? json['image'], // Try thumb_image first, then fallback to image
    );
  }
}
// --- Model bóc tách dữ liệu Trang Chủ từ API ---
class HomePageData {
  final HomeBannerModel? banner;
  final List<OfferItemModel> offers;
  final List<ServiceModel> featuredHotels;
  final List<ServiceModel> featuredTours;
  final List<ServiceModel> featuredCars;
  final List<ServiceModel> featuredSpaces;

  HomePageData({
    this.banner,
    required this.offers,
    required this.featuredHotels,
    required this.featuredTours,
    required this.featuredCars,
    required this.featuredSpaces,
  });

  factory HomePageData.fromJson(Map<String, dynamic> json) {
    HomeBannerModel? banner;
    List<OfferItemModel> offers = [];
    List<ServiceModel> hotels = [];
    List<ServiceModel> tours = [];
    List<ServiceModel> cars = [];
    List<ServiceModel> spaces = [];

    final dynamic rawData = json['data'];

    if (rawData is Map<String, dynamic>) {
      // Iterate through all keys in the Map (ROOT, 6954dd..., etc.)
      rawData.forEach((key, value) {
        if (value is Map<String, dynamic>) {
          final String? type = value['type'];
          final dynamic model = value['model'];

          // 1. Capture the Banner/Search Form
          if (type == 'form_search_all_service') {
            banner = HomeBannerModel.fromJson(value);
          }

          // 2. Parse Offer Block
          if (type == 'offer_block' && model is Map<String, dynamic>) {
            if (model['list_item'] is List) {
              List<dynamic> items = model['list_item'];
              offers = items.map((item) => OfferItemModel.fromJson(item)).toList();
            }
          }

          // 3. Capture Service Lists
          if (model is Map<String, dynamic> && model['data'] is List) {
            List<dynamic> items = model['data'];
            try {
              switch (type) {
                case 'list_hotel':
                  hotels = items.map((item) => ServiceModel.fromJson(item)).toList();
                  break;
                case 'list_tour': // Note: API might use singular or plural
                case 'list_tours':
                  tours = items.map((item) => ServiceModel.fromJson(item)).toList();
                  break;
                case 'list_car':
                case 'list_cars':
                  cars = items.map((item) => ServiceModel.fromJson(item)).toList();
                  break;
                case 'list_space':
                case 'list_spaces':
                  spaces = items.map((item) => ServiceModel.fromJson(item)).toList();
                  break;
              }
            } catch (e) {
              debugPrint("Error parsing block $type: $e");
            }
          }
        }
      });
    }
    

    return HomePageData(
      banner: banner,
      offers: offers,
      featuredHotels: hotels,
      featuredTours: tours,
      featuredCars: cars,
      featuredSpaces: spaces,
    );
  }
}
