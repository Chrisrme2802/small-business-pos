import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/pos_controller.dart';
import '../models/pedido.dart';
import 'tarjeta_ticket.dart';

/// Tarjeta resumen de un pedido individual dentro de las listas de operación,
/// cuentas por cobrar y desglose histórico.
///
/// Muestra el nombre del cliente, el importe total, el desglose de piezas de
/// puerco y elote, la hora de entrega o registro, interruptores rápidos
/// (`FilterChip`) para entrega y cobro, y un botón de cancelación protegido
/// por cuenta regresiva.
class TarjetaPedido extends StatelessWidget {
  /// Datos del pedido que se renderizará en la tarjeta.
  final Pedido pedido;

  /// Crea una instancia de [TarjetaPedido].
  const TarjetaPedido({super.key, required this.pedido});

  /// Color resaltador usado cuando los estados de entrega o pago están activos.
  static const Color _colorActivo = Color(0xFFD9F99D);

  /// Formateador de moneda en pesos mexicanos (`$0.00`).
  static final NumberFormat _moneda = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );

  /// Abre un diálogo de seguridad con temporizador de 3 segundos antes de
  /// habilitar el botón definitivo para cancelar el pedido.
  Future<void> _confirmarCancelacion(BuildContext context) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (_) => _DialogoConfirmarCancelacion(pedido: pedido),
    );

    if (confirmar == true && context.mounted) {
      context.read<PosController>().cancelarPedido(pedido.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.read<PosController>();

    final partes = <String>[
      if (pedido.cantidadPuerco > 0) '${pedido.cantidadPuerco} Puerco',
      if (pedido.cantidadElote > 0) '${pedido.cantidadElote} Elote',
    ];

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: pedido.cancelado ? Colors.grey.shade100 : null,
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: pedido.cancelado ? Colors.red.shade200 : Colors.black26,
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(8),
        onTap: () => mostrarTicket(context, pedido),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      pedido.cliente,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                        decoration: pedido.cancelado
                            ? TextDecoration.lineThrough
                            : null,
                        color: pedido.cancelado ? Colors.black54 : null,
                      ),
                    ),
                  ),
                  Text(
                    pedido.cancelado
                        ? 'Cancelado'
                        : _moneda.format(pedido.totalPesos),
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      color: pedido.cancelado ? Colors.red.shade700 : null,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                partes.join(' · '),
                style: TextStyle(
                  color: pedido.cancelado ? Colors.black54 : null,
                ),
              ),
              Text(
                pedido.horaEntrega == null
                    ? 'Inmediato · ${DateFormat.Hm().format(pedido.horaRegistro)}'
                    : 'Entrega ${DateFormat.Hm().format(pedido.horaEntrega!)}',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              if (!pedido.cancelado) ...[
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        children: [
                          FilterChip(
                            label: Text(
                              pedido.entregado ? 'Entregado' : 'Por entregar',
                            ),
                            selected: pedido.entregado,
                            selectedColor: _colorActivo,
                            onSelected: (_) {
                              final error = p.alternarEntregado(pedido.id);
                              if (error != null && context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(error)));
                              }
                            },
                          ),
                          FilterChip(
                            label: Text(
                              pedido.pagado ? 'Pagado' : 'Por cobrar',
                            ),
                            selected: pedido.pagado,
                            selectedColor: _colorActivo,
                            onSelected: (_) => p.alternarPagado(pedido.id),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancelar pedido',
                      icon: Icon(
                        Icons.cancel_outlined,
                        color: Colors.red.shade700,
                        size: 20,
                      ),
                      onPressed: () => _confirmarCancelacion(context),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Diálogo modal con cuenta regresiva de 3 segundos para evitar cancelaciones
/// accidentales de pedidos.
class _DialogoConfirmarCancelacion extends StatefulWidget {
  final Pedido pedido;

  const _DialogoConfirmarCancelacion({required this.pedido});

  @override
  State<_DialogoConfirmarCancelacion> createState() =>
      _DialogoConfirmarCancelacionState();
}

class _DialogoConfirmarCancelacionState
    extends State<_DialogoConfirmarCancelacion> {
  int _segundosRestantes = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) {
        t.cancel();
        return;
      }
      if (_segundosRestantes <= 1) {
        t.cancel();
        setState(() => _segundosRestantes = 0);
      } else {
        setState(() => _segundosRestantes--);
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listo = _segundosRestantes == 0;
    return AlertDialog(
      title: const Text('Cancelar pedido'),
      content: Text(
        'El pedido de ${widget.pedido.cliente} quedará marcado como CANCELADO '
        'en el historial${widget.pedido.entregado ? ' y sus tamales volverán a Listos' : ''}.',
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Volver'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Colors.red.shade700,
            foregroundColor: Colors.white,
          ),
          onPressed: listo ? () => Navigator.of(context).pop(true) : null,
          child: Text(
            listo ? 'Confirmar cancelación' : 'Espera $_segundosRestantes s...',
          ),
        ),
      ],
    );
  }
}
