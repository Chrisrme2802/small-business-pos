import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/pos_controller.dart';
import '../../models/pedido.dart';

/// Abre el editor de un pedido **que aún no se ha entregado ni cobrado**.
///
/// Permite cambiar nombre, tarifa, piezas y hora de entrega. La validación
/// final vive en [PosController.editarPedido].
Future<void> mostrarEditarPedido(BuildContext context, Pedido pedido) {
  return showDialog<void>(
    context: context,
    builder: (_) => _DialogoEditarPedido(pedido: pedido),
  );
}

class _DialogoEditarPedido extends StatefulWidget {
  final Pedido pedido;
  const _DialogoEditarPedido({required this.pedido});

  @override
  State<_DialogoEditarPedido> createState() => _DialogoEditarPedidoState();
}

class _DialogoEditarPedidoState extends State<_DialogoEditarPedido> {
  late final TextEditingController _nombre;
  late TipoTarifa _tarifa;
  late int _puerco;
  late int _elote;
  late bool _inmediato;
  TimeOfDay? _hora;

  @override
  void initState() {
    super.initState();
    final p = widget.pedido;
    _nombre = TextEditingController(
      text: p.cliente == 'Mostrador' ? '' : p.cliente,
    );
    _tarifa = p.tarifa;
    _puerco = p.cantidadPuerco;
    _elote = p.cantidadElote;
    _inmediato = p.horaEntrega == null;
    _hora = p.horaEntrega == null
        ? null
        : TimeOfDay.fromDateTime(p.horaEntrega!);
  }

  @override
  void dispose() {
    _nombre.dispose();
    super.dispose();
  }

  bool get _puedeGuardar =>
      _puerco + _elote > 0 && (_inmediato || _hora != null);

  Future<void> _elegirHora() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _hora ?? TimeOfDay.now(),
    );
    if (t != null) setState(() => _hora = t);
  }

  void _guardar() {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);

    // Se conserva la fecha original de la entrega si ya tenía una.
    final base = widget.pedido.horaEntrega ?? DateTime.now();
    final entrega = _inmediato
        ? null
        : DateTime(base.year, base.month, base.day, _hora!.hour, _hora!.minute);

    final error = context.read<PosController>().editarPedido(
      widget.pedido.id,
      cliente: _nombre.text,
      tarifa: _tarifa,
      cantidadPuerco: _puerco,
      cantidadElote: _elote,
      horaEntrega: entrega,
    );

    navigator.pop();
    if (error != null) messenger.showSnackBar(SnackBar(content: Text(error)));
  }

  Widget _contador(String etiqueta, int valor, ValueChanged<int> cambio) {
    return Row(
      children: [
        Expanded(child: Text(etiqueta, style: const TextStyle(fontSize: 16))),
        IconButton.filledTonal(
          onPressed: valor > 0 ? () => cambio(valor - 1) : null,
          icon: const Icon(Icons.remove),
        ),
        SizedBox(
          width: 40,
          child: Text(
            '$valor',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => cambio(valor + 1),
          icon: const Icon(Icons.add),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar pedido'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Nombre',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            SegmentedButton<TipoTarifa>(
              segments: const [
                ButtonSegment(
                  value: TipoTarifa.publico,
                  label: Text('Público'),
                ),
                ButtonSegment(value: TipoTarifa.tienda, label: Text('Tienda')),
              ],
              selected: {_tarifa},
              onSelectionChanged: (s) => setState(() => _tarifa = s.first),
            ),
            const SizedBox(height: 8),
            _contador('Puerco', _puerco, (v) => setState(() => _puerco = v)),
            _contador('Elote', _elote, (v) => setState(() => _elote = v)),
            const SizedBox(height: 8),
            SegmentedButton<bool>(
              segments: const [
                ButtonSegment(value: true, label: Text('Inmediato')),
                ButtonSegment(value: false, label: Text('Programado')),
              ],
              selected: {_inmediato},
              onSelectionChanged: (s) => setState(() => _inmediato = s.first),
            ),
            if (!_inmediato)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: OutlinedButton.icon(
                  onPressed: _elegirHora,
                  icon: const Icon(Icons.schedule),
                  label: Text(
                    _hora == null ? 'Elegir hora' : _hora!.format(context),
                  ),
                ),
              ),
            const SizedBox(height: 12),
            Text(
              widget.pedido.tienePrecioEspecial
                  ? 'Si cambias piezas o tarifa, se quita el precio especial. '
                        'Si cambias la tarifa, los precios se recalculan con las tarifas actuales.'
                  : 'Si cambias la tarifa, los precios se recalculan con las tarifas actuales.',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _puedeGuardar ? _guardar : null,
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
