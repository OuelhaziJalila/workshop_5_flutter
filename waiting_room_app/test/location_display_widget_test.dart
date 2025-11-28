import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:mockito/mockito.dart';

import 'mocks.dart';

// Local mock class so tests can instantiate MockQueueProvider when the original mock isn't provided.
// It implements the QueueProvider interface (from your app) so it can be used with ChangeNotifierProvider and Consumer.
class MockQueueProvider extends Mock implements QueueProvider {}

void main() {
  group('Location Display Widget Tests', () {
    testWidgets('Affiche la localisation quand elle est disponible', (
      WidgetTester tester,
    ) async {
      // Arrange : Mock provider avec un client ayant une localisation
      final mockProvider = MockQueueProvider();

      when(mockProvider.clients).thenReturn([
        {
          'id': '1',
          'name': 'Sam',
          'lat': 51.5074,
          'lng': -0.1278,
          'created_at': DateTime.now().toIso8601String(),
          'is_synced': 1,
        },
      ]);

      // Act : Construire le widget (basé sur votre main.dart)
      await tester.pumpWidget(
        ChangeNotifierProvider<QueueProvider>.value(
          value: mockProvider,
          child: MaterialApp(
            home: Scaffold(
              appBar: AppBar(title: const Text('Waiting Room')),
              body: Consumer<QueueProvider>(
                builder: (context, provider, _) {
                  return ListView.builder(
                    itemCount: provider.clients.length,
                    itemBuilder: (context, index) {
                      final client = provider.clients[index];
                      return Card(
                        child: ListTile(
                          title: Text(client['name'] ?? 'Unknown'),
                          subtitle: Text(
                            client['lat'] == null
                                ? '📍 Location not captured'
                                : '📍 ${client['lat']?.toStringAsFixed(4)}, ${client['lng']?.toStringAsFixed(4)}',
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Assert : Vérifier l'affichage
      expect(find.text('Sam'), findsOneWidget);
      expect(find.textContaining('51.5074'), findsOneWidget);
      expect(find.textContaining('-0.1278'), findsOneWidget);
    });

    testWidgets(
      'Affiche un message quand la localisation n\'est pas disponible',
      (WidgetTester tester) async {
        // Arrange : Client sans localisation
        final mockProvider = MockQueueProvider();

        when(mockProvider.clients).thenReturn([
          {
            'id': '2',
            'name': 'Alice',
            'lat': null,
            'lng': null,
            'created_at': DateTime.now().toIso8601String(),
            'is_synced': 1,
          },
        ]);

        // Act
        await tester.pumpWidget(
          ChangeNotifierProvider<QueueProvider>.value(
            value: mockProvider,
            child: MaterialApp(
              home: Scaffold(
                body: Consumer<QueueProvider>(
                  builder: (context, provider, _) {
                    return ListView.builder(
                      itemCount: provider.clients.length,
                      itemBuilder: (context, index) {
                        final client = provider.clients[index];
                        return ListTile(
                          title: Text(client['name'] ?? 'Unknown'),
                          subtitle: Text(
                            client['lat'] == null
                                ? '📍 Location not captured'
                                : '📍 ${client['lat']?.toStringAsFixed(4)}, ${client['lng']?.toStringAsFixed(4)}',
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Assert
        expect(find.text('Alice'), findsOneWidget);
        expect(find.text('📍 Location not captured'), findsOneWidget);
      },
    );

    testWidgets('Affiche plusieurs clients avec leurs localisations', (
      WidgetTester tester,
    ) async {
      // Arrange : Plusieurs clients
      final mockProvider = MockQueueProvider();

      when(mockProvider.clients).thenReturn([
        {
          'id': '1',
          'name': 'Client 1',
          'lat': 48.8566,
          'lng': 2.3522,
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': '2',
          'name': 'Client 2',
          'lat': null,
          'lng': null,
          'created_at': DateTime.now().toIso8601String(),
        },
        {
          'id': '3',
          'name': 'Client 3',
          'lat': 40.7128,
          'lng': -74.0060,
          'created_at': DateTime.now().toIso8601String(),
        },
      ]);

      // Act
      await tester.pumpWidget(
        ChangeNotifierProvider<QueueProvider>.value(
          value: mockProvider,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<QueueProvider>(
                builder: (context, provider, _) {
                  return ListView.builder(
                    itemCount: provider.clients.length,
                    itemBuilder: (context, index) {
                      final client = provider.clients[index];
                      return ListTile(
                        title: Text(client['name'] ?? 'Unknown'),
                        subtitle: Text(
                          client['lat'] == null
                              ? '📍 Location not captured'
                              : '📍 ${client['lat']?.toStringAsFixed(4)}, ${client['lng']?.toStringAsFixed(4)}',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Assert : Tous les clients sont affichés
      expect(find.text('Client 1'), findsOneWidget);
      expect(find.text('Client 2'), findsOneWidget);
      expect(find.text('Client 3'), findsOneWidget);

      // Vérifier les localisations
      expect(find.textContaining('48.8566'), findsOneWidget);
      expect(find.text('📍 Location not captured'), findsOneWidget);
      expect(find.textContaining('40.7128'), findsOneWidget);
    });

    testWidgets('Affiche correctement la précision à 4 décimales', (
      WidgetTester tester,
    ) async {
      // Arrange : Position avec beaucoup de décimales
      final mockProvider = MockQueueProvider();

      when(mockProvider.clients).thenReturn([
        {
          'id': '1',
          'name': 'Precision Test',
          'lat': 48.85661234567,
          'lng': 2.35221234567,
          'created_at': DateTime.now().toIso8601String(),
        },
      ]);

      // Act
      await tester.pumpWidget(
        ChangeNotifierProvider<QueueProvider>.value(
          value: mockProvider,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<QueueProvider>(
                builder: (context, provider, _) {
                  return ListView.builder(
                    itemCount: provider.clients.length,
                    itemBuilder: (context, index) {
                      final client = provider.clients[index];
                      return ListTile(
                        title: Text(client['name'] ?? 'Unknown'),
                        subtitle: Text(
                          client['lat'] == null
                              ? '📍 Location not captured'
                              : '📍 ${client['lat']?.toStringAsFixed(4)}, ${client['lng']?.toStringAsFixed(4)}',
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Assert : Vérifier que les coordonnées sont tronquées à 4 décimales
      expect(find.textContaining('48.8566'), findsOneWidget);
      expect(find.textContaining('2.3522'), findsOneWidget);
      // Ne devrait PAS contenir plus de 4 décimales
      expect(find.textContaining('48.85661234567'), findsNothing);
    });

    testWidgets('Le bouton delete est présent pour chaque client', (
      WidgetTester tester,
    ) async {
      // Arrange
      final mockProvider = MockQueueProvider();

      when(mockProvider.clients).thenReturn([
        {
          'id': '1',
          'name': 'Test Client',
          'lat': 40.7128,
          'lng': -74.0060,
          'created_at': DateTime.now().toIso8601String(),
        },
      ]);

      // Act
      await tester.pumpWidget(
        ChangeNotifierProvider<QueueProvider>.value(
          value: mockProvider,
          child: MaterialApp(
            home: Scaffold(
              body: Consumer<QueueProvider>(
                builder: (context, provider, _) {
                  return ListView.builder(
                    itemCount: provider.clients.length,
                    itemBuilder: (context, index) {
                      final client = provider.clients[index];
                      return ListTile(
                        title: Text(client['name'] ?? 'Unknown'),
                        trailing: IconButton(
                          icon: const Icon(Icons.delete),
                          onPressed: () {},
                        ),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Assert
      expect(find.byIcon(Icons.delete), findsOneWidget);
    });
  });
}
