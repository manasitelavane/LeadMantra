class ApiEndpoints {
  ApiEndpoints._();

  static const String baseUrl = 'https://leadmantracrm.com/api';

  // Auth
  static const String login         = '$baseUrl/mobile/login';
  static const String logout        = '$baseUrl/mobile/logout';
  static const String deleteAccount = '$baseUrl/mobile/delete-account';

  // Call Leads
  static const String captureCallLead = '$baseUrl/call-lead/capture';
}
