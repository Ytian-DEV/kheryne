import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Typed route locations. Screens navigate only through these helpers, so
/// a path typo is a compile error.
abstract final class Routes {
  // Shell branches.
  static const home = '/home';
  static const history = '/history';
  static const gallery = '/gallery';
  static const settings = '/settings';
  static const workspace = '/workspace';
  static const live = '/live';
  static const batchDesktop = '/batch';
  static const keyDesktop = '/key';

  // Nested in branches.
  static String historyDetail(String id) => '/history/$id';
  static String genus(String name) => '/gallery/genus/$name';
  static const settingsModels = '/settings/models';
  static const settingsCalibration = '/settings/calibration';
  static const settingsPrivacy = '/settings/privacy';
  static const settingsAbout = '/settings/about';

  // Full screen.
  static const onboarding = '/onboarding';
  static const scan = '/scan';
  static String zoom(String specimenId, String detectionId) => '/scan/zoom/$specimenId/$detectionId';
  static String captureReview(String specimenId) => '/capture/$specimenId';
  static String editor(String specimenId) => '/editor/$specimenId';
  static String identify(String specimenId) => '/identify/$specimenId';
  static String analysis(String specimenId, String detectionId) => '/analysis/$specimenId/$detectionId';
  static String report(String id) => '/report/$id';
  static String reportPdf(String id) => '/report/$id/pdf';
  static String reportFull(String id) => '/report/$id/full';
  static String measure(String specimenId, {String? reportId}) =>
      reportId == null ? '/measure/$specimenId' : '/measure/$specimenId?report=$reportId';
  static const calibrate = '/calibrate';
  static String key({String? fromReport}) => fromReport == null ? '/tools/key' : '/tools/key?from=$fromReport';
  static const batch = '/tools/batch';
  static const pairPhone = '/pair-phone';
  static String compare(String specimenId, String genus) => '/compare/$specimenId/$genus';
  static const import = '/import';
  static const screenGallery = '/dev/gallery';
  static const components = '/dev/components';
}

extension KNav on BuildContext {
  void goTo(String location) => GoRouter.of(this).go(location);
  Future<T?> pushTo<T>(String location) => GoRouter.of(this).push<T>(location);
}
