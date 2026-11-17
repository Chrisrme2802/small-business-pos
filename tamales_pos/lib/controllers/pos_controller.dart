import 'package:flutter/foundation.dart';

import '../models/configuracion_precios.dart';
import '../models/inventario.dart';
import '../models/olla_coccion.dart';
import '../models/pedido.dart';
import '../services/supabase_service.dart';

/// Controlador principal del estado y la lógica de negocio del punto de venta.
///
/// Coordina la interfaz reactiva con [SupabaseService] para persistir en la
/// nube el inventario diario, el carrusel de ollas activas, los pedidos,
/// las devoluciones de tiendas, cancelaciones y cortes semanales.
class PosController extends ChangeNotifier {
  final SupabaseService _db = SupabaseService();

  ConfiguracionPrecios _precios = const ConfiguracionPrecios();
  Inventario _inventario = const Inventario();
  final List<Pedido> _pedidos = [];

  bool _estaCargando = true;
  String? _errorConexion;

  /// Crea una instancia de [PosController] e inicia la sincronización inicial.
  PosController() {
    inicializar();
  }

  /// Indica si la aplicación aún está descargando el estado inicial de la nube.
  bool get estaCargando => _estaCargando;

  /// Mensaje descriptivo si ocurrió un fallo de red al cargar datos iniciales.
  String? get errorConexion => _errorConexion;

  /// Tarifas unitarias vigentes para público y tiendas.
  ConfiguracionPrecios get precios => _precios;

  /// Estado actual del inventario diario y ollas en cocción.
  Inventario get inventario => _inventario;

  /// Lista completa de movimientos registrados (pedidos, devoluciones y cancelados).
  List<Pedido> get todosLosPedidos => List.unmodifiable(_pedidos);

  /// Descarga las tarifas, el inventario y todos los movimientos desde Supabase.
  Future<void> inicializar() async {
    _estaCargando = true;
    _errorConexion = null;
    notifyListeners();

    try {
      final datos = await _db.cargarTodo();
      _precios = datos.precios;
      _inventario = datos.inventario;
      _pedidos
        ..clear()
        ..addAll(datos.pedidos);
    } catch (e) {
      _errorConexion = 'No se pudo conectar con Supabase: $e';
    } finally {
      _estaCargando = false;
      notifyListeners();
    }
  }

  /// Pedidos regulares (incluidos los cancelados de la semana actual)
  /// pertenecientes a la semana abierta o con adeudo activo.
  List<Pedido> get pedidosVisiblesEnOperacion {
    final activos = _pedidos
        .where(
          (p) =>
              !p.esDevolucion &&
              (p.semanaId == 'actual' || (!p.pagado && !p.cancelado)),
        )
        .toList();

    activos.sort((a, b) {
      if (a.cancelado != b.cancelado) {
        return a.cancelado ? 1 : -1;
      }
      if (a.entregado != b.entregado) {
        return a.entregado ? 1 : -1;
      }
      final horaA = a.horaEntrega ?? a.horaRegistro;
      final horaB = b.horaEntrega ?? b.horaRegistro;
      return horaA.compareTo(horaB);
    });

    return activos;
  }

  /// Lista única de nombres de clientes y tiendas para autocompletado.
  List<String> get clientesFrecuentes {
    return _pedidos
        .map((p) => p.cliente.trim())
        .where((nombre) => nombre.isNotEmpty && nombre != 'Mostrador')
        .toSet()
        .toList()
      ..sort();
  }

  /// Identificadores de semanas cerradas ordenadas de más reciente a más antigua.
  List<String> get semanasCerradas {
    final ids = _pedidos
        .map((p) => p.semanaId)
        .where((id) => id != 'actual')
        .toSet()
        .toList();
    ids.sort((a, b) => b.compareTo(a));
    return ids;
  }

  // --- Gestión de precios e inventario ---

  /// Actualiza las tarifas vigentes del negocio y las guarda en Supabase.
  void actualizarPrecios(ConfiguracionPrecios nuevosPrecios) {
    _precios = nuevosPrecios;
    notifyListeners();
    _db.guardarPrecios(_precios);
  }

  /// Reinicia desde cero el inventario del día (limpia ollas activas y
  /// vendidos de la jornada anterior) cargando las nuevas existencias iniciales.
  void inicializarInventarioDia({
    required int puercoCocidos,
    required int eloteCocidos,
    required int puercoCongelados,
    required int eloteCongelados,
  }) {
    _inventario = Inventario(
      puercoCocidos: puercoCocidos.clamp(0, 99999),
      eloteCocidos: eloteCocidos.clamp(0, 99999),
      puercoCongelados: puercoCongelados.clamp(0, 99999),
      eloteCongelados: eloteCongelados.clamp(0, 99999),
      puercoVendidosHoy: 0,
      eloteVendidosHoy: 0,
      ollasActivas: const [],
    );
    notifyListeners();
    _db.guardarInventario(_inventario);
  }

  /// Ajusta manualmente las existencias físicas actuales de listos y congelados
  /// conservando las ollas en cocción y el acumulado vendido del día.
  void editarInventarioExistencias({
    required int puercoCocidos,
    required int eloteCocidos,
    required int puercoCongelados,
    required int eloteCongelados,
  }) {
    _inventario = _inventario.copyWith(
      puercoCocidos: puercoCocidos.clamp(0, 99999),
      eloteCocidos: eloteCocidos.clamp(0, 99999),
      puercoCongelados: puercoCongelados.clamp(0, 99999),
      eloteCongelados: eloteCongelados.clamp(0, 99999),
    );
    notifyListeners();
    _db.guardarInventario(_inventario);
  }

  // --- Gestión de ollas en cocción ---

  /// Agrega una nueva olla al carrusel validando estrictamente que no exceda
  /// los tamales congelados disponibles en inventario.
  void ponerOlla({
    required int puerco,
    required int elote,
    required int minutosCoccion,
    String? nombrePersonalizado,
  }) {
    final puercoValido = puerco.clamp(0, _inventario.puercoCongelados);
    final eloteValido = elote.clamp(0, _inventario.eloteCongelados);
    if (puercoValido <= 0 && eloteValido <= 0) return;

    final nuevosCongeladosPuerco = _inventario.puercoCongelados - puercoValido;
    final nuevosCongeladosElote = _inventario.eloteCongelados - eloteValido;

    final numeroOlla = _inventario.ollasActivas.length + 1;
    final nuevaOlla = OllaCoccion(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      nombre: nombrePersonalizado?.trim().isNotEmpty == true
          ? nombrePersonalizado!.trim()
          : 'Olla $numeroOlla',
      cantidadPuerco: puercoValido,
      cantidadElote: eloteValido,
      horaFin: DateTime.now().add(Duration(minutes: minutosCoccion)),
    );

    final ollasActualizadas = List<OllaCoccion>.from(_inventario.ollasActivas)
      ..add(nuevaOlla);

    _inventario = _inventario.copyWith(
      puercoCongelados: nuevosCongeladosPuerco,
      eloteCongelados: nuevosCongeladosElote,
      ollasActivas: ollasActualizadas,
    );
    notifyListeners();
    _db.guardarInventario(_inventario);
  }

  /// Retira una olla específica del carrusel y suma todo su contenido al
  /// inventario de tamales cocidos listos para entrega.
  void sacarOlla(String ollaId) {
    final index = _inventario.ollasActivas.indexWhere((o) => o.id == ollaId);
    if (index == -1) return;

    final olla = _inventario.ollasActivas[index];
    final ollasRestantes = List<OllaCoccion>.from(_inventario.ollasActivas)
      ..removeAt(index);

    _inventario = _inventario.copyWith(
      puercoCocidos: _inventario.puercoCocidos + olla.cantidadPuerco,
      eloteCocidos: _inventario.eloteCocidos + olla.cantidadElote,
      ollasActivas: ollasRestantes,
    );
    notifyListeners();
    _db.guardarInventario(_inventario);
  }

  // --- Gestión de pedidos, entregas, cancelaciones y devoluciones ---

  /// Registra un nuevo pedido congelando las tarifas vigentes del momento,
  /// lo persiste en Supabase y devuelve el [Pedido] creado.
  Pedido agregarPedido({
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

    final ahora = DateTime.now();
    final nuevo = Pedido(
      id: ahora.microsecondsSinceEpoch.toString(),
      cliente: cliente.trim().isEmpty ? 'Mostrador' : cliente.trim(),
      tarifa: tarifa,
      cantidadPuerco: cantidadPuerco,
      cantidadElote: cantidadElote,
      precioPuercoAplicado: precioPuerco,
      precioEloteAplicado: precioElote,
      horaRegistro: ahora,
      horaEntrega: horaEntrega,
      horaEntregadoReal: entregado ? ahora : null,
      entregado: entregado,
      pagado: pagado,
    );

    _pedidos.add(nuevo);
    _db.guardarPedido(nuevo);

    if (entregado) {
      _ajustarInventarioPorEntrega(nuevo, entregando: true);
    }

    notifyListeners();
    return nuevo;
  }

  /// Alterna el estado de entrega validando que existan suficientes tamales
  /// **Listos** antes de marcar como entregado, y registra o limpia la hora
  /// exacta en que ocurrió la entrega (`horaEntregadoReal`).
  ///
  /// Devuelve `null` si la operación fue exitosa, o un mensaje descriptivo si
  /// falta inventario listo por sacar de la olla.
  String? alternarEntregado(String pedidoId) {
    final index = _pedidos.indexWhere((p) => p.id == pedidoId);
    if (index == -1) return null;

    final actual = _pedidos[index];
    if (actual.cancelado) return 'El pedido está cancelado.';

    final nuevoEstado = !actual.entregado;

    if (nuevoEstado) {
      final faltanPuerco = actual.cantidadPuerco - _inventario.puercoCocidos;
      final faltanElote = actual.cantidadElote - _inventario.eloteCocidos;

      if (faltanPuerco > 0 || faltanElote > 0) {
        final partes = <String>[
          if (faltanPuerco > 0) '$faltanPuerco de puerco',
          if (faltanElote > 0) '$faltanElote de elote',
        ];
        return 'Faltan ${partes.join(' y ')} en Listos (saca una olla o ajusta inventario).';
      }
    }

    final actualizado = actual.copyWith(
      entregado: nuevoEstado,
      horaEntregadoReal: nuevoEstado ? DateTime.now() : null,
      limpiarHoraEntregadoReal: !nuevoEstado,
    );
    _pedidos[index] = actualizado;
    _ajustarInventarioPorEntrega(actual, entregando: nuevoEstado);
    notifyListeners();

    _db.guardarPedido(actualizado);
    return null;
  }

  /// Alterna el estado de pago de un pedido individual.
  void alternarPagado(String pedidoId) {
    final index = _pedidos.indexWhere((p) => p.id == pedidoId);
    if (index == -1) return;

    final actual = _pedidos[index];
    if (actual.cancelado) return;

    final actualizado = actual.copyWith(pagado: !actual.pagado);
    _pedidos[index] = actualizado;
    notifyListeners();

    _db.guardarPedido(actualizado);
  }

  /// Cancela un pedido conservándolo en el historial como `cancelado = true`
  /// y reingresando sus piezas a **Listos** si ya había sido marcado como entregado.
  void cancelarPedido(String pedidoId) {
    final index = _pedidos.indexWhere((p) => p.id == pedidoId);
    if (index == -1) return;

    final actual = _pedidos[index];
    if (actual.cancelado) return;

    if (actual.entregado) {
      _ajustarInventarioPorEntrega(actual, entregando: false);
    }

    final cancelado = actual.copyWith(
      cancelado: true,
      entregado: false,
      pagado: false,
      limpiarHoraEntregadoReal: true,
    );
    _pedidos[index] = cancelado;
    notifyListeners();

    _db.guardarPedido(cancelado);
  }

  /// Registra una devolución de mercancía a nombre de [cliente] sin alterar
  /// sus pedidos originales, descontando su importe de su cuenta por cobrar
  /// y reingresando las piezas a congelado o listo (caliente).
  void registrarDevolucionCliente({
    required String cliente,
    required int devueltosPuerco,
    required int devueltosElote,
    bool regresarACongelado = true,
  }) {
    if (devueltosPuerco <= 0 && devueltosElote <= 0) return;

    final pedidosCliente = _pedidos
        .where((p) => p.cliente == cliente && !p.esDevolucion && !p.cancelado)
        .toList();
    final ultimoPedido = pedidosCliente.isNotEmpty ? pedidosCliente.last : null;

    final tarifaAplicada = ultimoPedido?.tarifa ?? TipoTarifa.tienda;
    final precioPuerco =
        ultimoPedido?.precioPuercoAplicado ??
        (tarifaAplicada == TipoTarifa.tienda
            ? _precios.puercoTienda
            : _precios.puercoPublico);
    final precioElote =
        ultimoPedido?.precioEloteAplicado ??
        (tarifaAplicada == TipoTarifa.tienda
            ? _precios.eloteTienda
            : _precios.elotePublico);

    final ahora = DateTime.now();
    final devolucion = Pedido(
      id: ahora.microsecondsSinceEpoch.toString(),
      cliente: cliente,
      tarifa: tarifaAplicada,
      cantidadPuerco: devueltosPuerco,
      cantidadElote: devueltosElote,
      precioPuercoAplicado: precioPuerco,
      precioEloteAplicado: precioElote,
      horaRegistro: ahora,
      horaEntregadoReal: ahora,
      entregado: true,
      pagado: false,
      esDevolucion: true,
    );

    _pedidos.add(devolucion);

    if (regresarACongelado) {
      _inventario = _inventario.copyWith(
        puercoCongelados: _inventario.puercoCongelados + devueltosPuerco,
        eloteCongelados: _inventario.eloteCongelados + devueltosElote,
      );
    } else {
      _inventario = _inventario.copyWith(
        puercoCocidos: _inventario.puercoCocidos + devueltosPuerco,
        eloteCocidos: _inventario.eloteCocidos + devueltosElote,
      );
    }

    notifyListeners();
    _db.guardarPedido(devolucion);
    _db.guardarInventario(_inventario);
  }

  /// Descuenta o reintegra tamales cocidos listos al cambiar el estado de entrega.
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
    _db.guardarInventario(_inventario);
  }

  // --- Resumen y cuentas por cobrar ---

  /// Filtra los movimientos pertenecientes a una semana específica.
  List<Pedido> pedidosPorSemana(String semanaId) {
    return _pedidos.where((p) => p.semanaId == semanaId).toList();
  }

  /// Agrupa todos los movimientos abiertos (`!pagado && !cancelado`) por cliente.
  Map<String, List<Pedido>> get deudasPorCliente {
    final pendientes = _pedidos.where((p) => !p.pagado && !p.cancelado);
    final Map<String, List<Pedido>> agrupados = {};

    for (final movimiento in pendientes) {
      agrupados.putIfAbsent(movimiento.cliente, () => []).add(movimiento);
    }
    return agrupados;
  }

  /// Liquida todos los pedidos y devoluciones pendientes de [cliente],
  /// marcando además como `entregado: true` (con su hora de entrega) aquellos
  /// pedidos que aún no lo estaban.
  void liquidarDeudaCliente(String cliente) {
    final modificados = <Pedido>[];
    final ahora = DateTime.now();
    for (int i = 0; i < _pedidos.length; i++) {
      final actual = _pedidos[i];
      if (actual.cliente == cliente && !actual.pagado && !actual.cancelado) {
        if (!actual.entregado && !actual.esDevolucion) {
          _ajustarInventarioPorEntrega(actual, entregando: true);
        }
        final liquidado = actual.copyWith(
          pagado: true,
          entregado: true,
          horaEntregadoReal: actual.horaEntregadoReal ?? ahora,
        );
        _pedidos[i] = liquidado;
        modificados.add(liquidado);
      }
    }
    notifyListeners();
    _db.guardarVariosPedidos(modificados);
  }

  /// Archiva los movimientos saldados o cancelados de la semana actual bajo
  /// [etiquetaSemana], conservando abiertos los que aún tienen saldo pendiente.
  void cerrarSemana(String etiquetaSemana) {
    final modificados = <Pedido>[];
    for (int i = 0; i < _pedidos.length; i++) {
      final p = _pedidos[i];
      if (p.semanaId == 'actual' && (p.pagado || p.cancelado)) {
        final archivado = p.copyWith(semanaId: etiquetaSemana);
        _pedidos[i] = archivado;
        modificados.add(archivado);
      }
    }
    notifyListeners();
    _db.guardarVariosPedidos(modificados);
  }
}
