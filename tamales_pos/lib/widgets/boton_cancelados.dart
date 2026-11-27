import 'package:flutter/material.dart';

import '../models/pedido.dart';
import 'tarjeta_pedido.dart';

/// Ficha compacta que reemplaza a los pedidos cancelados dentro de la lista.
///
/// Solo muestra un ícono y el conteo; al tocarla abre una hoja inferior con
/// los pedidos cancelados. Si no hay ninguno, no ocupa espacio.
class BotonCancelados extends StatelessWidget {
  /// Pedidos cancelados que se mostrarán al abrir la hoja.
  final List<Pedido> cancelados;

  /// Crea una instancia de [BotonCancelados].
  const BotonCancelados({super.key, required this.cancelados});

  void _abrir(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      constraints: const BoxConstraints(maxWidth: 480),
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(ctx).size.height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: Text(
                  'Pedidos cancelados',
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
              ),
              Flexible(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  shrinkWrap: true,
                  children: [
                    for (final p in cancelados) TarjetaPedido(pedido: p),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (cancelados.isEmpty) return const SizedBox.shrink();
    return ActionChip(
      tooltip: 'Pedidos cancelados',
      avatar: Icon(Icons.cancel_outlined, size: 18, color: Colors.red.shade700),
      label: Text('${cancelados.length}'),
      onPressed: () => _abrir(context),
    );
  }
}
