// lib/config/api_config.dart

class ApiConfig {
  // Base URL
  static String baseUrl = 'https://megatour.vn/api/';
  static String currentLanguage = 'en';
  // API Endpoints
  static String configs = 'configs';
  static String countries = 'configs/countries';
  
  // Auth
  static String login = 'auth/login';
  static String register = 'auth/register';
  static String logout = 'auth/logout';
  static String me = 'auth/me';
  static String updateProfile = 'auth/me';
  static String changePassword = 'auth/change-password';
  static String refreshToken = 'auth/refresh';
  
  // Search
  static String hotelSearch = 'hotel/search';
  static String tourSearch = 'tour/search';
  static String spaceSearch = 'space/search';
  static String carSearch = 'car/search';
  static String eventSearch = 'event/search';
  static String boatSearch = 'boat/search';
  static String flightSearch = 'flight/search';
  static String servicesSearch = 'services';
  
  // Filters
  static String hotelFilters = 'hotel/filters';
  static String tourFilters = 'tour/filters';
  static String spaceFilters = 'space/filters';
  static String carFilters = 'car/filters';
  static String eventFilters = 'event/filters';
  static String boatFilters = 'boat/filters';
  static String flightFilters = 'flight/filters';
  
  // Form Search
  static String hotelFormSearch = 'hotel/form-search';
  static String tourFormSearch = 'tour/form-search';
  static String spaceFormSearch = 'space/form-search';
  static String carFormSearch = 'car/form-search';
  static String eventFormSearch = 'event/form-search';
  static String boatFormSearch = 'boat/form-search';
  static String flightFormSearch = 'flight/form-search';
  
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
  static String locations = 'locations';
  static String locationDetail(int id) => 'location/$id';
  
  // User
  static String bookingHistory = 'user/booking-history';
  static String wishlist = 'user/wishlist';
  static String wishlistAdd(String type, int id) => 'user/wishlist/$type/$id';
  static String wishlistRemove(String type, int id) => 'user/wishlist/$type/$id';
  static String wishlistRemoveAll = 'user/wishlist';
  static String myTickets = 'user/ticket';
  
  // Booking
  static String addToCart = 'booking/addToCart';
  static String bookingCheckout(String code) => 'booking/$code/checkout';
  static String bookingSuccess(String code) => 'booking/$code';
  static String doCheckout = 'booking/doCheckout';
  static String gateways = 'gateways';
  
  // Tickets
  static String scanTicket(int bookingId, int ticketId, String hashedCode) => 
      'user/booking/ticket/scan/$bookingId/$ticketId?code=$hashedCode';
  static String scanHistory = 'user/booking/ticket';
  
  // Media
  static String uploadImage = 'media/store';
  
  // News
  static String news = 'news';
  static String newsDetail(int id) => 'news/$id';
  static String newsCategory = 'news/category';
  
  // Home
  static String homePage = 'home-page';
  
  // Social Login
  static String socialLogin(String provider) => 
      'social-login/$provider?for_api=1';
  
  // Request timeout
  static int connectTimeout = 30000;
  static int receiveTimeout = 30000;
  
  // Headers
  static Map<String, String> getHeaders({String? token}) {
    final headers = {
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Accept-Language': currentLanguage,
    };
    
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    
    return headers;
  }
}