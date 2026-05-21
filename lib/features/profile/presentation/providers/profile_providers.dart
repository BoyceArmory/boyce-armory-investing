import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/profile_repository.dart';

final Provider<ProfileRepository> profileRepositoryProvider =
    Provider<ProfileRepository>((Ref ref) => ProfileRepository());
