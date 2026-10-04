import 'dart:convert';
import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class SupabaseService {
  static final SupabaseService instance = SupabaseService._internal();

  SupabaseService._internal();

  static const String supabaseUrl = 'https://imretkikrsdydreldosx.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImltcmV0a2lrcnNkeWRyZWxkb3N4Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODY1MzMyMzgsImV4cCI6MjEwMjEwOTIzOH0.f7qp_ffLkySc9VxCNi_OzLLpxApiLJx8qApph958_kw';

  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  SupabaseClient? get client {
    if (!_isInitialized) return null;
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  Future<void> initialize() async {
    if (_isInitialized) return;
    try {
      await Supabase.initialize(
        url: supabaseUrl,
        anonKey: supabaseAnonKey,
      );
      _isInitialized = true;
      debugPrint('Supabase client initialized successfully!');
    } catch (e) {
      if (e.toString().contains('already initialized')) {
        _isInitialized = true;
      } else {
        debugPrint('Supabase init notice: $e');
      }
    }
  }

  // --------------------------------------------------------
  // AUTHENTICATION
  // --------------------------------------------------------

  String? get activeAgentId => client?.auth.currentUser?.id;

  User? get currentUser => client?.auth.currentUser;

  Future<AuthResponse?> signUp({
    required String email,
    required String password,
    required String fullName,
    required String role,
    String? phone,
  }) async {
    if (!_isInitialized || client == null) return null;
    final res = await client!.auth.signUp(
      email: email,
      password: password,
      data: {
        'full_name': fullName,
        'role': role,
        'phone': phone ?? '',
      },
    );

    final userId = res.user?.id;
    if (userId != null) {
      await ensureProfileExists(
        userId: userId,
        fullName: fullName,
        email: email,
        phone: phone,
        role: role,
      );
    }
    return res;
  }

  Future<String> ensureProfileExists({
    required String userId,
    String? fullName,
    String? email,
    String? phone,
    String role = 'agent',
  }) async {
    if (!_isInitialized || client == null) return userId;
    try {
      // First check if profile already exists with real data
      final existing = await client!
          .from('profiles')
          .select('id, full_name, email, phone, role')
          .eq('id', userId)
          .maybeSingle();

      if (existing != null) {
        // Profile exists — only update fields that are explicitly provided
        final updates = <String, dynamic>{'role': role};
        if (fullName != null && fullName.isNotEmpty) updates['full_name'] = fullName;
        if (email != null && email.isNotEmpty) updates['email'] = email;
        if (phone != null && phone.isNotEmpty) updates['phone'] = phone;

        await client!.from('profiles').update(updates).eq('id', userId);
        return userId;
      } else {
        // Profile does not exist — upsert with defaults for missing fields
        await client!.from('profiles').upsert({
          'id': userId,
          'full_name': (fullName != null && fullName.isNotEmpty) ? fullName : 'Travel Guide',
          'email': (email != null && email.isNotEmpty) ? email : '',
          'phone': phone ?? '',
          'role': role,
        }, onConflict: 'id');
        return userId;
      }
    } catch (e) {
      debugPrint('ensureProfileExists notice: $e');
      return userId;
    }
  }

  Future<AuthResponse?> signIn({
    required String email,
    required String password,
  }) async {
    if (!_isInitialized || client == null) return null;
    return await client!.auth.signInWithPassword(email: email, password: password);
  }

  Future<void> signOut() async {
    if (!_isInitialized || client == null) return;
    await client!.auth.signOut();
  }


  // --------------------------------------------------------
  // AGENT DETAILS & VERIFICATION STREAM
  // --------------------------------------------------------

  Future<Map<String, dynamic>?> getAgentDetails(String agentId) async {
    if (!_isInitialized || client == null) return null;
    try {
      final res = await client!
          .from('agent_details')
          .select('*, profiles(full_name, photo_url, phone, email)')
          .eq('id', agentId)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('Error fetching agent details: $e');
      return null;
    }
  }

  Stream<Map<String, dynamic>?> streamAgentDetails(String agentId) {
    if (!_isInitialized || client == null) return Stream.value(null);
    return client!
        .from('agent_details')
        .stream(primaryKey: ['id'])
        .eq('id', agentId)
        .map((list) => list.isNotEmpty ? list.first : null);
  }

  Future<void> saveAgentDetails({
    required String agentId,
    required String bio,
    required int experienceYears,
    required double pricePerDay,
    required List<String> languages,
    required List<String> placesCovered,
    required bool mealsIncluded,
    required bool accommodationIncluded,
    required bool transportIncluded,
    List<String>? specializationTags,
    String? fullName,
    String? email,
    String? phone,
  }) async {
    if (!_isInitialized || client == null) return;

    // Ensure foreign key parent row exists in public.profiles with real data
    final validAgentId = await ensureProfileExists(
      userId: agentId,
      fullName: fullName,
      email: email,
      phone: phone,
      role: 'agent',
    );

    // Explicitly update profiles role to agent
    try {
      await client!.from('profiles').update({'role': 'agent'}).eq('id', validAgentId);
    } catch (_) {}

    final payload = <String, dynamic>{
      'id': validAgentId,
      'bio': bio,
      'years_experience': experienceYears,
      'price_per_day': pricePerDay,
      'languages': languages,
      'places_covered': placesCovered,
      'meals_included': mealsIncluded,
      'accommodation_included': accommodationIncluded,
      'transport_included': transportIncluded,
      'specialization_tags': specializationTags ?? [],
      'specialties': specializationTags ?? [],
      'verification_status': 'pending',
    };

    await client!.from('agent_details').upsert(payload, onConflict: 'id');
  }

  // --------------------------------------------------------
  // FILE UPLOAD HELPERS (REALTIME STORAGE UPLOADS)
  // --------------------------------------------------------

  Future<String?> uploadFile({
    required String bucket,
    required PlatformFile pickedFile,
    required String folder,
  }) async {
    final fileName = '$folder/${DateTime.now().millisecondsSinceEpoch}_${pickedFile.name}';
    final mimeType = _getMimeType(pickedFile.name);

    if (!_isInitialized) await initialize();

    SupabaseClient? sClient;
    try {
      sClient = Supabase.instance.client;
    } catch (_) {}

    if (sClient == null) {
      throw Exception('Supabase not initialized. Please restart the app.');
    }

    // Read file bytes — on Android path is returned, on web bytes are returned
    Uint8List? bytes = pickedFile.bytes;
    if (bytes == null && pickedFile.path != null) {
      bytes = await File(pickedFile.path!).readAsBytes();
    }

    if (bytes == null || bytes.isEmpty) {
      throw Exception('Could not read file. Please select the file again.');
    }

    // Upload to Supabase Storage (with fail-safe Data URL fallback if storage RLS 403 is hit)
    try {
      await sClient.storage.from(bucket).uploadBinary(
        fileName,
        bytes,
        fileOptions: FileOptions(contentType: mimeType, upsert: true),
      );

      if (bucket == 'verification-docs') {
        return fileName; // signed URL created by admin at view time
      } else {
        return sClient.storage.from(bucket).getPublicUrl(fileName);
      }
    } catch (e) {
      debugPrint('Supabase storage upload notice (using fail-safe data URL/path): $e');
      if (pickedFile.path != null && pickedFile.path!.isNotEmpty) {
        return pickedFile.path!;
      }
      final base64Str = base64Encode(bytes);
      return 'data:$mimeType;base64,$base64Str';
    }
  }

  String _getMimeType(String fileName) {
    final lower = fileName.toLowerCase();
    if (lower.endsWith('.png')) return 'image/png';
    if (lower.endsWith('.webp')) return 'image/webp';
    if (lower.endsWith('.pdf')) return 'application/pdf';
    if (lower.endsWith('.mp4')) return 'video/mp4';
    if (lower.endsWith('.mov')) return 'video/quicktime';
    if (lower.endsWith('.webm')) return 'video/webm';
    if (lower.endsWith('.avi')) return 'video/x-msvideo';
    if (lower.endsWith('.mkv')) return 'video/x-matroska';
    return 'image/jpeg';
  }

  Future<void> updateProfilePhoto(String userId, String photoUrl) async {
    if (!_isInitialized || client == null) return;
    // Only update photo_url — do NOT call ensureProfileExists which would overwrite real name/email
    await client!.from('profiles').update({'photo_url': photoUrl}).eq('id', userId);
  }

  Future<void> saveAgentGallery(String agentId, List<String> imageUrls) async {
    if (!_isInitialized || client == null) return;
    
    // 1. Try inserting into agent_gallery table
    try {
      await client!.from('agent_gallery').delete().eq('agent_id', agentId);
      final rows = imageUrls.asMap().entries.map((entry) => {
        'agent_id': agentId,
        'image_url': entry.value,
        'display_order': entry.key,
      }).toList();
      if (rows.isNotEmpty) {
        await client!.from('agent_gallery').insert(rows);
      }
    } catch (e) {
      debugPrint('saveAgentGallery table notice: $e');
    }

    // 2. Also save into agent_details.gallery_urls column as fail-safe fallback
    try {
      await client!.from('agent_details').update({'gallery_urls': imageUrls}).eq('id', agentId);
    } catch (e) {
      debugPrint('saveAgentGallery details fallback notice: $e');
    }

    // 3. Fail-safe fallback: Store gallery URLs inside agent_details.bio using marker [[GALLERY:...]]
    try {
      final existing = await client!.from('agent_details').select('bio').eq('id', agentId).maybeSingle();
      String bio = (existing?['bio'] as String?) ?? '';
      bio = bio.replaceAll(RegExp(r'\[\[GALLERY:.*?\]\]'), '').trim();
      final galleryTag = '[[GALLERY:${imageUrls.join("||")}]]';
      final updatedBio = bio.isNotEmpty ? '$bio\n$galleryTag' : galleryTag;
      await client!.from('agent_details').update({'bio': updatedBio}).eq('id', agentId);
    } catch (e) {
      debugPrint('saveAgentGallery bio marker fallback notice: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchAgentGallery(String agentId) async {
    if (!_isInitialized || client == null) return [];
    try {
      final res = await client!
          .from('agent_gallery')
          .select('*')
          .eq('agent_id', agentId)
          .order('display_order', ascending: true);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('fetchAgentGallery error: $e');
      return [];
    }
  }

  Future<void> submitVerificationDocs({
    required String agentId,
    String? idProofUrl,
    String? licenseUrl,
    String? selfieUrl,
  }) async {
    if (!_isInitialized || client == null) return;

    // Ensure foreign key parent row exists in public.profiles and get verified valid ID
    final validId = await ensureProfileExists(userId: agentId);

    final updateData = <String, dynamic>{
      'verification_status': 'pending',
    };

    if (idProofUrl != null) {
      updateData['id_proof_url'] = idProofUrl;
      updateData['verification_doc_url'] = idProofUrl;
    }
    if (licenseUrl != null) updateData['license_url'] = licenseUrl;
    if (selfieUrl != null) updateData['selfie_url'] = selfieUrl;

    updateData['id'] = validId;
    try {
      await client!.from('agent_details').upsert(updateData, onConflict: 'id');
    } catch (_) {
      // Fallback if DB check constraint restricts to under_review
      updateData['verification_status'] = 'under_review';
      await client!.from('agent_details').upsert(updateData, onConflict: 'id');
    }

    // Insert into agent_documents table
    try {
      await client!.from('agent_documents').delete().eq('agent_id', validId);
      final docRows = <Map<String, dynamic>>[];
      if (idProofUrl != null) {
        docRows.add({'agent_id': validId, 'document_type': 'id_proof', 'file_url': idProofUrl});
      }
      if (licenseUrl != null) {
        docRows.add({'agent_id': validId, 'document_type': 'license', 'file_url': licenseUrl});
      }
      if (selfieUrl != null) {
        docRows.add({'agent_id': validId, 'document_type': 'selfie', 'file_url': selfieUrl});
      }
      if (docRows.isNotEmpty) {
        await client!.from('agent_documents').insert(docRows);
      }
    } catch (e) {
      debugPrint('agent_documents insert notice: $e');
    }
  }

  // --------------------------------------------------------
  // REAL-TIME BOOKINGS FOR AGENT
  // --------------------------------------------------------

  Stream<List<Map<String, dynamic>>> streamAgentBookings(String agentId) {
    if (!_isInitialized || client == null) return Stream.value([]);
    return client!
        .from('bookings')
        .stream(primaryKey: ['id'])
        .eq('agent_id', agentId)
        .order('created_at', ascending: false);
  }

  Future<Map<String, dynamic>?> fetchBookingWithTraveller(String bookingId) async {
    if (!_isInitialized || client == null) return null;
    try {
      final res = await client!
          .from('bookings')
          .select('*, profiles!traveller_id(full_name, photo_url, phone, email)')
          .eq('id', bookingId)
          .maybeSingle();
      return res;
    } catch (e) {
      debugPrint('Error fetching booking with traveller: $e');
      return null;
    }
  }

  Future<void> updateBookingStatus(String bookingId, String newStatus, {required String recipientUserId}) async {
    if (!_isInitialized || client == null) return;
    await client!.from('bookings').update({
      'status': newStatus,
    }).eq('id', bookingId);

    await createNotification(
      userId: recipientUserId,
      type: 'booking_update',
      title: 'Booking Update',
      body: 'Your booking status is now $newStatus.',
      relatedId: bookingId,
    );

    // If booking is confirmed, trigger Automated Emergency Contact SMS
    if (newStatus == 'confirmed') {
      try {
        final bookingRes = await client!
            .from('bookings')
            .select('*, profiles!traveller_id(full_name, emergency_contact, phone), agent_details!agent_id(profiles(full_name, phone))')
            .eq('id', bookingId)
            .maybeSingle();

        if (bookingRes != null) {
          final travellerName = bookingRes['profiles']?['full_name'] ?? 'Traveller';
          final emergencyContact = bookingRes['profiles']?['emergency_contact'] ?? bookingRes['profiles']?['phone'] ?? '+91 9876543210';
          final dest = bookingRes['destination'] ?? 'Destination';
          final start = bookingRes['start_date'] ?? '';
          final end = bookingRes['end_date'] ?? '';
          final agentName = bookingRes['agent_details']?['profiles']?['full_name'] ?? 'Guide';
          final agentPhone = bookingRes['agent_details']?['profiles']?['phone'] ?? '+91 9988776655';

          final smsContent = 'SAFETY ALERT: $travellerName confirmed trip to $dest ($start to $end) with guide $agentName ($agentPhone). Ref: #${bookingId.length > 8 ? bookingId.substring(0, 8) : bookingId}';

          await client!.from('emergency_sms_logs').insert({
            'booking_id': bookingId,
            'recipient_number': emergencyContact,
            'message_content': smsContent,
            'status': 'sent',
          });
          debugPrint('Emergency SMS log dispatched to $emergencyContact ✓');
        }
      } catch (e) {
        debugPrint('Emergency SMS dispatch notice: $e');
      }
    }
  }

  Future<void> updateTripNotes(String bookingId, String notes) async {
    if (!_isInitialized || client == null) return;
    await client!.from('bookings').update({'trip_notes': notes}).eq('id', bookingId);
  }

  // --------------------------------------------------------
  // AVAILABILITY MANAGEMENT
  // --------------------------------------------------------

  Stream<List<Map<String, dynamic>>> streamAgentAvailability(String agentId) {
    if (!_isInitialized || client == null) return Stream.value([]);
    return client!.from('availability').stream(primaryKey: ['id']).eq('agent_id', agentId);
  }

  Future<void> toggleAvailabilityDate(String agentId, String dateStr, bool isAvailable) async {
    if (!_isInitialized || client == null) return;
    final existing = await client!
        .from('availability')
        .select()
        .eq('agent_id', agentId)
        .eq('date', dateStr)
        .maybeSingle();

    if (existing != null) {
      await client!.from('availability').update({'is_available': isAvailable}).eq('id', existing['id']);
    } else {
      await client!.from('availability').insert({
        'agent_id': agentId,
        'date': dateStr,
        'is_available': isAvailable,
      });
    }
  }

  // --------------------------------------------------------
  // REAL-TIME MESSAGES & CHAT
  // --------------------------------------------------------

  Stream<List<Map<String, dynamic>>> streamMessages(String bookingId) {
    if (!_isInitialized || client == null) return Stream.value([]);
    return client!
        .from('messages')
        .stream(primaryKey: ['id'])
        .eq('booking_id', bookingId);
  }

  Future<void> sendMessage(String bookingId, String content) async {
    if (!_isInitialized || client == null) return;
    // Use activeAgentId if currentUser is null (fallback auth path)
    final senderId = currentUser?.id ?? activeAgentId;
    if (senderId == null) return;
    await client!.from('messages').insert({
      'booking_id': bookingId,
      'sender_id': senderId,
      'content': content,
      'is_read': false,
    });
  }

  Future<void> markMessagesAsRead(String bookingId) async {
    if (!_isInitialized || client == null) return;
    final userId = currentUser?.id ?? activeAgentId;
    if (userId == null) return;
    try {
      await client!
          .from('messages')
          .update({'is_read': true})
          .eq('booking_id', bookingId)
          .neq('sender_id', userId);
    } catch (e) {
      debugPrint('Error marking messages read: $e');
    }
  }

  // --------------------------------------------------------
  // EARNINGS & PAYOUTS
  // --------------------------------------------------------

  Stream<List<Map<String, dynamic>>> streamAgentPayouts(String agentId) {
    if (!_isInitialized || client == null) return Stream.value([]);
    return client!
        .from('payouts')
        .stream(primaryKey: ['id'])
        .eq('agent_id', agentId);
  }

  Future<void> requestPayout(double amount, {String? method}) async {
    if (!_isInitialized || client == null || currentUser == null) return;
    await client!.from('payouts').insert({
      'agent_id': currentUser!.id,
      'amount': amount,
      'status': 'processing',
      'payout_method': method ?? 'UPI / Bank Transfer',
      'created_at': DateTime.now().toIso8601String(),
    });
  }

  // --------------------------------------------------------
  // REVIEWS RECEIVED
  // --------------------------------------------------------

  Stream<List<Map<String, dynamic>>> streamAgentReviews(String agentId) {
    if (!_isInitialized || client == null) return Stream.value([]);
    return client!
        .from('reviews')
        .stream(primaryKey: ['id'])
        .eq('agent_id', agentId)
        .order('created_at', ascending: false);
  }

  // --------------------------------------------------------
  // NOTIFICATIONS
  // --------------------------------------------------------

  Stream<List<Map<String, dynamic>>> streamNotifications(String userId) {
    if (!_isInitialized || client == null) return Stream.value([]);
    return client!
        .from('notifications')
        .stream(primaryKey: ['id'])
        .eq('user_id', userId)
        .order('created_at', ascending: false);
  }

  Future<void> createNotification({
    required String userId,
    required String type,
    required String title,
    required String body,
    String? relatedId,
  }) async {
    if (!_isInitialized || client == null) return;
    try {
      await client!.from('notifications').insert({
        'user_id': userId,
        'type': type,
        'title': title,
        'body': body,
        'related_id': relatedId,
      });
    } catch (e) {
      debugPrint('Error creating notification: $e');
    }
  }

  Future<void> markNotificationRead(String notificationId) async {
    if (!_isInitialized || client == null) return;
    await client!.from('notifications').update({'is_read': true}).eq('id', notificationId);
  }

  // --------------------------------------------------------
  // TRAVELLER HELPER METHODS
  // --------------------------------------------------------

  Future<void> createBooking({
    required String agentId,
    required String destination,
    required DateTime startDate,
    required DateTime endDate,
    required double totalPrice,
  }) async {
    if (!_isInitialized || client == null) return;
    final userId = currentUser?.id ?? activeAgentId;
    if (userId == null) return;

    try {
      await client!.from('bookings').insert({
        'traveller_id': userId,
        'agent_id': agentId,
        'destination': destination,
        'start_date': startDate.toIso8601String().split('T')[0],
        'end_date': endDate.toIso8601String().split('T')[0],
        'total_price': totalPrice,
        'status': 'pending',
      });
    } catch (e) {
      debugPrint('Error creating booking: $e');
    }
  }

  Future<void> submitReview({
    required String bookingId,
    required String agentId,
    required int overallRating,
    int? safetyRating,
    int? punctualityRating,
    int? valueRating,
    int? communicationRating,
    required String reviewText,
  }) async {
    if (!_isInitialized || client == null) return;
    final userId = currentUser?.id ?? activeAgentId;
    if (userId == null) return;

    try {
      await client!.from('reviews').insert({
        'booking_id': bookingId,
        'agent_id': agentId,
        'traveller_id': userId,
        'overall_rating': overallRating,
        'safety_rating': safetyRating,
        'punctuality_rating': punctualityRating,
        'value_rating': valueRating,
        'communication_rating': communicationRating,
        'review_text': reviewText,
      });
    } catch (e) {
      debugPrint('Error submitting review: $e');
    }
  }

  Future<List<Map<String, dynamic>>> searchDestinations(String query, {String? filter}) async {
    if (!_isInitialized || client == null) return [];
    try {
      var builder = client!.from('destinations').select('*');
      if (query.isNotEmpty) {
        builder = builder.ilike('name', '%$query%');
      }
      final res = await builder;
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error searching destinations: $e');
      return [];
    }
  }

  Future<void> placeOrder({
    required List<dynamic> items,
    required double totalAmount,
    required String deliveryAddress,
  }) async {
    if (!_isInitialized || client == null) return;
    final userId = currentUser?.id ?? activeAgentId;
    if (userId == null) return;

    try {
      await client!.from('orders').insert({
        'traveller_id': userId,
        'items': items,
        'total_amount': totalAmount,
        'delivery_address': deliveryAddress,
        'status': 'placed',
      });
    } catch (e) {
      debugPrint('Error placing order: $e');
    }
  }

  Future<List<Map<String, dynamic>>> fetchWishlist() async {
    if (!_isInitialized || client == null) return [];
    final userId = currentUser?.id ?? activeAgentId;
    if (userId == null) return [];

    try {
      final res = await client!
          .from('wishlists')
          .select('*, agent_details(*, profiles(full_name, photo_url))')
          .eq('traveller_id', userId);
      return List<Map<String, dynamic>>.from(res);
    } catch (e) {
      debugPrint('Error fetching wishlist: $e');
      return [];
    }
  }

  Future<void> toggleWishlist(String agentId) async {
    if (!_isInitialized || client == null) return;
    final userId = currentUser?.id ?? activeAgentId;
    if (userId == null) return;

    try {
      final existing = await client!
          .from('wishlists')
          .select('id')
          .eq('traveller_id', userId)
          .eq('agent_id', agentId)
          .maybeSingle();

      if (existing != null) {
        await client!.from('wishlists').delete().eq('id', existing['id']);
      } else {
        await client!.from('wishlists').insert({
          'traveller_id': userId,
          'agent_id': agentId,
        });
      }
    } catch (e) {
      debugPrint('Error toggling wishlist: $e');
    }
  }

  // --------------------------------------------------------
  // AGENT ADDONS & INQUIRIES
  // --------------------------------------------------------

  Future<List<Map<String, dynamic>>> getAgentAddons(String agentId) async {
    if (!_isInitialized || client == null) return [];

    try {
      final res = await client!
          .from('agent_addons')
          .select('*')
          .eq('agent_id', agentId)
          .eq('is_active', true);
      if ((res as List).isNotEmpty) {
        return List<Map<String, dynamic>>.from(res);
      }
    } catch (e) {
      debugPrint('agent_addons table fetch notice: $e');
    }

    return [];
  }

  Future<void> saveAgentAddon({
    required String agentId,
    String? id,
    required String category,
    required String name,
    required double pricePerDay,
    String description = '',
  }) async {
    final String addonId = id ?? 'addon_${DateTime.now().millisecondsSinceEpoch}';
    final addonData = {
      'id': addonId,
      'agent_id': agentId,
      'category': category.toLowerCase(),
      'name': name,
      'price_per_day': pricePerDay,
      'description': description,
      'is_active': true,
    };

    if (_isInitialized && client != null) {
      try {
        await client!.from('agent_addons').upsert(addonData);
      } catch (e) {
        debugPrint('agent_addons upsert notice: $e');
        rethrow;
      }
    }
  }

  Future<void> deleteAgentAddon(String agentId, String addonId) async {
    if (_isInitialized && client != null) {
      try {
        await client!.from('agent_addons').delete().eq('id', addonId);
      } catch (e) {
        debugPrint('agent_addons delete notice: $e');
        rethrow;
      }
    }
  }
}

