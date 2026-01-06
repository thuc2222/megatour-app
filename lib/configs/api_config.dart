// lib/config/api_config.dart

class ApiConfig {
  // Base URL
  static const String baseUrl = 'https://megatour.vn/api/';
  
  // API Endpoints
  static const String configs = 'configs';
  static const String countries = 'configs/countries';
  
  // Auth
  static const String login = 'auth/login';
  static const String register = 'auth/register';
  static const String logout = 'auth/logout';
  static const String me = 'auth/me';
  static const String updateProfile = 'auth/me';
  static const String changePassword = 'auth/change-password';
  static const String refreshToken = 'auth/refresh';
  
  // Search
  static const String hotelSearch = 'hotel/search';
  static const String tourSearch = 'tour/search';
  static const String spaceSearch = 'space/search';
  static const String carSearch = 'car/search';
  static const String eventSearch = 'event/search';
  static const String boatSearch = 'boat/search';
  static const String flightSearch = 'flight/search';
  static const String servicesSearch = 'services';
  
  // Filters
  static const String hotelFilters = 'hotel/filters';
  static const String tourFilters = 'tour/filters';
  static const String spaceFilters = 'space/filters';
  static const String carFilters = 'car/filters';
  static const String eventFilters = 'event/filters';
  static const String boatFilters = 'boat/filters';
  static const String flightFilters = 'flight/filters';
  
  // Form Search
  static const String hotelFormSearch = 'hotel/form-search';
  static const String tourFormSearch = 'tour/form-search';
  static const String spaceFormSearch = 'space/form-search';
  static const String carFormSearch = 'car/form-search';
  static const String eventFormSearch = 'event/form-search';
  static const String boatFormSearch = 'boat/form-search';
  static const String flightFormSearch = 'flight/form-search';
  
  // Detail
  static String hotelDetail(int id) => 'hotel/detail/$id';
  static String tourDetail(int id) => 'tour/detail/$id';
  static String spaceDetail(int id) => 'space/detail/$id';
  static String carDetail(int id) => 'car/detail/$id';
  static String eventDetail(int id) => 'event/detail/$id';
  static String boatDetail(int id) => 'boat/detail/$id';
  static String flightDetail(int id) => 'flight/detail/$id';
  
  // Availability
  static String tourAvailability(int id) => 'tour/availability/$id';
  static String spaceAvailability(int id) => 'space/availability/$id';
  static String carAvailability(int id) => 'car/availability/$id';
  static String eventAvailability(int id) => 'event/availability/$id';
  static String hotelAvailability(int id) => 'hotel/availability/$id';
  static String boatAvailability(int id) => 'boat/availability-booking/$id';
  
  // Review
  static String writeReview(String serviceType, int id) => 
      '$serviceType/write-review/$id';
  
  // Location
  static const String locations = 'locations';
  static String locationDetail(int id) => 'location/$id';
  
  // User
  static const String bookingHistory = 'user/booking-history';
  static const String wishlist = 'user/wishlist';
  static String wishlistAdd(String type, int id) => 'user/wishlist/$type/$id';
  static String wishlistRemove(String type, int id) => 'user/wishlist/$type/$id';
  static const String wishlistRemoveAll = 'user/wishlist';
  static const String myTickets = 'user/ticket';
  
  // Booking
  static const String addToCart = 'booking/addToCart';
  static String bookingCheckout(String code) => 'booking/$code/checkout';
  static String bookingSuccess(String code) => 'booking/$code';
  static const String doCheckout = 'booking/doCheckout';
  static const String gateways = 'gateways';
  
  // Tickets
  static String scanTicket(int bookingId, int ticketId, String hashedCode) => 
      'user/booking/ticket/scan/$bookingId/$ticketId?code=$hashedCode';
  static const String scanHistory = 'user/booking/ticket';
  
  // Media
  static const String uploadImage = 'media/store';
  
  // News
  static const String news = 'news';
  static String newsDetail(int id) => 'news/$id';
  static const String newsCategory = 'news/category';
  
  // Home
  static const String homePage = 'home-page';
  
  // Social Login
  static String socialLogin(String provider) => 
      'social-login/$provider?for_api=1';
  
  // Request timeout
  static const int connectTimeout = 30000;
  static const int receiveTimeout = 30000;
  
  // Headers
  static Map<String, String> getHeaders({String? token}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
}