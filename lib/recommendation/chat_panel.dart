import 'package:flutter/material.dart';
import '../closet/closet_module.dart';
import '../closet/domain/garment.dart';
import '../closet/presentation/closet_widgets.dart';
import '../shared/theme/mirage_theme.dart';
import 'chat_controller.dart';
import 'recommendation_repository.dart';

class ChatPanel extends StatefulWidget {
  const ChatPanel({
    super.key,
    required this.controller,
    required this.closet,
    required this.onClose,
    required this.onCloset,
    required this.onTryOutfit,
  });
  final ChatController controller;
  final ClosetModule closet;
  final VoidCallback onClose, onCloset;
  final Future<void> Function(List<Garment>) onTryOutfit;
  @override
  State<ChatPanel> createState() => _ChatPanelState();
}

class _ChatPanelState extends State<ChatPanel> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  bool handingOff = false;
  String? handoffError;
  @override
  void dispose() {
    _input.dispose();
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    final future = widget.controller.send(text);
    if (widget.controller.pendingMessage != null) _input.clear();
    _bottom();
    await future;
    _bottom();
  }

  void _bottom() => WidgetsBinding.instance.addPostFrameCallback((_) {
    if (mounted && _scroll.hasClients) {
      _scroll.animateTo(
        _scroll.position.maxScrollExtent,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  });

  Future<void> _try(List<Garment> garments) async {
    if (handingOff) return;
    setState(() {
      handingOff = true;
      handoffError = null;
    });
    try {
      await widget.onTryOutfit(garments);
    } catch (_) {
      if (mounted) {
        setState(
          () => handoffError =
              'No pudimos preparar este look. Comprueba que las prendas sigan disponibles, tengan foto y no hayan cambiado.',
        );
      }
    } finally {
      if (mounted) setState(() => handingOff = false);
    }
  }

  @override
  Widget build(BuildContext context) => Material(
    color: MirageColors.paper,
    elevation: 16,
    shadowColor: Colors.black26,
    borderRadius: BorderRadius.circular(24),
    clipBehavior: Clip.antiAlias,
    child: ListenableBuilder(
      listenable: widget.controller,
      builder: (context, _) {
        final chat = widget.controller;
        return Column(
          children: [
            Container(
              padding: const EdgeInsets.fromLTRB(18, 12, 6, 12),
              decoration: const BoxDecoration(color: MirageColors.lavender),
              child: Row(
                children: [
                  const Icon(Icons.auto_awesome_outlined, size: 23),
                  const SizedBox(width: 10),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Mirage, tu estilista',
                          style: TextStyle(fontFamily: 'Lora', fontSize: 19),
                        ),
                        Text(
                          'Ideas con tu propio clóset',
                          style: TextStyle(
                            fontSize: 11,
                            color: MirageColors.muted,
                          ),
                        ),
                      ],
                    ),
                  ),
                  PopupMenuButton<String>(
                    tooltip: 'Conversaciones',
                    enabled: !chat.busy,
                    onSelected: (id) {
                      if (id == 'new') {
                        chat.newChat();
                        _input.clear();
                      } else {
                        chat.open(id);
                      }
                    },
                    itemBuilder: (_) => [
                      const PopupMenuItem(
                        value: 'new',
                        child: Text('Nueva conversación'),
                      ),
                      for (final c in chat.history)
                        PopupMenuItem(
                          value: c['id'] as String,
                          child: Text(
                            c['title'] as String? ?? 'Conversación',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                    ],
                    icon: const Icon(Icons.history),
                  ),
                  IconButton(
                    onPressed: widget.onClose,
                    tooltip: 'Minimizar asistente',
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                controller: _scroll,
                padding: const EdgeInsets.all(16),
                children: [
                  if (chat.turns.isEmpty && chat.pendingMessage == null) ...[
                    const Text(
                      'Tu estilo.\nOtra perspectiva.',
                      style: TextStyle(
                        fontFamily: 'Lora',
                        fontSize: 30,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Cuéntame adónde vas y cómo quieres sentirte. Buscaré prendas de tu clóset e ideas para combinarlas.',
                      style: TextStyle(color: MirageColors.muted, height: 1.5),
                    ),
                    const SizedBox(height: 16),
                    for (final prompt in [
                      'Un look oscuro pero llamativo',
                      'Algo para clases, sin blanco',
                    ])
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: OutlinedButton(
                          onPressed: chat.busy || !chat.initialized
                              ? null
                              : () {
                                  _input.text = prompt;
                                  _send();
                                },
                          child: Text(prompt),
                        ),
                      ),
                    TextButton.icon(
                      onPressed: widget.onCloset,
                      icon: const Icon(Icons.checkroom_outlined),
                      label: const Text('Abrir mi clóset'),
                    ),
                  ],
                  for (final turn in chat.turns) ...[
                    _bubble('${turn['message']}', user: true),
                    _bubble('${turn['assistant_message']}'),
                    if (turn['recommendation']
                        case final Map<String, dynamic> recommendation)
                      ..._recommendation(recommendation),
                  ],
                  if (chat.pendingMessage != null)
                    _bubble(chat.pendingMessage!, user: true),
                  if (chat.busy)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                          SizedBox(width: 12),
                          Expanded(child: Text('Consultando tu clóset…')),
                        ],
                      ),
                    ),
                  if (chat.error != null) ...[
                    Text(
                      chat.error!,
                      style: const TextStyle(color: Color(0xFF9B2351)),
                    ),
                    TextButton(
                      onPressed: chat.busy
                          ? null
                          : () async {
                              if (chat.pendingMessage != null) {
                                await chat.retry();
                              } else {
                                await chat.initialize();
                              }
                              _bottom();
                            },
                      child: const Text('Reintentar'),
                    ),
                  ],
                  if (handoffError != null)
                    Text(
                      handoffError!,
                      style: const TextStyle(color: Color(0xFF9B2351)),
                    ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 10, 14),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: TextField(
                      controller: _input,
                      key: const ValueKey('chat-input'),
                      enabled:
                          !chat.busy &&
                          chat.pendingMessage == null &&
                          chat.initialized,
                      minLines: 1,
                      maxLines: 4,
                      maxLength: 2000,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: '¿Qué te gustaría ponerte?',
                        counterText: '',
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: EdgeInsets.all(14),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.all(Radius.circular(18)),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed:
                        chat.busy ||
                            chat.pendingMessage != null ||
                            !chat.initialized
                        ? null
                        : _send,
                    style: IconButton.styleFrom(
                      backgroundColor: MirageColors.pink,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(48, 48),
                    ),
                    tooltip: 'Enviar mensaje',
                    icon: const Icon(Icons.arrow_upward),
                  ),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );

  Widget _bubble(String text, {bool user = false}) => Align(
    alignment: user ? Alignment.centerRight : Alignment.centerLeft,
    child: Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: user ? MirageColors.lavender : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: SelectableText(
        text,
        style: const TextStyle(fontSize: 13, height: 1.55),
      ),
    ),
  );

  List<Widget> _recommendation(Json recommendation) {
    final garments = <String, Garment>{};
    for (final raw in recommendation['garments'] as List? ?? []) {
      try {
        final g = Garment.fromJson(Map<String, dynamic>.from(raw as Map));
        garments[g.id] = g;
      } catch (_) {
        /* An older snapshot may not have the current garment contract. */
      }
    }
    return [
      for (final outfit in recommendation['outfits'] as List? ?? [])
        _outfit(Map<String, dynamic>.from(outfit as Map), garments),
      if ((recommendation['outfit_examples'] as List? ?? []).isNotEmpty ||
          (recommendation['style_references'] as List? ?? []).isNotEmpty ||
          (recommendation['web_references'] as List? ?? []).isNotEmpty)
        ExpansionTile(
          tilePadding: EdgeInsets.zero,
          title: const Text(
            'Referencias consultadas',
            style: TextStyle(fontSize: 13),
          ),
          children: [
            const Text(
              'Son ejemplos de inspiración; las prendas propuestas pertenecen a tu clóset.',
              style: TextStyle(fontSize: 11, color: MirageColors.muted),
            ),
            for (final ref in [
              ...?recommendation['outfit_examples'] as List?,
              ...?recommendation['style_references'] as List?,
              ...?recommendation['web_references'] as List?,
            ])
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: SelectableText(
                  '${ref['source_outfit_id'] != null ? 'Polyvore · ' : ''}${ref['title']}\n${ref['content'] ?? ''}\n${ref['dataset_release'] != null ? 'Publicación: ${ref['dataset_release']}\n' : ''}${ref['source_url'] ?? ''}\n${ref['license'] ?? ''} · ${ref['attribution'] ?? ''}\n${ref['license_url'] ?? ''}',
                  style: const TextStyle(fontSize: 11, height: 1.5),
                ),
              ),
          ],
        ),
    ];
  }

  Widget _outfit(Json outfit, Map<String, Garment> available) {
    final ids = List<String>.from(outfit['garment_ids'] as List? ?? []);
    final pieces = [
      for (final id in ids)
        if (available[id] != null) available[id]!,
    ];
    final canTry =
        ids.isNotEmpty &&
        ids.length <= 3 &&
        pieces.length == ids.length &&
        ids.toSet().length == ids.length;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: MirageColors.blue,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pieces.isNotEmpty)
            SizedBox(
              height: 94,
              child: Row(
                children: [
                  for (final g in pieces)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: GarmentImage(
                          garment: g,
                          closet: widget.closet.closet,
                        ),
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: 8),
          Text(
            '${outfit['explanation'] ?? 'Tu combinación'}',
            style: const TextStyle(fontSize: 13, height: 1.5),
          ),
          const SizedBox(height: 6),
          Text(
            pieces.map((g) => g.name).join(' · '),
            style: const TextStyle(fontSize: 11, color: MirageColors.muted),
          ),
          const SizedBox(height: 12),
          FilledButton(
            onPressed: canTry && !handingOff ? () => _try(pieces) : null,
            style: FilledButton.styleFrom(
              backgroundColor: MirageColors.ink,
              foregroundColor: Colors.white,
            ),
            child: Text(
              handingOff ? 'Comprobando prendas…' : 'Probar en mi clóset',
            ),
          ),
          if (!canTry)
            const Text(
              'Selecciona hasta 3 prendas en el clóset para crear la imagen.',
              style: TextStyle(fontSize: 11),
            ),
        ],
      ),
    );
  }
}
