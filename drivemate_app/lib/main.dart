import 'package:flutter/material.dart';

import 'app.dart';
import 'firebase_options.dart';
import 'services/fcm_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Initialize Firebase
  await DefaultFirebaseOptions.initialize();
  
  // Initialize FCM service
  await FCMService.instance.initialize();
  
  runApp(const DriveMateApp());
}
