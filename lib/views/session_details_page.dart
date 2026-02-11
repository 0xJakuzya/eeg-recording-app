// import 'package:flutter/material.dart';
// import 'package:ble_app/models/processed_session.dart';
// import 'package:ble_app/services/polysomnography_service.dart';

// class SessionDetailsPage extends StatelessWidget {
//   const SessionDetailsPage({
//     super.key,
//     required this.session,
//   });

//   final ProcessedSession session;

//   @override
//   Widget build(BuildContext context) {
//     final prediction = session.prediction;

//     // Пытаемся построить URL для гипнограммы, если известен индекс JSON.
//     Uri? sleepGraphUri;
//     if (session.jsonIndex != null) {
//       final api = PolysomnographyApiService();
//       sleepGraphUri = Uri.parse('${api.baseUrl}/users/sleep_graph').replace(
//         queryParameters: <String, String>{
//           'index': session.jsonIndex.toString(),
//           // При необходимости можно добавить:
//           // 'start_from': '0',
//           // 'end_to': '3600',
//         },
//       );
//     }

//     if (prediction == null || prediction.isEmpty) {
//       return Scaffold(
//         appBar: AppBar(
//           title: Text('Сессия ${session.id}'),
//         ),
//         body: const Center(
//           child: Text('Данных предикта для этой сессии пока нет'),
//         ),
//       );
//     }

//     final List<Widget> children = <Widget>[];

//     // Блок с гипнограммой, если есть индекс.
//     if (sleepGraphUri != null) {
//       children.add(
//         Card(
//           margin: const EdgeInsets.only(bottom: 16),
//           child: Padding(
//             padding: const EdgeInsets.all(12),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   'Гипнограмма',
//                   style: Theme.of(context)
//                       .textTheme
//                       .titleMedium
//                       ?.copyWith(fontWeight: FontWeight.w600),
//                 ),
//                 const SizedBox(height: 8),
//                 AspectRatio(
//                   aspectRatio: 3,
//                   child: Image.network(
//                     sleepGraphUri.toString(),
//                     fit: BoxFit.contain,
//                     errorBuilder: (_, Object error, __) =>
//                         const Text('Ошибка загрузки гипнограммы'),
//                   ),
//                 ),
//               ],
//             ),
//           ),
//         ),
//       );
//     }

//     // Блок со стадиями сна и интервалами.
//     children.addAll(
//       prediction.entries.map((entry) {
//         final stage = entry.key;
//         final intervals = entry.value;

//         final List<Widget> chips = <Widget>[];
//         if (intervals is List) {
//           for (final interval in intervals) {
//             if (interval is List && interval.length == 2) {
//               final start = interval[0];
//               final end = interval[1];
//               chips.add(
//                 Chip(
//                   label: Text('$start–$end c'),
//                 ),
//               );
//             }
//           }
//         }

//         return Card(
//           margin: const EdgeInsets.only(bottom: 12),
//           child: Padding(
//             padding: const EdgeInsets.all(12),
//             child: Column(
//               crossAxisAlignment: CrossAxisAlignment.start,
//               children: [
//                 Text(
//                   stage,
//                   style: Theme.of(context)
//                       .textTheme
//                       .titleMedium
//                       ?.copyWith(fontWeight: FontWeight.w600),
//                 ),
//                 const SizedBox(height: 8),
//                 if (chips.isEmpty)
//                   const Text(
//                     'Интервалы отсутствуют',
//                     style: TextStyle(color: Colors.black54),
//                   )
//                 else
//                   Wrap(
//                     spacing: 8,
//                     runSpacing: 8,
//                     children: chips,
//                   ),
//               ],
//             ),
//           ),
//         );
//       }),
//     );

//     return Scaffold(
//       appBar: AppBar(
//         title: Text('Сессия ${session.id}'),
//       ),
//       body: ListView(
//         padding: const EdgeInsets.all(16),
//         children: children,
//       ),
//     );
//   }
// }