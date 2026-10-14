import 'dart:typed_data';
import '../core/errors.dart';
import 'admin_repository.dart';
import 'admin_models.dart';
import 'landlord_models.dart';
import 'landlord_repository.dart';
import 'models.dart';
import 'repository.dart';

/// Wraps the live repositories so every call has a timeout and every failure
/// arrives as a typed [AppException] that the UI can explain specifically.
class GuardedRepository implements Repository {
  final Repository _r;
  GuardedRepository(this._r);

  @override
  Future<List<Property>> search(SearchFilter f, {int page = 0}) => Net.run(() => _r.search(f, page: page));
  @override
  Future<Property> property(String id) => Net.run(() => _r.property(id));
  @override
  Future<Set<String>> favouriteIds() => Net.run(() => _r.favouriteIds());
  @override
  Future<List<Property>> favourites() => Net.run(() => _r.favourites());
  @override
  Future<void> setFavourite(String propertyId, bool on) => Net.run(() => _r.setFavourite(propertyId, on));
  @override
  Future<void> requestViewing(String propertyId, DateTime preferred, String note) => Net.run(() => _r.requestViewing(propertyId, preferred, note));
  @override
  Future<void> sendEnquiry(String propertyId, String message) => Net.run(() => _r.sendEnquiry(propertyId, message));
  @override
  Future<List<Conversation>> conversations() => Net.run(() => _r.conversations());
  @override
  Future<List<ChatMessage>> messages(String conversationId) => Net.run(() => _r.messages(conversationId));
  @override
  Future<void> sendMessage(String conversationId, String body) => Net.run(() => _r.sendMessage(conversationId, body));
  @override
  Future<void> report(String targetType, String targetId, String reason, String details) => Net.run(() => _r.report(targetType, targetId, reason, details));
  @override
  Future<void> blockUser(String userId) => Net.run(() => _r.blockUser(userId));
}

class GuardedLandlordRepository implements LandlordRepository {
  final LandlordRepository _r;
  GuardedLandlordRepository(this._r);

  @override
  Future<List<University>> universities() => Net.run(() => _r.universities());
  @override
  Future<DashboardStats> stats() => Net.run(() => _r.stats());
  @override
  Future<List<LandlordListing>> myListings() => Net.run(() => _r.myListings());
  @override
  Future<LandlordListing> myListing(String id) => Net.run(() => _r.myListing(id));
  @override
  Future<String> saveDraft(String? id, ListingInput input) => Net.run(() => _r.saveDraft(id, input));
  @override
  Future<PhotoRef> addPhoto(String propertyId, Uint8List bytes, String fileName, int sortOrder) =>
      Net.run(() => _r.addPhoto(propertyId, bytes, fileName, sortOrder), timeout: Net.upload);
  @override
  Future<void> removePhoto(String propertyId, PhotoRef photo) => Net.run(() => _r.removePhoto(propertyId, photo));
  @override
  Future<void> setAmenities(String propertyId, List<String> codes) => Net.run(() => _r.setAmenities(propertyId, codes));
  @override
  Future<void> uploadVerificationDoc(String propertyId, String docType, Uint8List bytes, String fileName) =>
      Net.run(() => _r.uploadVerificationDoc(propertyId, docType, bytes, fileName), timeout: Net.upload);
  @override
  Future<void> submitForReview(String propertyId) => Net.run(() => _r.submitForReview(propertyId));
  @override
  Future<void> setAvailability(String id, String status) => Net.run(() => _r.setAvailability(id, status));
  @override
  Future<void> renew(String id) => Net.run(() => _r.renew(id));
  @override
  Future<void> delete(String id) => Net.run(() => _r.delete(id));
  @override
  Future<List<ViewingRequestItem>> viewingRequests() => Net.run(() => _r.viewingRequests());
  @override
  Future<void> decideViewing(String id, String status) => Net.run(() => _r.decideViewing(id, status));
}

class GuardedAdminRepository implements AdminRepository {
  final AdminRepository _r;
  GuardedAdminRepository(this._r);

  @override
  Future<AdminStats> stats() => Net.run(() => _r.stats());
  @override
  Future<List<LandlordListing>> pendingListings() => Net.run(() => _r.pendingListings());
  @override
  Future<void> moderate(String id, String decision, String note) => Net.run(() => _r.moderate(id, decision, note));
  @override
  Future<void> setSuspension(String userId, bool suspended, String reason) => Net.run(() => _r.setSuspension(userId, suspended, reason));
  @override
  Future<List<AdminReport>> reports({bool openOnly = true}) => Net.run(() => _r.reports(openOnly: openOnly));
  @override
  Future<void> resolveReport(String id, String status, String note) => Net.run(() => _r.resolveReport(id, status, note));
  @override
  Future<List<VerificationItem>> verifications() => Net.run(() => _r.verifications());
  @override
  Future<String> signedDocUrl(String path) => Net.run(() => _r.signedDocUrl(path));
  @override
  Future<void> reviewVerification(String id, bool approved, String note) => Net.run(() => _r.reviewVerification(id, approved, note));
  @override
  Future<List<LeadItem>> leads() => Net.run(() => _r.leads());
  @override
  Future<void> setLeadStatus(String id, String status) => Net.run(() => _r.setLeadStatus(id, status));
  @override
  Future<List<AuditItem>> audit() => Net.run(() => _r.audit());
}
