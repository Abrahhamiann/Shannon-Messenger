// ignore: unused_import
import 'package:intl/intl.dart' as intl;

import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Russian (`ru`).
class AppLocalizationsRu extends AppLocalizations {
  AppLocalizationsRu([String locale = 'ru']) : super(locale);

  @override
  String get tagline => 'Личные разговоры —\nдля более открытого мира.';

  @override
  String get privacyFeatures =>
      'Приватность по замыслу.\nВы управляете своими данными.\nНомер телефона не нужен.';

  @override
  String get signUp => 'Зарегистрироваться';

  @override
  String get existingAccount => 'Уже есть аккаунт?';

  @override
  String get earlyAccess =>
      'Ранний доступ · Сообщения и звонки пока недоступны.';

  @override
  String get createAccount => 'Создайте аккаунт';

  @override
  String get createSubtitle =>
      'Несколько деталей, чтобы начать пользоваться Shannon.';

  @override
  String get nickname => 'Имя';

  @override
  String get username => 'Имя пользователя (необязательно)';

  @override
  String get usernameHelp => 'Доступность проверяется при создании аккаунта.';

  @override
  String get choosePhoto => 'Выбрать фото (необязательно)';

  @override
  String get localProfile =>
      'Номер телефона не нужен. Ваше имя и фото остаются на этом устройстве. Поиск по имени пользователя отключён, пока вы не включите его в настройках приватности контактов.';

  @override
  String get recoveryWarning =>
      'Восстановление аккаунта пока недоступно. Сохраняйте приложение и его данные: потеря устройства или удаление данных может навсегда лишить вас доступа к аккаунту.';

  @override
  String get consent => 'Я понимаю и хочу продолжить.';

  @override
  String get createAction => 'Создать аккаунт';

  @override
  String get connecting => 'Подключение к Shannon…';

  @override
  String get checkConnection => 'Проверить соединение';

  @override
  String get yourAccount => 'Ваш аккаунт';

  @override
  String get welcomeBack => 'С возвращением';

  @override
  String get continueAccount => 'Продолжить с аккаунтом на этом устройстве';

  @override
  String get appLock => 'Блокировка приложения';

  @override
  String get enableAppLock => 'Включить блокировку';

  @override
  String get lockDescription =>
      'Защитите Shannon отпечатком пальца или PIN-кодом, графическим ключом либо паролем устройства. Это не восстанавливает аккаунт и не выполняет вход.';

  @override
  String get lockLaunch => 'Всегда заблокировано при новом запуске приложения.';

  @override
  String get setDeviceLock => 'Сначала настройте блокировку экрана устройства.';

  @override
  String get lockAfter => 'Блокировать после выхода из Shannon';

  @override
  String get immediately => 'Сразу';

  @override
  String get thirtySeconds => '30 секунд';

  @override
  String get oneMinute => '1 минута';

  @override
  String get fiveMinutes => '5 минут';

  @override
  String get lockNow => 'Заблокировать сейчас';

  @override
  String get language => 'Язык';

  @override
  String get languageNote =>
      'Начальная настройка и блокировка приложения переведены. Остальные экраны пока на английском.';

  @override
  String get nicknameRequired => 'Введите имя, чтобы продолжить.';

  @override
  String get photoUnavailable =>
      'Фото недоступно. Выберите изображение поменьше или пропустите этот шаг.';
}
