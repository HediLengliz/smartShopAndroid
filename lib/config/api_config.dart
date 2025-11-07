class ApiConfig {
  // IMPORTANT: Update this URL based on where you're running the app:
  // - For Android Emulator: Use 'http://10.0.2.2:3000/api' (10.0.2.2 is special IP for emulator to reach host)
  // - For Physical Device: Use 'http://YOUR_COMPUTER_IP:3000/api' (find IP with 'ipconfig' command)
  // - For Web/Desktop: Use 'http://localhost:3000/api'



  static const String baseUrl = 'http://localhost:3000/api';


  //static const String baseUrl = 'http://192.168.100.36:3000/api';
  static const String authEndpoint = '$baseUrl/auth';
  static const String productsEndpoint = '$baseUrl/products';
  static const String ordersEndpoint = '$baseUrl/orders';
  static const String shoppingListsEndpoint = '$baseUrl/shopping-lists';
  static const String paymentsEndpoint = '$baseUrl/payments';
  static const String profileEndpoint = '$baseUrl/profile';
  
  static const Duration timeoutDuration = Duration(seconds: 30);
}
