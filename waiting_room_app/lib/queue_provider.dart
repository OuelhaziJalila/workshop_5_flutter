import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'local_queue_service.dart';
import 'geolocation_service.dart';

class QueueProvider extends ChangeNotifier {
  final SupabaseClient _supabase;
  final LocalQueueService _localDb;
  final GeolocationService _geoService;

  List<Map<String, dynamic>> _clients = [];
  List<Map<String, dynamic>> get clients => _clients;

  RealtimeChannel? _subscription;

  QueueProvider({
    SupabaseClient? supabase,
    LocalQueueService? localDb,
    GeolocationService? geoService,
  })  : _supabase = supabase ?? Supabase.instance.client,
        _localDb = localDb ?? LocalQueueService(),
        _geoService = geoService ?? GeolocationService();

  Future<void> initialize() async {
    await _loadQueue();
  }

  Future<void> _loadQueue() async {
    try {
      // 1. Load from local DB immediately (offline support)
      final localClients = await _localDb.getClients();
      _clients = List<Map<String, dynamic>>.from(localClients); // Make it mutable!
      notifyListeners();

      // 2. Sync unsynced records to Supabase
      await _syncLocalToRemote();

      // 3. Fetch latest from Supabase
      await _fetchFromSupabase();

      // 4. Subscribe to real-time updates
      _setupRealtimeSubscription();
    } catch (e) {
      debugPrint('Error loading queue: $e');
    }
  }

  Future<void> _fetchFromSupabase() async {
    try {
      final response = await _supabase
          .from('clients')
          .select()
          .order('created_at', ascending: true);

      // ✅ CRITICAL: Convert to mutable list
      _clients = List<Map<String, dynamic>>.from(response);
      notifyListeners();

      // Update local DB with synced data
      for (var client in _clients) {
        await _localDb.insertClientLocally({
          ...client,
          'is_synced': 1,
        });
      }
    } catch (e) {
      debugPrint('Error fetching from Supabase: $e');
    }
  }

  Future<void> _syncLocalToRemote() async {
    final unsynced = await _localDb.getUnsyncedClients();
    for (var client in unsynced) {
      try {
        final remoteClient = Map<String, dynamic>.from(client)
          ..remove('is_synced');
        await _supabase.from('clients').upsert(remoteClient);
        await _localDb.markClientAsSynced(client['id'] as String);
        debugPrint('Successfully synced client: ${client['name']}');
      } catch (e) {
        debugPrint('Sync failed for ${client['id']}: $e');
      }
    }

    // Refresh UI if any sync succeeded
    final refreshedClients = await _localDb.getClients();
    _clients = List<Map<String, dynamic>>.from(refreshedClients); // Make it mutable!
    notifyListeners();
  }

  Future<void> addClient(String name) async {
    final position = await _geoService.getCurrentPosition();
    final newClient = {
      'id': const Uuid().v4(),
      'name': name,
      'lat': position?.latitude,
      'lng': position?.longitude,
      'created_at': DateTime.now().toIso8601String(),
      'is_synced': 0,
    };

    // Save locally immediately
    await _localDb.insertClientLocally(newClient);

    // Update UI instantly - now works because _clients is mutable!
    _clients.add(newClient);
    _clients.sort((a, b) => a['created_at'].compareTo(b['created_at']));
    notifyListeners();

    // Attempt sync (non-blocking for UX)
    unawaited(_syncLocalToRemote());
  }

  Future<void> removeClient(String id) async {
    try {
      // Remove from local state immediately for instant UI update
      _clients.removeWhere((c) => c['id'] == id);
      notifyListeners();

      // Remove from Supabase
      await _supabase.from('clients').delete().eq('id', id);

      // Remove from local DB
      await _localDb.deleteClient(id);
    } catch (e) {
      debugPrint('removeClient error: $e');
      // If removal failed, reload from local DB to restore state
      final refreshedClients = await _localDb.getClients();
      _clients = List<Map<String, dynamic>>.from(refreshedClients);
      notifyListeners();
    }
  }

  Map<String, dynamic>? nextClient() {
    if (_clients.isEmpty) return null;

    final next = _clients.removeAt(0);
    notifyListeners();

    // Remove from backend asynchronously
    removeClient(next['id'] as String);

    return next;
  }

  void _setupRealtimeSubscription() {
    _subscription?.unsubscribe();

    _subscription = _supabase
        .channel('public:clients')
        .onPostgresChanges(
          event: PostgresChangeEvent.all,
          schema: 'public',
          table: 'clients',
          callback: (payload) {
            debugPrint('Real-time event: ${payload.eventType}');
            _handleRealtimeEvent(payload);
          },
        )
        .subscribe();

    debugPrint('Real-time subscription established');
  }

  void _handleRealtimeEvent(PostgresChangePayload payload) {
    switch (payload.eventType) {
      case PostgresChangeEvent.insert:
        final newClient = payload.newRecord;
        if (!_clients.any((c) => c['id'] == newClient['id'])) {
          _clients.add(newClient);
          _clients.sort((a, b) => a['created_at'].compareTo(b['created_at']));
          notifyListeners();

          _localDb.insertClientLocally({
            ...newClient,
            'is_synced': 1,
          });
        }
        break;

      case PostgresChangeEvent.delete:
        final oldRecord = payload.oldRecord;
        _clients.removeWhere((c) => c['id'] == oldRecord['id']);
        notifyListeners();

        _localDb.deleteClient(oldRecord['id'] as String);
        break;

      case PostgresChangeEvent.update:
        final updatedClient = payload.newRecord;
        final index =
            _clients.indexWhere((c) => c['id'] == updatedClient['id']);
        if (index != -1) {
          _clients[index] = updatedClient;
          notifyListeners();

          _localDb.insertClientLocally({
            ...updatedClient,
            'is_synced': 1,
          });
        }
        break;

      default:
        break;
    }
  }

  @override
  void dispose() {
    _subscription?.unsubscribe();
    _localDb.close();
    super.dispose();
  }
}