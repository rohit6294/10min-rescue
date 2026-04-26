class FirestorePaths {
  FirestorePaths._();

  static const String users = 'users';
  static const String drivers = 'drivers';
  static const String hospitals = 'hospitals';
  static const String rescueRequests = 'rescue_requests';
  static const String locationUpdates = 'location_updates';

  static String user(String uid) => '$users/$uid';
  static String driver(String uid) => '$drivers/$uid';
  static String hospital(String uid) => '$hospitals/$uid';
  static String rescueRequest(String id) => '$rescueRequests/$id';
  static String locationUpdate(String driverId) => '$locationUpdates/$driverId';
}
