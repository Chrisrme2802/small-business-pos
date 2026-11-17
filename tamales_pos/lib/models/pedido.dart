/// Modalidad de precio aplicable a un pedido.
enum TipoTarifa {
  /// Venta directa al público general.
  publico,

  /// Venta a tiendas o revendedores con precio preferencial.
  tienda,
}

/// Representa un pedido individual, una devolución de mercancía o una orden cancelada.
///
/// Congela los precios unitarios vigentes al momento de registrarse para que
/// cambios futuros en [ConfiguracionPrecios] no alteren el historial ni los
/// cortes semanales.
class Pedido {
  /// Identificador único del movimiento.
  final String id;

  /// Nombre del cliente o tienda (`'Mostrador'` por defecto).
  final String cliente;

  /// Modalidad de precio aplicada al movimiento.
  final TipoTarifa tarifa;

  /// Cantidad de tamales de puerco involucrados en el movimiento.
  final int cantidadPuerco;

  /// Cantidad de tamales de elote involucrados en el movimiento.
  final int cantidadElote;

  /// Precio unitario aplicado por cada pieza de puerco.
  final double precioPuercoAplicado;

  /// Precio unitario aplicado por cada pieza de elote.
  final double precioEloteAplicado;

  /// Fecha y hora exacta en que se registró el movimiento.
  final DateTime horaRegistro;

  /// Hora programada de entrega (`null` si es entrega inmediata).
  final DateTime? horaEntrega;

  /// Fecha y hora exacta en que el pedido fue marcado como entregado (`null` si aún no se entrega).
  final DateTime? horaEntregadoReal;

  /// Indica si la mercancía ya fue entregada físicamente.
  final bool entregado;

  /// Indica si el pedido ya fue cobrado o la devolución ya fue aplicada a un corte.
  final bool pagado;

  /// Identificador de la semana contable (`'actual'` mientras siga abierta).
  final String semanaId;

  /// Indica si este registro corresponde a una devolución de mercancía (`true`)
  /// que resta saldo al cliente sin borrar sus pedidos originales.
  final bool esDevolucion;

  /// Indica si el pedido fue cancelado (`true`), conservándose en el historial
  /// con impacto monetario cero (`0.0`).
  final bool cancelado;

  /// Crea una instancia inmutable de [Pedido].
  const Pedido({
    required this.id,
    required this.cliente,
    required this.tarifa,
    required this.cantidadPuerco,
    required this.cantidadElote,
    required this.precioPuercoAplicado,
    required this.precioEloteAplicado,
    required this.horaRegistro,
    this.horaEntrega,
    this.horaEntregadoReal,
    this.entregado = false,
    this.pagado = false,
    this.semanaId = 'actual',
    this.esDevolucion = false,
    this.cancelado = false,
  });

  /// Suma total de piezas incluidas en el movimiento.
  int get totalPiezas => cantidadPuerco + cantidadElote;

  /// Importe monetario bruto de las piezas (`>= 0`).
  double get importeBruto =>
      (cantidadPuerco * precioPuercoAplicado) +
      (cantidadElote * precioEloteAplicado);

  /// Impacto monetario neto (`0.0` si está [cancelado], negativo si [esDevolucion]).
  double get totalPesos {
    if (cancelado) return 0.0;
    return esDevolucion ? -importeBruto : importeBruto;
  }

  /// Devuelve una copia modificando únicamente los campos especificados.
  Pedido copyWith({
    String? id,
    String? cliente,
    TipoTarifa? tarifa,
    int? cantidadPuerco,
    int? cantidadElote,
    double? precioPuercoAplicado,
    double? precioEloteAplicado,
    DateTime? horaRegistro,
    DateTime? horaEntrega,
    bool limpiarHoraEntrega = false,
    DateTime? horaEntregadoReal,
    bool limpiarHoraEntregadoReal = false,
    bool? entregado,
    bool? pagado,
    String? semanaId,
    bool? esDevolucion,
    bool? cancelado,
  }) {
    return Pedido(
      id: id ?? this.id,
      cliente: cliente ?? this.cliente,
      tarifa: tarifa ?? this.tarifa,
      cantidadPuerco: cantidadPuerco ?? this.cantidadPuerco,
      cantidadElote: cantidadElote ?? this.cantidadElote,
      precioPuercoAplicado: precioPuercoAplicado ?? this.precioPuercoAplicado,
      precioEloteAplicado: precioEloteAplicado ?? this.precioEloteAplicado,
      horaRegistro: horaRegistro ?? this.horaRegistro,
      horaEntrega: limpiarHoraEntrega
          ? null
          : (horaEntrega ?? this.horaEntrega),
      horaEntregadoReal: limpiarHoraEntregadoReal
          ? null
          : (horaEntregadoReal ?? this.horaEntregadoReal),
      entregado: entregado ?? this.entregado,
      pagado: pagado ?? this.pagado,
      semanaId: semanaId ?? this.semanaId,
      esDevolucion: esDevolucion ?? this.esDevolucion,
      cancelado: cancelado ?? this.cancelado,
    );
  }

  /// Serializa el movimiento a un mapa clave-valor para Supabase.
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'cliente': cliente,
      'tarifa': tarifa.name,
      'cantidadPuerco': cantidadPuerco,
      'cantidadElote': cantidadElote,
      'precioPuercoAplicado': precioPuercoAplicado,
      'precioEloteAplicado': precioEloteAplicado,
      'horaRegistro': horaRegistro.toIso8601String(),
      'horaEntrega': horaEntrega?.toIso8601String(),
      'horaEntregadoReal': horaEntregadoReal?.toIso8601String(),
      'entregado': entregado,
      'pagado': pagado,
      'semanaId': semanaId,
      'esDevolucion': esDevolucion,
      'cancelado': cancelado,
    };
  }

  /// Reconstruye un [Pedido] a partir de un mapa proveniente de Supabase.
  factory Pedido.fromMap(Map<String, dynamic> map) {
    return Pedido(
      id: map['id'] ?? '',
      cliente: map['cliente'] ?? 'Mostrador',
      tarifa: TipoTarifa.values.firstWhere(
        (t) => t.name == map['tarifa'],
        orElse: () => TipoTarifa.publico,
      ),
      cantidadPuerco: map['cantidadPuerco'] ?? 0,
      cantidadElote: map['cantidadElote'] ?? 0,
      precioPuercoAplicado: (map['precioPuercoAplicado'] ?? 0).toDouble(),
      precioEloteAplicado: (map['precioEloteAplicado'] ?? 0).toDouble(),
      horaRegistro: DateTime.parse(map['horaRegistro']),
      horaEntrega: map['horaEntrega'] != null
          ? DateTime.parse(map['horaEntrega'])
          : null,
      horaEntregadoReal: map['horaEntregadoReal'] != null
          ? DateTime.parse(map['horaEntregadoReal'])
          : null,
      entregado: map['entregado'] ?? false,
      pagado: map['pagado'] ?? false,
      semanaId: map['semanaId'] ?? 'actual',
      esDevolucion: map['esDevolucion'] ?? false,
      cancelado: map['cancelado'] ?? false,
    );
  }
}
