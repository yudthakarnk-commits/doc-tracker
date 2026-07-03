import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../config.dart';
import '../i18n.dart';
import '../models/doc_record.dart';
import '../services/data_service.dart';
import 'widgets/driver_qr_dialog.dart';

final _numFmt = NumberFormat('#,##0');

class TransportScreen extends StatefulWidget {
  const TransportScreen({super.key});

  @override
  State<TransportScreen> createState() => _TransportScreenState();
}

class _TransportScreenState extends State<TransportScreen> {
  int? _week;
  String? _hatchery;

  @override
  Widget build(BuildContext context) {
    final svc = DataService.instance;
    return AnimatedBuilder(
      animation: svc,
      builder: (context, _) {
        if (svc.loading && svc.records.isEmpty) {
          return const Center(child: CircularProgressIndicator());
        }
        final weeks = svc.weeksByRecency();
        if (weeks.isEmpty) return Center(child: Text(tr('noData')));

        final currentWeek = isoWeek(DateTime.now());
        final selWeek = _week ??
            (weeks.contains(currentWeek) ? currentWeek : weeks.first);

        var rows = svc.records.where((r) => r.weekNo == selWeek).toList();
        if (_hatchery != null) {
          rows = rows.where((r) => r.hatchery == _hatchery).toList();
        }
        // Transport view: only records with delivery info
        final trips = rows
            .where((r) =>
                (r.truckPlate ?? '').isNotEmpty ||
                (r.departureTime ?? '').isNotEmpty ||
                (r.location ?? '').isNotEmpty)
            .toList()
          ..sort((a, b) {
            final d = b.recordDate.compareTo(a.recordDate);
            if (d != 0) return d;
            return (a.departureTime ?? '').compareTo(b.departureTime ?? '');
          });

        final delivered = rows.fold<int>(0, (s, r) => s + r.totalActual);
        final doa = rows.fold<int>(0, (s, r) => s + (r.doaCount ?? 0));
        final doaRate = delivered > 0 ? doa / delivered * 100 : 0.0;

        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Filters ──
            Row(children: [
              Expanded(
                child: DropdownButtonFormField<int>(
                  value: selWeek,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: weeks
                      .map((w) =>
                          DropdownMenuItem(value: w, child: Text('Week $w')))
                      .toList(),
                  onChanged: (v) => setState(() => _week = v),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: DropdownButtonFormField<String?>(
                  value: _hatchery,
                  isExpanded: true,
                  decoration: const InputDecoration(
                      isDense: true,
                      contentPadding:
                          EdgeInsets.symmetric(horizontal: 12, vertical: 10)),
                  items: [
                    DropdownMenuItem<String?>(
                        value: null, child: Text(tr('allHatcheries'))),
                    for (final h in AppConfig.hatcheries)
                      DropdownMenuItem<String?>(value: h, child: Text(h)),
                  ],
                  onChanged: (v) => setState(() => _hatchery = v),
                ),
              ),
            ]),
            const SizedBox(height: 14),
            // ── KPI row ──
            Row(children: [
              _kpi('🚚', tr('kpiTrips'), _numFmt.format(trips.length),
                  const Color(0xFF6366F1)),
              const SizedBox(width: 10),
              _kpi('💀', tr('kpiDOA'), _numFmt.format(doa),
                  const Color(0xFFDC2626)),
              const SizedBox(width: 10),
              _kpi(
                  '📉',
                  tr('kpiDoaRate'),
                  '${doaRate.toStringAsFixed(2)}%',
                  doaRate > 0.5
                      ? const Color(0xFFDC2626)
                      : const Color(0xFF059669)),
            ]),
            const SizedBox(height: 14),
            if (trips.isEmpty)
              Padding(
                padding: const EdgeInsets.all(32),
                child: Center(
                    child: Text(tr('noTruckData'),
                        style: TextStyle(color: Colors.grey.shade500))),
              )
            else
              ...trips.map((r) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _TripCard(record: r),
                  )),
            const SizedBox(height: 24),
          ],
        );
      },
    );
  }

  Widget _kpi(String emoji, String label, String value, Color color) =>
      Expanded(
        child: Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$emoji $label',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Colors.grey.shade600)),
                const SizedBox(height: 4),
                Text(value,
                    style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: color)),
              ],
            ),
          ),
        ),
      );
}

class _TripCard extends StatelessWidget {
  final DocRecord record;
  const _TripCard({required this.record});

  @override
  Widget build(BuildContext context) {
    final r = record;
    final status = r.deliveryStatus ?? '';
    final (statusLabel, statusColor, statusBg) = switch (status) {
      'departed' => (
          tr('statusDeparted'),
          const Color(0xFF9A3412),
          const Color(0xFFFED7AA)
        ),
      'arrived' => (
          tr('statusArrived'),
          const Color(0xFF166534),
          const Color(0xFFBBF7D0)
        ),
      _ => (
          tr('statusPending'),
          const Color(0xFF475569),
          const Color(0xFFE2E8F0)
        ),
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text(r.customerName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                        fontSize: 15, fontWeight: FontWeight.w700)),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 9, vertical: 2),
                decoration: BoxDecoration(
                    color: statusBg,
                    borderRadius: BorderRadius.circular(999)),
                child: Text(statusLabel,
                    style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: statusColor)),
              ),
            ]),
            const SizedBox(height: 6),
            Text('📅 ${r.recordDate}   🏭 ${r.hatchery}',
                style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            const SizedBox(height: 8),
            Wrap(spacing: 14, runSpacing: 4, children: [
              if ((r.truckPlate ?? '').isNotEmpty)
                _info('🚛', r.truckPlate!),
              if ((r.departureTime ?? '').isNotEmpty)
                _info('🕐',
                    '${tr('depTime')} ${r.departureTime!.length >= 5 ? r.departureTime!.substring(0, 5) : r.departureTime!}'),
              if (r.distanceKm != null)
                _info('📏', '~${r.distanceKm!.toStringAsFixed(1)} km'),
              _info('🐣', _numFmt.format(r.totalActual)),
              if ((r.doaCount ?? 0) > 0) _info('💀', 'DOA ${r.doaCount}'),
            ]),
            if ((r.location ?? '').isNotEmpty) ...[
              const SizedBox(height: 6),
              Text('📍 ${r.location}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style:
                      TextStyle(fontSize: 12, color: Colors.grey.shade600)),
            ],
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => showDriverQrDialog(context, r),
                icon: const Icon(Icons.qr_code_2, size: 18),
                label: Text(tr('driverQr'),
                    style: const TextStyle(fontSize: 12)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _info(String emoji, String text) => Text('$emoji $text',
      style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600));
}
