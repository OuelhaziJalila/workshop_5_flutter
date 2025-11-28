import 'package:mockito/annotations.dart';
import 'package:waiting_room_app/geolocation_service.dart';
import 'package:waiting_room_app/local_queue_service.dart';
import 'package:waiting_room_app/queue_provider.dart';

@GenerateMocks([
  GeolocationService,
  LocalQueueService,
  QueueProvider,
])
void main() {}