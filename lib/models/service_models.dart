import 'package:flutter/material.dart';

/// ===============================================================
/// SERVICE MODEL (USED EVERYWHERE)
/// ===============================================================
class ServiceModel {
  final int id;
  final String title;
  final String? objectModel;
  final String? price;
  final String? salePrice;
  final String? image;
  final int isFeatured;
  final String? locationName;
  final String? address;
  final String? content;
  final String? reviewScore;
  final int? reviewCount;

  /// ⭐ hotel star_rate from API
  final int? starRate;

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
    this.starRate,
  });

  factory ServiceModel.fromJson(Map<String, dynamic> json) {
    final review = json['review_score'];

    return ServiceModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? '',
      objectModel: json['object_model'],
      price: json['price']?.toString(),
      salePrice: json['sale_price']?.toString(),
      image: json['image'],
      isFeatured: json['is_featured'] is int
          ? json['is_featured']
          : int.tryParse(json['is_featured']?.toString() ?? '0') ?? 0,
      locationName: json['location']?['name'],
      address: json['address'] ?? json['location']?['name'],
      content: json['content'],
      reviewScore:
          review is Map ? review['score_total']?.toString() : null,
      reviewCount:
          review is Map ? review['total_review'] : null,

      /// ⭐ SAFE parse
      starRate: json['star_rate'] is int
          ? json['star_rate']
          : int.tryParse(json['star_rate']?.toString() ?? ''),
    );
  }

  /// ---------------------------------------------------------------
  /// SAFE HELPERS (NO UI CRASH)
  /// ---------------------------------------------------------------
  bool get hasStar =>
      starRate != null && starRate! >= 1 && starRate! <= 5;

  int get safeStar =>
      hasStar ? starRate! : 0;
}

/// ===============================================================
/// SEARCH RESPONSE
/// ===============================================================
class SearchResponse {
  final List<ServiceModel> data;
  final int total;
  final int currentPage;
  final int lastPage;

  SearchResponse({
    required this.data,
    required this.total,
    required this.currentPage,
    required this.lastPage,
  });

  factory SearchResponse.fromJson(Map<String, dynamic> json) {
    final list = json['data'] as List? ?? [];
    return SearchResponse(
      data: list.map((e) => ServiceModel.fromJson(e)).toList(),
      total: json['total'] ?? 0,
      currentPage: json['current_page'] ?? 1,
      lastPage: json['last_page'] ?? 1,
    );
  }
}

/// ===============================================================
/// LOCATION MODEL
/// ===============================================================
class LocationModel {
  final int id;
  final String title;
  final String? image;

  LocationModel({
    required this.id,
    required this.title,
    this.image,
  });

  factory LocationModel.fromJson(Map<String, dynamic> json) {
    return LocationModel(
      id: json['id'] ?? 0,
      title: json['title'] ?? json['name'] ?? '',
      image: json['image'],
    );
  }
}

/// ===============================================================
/// HOME PAGE MODELS
/// ===============================================================
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
      serviceTypes:
          List<String>.from(model['service_types'] ?? []),
    );
  }
}

class OfferItemModel {
  final String title;
  final String desc;
  final String? link;
  final String? thumbImage;

  OfferItemModel({
    required this.title,
    required this.desc,
    this.link,
    this.thumbImage,
  });

  factory OfferItemModel.fromJson(Map<String, dynamic> json) {
    return OfferItemModel(
      title: json['title'] ?? '',
      desc: json['desc'] ?? '',
      link: json['link'],
      thumbImage: json['thumb_image'] ?? json['image'],
    );
  }
}

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

    final raw = json['data'];

    if (raw is Map<String, dynamic>) {
      raw.forEach((_, value) {
        if (value is Map<String, dynamic>) {
          final type = value['type'];
          final model = value['model'];

          if (type == 'form_search_all_service') {
            banner = HomeBannerModel.fromJson(value);
          }

          if (type == 'offer_block' &&
              model is Map &&
              model['list_item'] is List) {
            offers = (model['list_item'] as List)
                .map((e) => OfferItemModel.fromJson(e))
                .toList();
          }

          if (model is Map && model['data'] is List) {
            final items = model['data'] as List;
            switch (type) {
              case 'list_hotel':
                hotels =
                    items.map((e) => ServiceModel.fromJson(e)).toList();
                break;
              case 'list_tour':
              case 'list_tours':
                tours =
                    items.map((e) => ServiceModel.fromJson(e)).toList();
                break;
              case 'list_car':
              case 'list_cars':
                cars =
                    items.map((e) => ServiceModel.fromJson(e)).toList();
                break;
              case 'list_space':
              case 'list_spaces':
                spaces =
                    items.map((e) => ServiceModel.fromJson(e)).toList();
                break;
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
