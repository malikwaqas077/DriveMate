import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';
import 'services/notification_service.dart';
import 'services/theme_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await DefaultFirebaseOptions.initialize();
  
  // Initialize Notification Service (for heads-up notifications and actions)
  await NotificationService.instance.initialize();
  
  // Initialize FCM service
  await FCMService.instance.initialize();
  
  await ThemeService.instance.ensureLoaded();
  
  runApp(const DriveMateApp());
}
