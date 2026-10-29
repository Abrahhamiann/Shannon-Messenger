import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../identity/presentation/identity_controller.dart';

final contactPreferencesProvider =
    AsyncNotifierProvider<ContactPreferences, Map<String, dynamic>>(
      ContactPreferences.new,
    );

class ContactPreferences extends AsyncNotifier<Map<String, dynamic>> {
  static const storage = FlutterSecureStorage(
    aOptions: AndroidOptions(
      resetOnError: false,
      migrateOnAlgorithmChange: false,
      storageNamespace: 'shannon_ui_v1',
    ),
  );
  String? _owner;
  @override
  Future<Map<String, dynamic>> build() async {
    _owner = ref.watch(identityControllerProvider).asData?.value.id;
    if (_owner == null) return {};
    final value = await storage.read(key: 'contacts_$_owner');
    return value == null
        ? {}
        : Map<String, dynamic>.from(jsonDecode(value) as Map);
  }

  Future<void> saveContact(String account, {bool? pinned, String? name}) async {
    final values = Map<String, dynamic>.from(await future);
    if (_owner == null) throw StateError('Identity unavailable');
    if (!values.containsKey(account) && values.length >= 500) {
      throw StateError('Contact preference limit reached');
    }
    final item = Map<String, dynamic>.from(values[account] as Map? ?? {});
    if (pinned != null) item['pinned'] = pinned;
    if (name != null) item['name'] = name.trim().characters.take(64).toString();
    values[account] = item;
    await storage.write(key: 'contacts_$_owner', value: jsonEncode(values));
    if (ref.mounted) state = AsyncData(values);
  }
}

bool contactPinned(Map<String, dynamic> preferences, String account) =>
    preferences[account]?['pinned'] == true;
String contactName(
  Map<String, dynamic> preferences,
  String account,
  String fallback,
) {
  final name = preferences[account]?['name'] as String?;
  return name != null && name.isNotEmpty ? name : fallback;
}
