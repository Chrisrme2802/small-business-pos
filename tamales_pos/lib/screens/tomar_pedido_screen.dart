import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/pos_controller.dart';
import '../models/pedido.dart';
import '../widgets/stepper_cantidad.dart';
import '../widgets/tarjeta_ticket.dart';
import '../widgets/titulo_marcador.dart';

/// Pantalla de captura rápida de pedidos y generación de ticket (Pestaña 2).
class TomarPedidoScreen extends StatefulWidget {
  /// Crea una instancia de [TomarPedidoScreen].
  const TomarPedidoScreen({super.key});

  @override
  State<TomarPedidoScreen> createState() => _TomarPedidoScreenState();
}

class _TomarPedidoScreenState extends State<TomarPedidoScreen> {
  String _nombre = '';
  TipoTarifa _tarifa = TipoTarifa.publico;
  bool _inmediato = true;
  TimeOfDay? _hora;
  int _cantPuerco = 0;
  int _cantElote = 0;
  Pedido? _creado;
  int _formKey = 0;
  bool _gratis = false;

  static const Color _colorMarcador = Color(0xFFD9F99D);

  static final NumberFormat _moneda = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );

  int get _piezas => _cantPuerco + _cantElote;

  Future<void> _elegirHora() async {
    final t = await showTimePicker(
      context: context,
      initialTime: _hora ?? TimeOfDay.now(),
    );
    if (t != null) setState(() => _hora = t);
  }

  void _confirmar() {
    final p = context.read<PosController>();
    final ahora = DateTime.now();
    final entrega = (!_inmediato && _hora != null)
        ? DateTime(
            ahora.year,
            ahora.month,
            ahora.day,
            _hora!.hour,
            _hora!.minute,
          )
        : null;

    final pedido = p.agregarPedido(
      cliente: _nombre.trim(),
      tarifa: _tarifa,
      cantidadPuerco: _cantPuerco,
      cantidadElote: _cantElote,
      horaEntrega: entrega,
      gratis: _gratis,
    );
    setState(() => _creado = pedido);
  }

  void _nuevo() => setState(() {
    _creado = null;
    _nombre = '';
    _cantPuerco = 0;
    _cantElote = 0;
    _tarifa = TipoTarifa.publico;
    _inmediato = true;
    _hora = null;
    _formKey++;
    _gratis = false;
  });

  @override
  Widget build(BuildContext context) {
    if (_creado != null) {
      return ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TarjetaTicket(pedido: _creado!),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _nuevo,
            icon: const Icon(Icons.add),
            label: const Text('Nuevo pedido'),
          ),
        ],
      );
    }

    final p = context.watch<PosController>();
    final precios = p.precios;
    final precioPuerco = _tarifa == TipoTarifa.tienda
        ? precios.puercoTienda
        : precios.puercoPublico;
    final precioElote = _tarifa == TipoTarifa.tienda
        ? precios.eloteTienda
        : precios.elotePublico;
    final totalEstimado =
        (_cantPuerco * precioPuerco) + (_cantElote * precioElote);

    final puedeConfirmar = _piezas > 0 && (_inmediato || _hora != null);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TituloMarcador('Pedido'),
        const SizedBox(height: 16),

        Autocomplete<String>(
          key: ValueKey(_formKey),
          optionsBuilder: (v) => p.clientesFrecuentes.where(
            (c) => c.toLowerCase().contains(v.text.toLowerCase()),
          ),
          onSelected: (v) => setState(() => _nombre = v),
          fieldViewBuilder: (ctx, ctrl, focus, _) => TextField(
            controller: ctrl,
            focusNode: focus,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Nombre (opcional, vacío = Mostrador)',
              border: OutlineInputBorder(),
            ),
            onChanged: (v) => setState(() => _nombre = v),
          ),
        ),
        const SizedBox(height: 16),

        const Text('Tarifa', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        SegmentedButton<TipoTarifa>(
          segments: const [
            ButtonSegment(value: TipoTarifa.publico, label: Text('Público')),
            ButtonSegment(value: TipoTarifa.tienda, label: Text('Tienda')),
          ],
          selected: {_tarifa},
          onSelectionChanged: (s) => setState(() => _tarifa = s.first),
        ),
        const SizedBox(height: 16),
        FilterChip(
          avatar: const Icon(Icons.card_giftcard, size: 18),
          label: const Text('Gratis'),
          selected: _gratis,
          selectedColor: colorActivo,
          onSelected: (v) => setState(() => _gratis = v),
        ),

        const Text('Hora', style: TextStyle(fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Inmediato')),
                  ButtonSegment(value: false, label: Text('Programado')),
                ],
                selected: {_inmediato},
                onSelectionChanged: (s) => setState(() => _inmediato = s.first),
              ),
            ),
          ],
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
        const SizedBox(height: 16),

        const Text('Productos', style: TextStyle(fontWeight: FontWeight.w700)),
        _construirFilaProducto(
          nombre: 'Puerco',
          precioUnitario: precioPuerco,
          cantidad: _cantPuerco,
          onChanged: (v) => setState(() => _cantPuerco = v),
        ),
        _construirFilaProducto(
          nombre: 'Elote',
          precioUnitario: precioElote,
          cantidad: _cantElote,
          onChanged: (v) => setState(() => _cantElote = v),
        ),
        const SizedBox(height: 16),

        FilledButton(
          style: FilledButton.styleFrom(
            minimumSize: const Size.fromHeight(52),
            backgroundColor: _colorMarcador,
            foregroundColor: const Color.fromARGB(255, 1, 32, 4),
          ),
          onPressed: puedeConfirmar ? _confirmar : null,
          child: Text(
            'Confirmar pedido (${_moneda.format(totalEstimado)})',
            style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ),
      ],
    );
  }

  /// Renglón táctil con círculos `- [número tocable] +` para cada sabor.
  Widget _construirFilaProducto({
    required String nombre,
    required double precioUnitario,
    required int cantidad,
    required ValueChanged<int> onChanged,
  }) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(nombre, style: const TextStyle(fontSize: 18)),
      subtitle: Text('${_moneda.format(precioUnitario)} c/u'),
      trailing: StepperCantidad(
        valor: cantidad,
        mostrarBotonesDeCinco: false,
        onChanged: onChanged,
      ),
    );
  }
}
