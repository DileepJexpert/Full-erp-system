class AppConstants {
  AppConstants._();

  static const String appName = 'Business Manager';
  static const String apiBaseUrl = 'http://localhost:3000/api/v1';
  static const Duration apiTimeout = Duration(seconds: 30);
  static const Duration syncInterval = Duration(seconds: 30);
  static const int maxSyncRetries = 5;
  static const int gpsMaxDistanceMeters = 200;
  static const int gpsRemoteDistanceMeters = 100;
  static const int posGridColumnsPhone = 2;
  static const int posGridColumnsTablet = 4;
  static const int posGridColumnsDesktop = 4;
  static const int paginationLimit = 20;
  static const double minTouchTarget = 48.0;
  static const String defaultCurrency = '₹';
  static const String defaultLocale = 'en_IN';
  static const String mockOtp = '123456';
}
