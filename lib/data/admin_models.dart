class AdminStats {
  final int pendingListings, liveListings, totalListings, openReports, pendingVerifications, newLeads, users;
  const AdminStats(this.pendingListings, this.liveListings, this.totalListings, this.openReports, this.pendingVerifications, this.newLeads, this.users);
}

class AdminReport {
  final String id, targetType, targetId, reason, status;
  final String? details, targetTitle;
  final DateTime createdAt;
  const AdminReport(this.id, this.targetType, this.targetId, this.reason, this.details, this.status, this.createdAt, this.targetTitle);
}

class VerificationItem {
  final String id, userId, docType, path, propertyTitle;
  final DateTime createdAt;
  const VerificationItem(this.id, this.userId, this.docType, this.path, this.propertyTitle, this.createdAt);
}

class LeadItem {
  final String id, name, phone, schoolOrArea, roomType, status;
  final int? rentNgn;
  final String? description;
  final DateTime createdAt;
  const LeadItem(this.id, this.name, this.phone, this.schoolOrArea, this.roomType, this.rentNgn, this.description, this.status, this.createdAt);
}

class AuditItem {
  final int id;
  final String action, targetType;
  final String? targetId;
  final Map<String, dynamic> details;
  final DateTime createdAt;
  const AuditItem(this.id, this.action, this.targetType, this.targetId, this.details, this.createdAt);
}
