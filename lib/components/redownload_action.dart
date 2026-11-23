import 'package:finamp/components/global_snackbar.dart';
import 'package:finamp/l10n/app_localizations.dart';
import 'package:finamp/models/finamp_models.dart';
import 'package:finamp/services/downloads_service.dart';
import 'package:finamp/services/finamp_user_helper.dart';
import 'package:get_it/get_it.dart';

/// Starts a redownload of the given item and informs the user about the result.
Future<void> startRedownload(DownloadStub stub) async {
  final viewId = GetIt.instance<FinampUserHelper>().currentUser?.currentViewId;
  GlobalSnackbar.message((context) => AppLocalizations.of(context)!.redownloadQueued, isConfirmation: true);
  try {
    await GetIt.instance<DownloadsService>().redownload(stub, viewId);
  } catch (e) {
    GlobalSnackbar.error(e);
  }
}
