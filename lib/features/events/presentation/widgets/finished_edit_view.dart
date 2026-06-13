import 'package:countdown/core/database/database.dart';
import 'package:flutter/material.dart';

import 'event_list_item.dart';
import 'events_ui_components.dart';

class FinishedEditView extends StatelessWidget {
  const FinishedEditView({
    super.key,
    required this.events,
    required this.onDelete,
  });

  final List<Event> events;
  final Future<void> Function(Event) onDelete;

  @override
  Widget build(BuildContext context) {
    if (events.isEmpty) {
      return const EmptyEventsState(message: 'No finished events.');
    }
    return ListView.separated(
      padding: EdgeInsets.only(
          top: 8, bottom: MediaQuery.of(context).padding.bottom),
      itemCount: events.length,
      separatorBuilder: (_, _) => const EventsDivider(),
      itemBuilder: (ctx, i) => EventListItem(
        event: events[i],
        isEditing: true,
        onDelete: () => onDelete(events[i]),
      ),
    );
  }
}