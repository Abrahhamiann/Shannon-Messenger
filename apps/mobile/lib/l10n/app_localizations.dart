import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_hy.dart';
import 'app_localizations_ru.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('hy'),
    Locale('ru'),
  ];

  /// No description provided for @tagline.
  ///
  /// In en, this message translates to:
  /// **'Private conversations,\nfor a more open world.'**
  String get tagline;

  /// No description provided for @privacyFeatures.
  ///
  /// In en, this message translates to:
  /// **'Private by design.\nYou control your data.\nNo phone number needed.'**
  String get privacyFeatures;

  /// No description provided for @signUp.
  ///
  /// In en, this message translates to:
  /// **'Sign Up'**
  String get signUp;

  /// No description provided for @existingAccount.
  ///
  /// In en, this message translates to:
  /// **'Already Have an Account?'**
  String get existingAccount;

  /// No description provided for @earlyAccess.
  ///
  /// In en, this message translates to:
  /// **'Early access · Messaging and calls are not available yet.'**
  String get earlyAccess;

  /// No description provided for @createAccount.
  ///
  /// In en, this message translates to:
  /// **'Create your account'**
  String get createAccount;

  /// No description provided for @createSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A few details to get you started on Shannon.'**
  String get createSubtitle;

  /// No description provided for @nickname.
  ///
  /// In en, this message translates to:
  /// **'Nickname'**
  String get nickname;

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username (optional)'**
  String get username;

  /// No description provided for @usernameHelp.
  ///
  /// In en, this message translates to:
  /// **'Availability is checked when you create your account.'**
  String get usernameHelp;

  /// No description provided for @choosePhoto.
  ///
  /// In en, this message translates to:
  /// **'Choose photo (optional)'**
  String get choosePhoto;

  /// No description provided for @localProfile.
  ///
  /// In en, this message translates to:
  /// **'No phone number needed. Your nickname and photo stay on this device. Username discovery is off until you enable it in Contact privacy.'**
  String get localProfile;

  /// No description provided for @recoveryWarning.
  ///
  /// In en, this message translates to:
  /// **'Account recovery is not available yet. Keep this app and its data: losing your device or clearing app data can permanently lose your account.'**
  String get recoveryWarning;

  /// No description provided for @consent.
  ///
  /// In en, this message translates to:
  /// **'I understand and want to continue.'**
  String get consent;

  /// No description provided for @createAction.
  ///
  /// In en, this message translates to:
  /// **'Create account'**
  String get createAction;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting to Shannon…'**
  String get connecting;

  /// No description provided for @checkConnection.
  ///
  /// In en, this message translates to:
  /// **'Check connection'**
  String get checkConnection;

  /// No description provided for @yourAccount.
  ///
  /// In en, this message translates to:
  /// **'Your account'**
  String get yourAccount;

  /// No description provided for @welcomeBack.
  ///
  /// In en, this message translates to:
  /// **'Welcome back'**
  String get welcomeBack;

  /// No description provided for @continueAccount.
  ///
  /// In en, this message translates to:
  /// **'Continue with identity on this device'**
  String get continueAccount;

  /// No description provided for @appLock.
  ///
  /// In en, this message translates to:
  /// **'App Lock'**
  String get appLock;

  /// No description provided for @enableAppLock.
  ///
  /// In en, this message translates to:
  /// **'Enable App Lock'**
  String get enableAppLock;

  /// No description provided for @lockDescription.
  ///
  /// In en, this message translates to:
  /// **'Protect Shannon with your fingerprint or device PIN, pattern, or password. This does not recover or sign in to your account.'**
  String get lockDescription;

  /// No description provided for @lockLaunch.
  ///
  /// In en, this message translates to:
  /// **'Always locked on a fresh app launch.'**
  String get lockLaunch;

  /// No description provided for @setDeviceLock.
  ///
  /// In en, this message translates to:
  /// **'Set up a device screen lock first.'**
  String get setDeviceLock;

  /// No description provided for @lockAfter.
  ///
  /// In en, this message translates to:
  /// **'Lock after leaving Shannon'**
  String get lockAfter;

  /// No description provided for @immediately.
  ///
  /// In en, this message translates to:
  /// **'Immediately'**
  String get immediately;

  /// No description provided for @thirtySeconds.
  ///
  /// In en, this message translates to:
  /// **'30 seconds'**
  String get thirtySeconds;

  /// No description provided for @oneMinute.
  ///
  /// In en, this message translates to:
  /// **'1 minute'**
  String get oneMinute;

  /// No description provided for @fiveMinutes.
  ///
  /// In en, this message translates to:
  /// **'5 minutes'**
  String get fiveMinutes;

  /// No description provided for @lockNow.
  ///
  /// In en, this message translates to:
  /// **'Lock now'**
  String get lockNow;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @languageNote.
  ///
  /// In en, this message translates to:
  /// **'Onboarding and App Lock are translated. Other screens currently use English.'**
  String get languageNote;

  /// No description provided for @nicknameRequired.
  ///
  /// In en, this message translates to:
  /// **'Enter a nickname to continue.'**
  String get nicknameRequired;

  /// No description provided for @photoUnavailable.
  ///
  /// In en, this message translates to:
  /// **'Photo unavailable. Choose a smaller image or skip it.'**
  String get photoUnavailable;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'hy', 'ru'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'hy':
      return AppLocalizationsHy();
    case 'ru':
      return AppLocalizationsRu();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
