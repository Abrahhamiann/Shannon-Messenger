import 'package:flutter/widgets.dart';

import 'app_localizations.dart';
import 'app_localizations_en.dart';

// Standalone widget previews use the same English fallback as the application.
AppLocalizations strings(BuildContext context) =>
    Localizations.of<AppLocalizations>(context, AppLocalizations) ??
    AppLocalizationsEn();
