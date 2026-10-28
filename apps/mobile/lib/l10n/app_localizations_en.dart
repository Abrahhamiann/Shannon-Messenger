// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get tagline => 'Private conversations,\nfor a more open world.';

  @override
  String get privacyFeatures =>
      'Private by design.\nYou control your data.\nNo phone number needed.';

  @override
  String get signUp => 'Sign Up';

  @override
  String get existingAccount => 'Already Have an Account?';

  @override
  String get earlyAccess =>
      'Early access · Messaging and calls are not available yet.';

  @override
  String get createAccount => 'Create your account';

  @override
  String get createSubtitle => 'A few details to get you started on Shannon.';

  @override
  String get nickname => 'Nickname';

  @override
  String get username => 'Username (optional)';

  @override
  String get usernameHelp =>
      'Availability is checked when you create your account.';

  @override
  String get choosePhoto => 'Choose photo (optional)';

  @override
  String get localProfile =>
      'No phone number needed. Your nickname and photo stay on this device. Username discovery is off until you enable it in Contact privacy.';

  @override
  String get recoveryWarning =>
      'Account recovery is not available yet. Keep this app and its data: losing your device or clearing app data can permanently lose your account.';

  @override
  String get consent => 'I understand and want to continue.';

  @override
  String get createAction => 'Create account';

  @override
  String get connecting => 'Connecting to Shannon…';

  @override
  String get checkConnection => 'Check connection';

  @override
  String get yourAccount => 'Your account';

  @override
  String get welcomeBack => 'Welcome back';

  @override
  String get continueAccount => 'Continue with identity on this device';

  @override
  String get appLock => 'App Lock';

  @override
  String get enableAppLock => 'Enable App Lock';

  @override
  String get lockDescription =>
      'Protect Shannon with your fingerprint or device PIN, pattern, or password. This does not recover or sign in to your account.';

  @override
  String get lockLaunch => 'Always locked on a fresh app launch.';

  @override
  String get setDeviceLock => 'Set up a device screen lock first.';

  @override
  String get lockAfter => 'Lock after leaving Shannon';

  @override
  String get immediately => 'Immediately';

  @override
  String get thirtySeconds => '30 seconds';

  @override
  String get oneMinute => '1 minute';

  @override
  String get fiveMinutes => '5 minutes';

  @override
  String get lockNow => 'Lock now';

  @override
  String get language => 'Language';

  @override
  String get languageNote =>
      'Onboarding and App Lock are translated. Other screens currently use English.';

  @override
  String get nicknameRequired => 'Enter a nickname to continue.';

  @override
  String get photoUnavailable =>
      'Photo unavailable. Choose a smaller image or skip it.';
}
