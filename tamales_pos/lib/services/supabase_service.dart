import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/configuracion_precios.dart';
import '../models/inventario.dart';
import '../models/pedido.dart';

/// Servicio de persistencia en la nube respaldado por **Supabase** (PostgreSQL).
///
/// Encapsula todas las operaciones de lectura y escritura de tarifas,
/// inventario diario, ollas activas y pedidos utilizando los serializadores
/// `toMap` / `fromMap` de los modelos de dominio.
class SupabaseService {
  /// Cliente activo de Supabase.
  final SupabaseClient _client;

  /// Crea una instancia de [SupabaseService] usando el cliente global por defecto.
  SupabaseService({SupabaseClient? client})
    : _client = client ?? Supabase.instance.client;

  /// Descarga en paralelo las tarifas, el inventario actual y todos los pedidos.
  Future<
    ({
      ConfiguracionPrecios precios,
      Inventario inventario,
      List<Pedido> pedidos,
    })
  >
  cargarTodo() async {
    final resultados = await Future.wait<dynamic>(<Future<dynamic>>[
      _client
          .from('configuracion_precios')
          .select('datos')
          .eq('id', 1)
          .maybeSingle(),
      _client
          .from('inventario_actual')
          .select('datos')
          .eq('id', 1)
          .maybeSingle(),
      _client.from('pedidos').select('datos'),
    ]);

    final preciosRow = resultados[0] as Map<String, dynamic>?;
    final invRow = resultados[1] as Map<String, dynamic>?;
    final pedidosRows = resultados[2] as List<dynamic>;

    final precios = preciosRow != null && preciosRow['datos'] != null
        ? ConfiguracionPrecios.fromMap(
            Map<String, dynamic>.from(preciosRow['datos']),
          )
        : const ConfiguracionPrecios();

    final inventario = invRow != null && invRow['datos'] != null
        ? Inventario.fromMap(Map<String, dynamic>.from(invRow['datos']))
        : const Inventario();

    final pedidos = pedidosRows
        .map(
          (row) => Pedido.fromMap(
            Map<String, dynamic>.from((row as Map<String, dynamic>)['datos']),
          ),
        )
        .toList();

    return (precios: precios, inventario: inventario, pedidos: pedidos);
  }

  /// Guarda o actualiza las tarifas vigentes en la nube.
  Future<void> guardarPrecios(ConfiguracionPrecios precios) async {
    await _client.from('configuracion_precios').upsert({
      'id': 1,
      'datos': precios.toMap(),
    });
  }

  /// Guarda o actualiza el estado del inventario y las ollas en cocción.
  Future<void> guardarInventario(Inventario inventario) async {
    await _client.from('inventario_actual').upsert({
      'id': 1,
      'datos': inventario.toMap(),
    });
  }

  /// Inserta o actualiza un pedido individual en la tabla `pedidos`.
  Future<void> guardarPedido(Pedido pedido) async {
    await _client.from('pedidos').upsert({
      'id': pedido.id,
      'datos': pedido.toMap(),
      'actualizado_at': DateTime.now().toIso8601String(),
    });
  }

  /// Inserta o actualiza múltiples pedidos en una sola operación (útil al
  /// liquidar cuentas de un cliente o ejecutar el cierre semanal).
  Future<void> guardarVariosPedidos(List<Pedido> pedidos) async {
    if (pedidos.isEmpty) return;
    final ahora = DateTime.now().toIso8601String();
    final filas = pedidos
        .map((p) => {'id': p.id, 'datos': p.toMap(), 'actualizado_at': ahora})
        .toList();

    await _client.from('pedidos').upsert(filas);
  }
}
