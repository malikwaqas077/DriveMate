import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'dart:async';
import 'package:flutter/widgets.dart';

import 'models/student.dart';
import 'models/terms.dart';
import 'models/user_profile.dart';
import 'screens/auth/auth_screen.dart';
import 'screens/auth/profile_setup_screen.dart';
import 'screens/instructor/cancellation_requests_screen.dart';
import 'screens/instructor/instructor_home.dart';
import 'screens/owner/owner_home.dart';
import 'screens/student/student_home.dart';
import 'screens/student/student_lessons_screen.dart';
import 'screens/student/student_terms_screen.dart';
import 'services/auth_service.dart';
import 'services/fcm_service.dart';
import 'services/firestore_service.dart';
import 'theme/app_theme.dart';
import 'widgets/loading_view.dart';

// Global navigator key for navigation from anywhere (including notifications)
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

class DriveMateApp extends StatelessWidget {
  const DriveMateApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Set system UI overlay style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.dark,
        statusBarBrightness: Brightness.light,
        systemNavigationBarColor: Colors.white,
        systemNavigationBarIconBrightness: Brightness.dark,
      ),
    );

    return MaterialApp(
      title: 'DriveMate',
      debugShowCheckedModeBanner: false,
      navigatorKey: navigatorKey,
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: const AuthGate(),
    );
  }
}

class _ErrorStartupScreen extends StatelessWidget {
  const _ErrorStartupScreen({required this.error});

  final String error;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: AppTheme.errorLight,
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.error_outline_rounded,
                  size: 40,
                  color: AppTheme.error,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Oops! Something went wrong',
                style: Theme.of(context).textTheme.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
              Text(
                'We couldn\'t start DriveMate. Please try again.',
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.neutral600,
                    ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Container(
                margin: const EdgeInsets.symmetric(vertical: 16),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppTheme.neutral100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  error,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        fontFamily: 'monospace',
                        color: AppTheme.neutral600,
                      ),
                  textAlign: TextAlign.center,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> with WidgetsBindingObserver {
  final AuthService _authService = AuthService();
  final FirestoreService _firestoreService = FirestoreService();
  String? _lastUserId;
  StreamSubscription<RemoteMessage>? _notificationSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    debugPrint('[Notification] ===== Setting up notification tap listener =====');
    // Listen for notification taps
    _notificationSubscription = FCMService.instance.onNotificationTap.listen(
      (message) {
        debugPrint('[Notification] ===== Stream received message: ${message.messageId} =====');
        debugPrint('[Notification] Message data: ${message.data}');
        _handleNotificationTap(message);
      },
      onError: (error) {
        debugPrint('[Notification] ===== Stream error: $error =====');
      },
      cancelOnError: false,
    );
    debugPrint('[Notification] ===== Notification tap listener set up successfully =====');
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _notificationSubscription?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    debugPrint('[Notification] App lifecycle changed to: $state');
  }

  void _saveFcmToken(String userId) {
    // Only save once per user session
    if (_lastUserId != userId) {
      _lastUserId = userId;
      FCMService.instance.saveTokenForUser(userId);
    }
  }

  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('[Notification] Tap received: ${message.messageId}');
    debugPrint('[Notification] Data: ${message.data}');
    
    final data = message.data;
    final type = data['type'] as String?;
    
    if (type == null) {
      debugPrint('[Notification] No type found in data');
      return;
    }

    debugPrint('[Notification] Type: $type');

    // Wait a bit for the app to be fully loaded, then navigate
    Future.delayed(const Duration(milliseconds: 500), () {
      _navigateFromNotification(type, data);
    });
  }

  void _navigateFromNotification(
    String type,
    Map<String, dynamic> data,
  ) {
    debugPrint('[Notification] Navigating for type: $type');
    
    // Get current user profile to determine role
    final user = _authService.currentUser;
    if (user == null) {
      debugPrint('[Notification] No user found');
      return;
    }

    _firestoreService.getUserProfile(user.uid).then((profile) {
      if (profile == null) {
        debugPrint('[Notification] No profile found for user');
        return;
      }

      debugPrint('[Notification] Profile role: ${profile.role}');

      final navigator = navigatorKey.currentState;
      if (navigator == null) {
        debugPrint('[Notification] Navigator not ready, retrying...');
        // Retry after a delay
        Future.delayed(const Duration(seconds: 1), () {
          _navigateFromNotification(type, data);
        });
        return;
      }

      switch (type) {
        case 'lesson_created':
        case 'lesson_reminder':
        case 'cancellation_response':
        case 'instructor_notification':
          // Navigate to student lessons screen
          if (profile.role == 'student') {
            debugPrint('[Notification] Navigating to StudentHome');
            navigator.push(
              MaterialPageRoute(
                builder: (context) => StudentHome(profile: profile),
              ),
            );
          }
          break;

        case 'cancellation_request':
          // Navigate to instructor cancellation requests screen
          if (profile.role == 'instructor') {
            debugPrint('[Notification] Navigating to CancellationRequestsScreen');
            navigator.push(
              MaterialPageRoute(
                builder: (context) => CancellationRequestsScreen(
                  instructor: profile,
                ),
              ),
            );
          }
          break;

        case 'reflection_added':
          // Navigate to instructor calendar screen
          if (profile.role == 'instructor') {
            debugPrint('[Notification] Navigating to InstructorHome');
            navigator.push(
              MaterialPageRoute(
                builder: (context) => InstructorHome(profile: profile),
              ),
            );
          }
          break;

        default:
          debugPrint('[Notification] Unknown notification type: $type');
      }
    }).catchError((error) {
      debugPrint('[Notification] Error navigating: $error');
    });
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authService.authStateChanges,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(
            message: 'Checking session...',
            showLogo: true,
          );
        }
        final user = snapshot.data;
        if (user == null) {
          _lastUserId = null;
          return const AuthScreen();
        }
        return StreamBuilder<UserProfile?>(
          stream: _firestoreService.streamUserProfile(user.uid),
          builder: (context, profileSnapshot) {
            if (profileSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(
                message: 'Loading profile...',
                showLogo: true,
              );
            }
            final profile = profileSnapshot.data;
            if (profile == null) {
              return ProfileSetupScreen(
                uid: user.uid,
                email: user.email ?? '',
              );
            }
            
            // Save FCM token for the authenticated user
            _saveFcmToken(profile.id);
            if (profile.role == 'student' && profile.studentId == null) {
              return FutureBuilder<String?>(
                future: _firestoreService.findStudentIdByEmail(profile.email),
                builder: (context, linkSnapshot) {
                  if (linkSnapshot.connectionState == ConnectionState.waiting) {
                    return const LoadingView(
                      message: 'Linking student profile...',
                      showLogo: true,
                    );
                  }
                  final studentId = linkSnapshot.data;
                  if (studentId != null) {
                    _firestoreService.updateUserProfile(profile.id, {
                      'studentId': studentId,
                    });
                  }
                  return StudentAccessGate(
                    profile: profile.copyWith(studentId: studentId),
                  );
                },
              );
            }
            if (profile.role == 'instructor') {
              if (profile.schoolId == null || profile.schoolId!.isEmpty) {
                return FutureBuilder<String>(
                  future: _firestoreService.ensurePersonalSchool(
                    instructor: profile,
                  ),
                  builder: (context, schoolSnapshot) {
                    if (schoolSnapshot.connectionState ==
                        ConnectionState.waiting) {
                      return const LoadingView(
                        message: 'Setting up your school...',
                        showLogo: true,
                      );
                    }
                    final schoolId = schoolSnapshot.data;
                    return InstructorHome(
                      profile: profile.copyWith(schoolId: schoolId),
                    );
                  },
                );
              }
              return InstructorHome(profile: profile);
            }
            if (profile.role == 'owner') {
              return OwnerHome(profile: profile);
            }
            return StudentAccessGate(profile: profile);
          },
        );
      },
    );
  }
}

extension on UserProfile {
  UserProfile copyWith({
    String? studentId,
    String? schoolId,
    String? fcmToken,
    CancellationPolicy? cancellationPolicy,
    int? reminderHoursBefore,
  }) {
    return UserProfile(
      id: id,
      role: role,
      name: name,
      email: email,
      schoolId: schoolId ?? this.schoolId,
      studentId: studentId ?? this.studentId,
      acceptedTermsVersion: acceptedTermsVersion,
      acceptedTermsAt: acceptedTermsAt,
      fcmToken: fcmToken ?? this.fcmToken,
      cancellationPolicy: cancellationPolicy ?? this.cancellationPolicy,
      reminderHoursBefore: reminderHoursBefore ?? this.reminderHoursBefore,
    );
  }
}

class StudentAccessGate extends StatelessWidget {
  StudentAccessGate({super.key, required this.profile});

  final UserProfile profile;
  final FirestoreService _firestoreService = FirestoreService();

  @override
  Widget build(BuildContext context) {
    final studentId = profile.studentId;
    if (studentId == null) {
      return StudentHome(profile: profile);
    }
    return StreamBuilder<Student?>(
      stream: _firestoreService.streamStudentById(studentId),
      builder: (context, studentSnapshot) {
        if (studentSnapshot.connectionState == ConnectionState.waiting) {
          return const LoadingView(
            message: 'Loading student details...',
            showLogo: true,
          );
        }
        final student = studentSnapshot.data;
        if (student == null) {
          return StudentHome(profile: profile);
        }
        final schoolId = student.schoolId ?? '';
        if (schoolId.isEmpty) {
          return StudentHome(profile: profile);
        }
        return StreamBuilder<Terms?>(
          stream: _firestoreService.streamTermsForSchool(schoolId),
          builder: (context, termsSnapshot) {
            if (termsSnapshot.connectionState == ConnectionState.waiting) {
              return const LoadingView(
                message: 'Loading terms...',
                showLogo: true,
              );
            }
            final terms = termsSnapshot.data;
            if (terms == null || terms.text.trim().isEmpty) {
              return StudentHome(profile: profile);
            }
            final acceptedVersion = profile.acceptedTermsVersion ?? 0;
            if (acceptedVersion >= terms.version) {
              return StudentHome(profile: profile);
            }
            return StudentTermsScreen(profile: profile, terms: terms);
          },
        );
      },
    );
  }
}
