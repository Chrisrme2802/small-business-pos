import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../controllers/pos_controller.dart';
import '../models/pedido.dart';
import '../widgets/stepper_cantidad.dart';
import '../widgets/tarjeta_estado_cuenta.dart';
import '../widgets/tarjeta_pedido.dart';
import '../widgets/titulo_marcador.dart';

/// Pantalla de corte semanal, cobranza, devoluciones y analítica (Pestaña 3).
///
/// Permite consultar la semana abierta (`Actual`), el último corte cerrado
/// (`Pasada`) y el historial previo (`Anteriores`) tanto en acumulado global
/// como por semana individual, además de gestionar devoluciones, emitir
/// estados de cuenta consolidados, liquidar cuentas por cobrar y visualizar
/// gráficas de ventas y horas pico.
class ResumenScreen extends StatefulWidget {
  /// Crea una instancia de [ResumenScreen].
  const ResumenScreen({super.key});

  @override
  State<ResumenScreen> createState() => _ResumenScreenState();
}

class _ResumenScreenState extends State<ResumenScreen> {
  /// Índice del selector de semana (`0`: Anteriores, `1`: Pasada, `2`: Actual).
  int _sel = 2;

  /// Identificador de la semana individual elegida dentro de `Anteriores`
  /// (`null` representa el acumulado de todas las semanas anteriores).
  String? _semanaAnteriorSeleccionada;

  /// Texto de búsqueda para filtrar clientes o tiendas en la sección de cuentas.
  String _busquedaCuentas = '';

  /// Color resaltador usado en las barras de gráficas y chips activos.
  static const Color _colorMarcador = Color(0xFFD9F99D);

  /// Formateador de moneda en pesos mexicanos (`$0.00`).
  static final NumberFormat _moneda = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );

  /// Muestra un diálogo de confirmación y archiva los movimientos saldados o
  /// cancelados de la semana actual, dejando abierta la nueva semana.
  Future<void> _cerrarSemana() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Cerrar semana'),
        content: const Text(
          'Los pedidos saldados (y cancelados) de esta semana pasarán a "Pasada" '
          'y se iniciará una nueva semana en blanco (las cuentas por cobrar siguen activas). ¿Continuar?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cerrar y abrir nueva'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      final etiqueta = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());
      context.read<PosController>().cerrarSemana(etiqueta);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Semana cerrada. Ya puedes registrar pedidos de la nueva semana.',
          ),
        ),
      );
    }
  }

  /// Abre el diálogo para registrar una devolución de mercancía a una tienda
  /// o cliente sin alterar sus pedidos históricos.
  Future<void> _abrirDialogoDevolucionCliente(String cliente) async {
    int devPuerco = 0;
    int devElote = 0;
    bool aCongelado = true;

    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) => AlertDialog(
          title: Text('Devolución · $cliente'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Se registrará un abono en la cuenta de $cliente sin modificar sus pedidos anteriores.',
                  style: Theme.of(ctx).textTheme.bodySmall,
                ),
                const SizedBox(height: 12),
                StepperCantidad(
                  etiqueta: 'Puerco devueltos',
                  valor: devPuerco,
                  onChanged: (v) => setS(() => devPuerco = v),
                ),
                const SizedBox(height: 12),
                StepperCantidad(
                  etiqueta: 'Elote devueltos',
                  valor: devElote,
                  onChanged: (v) => setS(() => devElote = v),
                ),
                const SizedBox(height: 16),
                const Text(
                  'Reingresar tamales a:',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 6),
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment(value: true, label: Text('Congelado')),
                    ButtonSegment(
                      value: false,
                      label: Text('Listo (calientes)'),
                    ),
                  ],
                  selected: {aCongelado},
                  onSelectionChanged: (s) => setS(() => aCongelado = s.first),
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
              onPressed: (devPuerco + devElote) > 0
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: const Text('Registrar devolución'),
            ),
          ],
        ),
      ),
    );

    if (confirmar == true && mounted) {
      context.read<PosController>().registrarDevolucionCliente(
        cliente: cliente,
        devueltosPuerco: devPuerco,
        devueltosElote: devElote,
        regresarACongelado: aCongelado,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PosController>();

    final cerradas = p.semanasCerradas;
    final anterioresIds = cerradas.length > 1
        ? cerradas.sublist(1)
        : <String>[];

    final filtroAnteriorActivo =
        anterioresIds.contains(_semanaAnteriorSeleccionada)
        ? _semanaAnteriorSeleccionada
        : null;

    List<Pedido> movimientos = [];
    String subtituloSemana = 'Semana abierta en curso';

    if (_sel == 2) {
      movimientos = p.pedidosPorSemana('actual');
      subtituloSemana = 'Semana abierta · Los nuevos pedidos se suman aquí';
    } else if (_sel == 1) {
      if (cerradas.isNotEmpty) {
        movimientos = p.pedidosPorSemana(cerradas.first);
        subtituloSemana = 'Corte cerrado el ${cerradas.first}';
      } else {
        subtituloSemana = 'Aún no hay una semana pasada cerrada';
      }
    } else if (_sel == 0) {
      if (anterioresIds.isNotEmpty) {
        if (filtroAnteriorActivo == null) {
          for (final id in anterioresIds) {
            movimientos.addAll(p.pedidosPorSemana(id));
          }
          subtituloSemana =
              'Acumulado de ${anterioresIds.length} semana(s) archivadas';
        } else {
          movimientos = p.pedidosPorSemana(filtroAnteriorActivo);
          subtituloSemana = 'Semana archivada el $filtroAnteriorActivo';
        }
      } else {
        subtituloSemana = 'Sin historial de semanas anteriores';
      }
    }

    final movimientosVigentes = movimientos.where((x) => !x.cancelado).toList();
    final soloPedidos = movimientos.where((x) => !x.esDevolucion).toList();
    final soloPedidosVigentes = movimientosVigentes
        .where((x) => !x.esDevolucion)
        .toList();

    final total = movimientosVigentes.fold<double>(
      0,
      (a, x) => a + x.totalPesos,
    );
    final encaja = movimientosVigentes
        .where((x) => x.pagado)
        .fold<double>(0, (a, x) => a + x.totalPesos);
    final porCobrar = (total - encaja).clamp(0.0, double.infinity);

    final porDia = <int, List<Pedido>>{};
    for (final x in soloPedidos) {
      porDia.putIfAbsent(x.horaRegistro.weekday, () => []).add(x);
    }

    final esSemanaActual = _sel == 2;
    final Map<String, List<Pedido>> mapaCuentas;
    if (esSemanaActual) {
      mapaCuentas = p.deudasPorCliente;
    } else {
      mapaCuentas = <String, List<Pedido>>{};
      for (final mov in movimientos) {
        mapaCuentas.putIfAbsent(mov.cliente, () => []).add(mov);
      }
    }

    final cuentasFiltradas = mapaCuentas.entries
        .where(
          (e) => e.key.toLowerCase().contains(_busquedaCuentas.toLowerCase()),
        )
        .toList();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const TituloMarcador('Semanas'),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 0, label: Text('Anteriores')),
            ButtonSegment(value: 1, label: Text('Pasada')),
            ButtonSegment(value: 2, label: Text('Actual')),
          ],
          selected: {_sel},
          onSelectionChanged: (s) => setState(() => _sel = s.first),
        ),

        if (_sel == 0 && anterioresIds.isNotEmpty) ...[
          const SizedBox(height: 10),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  label: Text('Todas (${anterioresIds.length})'),
                  selected: filtroAnteriorActivo == null,
                  selectedColor: _colorMarcador,
                  onSelected: (_) =>
                      setState(() => _semanaAnteriorSeleccionada = null),
                ),
                const SizedBox(width: 8),
                for (final id in anterioresIds) ...[
                  ChoiceChip(
                    label: Text(id),
                    selected: filtroAnteriorActivo == id,
                    selectedColor: _colorMarcador,
                    onSelected: (_) =>
                        setState(() => _semanaAnteriorSeleccionada = id),
                  ),
                  const SizedBox(width: 8),
                ],
              ],
            ),
          ),
        ],

        const SizedBox(height: 6),
        Text(subtituloSemana, style: Theme.of(context).textTheme.bodySmall),
        const SizedBox(height: 12),

        if (porDia.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 24, horizontal: 12),
            child: Center(
              child: Text(
                esSemanaActual
                    ? 'Semana actual limpia. Toma un pedido en la pestaña central para comenzar.'
                    : 'Sin pedidos registrados en este periodo.',
                textAlign: TextAlign.center,
              ),
            ),
          )
        else
          for (final dia in (porDia.keys.toList()..sort()))
            _DiaTile(dia: dia, pedidos: porDia[dia]!, moneda: _moneda),

        if (esSemanaActual)
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: movimientos.any((x) => x.pagado || x.cancelado)
                  ? _cerrarSemana
                  : null,
              icon: const Icon(Icons.lock_clock, size: 18),
              label: const Text('Cerrar semana'),
            ),
          ),
        const SizedBox(height: 16),

        Row(
          children: [
            _Kpi('Vendido neto', total, _moneda),
            _Kpi('En caja', encaja, _moneda),
            _Kpi('Por cobrar', porCobrar, _moneda),
          ],
        ),
        const SizedBox(height: 20),

        TituloMarcador(
          esSemanaActual ? 'Módulo de cuentas' : 'Pedidos por cliente',
        ),
        const SizedBox(height: 8),
        TextField(
          decoration: const InputDecoration(
            prefixIcon: Icon(Icons.search),
            hintText: 'Buscar tienda o cliente',
            isDense: true,
            border: OutlineInputBorder(),
          ),
          onChanged: (v) => setState(() => _busquedaCuentas = v),
        ),
        const SizedBox(height: 8),
        if (cuentasFiltradas.isEmpty)
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              esSemanaActual
                  ? 'No hay cuentas por cobrar.'
                  : 'No hay pedidos de clientes en este periodo.',
            ),
          ),
        for (final d in cuentasFiltradas)
          _CuentaClienteTile(
            cliente: d.key,
            movimientos: d.value,
            moneda: _moneda,
            esHistorico: !esSemanaActual,
            onEstadoCuenta: () => mostrarEstadoCuenta(
              context,
              cliente: d.key,
              movimientos: d.value,
              esHistorico: !esSemanaActual,
            ),
            onDevolucion: () => _abrirDialogoDevolucionCliente(d.key),
            onLiquidarTodo: () =>
                context.read<PosController>().liquidarDeudaCliente(d.key),
          ),
        const SizedBox(height: 20),

        const TituloMarcador('Gráficas'),
        const SizedBox(height: 12),
        Text('Ventas por día', style: Theme.of(context).textTheme.titleSmall),
        SizedBox(height: 180, child: _graficaVentas(porDia)),
        const SizedBox(height: 16),
        Text(
          'Horas pico (pedidos)',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        SizedBox(height: 180, child: _graficaHoras(soloPedidosVigentes)),
      ],
    );
  }

  /// Configura los títulos de ejes para las gráficas de barras minimalistas.
  FlTitlesData _titulos(String Function(int) etiqueta) => FlTitlesData(
    topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
    bottomTitles: AxisTitles(
      sideTitles: SideTitles(
        showTitles: true,
        getTitlesWidget: (v, _) => Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text(
            etiqueta(v.toInt()),
            style: const TextStyle(fontSize: 11),
          ),
        ),
      ),
    ),
  );

  /// Construye la gráfica de barras con los ingresos netos por día de la semana.
  Widget _graficaVentas(Map<int, List<Pedido>> porDia) {
    const letras = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];
    return BarChart(
      BarChartData(
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: _titulos((i) => letras[(i - 1).clamp(0, 6)]),
        barGroups: [
          for (var d = 1; d <= 7; d++)
            BarChartGroupData(
              x: d,
              barRods: [
                BarChartRodData(
                  toY: (porDia[d] ?? [])
                      .where((x) => !x.cancelado)
                      .fold<double>(0, (a, x) => a + x.totalPesos),
                  color: _colorMarcador,
                  width: 16,
                  borderRadius: BorderRadius.circular(3),
                ),
              ],
            ),
        ],
      ),
    );
  }

  /// Construye la gráfica de barras con la distribución horaria de pedidos vigentes.
  Widget _graficaHoras(List<Pedido> pedidos) {
    final conteo = <int, int>{};
    for (final x in pedidos) {
      conteo[x.horaRegistro.hour] = (conteo[x.horaRegistro.hour] ?? 0) + 1;
    }
    return BarChart(
      BarChartData(
        borderData: FlBorderData(show: false),
        gridData: const FlGridData(show: false),
        titlesData: _titulos((h) => h % 2 == 0 ? '$h' : ''),
        barGroups: [
          for (var h = 6; h <= 22; h++)
            BarChartGroupData(
              x: h,
              barRods: [
                BarChartRodData(
                  toY: (conteo[h] ?? 0).toDouble(),
                  color: Colors.black87,
                  width: 9,
                  borderRadius: BorderRadius.circular(2),
                ),
              ],
            ),
        ],
      ),
    );
  }
}

/// Tarjeta desplegable de un cliente o tienda (por cobrar o histórico cerrado)
/// con acceso a su ticket consolidado de estado de cuenta, devoluciones y cobro.
class _CuentaClienteTile extends StatelessWidget {
  final String cliente;
  final List<Pedido> movimientos;
  final NumberFormat moneda;
  final bool esHistorico;
  final VoidCallback onEstadoCuenta;
  final VoidCallback onDevolucion;
  final VoidCallback onLiquidarTodo;

  const _CuentaClienteTile({
    required this.cliente,
    required this.movimientos,
    required this.moneda,
    required this.esHistorico,
    required this.onEstadoCuenta,
    required this.onDevolucion,
    required this.onLiquidarTodo,
  });

  @override
  Widget build(BuildContext context) {
    final devoluciones = movimientos
        .where((m) => m.esDevolucion && !m.cancelado)
        .toList();
    final pedidos = movimientos.where((m) => !m.esDevolucion).toList();
    final pedidosVigentes = pedidos.where((p) => !p.cancelado).toList();

    final saldoNeto = movimientos
        .where((m) => !m.cancelado)
        .fold<double>(0, (suma, mov) => suma + mov.totalPesos);
    final totalPuerco = pedidosVigentes.fold<int>(
      0,
      (s, p) => s + p.cantidadPuerco,
    );
    final totalElote = pedidosVigentes.fold<int>(
      0,
      (s, p) => s + p.cantidadElote,
    );

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: Colors.black26),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ExpansionTile(
        shape: const Border(),
        title: Text(
          cliente,
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          '${moneda.format(saldoNeto)} · ${pedidosVigentes.length} pedido(s) ($totalPuerco P / $totalElote E)'
          '${devoluciones.isNotEmpty ? ' · ${devoluciones.length} dev.' : ''}',
        ),
        childrenPadding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
        children: [
          if (devoluciones.isNotEmpty) ...[
            const Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: EdgeInsets.only(top: 4, bottom: 4),
                child: Text(
                  'Devoluciones aplicadas',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 12,
                    color: Color(0xFF8B1E3F),
                  ),
                ),
              ),
            ),
            for (final dev in devoluciones)
              _TarjetaDevolucion(devolucion: dev, moneda: moneda),
            const Divider(height: 16),
          ],

          for (final pedido in pedidos) TarjetaPedido(pedido: pedido),

          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.end,
            spacing: 8,
            runSpacing: 6,
            children: [
              OutlinedButton.icon(
                onPressed: onEstadoCuenta,
                icon: const Icon(Icons.receipt_long, size: 18),
                label: const Text('Estado de cuenta'),
              ),
              if (!esHistorico) ...[
                OutlinedButton.icon(
                  onPressed: onDevolucion,
                  icon: const Icon(Icons.assignment_return_outlined, size: 18),
                  label: const Text('Devolución'),
                ),
                FilledButton.tonalIcon(
                  onPressed: onLiquidarTodo,
                  icon: const Icon(Icons.check_circle_outline, size: 18),
                  label: Text('Liquidar todo (${moneda.format(saldoNeto)})'),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// Renglón visual que conserva el historial de una devolución aplicada.
class _TarjetaDevolucion extends StatelessWidget {
  final Pedido devolucion;
  final NumberFormat moneda;

  const _TarjetaDevolucion({required this.devolucion, required this.moneda});

  @override
  Widget build(BuildContext context) {
    final partes = <String>[
      if (devolucion.cantidadPuerco > 0) '-${devolucion.cantidadPuerco} Puerco',
      if (devolucion.cantidadElote > 0) '-${devolucion.cantidadElote} Elote',
    ];

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 3),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFFDF2F4),
        border: Border.all(
          color: const Color(0xFF8B1E3F).withValues(alpha: 0.4),
        ),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.assignment_return,
            size: 18,
            color: Color(0xFF8B1E3F),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Devolución · ${partes.join(' · ')}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    color: Color(0xFF8B1E3F),
                  ),
                ),
                Text(
                  DateFormat('dd/MM HH:mm').format(devolucion.horaRegistro),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          Text(
            moneda.format(devolucion.totalPesos),
            style: const TextStyle(
              fontWeight: FontWeight.w800,
              color: Color(0xFF8B1E3F),
            ),
          ),
        ],
      ),
    );
  }
}

/// Tarjeta compacta de indicador clave de rendimiento financiero (KPI).
class _Kpi extends StatelessWidget {
  final String titulo;
  final double valor;
  final NumberFormat moneda;

  const _Kpi(this.titulo, this.valor, this.moneda);

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
          side: const BorderSide(color: Colors.black26),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(titulo, style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: 4),
              FittedBox(
                child: Text(
                  moneda.format(valor),
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 18,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Acordeón desplegable que agrupa los pedidos por día de la semana y hora.
class _DiaTile extends StatelessWidget {
  final int dia;
  final List<Pedido> pedidos;
  final NumberFormat moneda;

  const _DiaTile({
    required this.dia,
    required this.pedidos,
    required this.moneda,
  });

  @override
  Widget build(BuildContext context) {
    final nombreDia = toBeginningOfSentenceCase(
      DateFormat('EEEE', 'es_MX').format(DateTime(2024, 1, dia)),
    )!;
    final porHora = <int, List<Pedido>>{};
    for (final x in pedidos) {
      porHora.putIfAbsent(x.horaRegistro.hour, () => []).add(x);
    }
    final total = pedidos
        .where((x) => !x.cancelado)
        .fold<double>(0, (a, x) => a + x.totalPesos);

    return ExpansionTile(
      tilePadding: EdgeInsets.zero,
      title: Text(
        nombreDia,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      trailing: Text(moneda.format(total)),
      children: [
        for (final h in (porHora.keys.toList()..sort()))
          ExpansionTile(
            title: Text(
              '${DateFormat('hh:00 a').format(DateTime(2024, 1, 1, h))}  ·  ${porHora[h]!.length} pedidos',
            ),
            children: [for (final x in porHora[h]!) TarjetaPedido(pedido: x)],
          ),
      ],
    );
  }
}
