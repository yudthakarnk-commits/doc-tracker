import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:share_plus/share_plus.dart';
import '../../i18n.dart';
import '../../models/doc_record.dart';

/// Same link format the web app generates: ?drv={id}&tk={driver_token}
const _appBase = 'https://yudthakarnk-commits.github.io/doc-tracker/';

void showDriverQrDialog(BuildContext context, DocRecord r) {
  if (r.id == null || (r.driverToken ?? '').isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tr('noDriverToken'))));
    return;
  }
  showDialog(
    context: context,
    builder: (_) => _DriverQrDialog(record: r),
  );
}

class _DriverQrDialog extends StatefulWidget {
  final DocRecord record;
  const _DriverQrDialog({required this.record});

  @override
  State<_DriverQrDialog> createState() => _DriverQrDialogState();
}

class _DriverQrDialogState extends State<_DriverQrDialog> {
  final _qrKey = GlobalKey();
  bool _busy = false;

  String get _url =>
      '$_appBase?drv=${widget.record.id}&tk=${widget.record.driverToken}';

  String get _shareText {
    final r = widget.record;
    return '🐣 DOC Tracker — Driver Update\n'
        '${r.customerName}\n'
        '📅 ${r.recordDate} · 🏭 ${r.hatchery}'
        '${(r.doNumber ?? '').isNotEmpty ? ' · DO# ${r.doNumber}' : ''}\n'
        '$_url';
  }

  Future<void> _copyLink() async {
    await Clipboard.setData(ClipboardData(text: _url));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(tr('copied'))));
    }
  }

  /// Captures the white-padded QR widget as a PNG and opens the system
  /// share sheet (which also allows saving to Files/Photos/Drive).
  Future<void> _share() async {
    setState(() => _busy = true);
    try {
      final boundary = _qrKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) return;
      final image = await boundary.toImage(pixelRatio: 3);
      final bytes =
          await image.toByteData(format: ui.ImageByteFormat.png);
      if (bytes == null) return;
      final dir = await getTemporaryDirectory();
      final file = File(
          '${dir.path}/driver-qr-${widget.record.id}.png');
      await file.writeAsBytes(bytes.buffer.asUint8List());
      await Share.shareXFiles([XFile(file.path)], text: _shareText);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('❌ $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = widget.record;
    return AlertDialog(
      title: Row(children: [
        const Icon(Icons.qr_code_2),
        const SizedBox(width: 8),
        Expanded(
            child:
                Text(tr('driverQr'), style: const TextStyle(fontSize: 17))),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            RepaintBoundary(
              key: _qrKey,
              child: Container(
                padding: const EdgeInsets.all(14),
                color: Colors.white,
                child: Column(mainAxisSize: MainAxisSize.min, children: [
                  QrImageView(
                    data: _url,
                    version: QrVersions.auto,
                    size: 210,
                    errorCorrectionLevel: QrErrorCorrectLevel.L,
                  ),
                  const SizedBox(height: 8),
                  Text(r.customerName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.black,
                          fontSize: 13,
                          fontWeight: FontWeight.w700)),
                  Text('${r.recordDate} · ${r.hatchery}',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                          color: Colors.black54, fontSize: 11)),
                ]),
              ),
            ),
            const SizedBox(height: 10),
            Text(tr('driverQrHint'),
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _busy ? null : _copyLink,
                  icon: const Icon(Icons.copy, size: 16),
                  label: Text(tr('copyLink'),
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy ? null : _share,
                  icon: _busy
                      ? const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.share, size: 16),
                  label: Text(tr('share'),
                      style: const TextStyle(fontSize: 12)),
                ),
              ),
            ]),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tr('close'))),
      ],
    );
  }
}
