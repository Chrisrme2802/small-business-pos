import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/pos_controller.dart';
import '../../models/pedido.dart';
import 'confirmar_con_espera.dart';
import '../titulo_marcador.dart';

/// Flujo para fijar, cambiar o quitar el **precio especial** de un pedido.
///
/// 1. Se captura el nuevo total acordado (por ejemplo 130 → 100).
/// 2. Se pide una confirmación con espera de 3 segundos mostrando el cambio.
/// 3. Solo entonces se llama a [PosController.fijarPrecioEspecial].
Future<void> mostrarPrecioEspecial(BuildContext context, Pedido pedido) async {
  final controller = context.read<PosController>();
  final messenger = ScaffoldMessenger.of(context);

  final r = await showDialog<_ResultadoPrecio>(
    context: context,
    builder: (_) => _DialogoPrecio(pedido: pedido),
  );
  if (r == null || !context.mounted) return;

  final original = pedido.totalCalculado;

  if (r.quitar) {
    final ok = await confirmarConEspera(
      context,
      titulo: 'Quitar precio especial',
      mensaje:
          'El total de ${pedido.cliente} volverá a ${moneda.format(original)}.',
      textoConfirmar: 'Quitar precio especial',
    );
    if (!ok) return;
    final error = controller.fijarPrecioEspecial(pedido.id, null);
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
    return;
  }

  final nuevo = r.valor!;
  final ok = await confirmarConEspera(
    context,
    titulo: 'Confirmar precio especial',
    mensaje:
        'El pedido de ${pedido.cliente} pasará de ${moneda.format(original)} '
        'a ${moneda.format(nuevo)}.',
    textoConfirmar: 'Aplicar ${moneda.format(nuevo)}',
    colorConfirmar: Colors.orange.shade800,
  );
  if (!ok) return;

  final error = controller.fijarPrecioEspecial(pedido.id, nuevo);
  if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
}

/// Resultado del primer diálogo: un valor nuevo o la orden de quitarlo.
class _ResultadoPrecio {
  final double? valor;
  final bool quitar;
  const _ResultadoPrecio({this.valor, this.quitar = false});
}

/// Diálogo que captura el precio especial; es dueño de su propio controlador.
class _DialogoPrecio extends StatefulWidget {
  final Pedido pedido;
  const _DialogoPrecio({required this.pedido});

  @override
  State<_DialogoPrecio> createState() => _DialogoPrecioState();
}

class _DialogoPrecioState extends State<_DialogoPrecio> {
  late final TextEditingController _campo;
  String? _error;

  @override
  void initState() {
    super.initState();
    final p = widget.pedido;
    _campo = TextEditingController(
      text: p.tienePrecioEspecial ? p.precioEspecial!.toStringAsFixed(2) : '',
    );
  }

  @override
  void dispose() {
    _campo.dispose();
    super.dispose();
  }

  void _continuar() {
    final valor = double.tryParse(_campo.text.trim().replaceAll(',', '.'));
    if (valor == null || valor <= 0) {
      setState(() => _error = 'Escribe un monto mayor que cero.');
      return;
    }
    Navigator.of(context)
        .pop(_ResultadoPrecio(valor: double.parse(valor.toStringAsFixed(2))));
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.pedido;
    return AlertDialog(
      title: const Text('Precio especial'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(p.cliente, style: const TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text('Total calculado: ${moneda.format(p.totalCalculado)}'),
          const SizedBox(height: 12),
          TextField(
            controller: _campo,
            autofocus: true,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            onSubmitted: (_) => _continuar(),
            decoration: InputDecoration(
              labelText: 'Total acordado',
              prefixText: '\$ ',
              errorText: _error,
              border: const OutlineInputBorder(),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        if (p.tienePrecioEspecial)
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(const _ResultadoPrecio(quitar: true)),
            child: const Text('Quitar'),
          ),
        FilledButton(onPressed: _continuar, child: const Text('Continuar')),
      ],
    );
  }
}
