import 'package:countdown/core/database/database.dart';
import 'package:countdown/features/events/presentation/screens/event_detail_sheet.dart';
import 'package:flutter/material.dart';

import '../../../domain/event.dart';
import 'event_list_item.dart';
import '../shared/events_ui_components.dart';

class EventListView extends StatelessWidget {
  const EventListView({
    super.key,
    required this.grouped,
    this.eventType = EventType.countdown,
  });

  final Map<String, List<Event>> grouped;
  final EventType eventType;

  @override
  Widget build(BuildContext context) {
    final entries = grouped.entries.toList();
    return ListView.builder(
      padding: EdgeInsets.only(
          top: 8, bottom: MediaQuery.of(context).padding.bottom),
      itemCount: entries.length,
      itemBuilder: (ctx, i) {
        final cat    = entries[i].key;
        final events = entries[i].value;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CategoryHeader(cat),
            for (int j = 0; j < events.length; j++) ...[
              EventListItem(
                event:     events[j],
                eventType: eventType,
                onTap:     () => showEventDetail(context, events[j].id),
              ),
              if (j < events.length - 1) const EventsDivider(),
            ],
          ],
        );
      },
    );
  }
}