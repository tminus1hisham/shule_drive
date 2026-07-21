import '../services/app_config.dart';

// API Endpoints - All API routes for ShuleDrive
// Organized by feature/category for easy maintenance

class Endpoints {
  Endpoints._(); // Private constructor to prevent instantiation

  // ==========================================================================
  // BASE URL
  // ==========================================================================
  // Note: Endpoints already include '/api' prefix
  static String get baseUrl => appConfig.apiBaseUrl;
  static const String devBaseUrl = 'http://localhost:8000';

  // ==========================================================================
  // AUTH ENDPOINTS
  // ==========================================================================
  static const String register = '/api/auth/register';
  static const String login = '/api/auth/login';
  static const String enableTwoFactor = '/api/auth/enable/two/factor';
  static const String verifyTwoFactor = '/api/auth/verify/two/factor';
  static const String verifyOtp = verifyTwoFactor;
  static const String refreshToken = '/api/auth/refresh/token';
  static const String confirmPhoneNumber = '/api/auth/confirm/phonenumber';
  static const String confirmEmail = '/api/auth/confirm/email';
  static const String forgotPassword = '/api/auth/forgot/password';
  static const String resetPassword = '/api/auth/reset/password';
  static const String changePassword = '/api/auth/change/password';
  static const String updateProfilePicture = '/api/auth/update/profile/picture';
  static String deleteAccount(String id) => '/api/auth/delete/$id';

  // ==========================================================================
  // USER / PROFILE ENDPOINTS
  // ==========================================================================
  static const String userProfile = '/api/auth/get/account';

  // ==========================================================================
  // BUS ENDPOINTS
  // ==========================================================================
  static const String getAllBuses = '/api/buses/get/all';
  static const String createBus = '/api/buses/create';
  static const String getBusesByUser = '/api/buses/get/by/user';
  static String getBusById(String id) => '/api/buses/get/$id';
  static String updateBus(String id) => '/api/buses/update/$id';
  static const String getActiveBuses = '/api/buses/get/active';
  static String deleteBus(String id) => '/api/buses/delete/$id';
  static const String getDeletedBuses = '/api/buses/get/deleted';
  static const String getInactiveBuses = '/api/buses/get/inactive';

  // ==========================================================================
  // CHATS ENDPOINTS
  // ==========================================================================
  static const String getChats = '/api/chats/get';
  static const String getChatContacts = '/api/chats/get/contacts';

  // ==========================================================================
  // DRIVERS ENDPOINTS
  // ==========================================================================
  static const String getAllDrivers = '/api/drivers/get/all';
  static const String getActiveDrivers = '/api/drivers/get/active';
  static String getDriversBySchool(String schoolId) =>
      '/api/drivers/get/by/school/$schoolId';
  static const String createDriver = '/api/drivers/create';
  static const String getDriversByUser = '/api/drivers/get/by/user';
  static String getDriverById(String id) => '/api/drivers/get/by/$id';
  static String updateDriver(String id) => '/api/drivers/update/$id';
  static String deleteDriver(String id) => '/api/drivers/delete/$id';
  static const String getDeletedDrivers = '/api/drivers/get/deleted';
  static const String getInactiveDrivers = '/api/drivers/get/inactive';

  // ==========================================================================
  // GUARDIANS / PARENTS ENDPOINTS
  // ==========================================================================
  static const String getAllGuardians = '/api/guardians/get/all';
  static const String getGuardiansBySchool = '/api/guardians/get/by/school';
  static const String createGuardian = '/api/guardians/create';
  static const String uploadGuardianFile = '/api/guardians/upload/file';
  static String getGuardianById(String id) => '/api/guardians/get/$id';
  static String updateGuardian(String id) => '/api/guardians/update/$id';
  static const String updateGuardianStudent = '/api/guardians/student/update';
  static const String getActiveGuardians = '/api/guardians/get/active';
  static const String createGuardianStudent = '/api/guardians/student/create';
  static const String getGuardianStudents = '/api/guardians/get/students';
  static const String getGuardianStudentsByPhone =
      '/api/guardians/get/students/by/phone';
  static const String getGuardianStudentsByPhoneDash =
      '/api/guardians/get/students/by/phone/dash';
  static String deleteGuardian(String id) => '/api/guardians/delete/$id';
  static String deleteGuardianStudent(String id) =>
      '/api/guardians/student/delete/$id';
  static const String getDeletedGuardians = '/api/guardians/get/deleted';
  static const String getInactiveGuardians = '/api/guardians/get/inactive';
  static const String requestDeleteGuardianAccount =
      '/api/guardians/request/delete/account';
  static const String updateGuardianChildImage =
      '/api/guardians/update/child/image';
  static const String addExtendedGuardianUser =
      '/api/guardians/add/extended/user';
  static const String addExtendedGuardianUserByAdmin =
      '/api/guardians/add/extended/user/by/admin';
  static const String getExtendedGuardians =
      '/api/guardians/get/extended/guardians';
  static String deleteExtendedGuardian(String id) =>
      '/api/guardians/delete/extended/guardian/$id';

  // ==========================================================================
  // NOTIFICATIONS ENDPOINTS
  // ==========================================================================
  static const String getNotificationCampaigns =
      '/api/notifications/get/campaigns';
  static const String sendNotification = '/api/notifications/send';
  static String getAllNotificationsByCampaign(String campaignId) =>
      '/api/notifications/get/all/$campaignId';
  static String getFailedNotificationsByCampaign(String campaignId) =>
      '/api/notifications/get/failed/$campaignId';
  static String getSuccessNotificationsByCampaign(String campaignId) =>
      '/api/notifications/get/success/$campaignId';
  static const String getAllNotifications = '/api/notifications/get/all';
  static const String getAllSmsNotifications = '/api/notifications/get/all/sms';
  static const String getAllEmailNotifications =
      '/api/notifications/get/all/emails';
  static String getNotificationsByPhoneNumber(String phoneNumber) =>
      '/api/notifications/get/by/$phoneNumber';
  static const String getEmailCampaigns =
      '/api/notifications/get/email/campaigns';
  static const String getNotificationCampaignsList =
      '/api/notifications/get/notifications/campaigns';
  static String getEmailCampaignRecipients(String campaignId) =>
      '/api/notifications/get/email/campaigns/recipients/$campaignId';
  static String getNotificationCampaignRecipients(String campaignId) =>
      '/api/notifications/get/notifications/campaigns/recipients/$campaignId';
  static const String getNotificationTypes =
      '/api/notifications/get/notification/type';
  static const String updateNotificationType =
      '/api/notifications/update/notification/type';
  static const String getNotificationsByPhone =
      '/api/notifications/get/notifications/by/phone';

  // ==========================================================================
  // PAYMENTS ENDPOINTS
  // ==========================================================================
  static const String payments = '/api/payment/get';
  static const String makePayment = '/api/payment/create/payment/request';
  static const String addPayment = '/api/payment/add/payment';
  static const String paymentStudents = '/api/payment/get/students';
  static const String paymentExtensions = '/api/payment/get/extensions';
  static const String extendSubscription = '/api/payment/extend/subscription';

  // ==========================================================================
  // PAYMENT PLANS ENDPOINTS
  // ==========================================================================
  static const String paymentPlans = '/api/payment-plans/get';
  static const String createPaymentPlan = '/api/payment-plans/create';
  static const String updatePaymentPlan = '/api/payment-plans/update';
  static String deletePaymentPlan(String id) => '/api/payment-plans/delete/$id';

  // ==========================================================================
  // REPORTS ENDPOINTS
  // ==========================================================================
  // api.md exposes a single Reports endpoint: the trips taken on a unique trip.
  // The trip identifier is passed as a `tripUniqueIdentity` query parameter.
  static const String getTripsFromUniqueTripReport =
      '/api/attendants/get/unique/trips/from/trip';

  // ==========================================================================
  // ROLES & PERMISSIONS ENDPOINTS
  // ==========================================================================
  static const String getAllRoles = '/api/roles/get/all/roles';
  static const String createRole = '/api/roles/create/role';
  static const String getAllUsersWithRoles = '/api/roles/get/all/users';
  static const String addUserToRole = '/api/roles/add/user/to/role';
  static const String getUserRoles = '/api/roles/get/user/roles';
  static const String removeUserFromRole = '/api/roles/remove/user/from/role';
  static const String getAllClaims = '/api/roles/get/all/claims';
  static const String addClaimsToUser = '/api/roles/add/claims/to/user';
  static const String removeClaimFromUser = '/api/roles/remove/claim/from/user';
  static const String addClaimToRole = '/api/roles/add/claim/to/role';
  static const String getClaimsForRole = '/api/roles/get/claims/for/role';
  static const String removeClaimFromRole = '/api/roles/remove/claim/from/role';

  // ==========================================================================
  // ROUTES ENDPOINTS
  // ==========================================================================
  static const String getAllRoutes = '/api/routes/get/all';
  static const String createRoute = '/api/routes/create';
  static const String getRoutesByUser = '/api/routes/get/by/user';
  static String updateRoute(String id) => '/api/routes/update/$id';
  static String deleteRoute(String id) => '/api/routes/delete/$id';

  // ==========================================================================
  // SCHOOLS ENDPOINTS
  // ==========================================================================
  static const String getAllSchools = '/api/schools/get/all';
  static const String createSchool = '/api/schools/create';
  static String getSchoolById(String id) => '/api/schools/get/$id';
  static const String getSchoolsByUser = '/api/schools/get/by/user';
  static String updateSchool(String id) => '/api/schools/update/$id';
  static const String getActiveSchools = '/api/schools/get/active';
  static String deleteSchool(String id) => '/api/schools/delete/$id';
  static const String getDeletedSchools = '/api/schools/get/deleted';
  static const String getInactiveSchools = '/api/schools/get/inactive';
  static const String getSosSchools = '/api/schools/get/sos';

  // ==========================================================================
  // STUDENTS ENDPOINTS
  // ==========================================================================
  static const String students = '/api/guardians/get/students';
  static const String updateStudent = '/api/guardians/student/update';
  static String deleteStudent(String id) => '/api/guardians/student/delete/$id';

  // ==========================================================================
  // TRIPS ENDPOINTS
  // ==========================================================================
  static const String getAllMasterTrips = '/api/trips/get/all/master/trips';
  // Note: api.md has no "master trips by driver" endpoint. Trips are fetched
  // via getAllMasterTrips and filtered client-side by driver id (createdBy).
  static const String createMasterTrip = '/api/trips/master/create';
  static const String addStudentToMasterTrip =
      '/api/trips/add/student/to/master';
  static const String activateDeactivateMasterTrip =
      '/api/trips/activate/deactivate/master/trip';
  static const String getMasterTripStudents =
      '/api/trips/get/master/trip/students';
  static const String getStudentsGuardiansInMasterTrips =
      '/api/trips/get/students/guardians/in/mastertrips';
  static const String editMasterTrip = '/api/trips/edit/master/trip';
  static const String deleteMasterTrip = '/api/trips/delete/master/trip';
  static const String startTrip = '/api/trips/start';
  static const String deleteStudentFromMasterTrip =
      '/api/trips/delete/student/from/master/trip';
  static const String getStudentActiveTrip =
      '/api/trips/get/student/active/trip';
  static const String pickAllStudents = '/api/trips/pick/all';
  static const String dropAllStudents = '/api/trips/drop/all';
  static const String pickDropStudent = '/api/trips/pick/drop/student';
  static const String getUniqueTrips = '/api/trips/get/unique/trips';
  static const String getUniqueTripsFromTrip =
      '/api/trips/get/unique/trips/from/trip';
  static const String studentNotPicked = '/api/trips/student/not/picked';
  static const String createTripRating = '/api/trips/create/rating';

  // ==========================================================================
  // UTILITIES / HELPER METHODS
  // ==========================================================================

  /// Build full URL with query parameters
  static String buildUrl(String endpoint, {Map<String, dynamic>? queryParams}) {
    var url = '$baseUrl$endpoint';

    if (queryParams != null && queryParams.isNotEmpty) {
      final queryString = queryParams.entries
          .where((e) => e.value != null)
          .map((e) => '${e.key}=${Uri.encodeComponent(e.value.toString())}')
          .join('&');

      if (queryString.isNotEmpty) {
        url = '$url?$queryString';
      }
    }

    return url;
  }

  /// Replace path parameters in endpoint
  /// Example: replacePathParams('/trips/{id}', {'id': '123'}) => '/trips/123'
  static String replacePathParams(String endpoint, Map<String, String> params) {
    var result = endpoint;
    params.forEach((key, value) {
      result = result.replaceAll('{$key}', value);
    });
    return result;
  }
}

// ==========================================================================
// QUERY PARAMETER BUILDERS
// ==========================================================================

class QueryParams {
  QueryParams._();

  /// Pagination params
  static Map<String, String> pagination({int page = 1, int limit = 20}) => {
    'page': page.toString(),
    'limit': limit.toString(),
  };

  /// Date range params
  static Map<String, String> dateRange({
    DateTime? startDate,
    DateTime? endDate,
  }) => {
    if (startDate != null) 'start_date': startDate.toIso8601String(),
    if (endDate != null) 'end_date': endDate.toIso8601String(),
  };

  /// Search params
  static Map<String, String> search(String query, {String? filter}) => {
    'q': query,
    if (filter != null) 'filter': filter,
  };

  /// Sorting params
  static Map<String, String> sort({
    required String by,
    bool ascending = true,
  }) => {'sort_by': by, 'sort_order': ascending ? 'asc' : 'desc'};

  /// Status filter
  static Map<String, String> status(String status) => {'status': status};
}
