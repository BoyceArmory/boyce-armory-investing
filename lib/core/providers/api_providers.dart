import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/api_client.dart';

/// App-wide ApiClient singleton.
final Provider<ApiClient> apiClientProvider = Provider<ApiClient>(
  (Ref ref) => ApiClient(),
);
