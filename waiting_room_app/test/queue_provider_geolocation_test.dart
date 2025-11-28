import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:geolocator/geolocator.dart';
import 'package:waiting_room_app/queue_provider.dart';

import 'mocks.mocks.dart';

void main() {
  group('QueueProvider - Geolocation Tests', () {
    late MockGeolocationService mockGeoService;
    late MockLocalQueueService mockLocalDb;
    late QueueProvider provider;

    setUp(() {
      mockGeoService = MockGeolocationService();
      mockLocalDb = MockLocalQueueService();
      
      // Configuration par défaut des mocks
      when(mockLocalDb.getClients()).thenAnswer((_) async => []);
      when(mockLocalDb.getUnsyncedClients()).thenAnswer((_) async => []);
      when(mockLocalDb.insertClientLocally(any)).thenAnswer((_) async => {});
      
      provider = QueueProvider(
        localDb: mockLocalDb,
        geoService: mockGeoService,
      );
    });

    test('addClient enregistre le client avec géolocalisation', () async {
      // Arrange : Mock de la position
      final mockPosition = Position(
        latitude: 37.7749,
        longitude: -122.4194,
        timestamp: DateTime.now(),
        accuracy: 5.0,
        altitude: 0.0,
        altitudeAccuracy: 0.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      when(mockGeoService.getCurrentPosition())
          .thenAnswer((_) async => mockPosition);

      // Act : Ajouter un client
      await provider.addClient('Alice');

      // Assert : Vérifier que la position a été capturée
      expect(provider.clients.length, 1);
      final client = provider.clients.first;
      
      expect(client['name'], 'Alice');
      expect(client['lat'], 37.7749);
      expect(client['lng'], -122.4194);
      expect(client['is_synced'], 0);
      
      // Vérifier que insertClientLocally a été appelé
      verify(mockLocalDb.insertClientLocally(any)).called(1);
    });

    test('addClient gère l\'absence de géolocalisation', () async {
      // Arrange : Pas de position disponible
      when(mockGeoService.getCurrentPosition())
          .thenAnswer((_) async => null);

      // Act
      await provider.addClient('Bob');

      // Assert : Le client est créé avec lat/lng null
      expect(provider.clients.length, 1);
      final client = provider.clients.first;
      
      expect(client['name'], 'Bob');
      expect(client['lat'], isNull);
      expect(client['lng'], isNull);
    });

    test('addClient génère un ID unique', () async {
      // Arrange
      when(mockGeoService.getCurrentPosition())
          .thenAnswer((_) async => null);

      // Act : Ajouter deux clients
      await provider.addClient('Client 1');
      await provider.addClient('Client 2');

      // Assert : Les IDs sont différents
      expect(provider.clients.length, 2);
      final id1 = provider.clients[0]['id'];
      final id2 = provider.clients[1]['id'];
      
      expect(id1, isNotNull);
      expect(id2, isNotNull);
      expect(id1, isNot(equals(id2)));
    });

    test('addClient trie les clients par date de création', () async {
      // Arrange
      when(mockGeoService.getCurrentPosition())
          .thenAnswer((_) async => null);

      // Act : Ajouter plusieurs clients avec délais
      await provider.addClient('Premier');
      await Future.delayed(const Duration(milliseconds: 10));
      await provider.addClient('Deuxième');
      await Future.delayed(const Duration(milliseconds: 10));
      await provider.addClient('Troisième');

      // Assert : Ordre chronologique
      expect(provider.clients[0]['name'], 'Premier');
      expect(provider.clients[1]['name'], 'Deuxième');
      expect(provider.clients[2]['name'], 'Troisième');
    });

    test('addClient marque le client comme non synchronisé', () async {
      // Arrange
      when(mockGeoService.getCurrentPosition())
          .thenAnswer((_) async => null);

      // Act
      await provider.addClient('Test User');

      // Assert
      final client = provider.clients.first;
      expect(client['is_synced'], 0);
    });

    test('addClient utilise l\'heure actuelle pour created_at', () async {
      // Arrange
      when(mockGeoService.getCurrentPosition())
          .thenAnswer((_) async => null);
      
      final beforeAdd = DateTime.now();

      // Act
      await provider.addClient('Time Test');

      // Assert
      final client = provider.clients.first;
      final createdAt = DateTime.parse(client['created_at']);
      
      expect(createdAt.isAfter(beforeAdd.subtract(const Duration(seconds: 1))), isTrue);
      expect(createdAt.isBefore(DateTime.now().add(const Duration(seconds: 1))), isTrue);
    });

    test('addClient avec coordonnées GPS de Paris', () async {
      // Arrange : Position GPS de Paris
      final parisPosition = Position(
        latitude: 48.8566,
        longitude: 2.3522,
        timestamp: DateTime.now(),
        accuracy: 10.0,
        altitude: 35.0,
        altitudeAccuracy: 5.0,
        heading: 0.0,
        headingAccuracy: 0.0,
        speed: 0.0,
        speedAccuracy: 0.0,
      );

      when(mockGeoService.getCurrentPosition())
          .thenAnswer((_) async => parisPosition);

      // Act
      await provider.addClient('Parisian');

      // Assert
      final client = provider.clients.first;
      expect(client['lat'], 48.8566);
      expect(client['lng'], 2.3522);
    });

    test('addClient avec nom vide', () async {
      // Arrange
      when(mockGeoService.getCurrentPosition())
          .thenAnswer((_) async => null);

      // Act
      await provider.addClient('');

      // Assert : Le client est quand même créé
      expect(provider.clients.length, 1);
      expect(provider.clients.first['name'], '');
    });

    test('nextClient retourne et retire le premier client', () async {
      // Arrange
      when(mockGeoService.getCurrentPosition())
          .thenAnswer((_) async => null);
      
      await provider.addClient('Client 1');
      await provider.addClient('Client 2');

      // Act
      final next = provider.nextClient();

      // Assert
      expect(next, isNotNull);
      expect(next!['name'], 'Client 1');
      expect(provider.clients.length, 1);
      expect(provider.clients.first['name'], 'Client 2');
    });

    test('nextClient retourne null si la file est vide', () {
      // Act
      final next = provider.nextClient();

      // Assert
      expect(next, isNull);
      expect(provider.clients.length, 0);
    });
  });
}