class RemoteLead {
  const RemoteLead({
    required this.id,
    required this.name,
    this.contactPerson,
    this.email,
    required this.phone,
    this.address,
    this.gstin,
    this.stateName,
    this.stateCode,
    required this.status,
    this.lostReason,
    this.lostReasonNote,
    required this.source,
    this.dealValue,
    required this.createdVia,
    required this.tags,
    required this.createdAt,
    required this.updatedAt,
  });

  final int      id;
  final String   name;
  final String?  contactPerson;
  final String?  email;
  final String   phone;
  final String?  address;
  final String?  gstin;
  final String?  stateName;
  final String?  stateCode;
  final String   status;
  final String?  lostReason;
  final String?  lostReasonNote;
  final String   source;
  final num?     dealValue;
  final String   createdVia;
  final List<String> tags;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory RemoteLead.fromJson(Map<String, dynamic> j) => RemoteLead(
    id:             j['id'] as int,
    name:           j['name'] as String? ?? 'Unknown',
    contactPerson:  j['contact_person'] as String?,
    email:          j['email'] as String?,
    phone:          j['phone'] as String? ?? '',
    address:        j['address'] as String?,
    gstin:          j['gstin'] as String?,
    stateName:      j['state_name'] as String?,
    stateCode:      j['state_code'] as String?,
    status:         j['status'] as String? ?? 'new',
    lostReason:     j['lost_reason'] as String?,
    lostReasonNote: j['lost_reason_note'] as String?,
    source:         j['source'] as String? ?? '',
    dealValue:      j['deal_value'] as num?,
    createdVia:     j['created_via'] as String? ?? '',
    tags: (j['tags'] as List<dynamic>? ?? const [])
        .map((e) => e.toString())
        .toList(),
    createdAt: DateTime.tryParse(j['created_at'] as String? ?? '')?.toLocal()
        ?? DateTime.now(),
    updatedAt: DateTime.tryParse(j['updated_at'] as String? ?? '')?.toLocal()
        ?? DateTime.now(),
  );
}

class RemoteLeadsMeta {
  const RemoteLeadsMeta({
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
    required this.hasMore,
    this.nextPage,
  });

  final int  currentPage;
  final int  perPage;
  final int  total;
  final int  lastPage;
  final bool hasMore;
  final int? nextPage;

  factory RemoteLeadsMeta.fromJson(Map<String, dynamic> j) => RemoteLeadsMeta(
    currentPage: j['current_page'] as int? ?? 1,
    perPage:     j['per_page']     as int? ?? 20,
    total:       j['total']        as int? ?? 0,
    lastPage:    j['last_page']    as int? ?? 1,
    hasMore:     j['has_more']     as bool? ?? false,
    nextPage:    j['next_page']    as int?,
  );
}

class RemoteLeadsPage {
  const RemoteLeadsPage({required this.leads, required this.meta});

  final List<RemoteLead> leads;
  final RemoteLeadsMeta   meta;
}
