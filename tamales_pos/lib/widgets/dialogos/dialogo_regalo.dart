import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../controllers/pos_controller.dart';
import '../../models/pedido.dart';
import '../stepper_cantidad.dart';

/// Abre el registro rápido de un **regalo**: solo piezas y motivo.
///
/// No pide tarifa ni precios: el pedido se crea con precios en cero, ya
/// marcado como pagado (nunca queda por cobrar) y pendiente de entregar.
Future<void> mostrarDialogoRegalo(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (_) => const _DialogoRegalo(),
  );
}

class _DialogoRegalo extends StatefulWidget {
  const _DialogoRegalo();

  @override
  State<_DialogoRegalo> createState() => _DialogoRegaloState();
}

class _DialogoRegaloState extends State<_DialogoRegalo> {
  /// Motivos predefinidos; el último permite escribir uno propio.
  static const _motivos = ['Tienda', 'Cliente', 'Familia', 'Personalizado'];

  final _nombre = TextEditingController();
  final _personalizado = TextEditingController();
  String? _motivo;
  int _puerco = 0;
  int _elote = 0;

  @override
  void dispose() {
    _nombre.dispose();
    _personalizado.dispose();
    super.dispose();
  }

  bool get _esPersonalizado => _motivo == 'Personalizado';

  bool get _puedeGuardar =>
      _puerco + _elote > 0 &&
      _motivo != null &&
      (!_esPersonalizado || _personalizado.text.trim().isNotEmpty);

  void _guardar() {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    final motivo = _esPersonalizado ? _personalizado.text.trim() : _motivo!;

    context.read<PosController>().agregarPedido(
      cliente: _nombre.text,
      tarifa: TipoTarifa.publico,
      cantidadPuerco: _puerco,
      cantidadElote: _elote,
      gratis: true,
      motivoRegalo: motivo,
    );

    navigator.pop();
    messenger.showSnackBar(
      SnackBar(content: Text('Regalo registrado ($motivo)')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Row(
        children: [
          Icon(Icons.card_giftcard),
          SizedBox(width: 8),
          Text('Registrar regalo'),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            StepperCantidad(
              etiqueta: 'Puerco',
              valor: _puerco,
              maximo: 999,
              onChanged: (v) => setState(() => _puerco = v),
            ),
            const SizedBox(height: 12),

            StepperCantidad(
              etiqueta: 'Elote',
              valor: _elote,
              maximo: 999,
              onChanged: (v) => setState(() => _elote = v),
            ),
            const Text('Motivo', style: TextStyle(fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                for (final m in _motivos)
                  ChoiceChip(
                    label: Text(m),
                    selected: _motivo == m,
                    selectedColor: const Color(0xFFD1C4E9),
                    onSelected: (_) => setState(() => _motivo = m),
                  ),
              ],
            ),
            if (_esPersonalizado) ...[
              const SizedBox(height: 10),
              TextField(
                controller: _personalizado,
                autofocus: true,
                textCapitalization: TextCapitalization.sentences,
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Motivo del regalo',
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
            ],
            const SizedBox(height: 12),
            TextField(
              controller: _nombre,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Para quién (opcional)',
                border: OutlineInputBorder(),
                isDense: true,
              ),
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
          child: const Text('Registrar'),
        ),
      ],
    );
  }
}
