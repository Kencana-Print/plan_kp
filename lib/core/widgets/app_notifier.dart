import 'dart:async';

import 'package:awesome_dialog/awesome_dialog.dart';
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import '../utils/date_formatter.dart';

typedef AppConfirmCallback = FutureOr<void> Function();

class AppNotifier {
  AppNotifier._();

  static const Duration _successSnackDuration = Duration(milliseconds: 1200);

  static double _dialogWidth(BuildContext context) {
    final screenWidth = MediaQuery.sizeOf(context).width;
    if (screenWidth <= 600) {
      return screenWidth * 0.92;
    }
    return 420;
  }

  static Future<void> showWarning(BuildContext context, String message) async {
    if (!context.mounted) return;
    final formatted = DateFormatter.formatMessageDates(message);
    await AwesomeDialog(
      context: context,
      width: _dialogWidth(context),
      dialogType: DialogType.warning,
      animType: AnimType.scale,
      title: 'Perhatian',
      desc: formatted,
      btnOkColor: AppColors.warning,
      btnOkOnPress: () {},
      headerAnimationLoop: true,
    ).show();
  }

  static Future<void> showError(BuildContext context, String message) async {
    if (!context.mounted) return;
    final formatted = DateFormatter.formatMessageDates(message);
    await AwesomeDialog(
      context: context,
      width: _dialogWidth(context),
      dialogType: DialogType.error,
      animType: AnimType.scale,
      title: 'Terjadi Kesalahan',
      desc: formatted,
      btnOkColor: AppColors.danger,
      btnOkOnPress: () {},
      headerAnimationLoop: true,
    ).show();
  }

  static Future<void> showSuccess(BuildContext context, String message) async {
    if (!context.mounted) return;
    await AwesomeDialog(
      context: context,
      width: _dialogWidth(context),
      dialogType: DialogType.success,
      animType: AnimType.scale,
      title: 'Berhasil',
      desc: message,
      btnOkColor: AppColors.primary,
      btnOkOnPress: () {},
      headerAnimationLoop: true,
    ).show();
  }

  static void showSuccessSnack(
    BuildContext context,
    String message, {
    Duration duration = _successSnackDuration,
  }) {
    if (!context.mounted) return;
    AwesomeDialog(
      context: context,
      width: _dialogWidth(context),
      dialogType: DialogType.success,
      animType: AnimType.scale,
      title: 'Berhasil',
      desc: message,
      btnOkColor: AppColors.primary,
      btnOkOnPress: () {},
      autoHide: duration,
      headerAnimationLoop: false,
    ).show();
  }

  static Future<void> showConfirm(
    BuildContext context, {
    required String title,
    required String message,
    required AppConfirmCallback onConfirm,
  }) async {
    if (!context.mounted) return;
    await AwesomeDialog(
      context: context,
      width: _dialogWidth(context),
      dialogType: DialogType.question,
      animType: AnimType.scale,
      title: title,
      desc: message,
      btnOkColor: AppColors.primary,
      btnCancelColor: AppColors.textSecondary,
      btnOkOnPress: () async {
        await onConfirm();
      },
      btnCancelOnPress: () {},
      headerAnimationLoop: true,
    ).show();
  }
}
