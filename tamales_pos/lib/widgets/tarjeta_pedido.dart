import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/pos_controller.dart';
import '../models/pedido.dart';
import 'dialogos/confirmar_con_espera.dart';
import 'dialogos/dialogo_editar_pedido.dart';
import 'dialogos/dialogo_precio_especial.dart';
import 'tarjeta_ticket.dart';

/// Tarjeta resumen de un pedido individual dentro de las listas de operación,
/// cuentas por cobrar y desglose histórico.
///
/// Muestra el nombre del cliente, el importe total (con el precio original
/// tachado si hay precio especial), el desglose de piezas de puerco y elote,
/// la hora de entrega o registro, interruptores rápidos (`FilterChip`) para
/// entrega y cobro, y un menú con las opciones de editar, precio especial y
/// cancelar (esta última protegida por cuenta regresiva).
///
/// Los **regalos** se distinguen con color lila, muestran su motivo y solo
/// ofrecen el interruptor de entrega, porque nunca se cobran.
class TarjetaPedido extends StatelessWidget {
  /// Datos del pedido que se renderizará en la tarjeta.
  final Pedido pedido;

  /// Crea una instancia de [TarjetaPedido].
  const TarjetaPedido({super.key, required this.pedido});

  /// Color resaltador usado cuando los estados de entrega o pago están activos.
  static const Color _colorActivo = Color(0xFFD9F99D);

  /// Colores distintivos de los pedidos de regalo.
  static const Color _regaloFondo = Color(0xFFF5F0FF);
  static const Color _regaloBorde = Color(0xFFB39DDB);
  static const Color _regaloActivo = Color(0xFFD1C4E9);
  static const Color _regaloTexto = Color(0xFF5E35B1);

  /// Formateador de moneda en pesos mexicanos (`$0.00`).
  static final NumberFormat _moneda = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );

  /// Abre un diálogo de seguridad con temporizador de 3 segundos antes de
  /// habilitar el botón definitivo para cancelar el pedido.
  Future<void> _confirmarCancelacion(BuildContext context) async {
    final confirmar = await confirmarConEspera(
      context,
      titulo: 'Cancelar pedido',
      mensaje:
          'El pedido de ${pedido.cliente} quedará marcado como CANCELADO '
          'en el historial${pedido.entregado ? ' y sus tamales volverán a Listos' : ''}.',
      textoConfirmar: 'Confirmar cancelación',
      colorConfirmar: Colors.red.shade700,
    );

    if (confirmar && context.mounted) {
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

    final esRegalo =
        pedido.esGratis && !pedido.cancelado && !pedido.esDevolucion;
    final conPrecioEspecial = pedido.tienePrecioEspecial && !pedido.cancelado;

    // Reglas del menú: las devoluciones y los regalos no llevan precio especial.
    final puedeEditar =
        !pedido.entregado && !pedido.pagado && !pedido.esDevolucion;
    final admitePrecioEspecial =
        !pedido.pagado && !pedido.esDevolucion && !pedido.esGratis;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      color: pedido.cancelado
          ? Colors.grey.shade100
          : (esRegalo ? _regaloFondo : null),
      shape: RoundedRectangleBorder(
        side: BorderSide(
          color: pedido.cancelado
              ? Colors.red.shade200
              : (esRegalo ? _regaloBorde : Colors.black26),
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
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (esRegalo) ...[
                    const Padding(
                      padding: EdgeInsets.only(top: 2, right: 6),
                      child: Icon(
                        Icons.card_giftcard,
                        size: 18,
                        color: _regaloTexto,
                      ),
                    ),
                  ],
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
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      if (conPrecioEspecial)
                        Text(
                          _moneda.format(pedido.totalCalculado),
                          style: const TextStyle(
                            fontSize: 11,
                            color: Colors.black45,
                            decoration: TextDecoration.lineThrough,
                          ),
                        ),
                      Text(
                        pedido.cancelado
                            ? 'Cancelado'
                            : (esRegalo
                                  ? 'Regalo'
                                  : _moneda.format(pedido.totalPesos)),
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: pedido.cancelado
                              ? Colors.red.shade700
                              : (esRegalo ? _regaloTexto : null),
                        ),
                      ),
                      if (esRegalo && pedido.motivoRegalo != null)
                        Text(
                          pedido.motivoRegalo!,
                          style: const TextStyle(
                            fontSize: 11,
                            color: _regaloTexto,
                          ),
                        ),
                      if (conPrecioEspecial)
                        Text(
                          'Precio especial',
                          style: TextStyle(
                            fontSize: 10,
                            color: Colors.orange.shade800,
                          ),
                        ),
                    ],
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
                            selectedColor: esRegalo
                                ? _regaloActivo
                                : _colorActivo,
                            onSelected: (_) {
                              final error = p.alternarEntregado(pedido.id);
                              if (error != null && context.mounted) {
                                ScaffoldMessenger.of(
                                  context,
                                ).showSnackBar(SnackBar(content: Text(error)));
                              }
                            },
                          ),
                          // Los regalos nunca se cobran: sin chip de pago.
                          if (!esRegalo)
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
                    PopupMenuButton<String>(
                      tooltip: 'Más opciones',
                      icon: const Icon(Icons.more_vert, size: 20),
                      onSelected: (v) {
                        switch (v) {
                          case 'editar':
                            mostrarEditarPedido(context, pedido);
                          case 'precio':
                            mostrarPrecioEspecial(context, pedido);
                          case 'cancelar':
                            _confirmarCancelacion(context);
                        }
                      },
                      itemBuilder: (_) => [
                        PopupMenuItem(
                          value: 'editar',
                          enabled: puedeEditar,
                          child: const Text('Editar pedido'),
                        ),
                        PopupMenuItem(
                          value: 'precio',
                          enabled: admitePrecioEspecial,
                          child: Text(
                            pedido.tienePrecioEspecial
                                ? 'Cambiar precio especial'
                                : 'Precio especial',
                          ),
                        ),
                        PopupMenuItem(
                          value: 'cancelar',
                          child: Text(
                            'Cancelar pedido',
                            style: TextStyle(color: Colors.red.shade700),
                          ),
                        ),
                      ],
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
