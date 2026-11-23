/// Domain model for an event, shared by the app shell, dashboard and pages.
class EventItem {
  EventItem({
    required this.title,
    required this.date,
    this.id,
    this.location = 'Location to be announced',
    this.description = '',
    this.category = 'Other',
    this.visibility = 'private',
    this.capacity,
    this.ownerId,
    this.ownerName,
    this.ownerAvatarUrl,
    this.createdAt,
  });

  final String? id;
  final String title;
  final DateTime date;
  final String location;
  final String description;
  final String category;
  final String visibility;
  final int? capacity;
  final String? ownerId;
  final String? ownerName;
  final String? ownerAvatarUrl;
  final String? createdAt;

  factory EventItem.fromBackend(Map<String, dynamic> event) {
    final date = DateTime.tryParse(
      (event['startsAt'] ?? event['starts_at'] ?? '').toString(),
    );
    return EventItem(
      id: event['id']?.toString(),
      title: event['title']?.toString() ?? 'Untitled event',
      date: date?.toLocal() ?? DateTime.now(),
      location: (event['venue'] as String?)?.isNotEmpty == true
          ? event['venue'] as String
          : 'Location to be announced',
      description: event['description']?.toString() ?? '',
      category: event['category']?.toString() ?? 'Other',
      visibility: event['visibility']?.toString() ?? 'private',
      capacity: (event['capacity'] as num?)?.toInt(),
      ownerId: (event['ownerId'] ?? event['owner_id'])?.toString(),
      ownerName: (event['ownerName'] ?? event['owner_name'])?.toString(),
      ownerAvatarUrl: (event['ownerAvatarUrl'] ?? event['owner_avatar_url'])
          ?.toString(),
      createdAt: (event['createdAt'] ?? event['created_at'])?.toString(),
    );
  }
}
