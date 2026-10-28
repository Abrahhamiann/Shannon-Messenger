import 'package:flutter_riverpod/flutter_riverpod.dart';

class PendingInvitation extends Notifier<String?> {
  @override
  String? build() => null;
  void save(String? token) => state = token;
}

final pendingInvitationProvider = NotifierProvider<PendingInvitation, String?>(
  PendingInvitation.new,
);
