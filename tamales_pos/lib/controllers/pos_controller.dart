import 'package:flutter/foundation.dart';

import '../models/configuracion_precios.dart';
import '../models/inventario.dart';
import '../models/pedido.dart';

/// Controlador principal del estado y la lógica de negocio del punto de venta.
///
/// Gestiona el inventario diario, la lista de pedidos activos e históricos,
/// las tarifas vigentes, el cálculo de deudas por tienda y el corte semanal.
class PosController extends ChangeNotifier {
  ConfiguracionPrecios _precios = const ConfiguracionPrecios();
  Inventario _inventario = const Inventario();
  final List<Pedido> _pedidos = [];

  /// Crea una instancia de [PosController] precargada con datos de prueba
  /// para facilitar el desarrollo y validación visual de las pantallas.
  PosController() {
    _cargarDatosPrueba();
  }

  /// Tarifas unitarias vigentes para público y tiendas.
  ConfiguracionPrecios get precios => _precios;

  /// Estado actual del inventario diario y temporizador de cocción.
  Inventario get inventario => _inventario;

  /// Lista completa de pedidos registrados (activos y archivados).
  List<Pedido> get todosLosPedidos => List.unmodifiable(_pedidos);

  /// Pedidos pertenecientes a la semana abierta (`semanaId == 'actual'`)
  /// más aquellos pedidos de semanas anteriores que aún siguen sin pagarse.
  List<Pedido> get pedidosVisiblesEnOperacion {
    final activos = _pedidos
        .where((p) => p.semanaId == 'actual' || !p.pagado)
        .toList();

    // Ordena priorizando los no entregados y por hora de entrega más próxima
    activos.sort((a, b) {
      if (a.entregado != b.entregado) {
        return a.entregado ? 1 : -1;
      }
      final horaA = a.horaEntrega ?? a.horaRegistro;
      final horaB = b.horaEntrega ?? b.horaRegistro;
      return horaA.compareTo(horaB);
    });

    return activos;
  }

  /// Lista única de nombres de clientes y tiendas registrados previamente
  /// para alimentar el autocompletado del formulario de pedidos.
  List<String> get clientesFrecuentes {
    return _pedidos
        .map((p) => p.cliente.trim())
        .where((nombre) => nombre.isNotEmpty && nombre != 'Mostrador')
        .toSet()
        .toList()
      ..sort();
  }

  /// Identificadores de semanas cerradas disponibles en el historial,
  /// ordenados de la más reciente a la más antigua.
  List<String> get semanasCerradas {
    final ids = _pedidos
        .map((p) => p.semanaId)
        .where((id) => id != 'actual')
        .toSet()
        .toList();
    ids.sort((a, b) => b.compareTo(a));
    return ids;
  }

  /// Gestión de precios e inventarios
  ///
  ///
  /// Actualiza las tarifas vigentes del negocio y notifica a la interfaz.
  void actualizarPrecios(ConfiguracionPrecios nuevosPrecios) {
    _precios = nuevosPrecios;
    notifyListeners();
  }

  /// Reemplaza manualmente los conteos del inventario diario.
  void actualizarInventarioManual(Inventario nuevoInventario) {
    _inventario = nuevoInventario;
    notifyListeners();
  }

  /// Mueve tamales de congelados a cocción e inicia el temporizador.
  ///
  /// Descuenta [puerco] y [elote] de las reservas congeladas (sin bajar de 0)
  /// y fija [Inventario.horaFinCoccion] sumando [minutosCoccion] a la hora actual.
  void iniciarCoccion({
    required int puerco,
    required int elote,
    required int minutosCoccion,
  }) {
    if (puerco <= 0 && elote <= 0) return;

    final nuevosCongeladosPuerco = (_inventario.puercoCongelados - puerco)
        .clamp(0, 99999);
    final nuevosCongeladosElote = (_inventario.eloteCongelados - elote).clamp(
      0,
      99999,
    );

    _inventario = _inventario.copyWith(
      puercoCongelados: nuevosCongeladosPuerco,
      eloteCongelados: nuevosCongeladosElote,
      puercoCociendose: _inventario.puercoCociendose + puerco,
      eloteCociendose: _inventario.eloteCociendose + elote,
      horaFinCoccion: DateTime.now().add(Duration(minutes: minutosCoccion)),
    );
    notifyListeners();
  }

  /// Finaliza la tanda activa de cocción moviendo todos los tamales en olla
  /// hacia el contador de tamales cocidos listos para entrega.
  void finalizarCoccion() {
    _inventario = _inventario.copyWith(
      puercoCocidos: _inventario.puercoCocidos + _inventario.puercoCociendose,
      eloteCocidos: _inventario.eloteCocidos + _inventario.eloteCociendose,
      puercoCociendose: 0,
      eloteCociendose: 0,
      limpiarHoraFin: true,
    );
    notifyListeners();
  }

  /// Reinicia los contadores de vendidos del día a cero al iniciar jornada.
  void reiniciarVendidosHoy() {
    _inventario = _inventario.copyWith(
      puercoVendidosHoy: 0,
      eloteVendidosHoy: 0,
    );
    notifyListeners();
  }

  /// Gestión de pedidos
  ///
  ///
  /// Registra un nuevo pedido congelando las tarifas vigentes del momento.
  ///
  /// Si [entregado] es `true` desde la creación, descuenta automáticamente las
  /// piezas del inventario cocido y las suma a los vendidos del día.
  void agregarPedido({
    required String cliente,
    required TipoTarifa tarifa,
    required int cantidadPuerco,
    required int cantidadElote,
    DateTime? horaEntrega,
    bool entregado = false,
    bool pagado = false,
  }) {
    final precioPuerco = tarifa == TipoTarifa.tienda
        ? _precios.puercoTienda
        : _precios.puercoPublico;
    final precioElote = tarifa == TipoTarifa.tienda
        ? _precios.eloteTienda
        : _precios.elotePublico;

    final nuevo = Pedido(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      cliente: cliente.trim().isEmpty ? 'Mostrador' : cliente.trim(),
      tarifa: tarifa,
      cantidadPuerco: cantidadPuerco,
      cantidadElote: cantidadElote,
      precioPuercoAplicado: precioPuerco,
      precioEloteAplicado: precioElote,
      horaRegistro: DateTime.now(),
      horaEntrega: horaEntrega,
      entregado: entregado,
      pagado: pagado,
    );

    _pedidos.add(nuevo);

    if (entregado) {
      _ajustarInventarioPorEntrega(nuevo, entregando: true);
    }

    notifyListeners();
  }

  /// Alterna el estado de entrega de un pedido y ajusta el inventario.
  ///
  /// Al marcar como entregado descuenta de cocidos y suma a vendidos; si se
  /// desmarca por error, revierte el movimiento en el inventario.
  void alternarEntregado(String pedidoId) {
    final index = _pedidos.indexWhere((p) => p.id == pedidoId);
    if (index == -1) return;

    final actual = _pedidos[index];
    final nuevoEstado = !actual.entregado;

    _pedidos[index] = actual.copyWith(entregado: nuevoEstado);
    _ajustarInventarioPorEntrega(actual, entregando: nuevoEstado);
    notifyListeners();
  }

  /// Alterna el estado de pago de un pedido individual.
  void alternarPagado(String pedidoId) {
    final index = _pedidos.indexWhere((p) => p.id == pedidoId);
    if (index == -1) return;

    final actual = _pedidos[index];
    _pedidos[index] = actual.copyWith(pagado: !actual.pagado);
    notifyListeners();
  }

  /// Elimina un pedido de la lista y revierte el inventario si ya había sido entregado.
  void eliminarPedido(String pedidoId) {
    final index = _pedidos.indexWhere((p) => p.id == pedidoId);
    if (index == -1) return;

    final pedido = _pedidos[index];
    if (pedido.entregado) {
      _ajustarInventarioPorEntrega(pedido, entregando: false);
    }
    _pedidos.removeAt(index);
    notifyListeners();
  }

  void _ajustarInventarioPorEntrega(Pedido pedido, {required bool entregando}) {
    if (entregando) {
      _inventario = _inventario.copyWith(
        puercoCocidos: (_inventario.puercoCocidos - pedido.cantidadPuerco)
            .clamp(0, 99999),
        eloteCocidos: (_inventario.eloteCocidos - pedido.cantidadElote).clamp(
          0,
          99999,
        ),
        puercoVendidosHoy:
            _inventario.puercoVendidosHoy + pedido.cantidadPuerco,
        eloteVendidosHoy: _inventario.eloteVendidosHoy + pedido.cantidadElote,
      );
    } else {
      _inventario = _inventario.copyWith(
        puercoCocidos: _inventario.puercoCocidos + pedido.cantidadPuerco,
        eloteCocidos: _inventario.eloteCocidos + pedido.cantidadElote,
        puercoVendidosHoy:
            (_inventario.puercoVendidosHoy - pedido.cantidadPuerco).clamp(
              0,
              99999,
            ),
        eloteVendidosHoy: (_inventario.eloteVendidosHoy - pedido.cantidadElote)
            .clamp(0, 99999),
      );
    }
  }

  /// Gestión de resumen y cobranza
  ///
  ///
  /// Filtra los pedidos correspondientes a una semana específica (`'actual'` o ID cerrado).
  List<Pedido> pedidosPorSemana(String semanaId) {
    return _pedidos.where((p) => p.semanaId == semanaId).toList();
  }

  /// Agrupa todos los pedidos pendientes de pago (`!pagado`) por nombre de cliente.
  Map<String, List<Pedido>> get deudasPorCliente {
    final pendientes = _pedidos.where((p) => !p.pagado);
    final Map<String, List<Pedido>> agrupados = {};

    for (final pedido in pendientes) {
      agrupados.putIfAbsent(pedido.cliente, () => []).add(pedido);
    }
    return agrupados;
  }

  /// Marca como pagados todos los pedidos pendientes de un mismo cliente o tienda.
  void liquidarDeudaCliente(String cliente) {
    for (int i = 0; i < _pedidos.length; i++) {
      if (_pedidos[i].cliente == cliente && !_pedidos[i].pagado) {
        _pedidos[i] = _pedidos[i].copyWith(pagado: true);
      }
    }
    notifyListeners();
  }

  /// Realiza el corte de la semana actual archivando los pedidos ya pagados
  /// bajo la etiqueta [etiquetaSemana] (ej. `'2026-11-16'`).
  ///
  /// Los pedidos que sigan pendientes de cobro (`!pagado`) permanecen en `'actual'`
  /// para no perder visibilidad de la deuda hasta que sean liquidados.
  void cerrarSemana(String etiquetaSemana) {
    for (int i = 0; i < _pedidos.length; i++) {
      final p = _pedidos[i];
      if (p.semanaId == 'actual' && p.pagado) {
        _pedidos[i] = p.copyWith(semanaId: etiquetaSemana);
      }
    }
    notifyListeners();
  }

  /// Carga un escenario inicial realista para probar pantallas sin captura manual (TEST).
  void _cargarDatosPrueba() {
    final ahora = DateTime.now();

    _inventario = Inventario(
      puercoCocidos: 35,
      puercoCociendose: 20,
      puercoCongelados: 80,
      puercoVendidosHoy: 25,
      eloteCocidos: 28,
      eloteCociendose: 15,
      eloteCongelados: 60,
      eloteVendidosHoy: 18,
      horaFinCoccion: ahora.add(const Duration(minutes: 18)),
    );

    _pedidos.addAll([
      Pedido(
        id: '1',
        cliente: 'Abarrotes Don Pepe',
        tarifa: TipoTarifa.tienda,
        cantidadPuerco: 15,
        cantidadElote: 10,
        precioPuercoAplicado: _precios.puercoTienda,
        precioEloteAplicado: _precios.eloteTienda,
        horaRegistro: ahora.subtract(const Duration(hours: 2)),
        entregado: true,
        pagado: false,
      ),
      Pedido(
        id: '2',
        cliente: 'Sra. Martha',
        tarifa: TipoTarifa.publico,
        cantidadPuerco: 6,
        cantidadElote: 4,
        precioPuercoAplicado: _precios.puercoPublico,
        precioEloteAplicado: _precios.elotePublico,
        horaRegistro: ahora.subtract(const Duration(minutes: 25)),
        horaEntrega: ahora.add(const Duration(minutes: 35)),
        entregado: false,
        pagado: true,
      ),
      Pedido(
        id: '3',
        cliente: 'Mini Súper La Esquina',
        tarifa: TipoTarifa.tienda,
        cantidadPuerco: 20,
        cantidadElote: 20,
        precioPuercoAplicado: _precios.puercoTienda,
        precioEloteAplicado: _precios.eloteTienda,
        horaRegistro: ahora.subtract(const Duration(days: 1)),
        entregado: true,
        pagado: false,
      ),
    ]);
  }
}
