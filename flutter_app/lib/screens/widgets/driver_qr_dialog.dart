import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
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
  final url = '$_appBase?drv=${r.id}&tk=${r.driverToken}';

  showDialog(
    context: context,
    builder: (c) => AlertDialog(
      title: Row(children: [
        const Icon(Icons.qr_code_2),
        const SizedBox(width: 8),
        Expanded(
            child: Text(tr('driverQr'),
                style: const TextStyle(fontSize: 17))),
      ]),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                size: 220,
                errorCorrectionLevel: QrErrorCorrectLevel.L,
              ),
            ),
            const SizedBox(height: 12),
            Text(r.customerName,
                textAlign: TextAlign.center,
                style: const TextStyle(
                    fontSize: 14, fontWeight: FontWeight.w700)),
            Text('${r.recordDate} · ${r.hatchery}',
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Text(tr('driverQrHint'),
                textAlign: TextAlign.center,
                style:
                    TextStyle(fontSize: 11.5, color: Colors.grey.shade600)),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(c), child: Text(tr('close'))),
      ],
    ),
  );
}
