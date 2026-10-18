import 'location_models.dart';
import 'models.dart';
import '../core/config.dart';
import 'admin_repository.dart';
import 'guarded_repository.dart';
import 'landlord_repository.dart';
import 'profile_repository.dart';
import 'sample_repository.dart';
import 'supabase_repository.dart';

abstract class Repository {
  static const pageSize = 10;
  Future<List<Property>> search(SearchFilter f, {int page = 0});
  Future<Property> property(String id);
  Future<Set<String>> favouriteIds();
  Future<List<Property>> favourites();
  Future<void> setFavourite(String propertyId, bool on);
  Future<void> requestViewing(String propertyId, DateTime preferred, String note);
  Future<void> sendEnquiry(String propertyId, String message);
  Future<List<Conversation>> conversations();
  Future<List<ChatMessage>> messages(String conversationId);
  Future<void> sendMessage(String conversationId, String body);
  Future<void> report(String targetType, String targetId, String reason, String details);
  Future<void> blockUser(String userId);
  Future<List<Property>> mapListings(SearchFilter f, {required double south, required double west, required double north, required double east});
  Future<ExactLocation?> exactLocation(String propertyId);
  Future<String> contactStatus(String propertyId);
  Future<String> revealPhone(String propertyId);
  Future<String> replySpeed(String propertyId);
  Future<ReviewSummary> reviewSummary(String propertyId);
  Future<List<Review>> reviews(String propertyId);
  Future<String> canReview(String propertyId); // signin | own | no | yes | edit
  Future<void> submitReview(String propertyId, int rating, String comment);
  Future<List<SavedSearch>> savedSearches();
  Future<void> saveSearch(String name, SearchFilter f);
  Future<void> deleteSavedSearch(String id);
  Future<int> countNewMatches(SavedSearch s);
  Future<void> markSearchSeen(String id);
}

class Services {
  static final Repository repo = AppConfig.devMode ? SampleRepository() : GuardedRepository(SupabaseRepository());
  static final LandlordRepository landlord = AppConfig.devMode ? SampleLandlordRepository() : GuardedLandlordRepository(SupabaseLandlordRepository());
  static final ProfileRepository profile = AppConfig.devMode ? SampleProfileRepository() : GuardedProfileRepository(SupabaseProfileRepository());
  static final AdminRepository admin = AppConfig.devMode ? SampleAdminRepository() : GuardedAdminRepository(SupabaseAdminRepository());
}
