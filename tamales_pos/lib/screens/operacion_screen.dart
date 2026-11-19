import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/pos_controller.dart';
import '../widgets/carrusel_ollas.dart';
import '../widgets/stepper_cantidad.dart';
import '../widgets/tarjeta_pedido.dart';
import '../widgets/titulo_marcador.dart';

/// Pantalla principal de operación diaria del punto de venta (Pestaña 1).
class OperacionScreen extends StatefulWidget {
  /// Crea una instancia de [OperacionScreen].
  const OperacionScreen({super.key});

  @override
  State<OperacionScreen> createState() => _OperacionScreenState();
}

class _OperacionScreenState extends State<OperacionScreen> {
  String _busqueda = '';
  String _filtro = 'Todos';

  static const Color _colorActivo = Color(0xFFD9F99D);

  /// Abre el modal para **Inicializar** el inventario del día (borrando ollas
  /// y vendidos previos) o **Editar** manualmente las existencias actuales.
  Future<void> _abrirDialogoInventario({required bool esInicializar}) async {
    final controller = context.read<PosController>();
    final inv = controller.inventario;

    int pListo = esInicializar ? 0 : inv.puercoCocidos;
    int eListo = esInicializar ? 0 : inv.eloteCocidos;
    int pCong = esInicializar ? 0 : inv.puercoCongelados;
    int eCong = esInicializar ? 0 : inv.eloteCongelados;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text(
            esInicializar ? 'Inicializar inventario' : 'Editar inventario',
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (esInicializar)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Text(
                      'Reinicia el conteo del día desde cero y carga los tamales iniciales.',
                      style: Theme.of(ctx).textTheme.bodySmall,
                    ),
                  ),
                const Text(
                  'Listos (cocidos)',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                StepperCantidad(
                  etiqueta: 'Puerco',
                  valor: pListo,
                  onChanged: (v) => setS(() => pListo = v),
                ),
                const SizedBox(height: 8),
                StepperCantidad(
                  etiqueta: 'Elote',
                  valor: eListo,
                  onChanged: (v) => setS(() => eListo = v),
                ),
                const Divider(height: 24),
                const Text(
                  'Congelados',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                StepperCantidad(
                  etiqueta: 'Puerco',
                  valor: pCong,
                  onChanged: (v) => setS(() => pCong = v),
                ),
                const SizedBox(height: 8),
                StepperCantidad(
                  etiqueta: 'Elote',
                  valor: eCong,
                  onChanged: (v) => setS(() => eCong = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(esInicializar ? 'Inicializar' : 'Guardar cambios'),
            ),
          ],
        ),
      ),
    );

    if (confirmar == true && mounted) {
      if (esInicializar) {
        controller.inicializarInventarioDia(
          puercoCocidos: pListo,
          eloteCocidos: eListo,
          puercoCongelados: pCong,
          eloteCongelados: eCong,
        );
      } else {
        controller.editarInventarioExistencias(
          puercoCocidos: pListo,
          eloteCocidos: eListo,
          puercoCongelados: pCong,
          eloteCongelados: eCong,
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PosController>();
    final inv = p.inventario;

    final pedidos = p.pedidosVisiblesEnOperacion.where((x) {
      if (_filtro == 'Por entregar' && x.entregado) return false;
      if (_filtro == 'Por cobrar' && x.pagado) return false;
      return x.cliente.toLowerCase().contains(_busqueda.toLowerCase());
    }).toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        TituloMarcador(
          'Tamales',
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(
              color: _colorActivo,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Text(
              DateFormat('dd/MM/yy').format(DateTime.now()),
              style: const TextStyle(
                fontWeight: FontWeight.w700,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        const CarruselOllas(),
        const SizedBox(height: 16),
        TituloMarcador(
          'Inventario',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextButton.icon(
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _abrirDialogoInventario(esInicializar: false),
                icon: const Icon(Icons.edit_outlined, size: 16),
                label: const Text('Editar'),
              ),
              const SizedBox(width: 4),
              FilledButton.tonalIcon(
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () => _abrirDialogoInventario(esInicializar: true),
                icon: const Icon(Icons.restart_alt, size: 16),
                label: const Text('Inicializar'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Table(
          columnWidths: const {0: FlexColumnWidth(1.4)},
          children: [
            const TableRow(
              children: [
                SizedBox(),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Puerco',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                Padding(
                  padding: EdgeInsets.symmetric(vertical: 4),
                  child: Text(
                    'Elote',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            _construirFilaInventario(
              etiqueta: 'Listos',
              valorPuerco: inv.puercoCocidos,
              valorElote: inv.eloteCocidos,
            ),
            _construirFilaInventario(
              etiqueta: 'Cociéndose',
              valorPuerco: inv.puercoCociendose,
              valorElote: inv.eloteCociendose,
            ),
            _construirFilaInventario(
              etiqueta: 'Congelados',
              valorPuerco: inv.puercoCongelados,
              valorElote: inv.eloteCongelados,
            ),
            _construirFilaInventario(
              etiqueta: 'Total',
              valorPuerco: inv.totalPuercoDisponible,
              valorElote: inv.totalEloteDisponible,
              esTotal: true,
            ),
          ],
        ),
        const SizedBox(height: 16),
        const TituloMarcador('Pedidos'),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar cliente',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _busqueda = v),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            for (final f in ['Todos', 'Por entregar', 'Por cobrar'])
              ChoiceChip(
                label: Text(f),
                selected: _filtro == f,
                selectedColor: _colorActivo,
                onSelected: (_) => setState(() => _filtro = f),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (pedidos.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Center(child: Text('Sin pedidos con este filtro.')),
          )
        else
          for (final x in pedidos) TarjetaPedido(pedido: x),
      ],
    );
  }

  TableRow _construirFilaInventario({
    required String etiqueta,
    required int valorPuerco,
    required int valorElote,
    bool esTotal = false,
  }) {
    final estiloNumero = TextStyle(
      fontWeight: esTotal ? FontWeight.w800 : FontWeight.w400,
    );

    return TableRow(
      decoration: esTotal
          ? const BoxDecoration(
              border: Border(top: BorderSide(color: Colors.black45)),
            )
          : null,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Text(
            etiqueta,
            style: TextStyle(
              fontWeight: esTotal ? FontWeight.w700 : FontWeight.w400,
            ),
          ),
        ),
        Text('$valorPuerco', textAlign: TextAlign.center, style: estiloNumero),
        Text('$valorElote', textAlign: TextAlign.center, style: estiloNumero),
      ],
    );
  }
}
