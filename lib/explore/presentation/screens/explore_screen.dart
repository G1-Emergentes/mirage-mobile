import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../shared/theme/mirage_theme.dart';
import '../../../shared/widgets/mirage_feature_components.dart';

enum ExploreTab {
  forYou('For You'),
  trending('Trending'),
  newest('New'),
  stores('Stores');

  const ExploreTab(this.label);
  final String label;
}

class ExploreItem {
  const ExploreItem({
    required this.id,
    required this.name,
    required this.store,
    required this.photo,
    this.matchLabel,
    this.capability,
  });
  final String id, name, store;
  final Uint8List photo;
  final String? matchLabel, capability;
}

class ExploreScreen extends StatefulWidget {
  const ExploreScreen({
    super.key,
    required this.navigation,
    required this.onHome,
    this.results = const {},
    this.onOpen,
    this.onEditorial,
  });
  final Widget navigation;
  final VoidCallback onHome;
  final Map<ExploreTab, List<ExploreItem>> results;
  final ValueChanged<ExploreItem>? onOpen;
  final VoidCallback? onEditorial;

  @override
  State<ExploreScreen> createState() => _ExploreScreenState();
}

class _ExploreScreenState extends State<ExploreScreen> {
  ExploreTab _selected = ExploreTab.forYou;
  bool _searching = false;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final items = (widget.results[_selected] ?? const <ExploreItem>[]).where(
      (item) => '${item.name} ${item.store}'.toLowerCase().contains(_query),
    );
    return MirageFeaturePage(
      title: 'Explore',
      subtitle: 'New finds. More ways to wear.',
      onBack: widget.onHome,
      action: 'search',
      actionLabel: 'Search Explore',
      onAction: () => setState(() {
        _searching = !_searching;
        if (!_searching) _query = '';
      }),
      navigation: widget.navigation,
      children: [
        if (_searching)
          TextField(
            autofocus: true,
            onChanged: (value) =>
                setState(() => _query = value.trim().toLowerCase()),
            decoration: const InputDecoration(hintText: 'Search Explore'),
          ),
        MirageChoices(
          options: ExploreTab.values,
          selected: _selected,
          label: (tab) => tab.label,
          onSelected: (tab) => setState(() => _selected = tab),
        ),
        const SizedBox(height: 12),
        if (_selected == ExploreTab.forYou && !_searching) ...[
          Material(
            borderRadius: BorderRadius.circular(22),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onEditorial,
              child: SizedBox(
                height: 234,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    Image.asset(
                      'assets/design/editorial.png',
                      fit: BoxFit.cover,
                    ),
                    Align(
                      alignment: Alignment.bottomLeft,
                      child: Container(
                        width: 220,
                        margin: const EdgeInsets.fromLTRB(12, 12, 12, 18),
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: MirageColors.paper,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: const Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'THE EVERYDAY EDIT',
                              style: TextStyle(
                                fontSize: 9,
                                color: MirageColors.pink,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            MirageFeatureTitle(
                              'A fresh take on familiar.',
                              size: 22,
                            ),
                            Text(
                              'REWEAR SELECT ↗',
                              style: TextStyle(
                                fontSize: 9,
                                color: MirageColors.muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),
        ],
        Text(
          _selected == ExploreTab.forYou
              ? 'Matches Your Closet'
              : _selected.label,
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 10),
        if (items.isEmpty)
          const MirageNotice('No discoveries available yet.')
        else
          LayoutBuilder(
            builder: (context, constraints) => Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final item in items)
                  SizedBox(
                    width: (constraints.maxWidth - 12) / 2,
                    child: InkWell(
                      onTap: widget.onOpen == null
                          ? null
                          : () => widget.onOpen!(item),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            height: 142,
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: MirageColors.lavender,
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                MiragePhoto(item.photo),
                                if (item.capability case final label?)
                                  Align(
                                    alignment: Alignment.topLeft,
                                    child: MirageBadge(label),
                                  ),
                              ],
                            ),
                          ),
                          Text(
                            item.name,
                            style: Theme.of(context).textTheme.labelSmall,
                          ),
                          Text(
                            item.store,
                            style: Theme.of(context).textTheme.bodySmall,
                          ),
                          if (item.matchLabel case final label?)
                            Text(
                              label,
                              style: const TextStyle(color: MirageColors.pink),
                            ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
