import 'models.dart';
import '../core/config.dart';
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
}

class Services {
  static final Repository repo = AppConfig.devMode ? SampleRepository() : SupabaseRepository();
}
