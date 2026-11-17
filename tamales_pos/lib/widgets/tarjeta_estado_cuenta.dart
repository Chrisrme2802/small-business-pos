import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/pedido.dart';
import 'titulo_marcador.dart';

/// Abre un diálogo modal centrando el [TarjetaEstadoCuenta] consolidado de
/// [cliente] junto con sus opciones para compartir/guardar como imagen PNG,
/// copiar en texto o cerrar.
Future<void> mostrarEstadoCuenta(
  BuildContext context, {
  required String cliente,
  required List<Pedido> movimientos,
  required bool esHistorico,
}) {
  return showDialog(
    context: context,
    builder: (ctx) => Dialog(
      insetPadding: const EdgeInsets.all(20),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TarjetaEstadoCuenta(
              cliente: cliente,
              movimientos: movimientos,
              esHistorico: esHistorico,
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Cerrar'),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Comprobante consolidado de cobranza semanal para una tienda o cliente.
///
/// Muestra en la app el resumen cálido con todos los pedidos entregados/abiertos,
/// las devoluciones descontadas, las piezas netas y el saldo final a liquidar;
/// al pulsar **Compartir estado de cuenta** genera una imagen PNG formal tipo
/// nota de cobranza térmica lista para enviar por WhatsApp.
class TarjetaEstadoCuenta extends StatefulWidget {
  /// Nombre de la tienda o cliente al que pertenece la cuenta.
  final String cliente;

  /// Lista completa de movimientos (pedidos y devoluciones) incluidos en el corte.
  final List<Pedido> movimientos;

  /// Indica si el estado de cuenta corresponde a una semana ya cerrada (`true`)
  /// o a un adeudo abierto pendiente de liquidar (`false`).
  final bool esHistorico;

  /// Crea una instancia de [TarjetaEstadoCuenta].
  const TarjetaEstadoCuenta({
    super.key,
    required this.cliente,
    required this.movimientos,
    this.esHistorico = false,
  });

  @override
  State<TarjetaEstadoCuenta> createState() => _TarjetaEstadoCuentaState();
}

class _TarjetaEstadoCuentaState extends State<TarjetaEstadoCuenta> {
  /// Evita pulsaciones múltiples mientras se genera o comparte la imagen PNG.
  bool _exportando = false;

  /// Formateador de moneda en pesos mexicanos (`$0.00`).
  static final NumberFormat _moneda = NumberFormat.currency(
    locale: 'es_MX',
    symbol: '\$',
  );

  /// Movimientos vigentes (excluyendo pedidos cancelados) ordenados por fecha.
  List<Pedido> get _movimientosVigentes {
    final lista = widget.movimientos.where((m) => !m.cancelado).toList();
    lista.sort((a, b) => a.horaRegistro.compareTo(b.horaRegistro));
    return lista;
  }

  /// Pedidos regulares vigentes incluidos en el estado de cuenta.
  List<Pedido> get _pedidos =>
      _movimientosVigentes.where((m) => !m.esDevolucion).toList();

  /// Devoluciones aplicadas incluidas en el estado de cuenta.
  List<Pedido> get _devoluciones =>
      _movimientosVigentes.where((m) => m.esDevolucion).toList();

  /// Suma bruta de todos los pedidos entregados o registrados antes de devoluciones.
  double get _subtotalPedidos =>
      _pedidos.fold<double>(0, (suma, p) => suma + p.importeBruto);

  /// Suma total descontada por concepto de devoluciones (`>= 0`).
  double get _totalDevoluciones =>
      _devoluciones.fold<double>(0, (suma, d) => suma + d.importeBruto);

  /// Saldo neto final a pagar (`_subtotalPedidos - _totalDevoluciones`).
  double get _saldoNeto =>
      _movimientosVigentes.fold<double>(0, (suma, m) => suma + m.totalPesos);

  /// Total neto de tamales de puerco (pedidos menos devoluciones).
  int get _piezasNetasPuerco {
    final ped = _pedidos.fold<int>(0, (s, p) => s + p.cantidadPuerco);
    final dev = _devoluciones.fold<int>(0, (s, d) => s + d.cantidadPuerco);
    return ped - dev;
  }

  /// Total neto de tamales de elote (pedidos menos devoluciones).
  int get _piezasNetasElote {
    final ped = _pedidos.fold<int>(0, (s, p) => s + p.cantidadElote);
    final dev = _devoluciones.fold<int>(0, (s, d) => s + d.cantidadElote);
    return ped - dev;
  }

  /// Dibuja en memoria mediante [ui.PictureRecorder] un estado de cuenta formal
  /// tipo recibo térmico consolidado y devuelve sus bytes en formato PNG.
  Future<Uint8List> _generarImagenEstadoCuentaFormal() async {
    const double ancho = 600;
    const double margenX = 36;
    const double anchoUtil = ancho - (margenX * 2);

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);

    final fondoBlanco = Paint()..color = const Color(0xFFFFFFFF);
    final bordeSutil = Paint()
      ..color = const Color(0xFFD4D4D8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;

    TextPainter crearTexto(
      String texto, {
      double size = 19,
      FontWeight weight = FontWeight.w500,
      Color color = const Color(0xFF111827),
      TextAlign align = TextAlign.left,
      double? maxWidth,
    }) {
      final tp = TextPainter(
        text: TextSpan(
          text: texto,
          style: TextStyle(
            fontFamily: 'Consolas',
            fontFamilyFallback: const ['Courier New', 'monospace'],
            fontSize: size,
            fontWeight: weight,
            color: color,
            letterSpacing: 0.3,
          ),
        ),
        textAlign: align,
        textDirection: ui.TextDirection.ltr,
      );
      tp.layout(maxWidth: maxWidth ?? anchoUtil);
      return tp;
    }

    // Estimación generosa del lienzo antes del recorte final
    final double altoEstimado =
        560.0 + (_pedidos.length * 56.0) + (_devoluciones.length * 56.0);

    final rectLienzo = Rect.fromLTWH(0, 0, ancho, altoEstimado);
    canvas.drawRect(rectLienzo, fondoBlanco);

    double y = 36;

    void dibujarCentrado(
      String texto, {
      double size = 20,
      FontWeight weight = FontWeight.w500,
      Color color = const Color(0xFF111827),
      double espacioDespues = 6,
    }) {
      final tp = crearTexto(
        texto,
        size: size,
        weight: weight,
        color: color,
        align: TextAlign.center,
      );
      tp.paint(canvas, Offset((ancho - tp.width) / 2, y));
      y += tp.height + espacioDespues;
    }

    void dibujarFila(
      String izquierda,
      String derecha, {
      double size = 18,
      FontWeight weight = FontWeight.w500,
      Color color = const Color(0xFF111827),
      double espacioDespues = 8,
    }) {
      final tpIzq = crearTexto(
        izquierda,
        size: size,
        weight: weight,
        color: color,
      );
      final tpDer = crearTexto(
        derecha,
        size: size,
        weight: weight,
        color: color,
      );
      tpIzq.paint(canvas, Offset(margenX, y));
      tpDer.paint(canvas, Offset(ancho - margenX - tpDer.width, y));
      y +=
          (tpIzq.height > tpDer.height ? tpIzq.height : tpDer.height) +
          espacioDespues;
    }

    void dibujarSeparador({String caracter = '-'}) {
      final linea = List.filled(44, caracter).join();
      final tp = crearTexto(
        linea,
        size: 17,
        color: const Color(0xFF6B7280),
        align: TextAlign.center,
      );
      tp.paint(canvas, Offset((ancho - tp.width) / 2, y));
      y += tp.height + 10;
    }

    // 1. Encabezado comercial
    dibujarCentrado(
      'TAMALES LUPIN',
      size: 32,
      weight: FontWeight.w800,
      espacioDespues: 4,
    );
    dibujarCentrado(
      'ESTADO DE CUENTA · COBRANZA',
      size: 18,
      weight: FontWeight.w700,
      color: const Color(0xFF4B5563),
      espacioDespues: 14,
    );

    dibujarSeparador(caracter: '=');

    // 2. Datos generales de la cuenta
    final fechaEmision = DateFormat('dd/MM/yyyy  HH:mm').format(DateTime.now());
    final estatus = widget.esHistorico ? 'CUENTA SALDADA' : 'POR LIQUIDAR';

    dibujarFila(
      'CLIENTE / TIENDA:',
      widget.cliente.toUpperCase(),
      weight: FontWeight.w800,
    );
    dibujarFila('EMISIÓN:', fechaEmision);
    dibujarFila(
      'ESTATUS:',
      estatus,
      weight: FontWeight.w700,
      color: widget.esHistorico
          ? const Color(0xFF15803D)
          : const Color(0xFFB45309),
      espacioDespues: 12,
    );

    dibujarSeparador();

    // 3. Desglose cronológico de notas de entrega
    dibujarFila(
      'FECHA       DETALLE DE PEDIDO',
      'IMPORTE',
      size: 16,
      weight: FontWeight.w700,
      color: const Color(0xFF4B5563),
      espacioDespues: 10,
    );

    for (final ped in _pedidos) {
      final fecha = DateFormat('dd/MM HH:mm').format(ped.horaRegistro);
      final piezas = <String>[
        if (ped.cantidadPuerco > 0) '${ped.cantidadPuerco}P',
        if (ped.cantidadElote > 0) '${ped.cantidadElote}E',
      ].join('/');

      dibujarFila(
        '$fecha · ${piezas.padRight(7)}',
        _moneda.format(ped.importeBruto),
        size: 18,
        weight: FontWeight.w600,
        espacioDespues: 6,
      );
    }

    // 4. Desglose de devoluciones aplicadas
    if (_devoluciones.isNotEmpty) {
      y += 6;
      dibujarSeparador();
      dibujarFila(
        'DEVOLUCIONES DESCONTADAS',
        'ABONO',
        size: 16,
        weight: FontWeight.w700,
        color: const Color(0xFF8B1E3F),
        espacioDespues: 8,
      );

      for (final dev in _devoluciones) {
        final fecha = DateFormat('dd/MM HH:mm').format(dev.horaRegistro);
        final piezas = <String>[
          if (dev.cantidadPuerco > 0) '-${dev.cantidadPuerco}P',
          if (dev.cantidadElote > 0) '-${dev.cantidadElote}E',
        ].join('/');

        dibujarFila(
          '$fecha · Dev. $piezas',
          _moneda.format(dev.totalPesos),
          size: 18,
          weight: FontWeight.w600,
          color: const Color(0xFF8B1E3F),
          espacioDespues: 6,
        );
      }
    }

    y += 4;
    dibujarSeparador(caracter: '=');

    // 5. Resumen financiero y de piezas netas
    dibujarFila(
      'PIEZAS NETAS:',
      '$_piezasNetasPuerco Puerco / $_piezasNetasElote Elote',
      size: 17,
      weight: FontWeight.w600,
    );
    dibujarFila(
      'SUBTOTAL ENTREGADO:',
      _moneda.format(_subtotalPedidos),
      size: 18,
    );
    if (_totalDevoluciones > 0) {
      dibujarFila(
        'MENOS DEVOLUCIONES:',
        '-${_moneda.format(_totalDevoluciones)}',
        size: 18,
        color: const Color(0xFF8B1E3F),
      );
    }

    y += 4;
    dibujarFila(
      widget.esHistorico ? 'TOTAL LIQUIDADO:' : 'SALDO A LIQUIDAR:',
      _moneda.format(_saldoNeto),
      size: 25,
      weight: FontWeight.w800,
      espacioDespues: 16,
    );

    dibujarSeparador();

    // 6. Pie del comprobante
    dibujarCentrado(
      '¡GRACIAS POR SU CONFIANZA!',
      size: 18,
      weight: FontWeight.w700,
      espacioDespues: 4,
    );
    dibujarCentrado(
      'Tamales Lupin · Resumen consolidado de cuenta',
      size: 14,
      color: const Color(0xFF6B7280),
      espacioDespues: 0,
    );

    final altoFinal = y + 28;
    canvas.drawRect(
      Rect.fromLTWH(6, 6, ancho - 12, altoFinal - 12),
      bordeSutil,
    );

    final picture = recorder.endRecording();
    final image = await picture.toImage(ancho.toInt(), altoFinal.toInt());
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    return byteData!.buffer.asUint8List();
  }

  /// Exporta el estado de cuenta formal en PNG (en Descargas en escritorio o
  /// mediante la hoja nativa de compartir en dispositivos móviles).
  Future<void> _compartirEstadoCuenta() async {
    if (_exportando) return;
    setState(() => _exportando = true);

    try {
      final pngBytes = await _generarImagenEstadoCuentaFormal();
      final clienteLimpio = widget.cliente.trim().replaceAll(
        RegExp(r'[^a-zA-Z0-9_-]'),
        '_',
      );
      final fechaArchivo = DateFormat('yyyyMMdd_HHmm').format(DateTime.now());
      final nombreArchivo = 'Estado_Cuenta_${clienteLimpio}_$fechaArchivo.png';

      if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
        final dirDescargas =
            await getDownloadsDirectory() ??
            await getApplicationDocumentsDirectory();
        final archivo = File(
          '${dirDescargas.path}${Platform.pathSeparator}$nombreArchivo',
        );
        await archivo.writeAsBytes(pngBytes, flush: true);

        if (Platform.isWindows) {
          await Process.run('explorer.exe', ['/select,', archivo.path]);
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                'Estado de cuenta guardado en Descargas: $nombreArchivo',
              ),
            ),
          );
        }
        return;
      }

      final dir = await getTemporaryDirectory();
      final archivo = File('${dir.path}/$nombreArchivo');
      await archivo.writeAsBytes(pngBytes, flush: true);
      await Share.shareXFiles([XFile(archivo.path)]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('No se pudo exportar el estado de cuenta: $e'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  /// Copia el desglose consolidado en texto plano al portapapeles.
  Future<void> _copiarTexto() async {
    final lineas = <String>[
      'TAMALES LUPIN · Estado de Cuenta',
      'Cliente: ${widget.cliente}',
      'Fecha de corte: ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
      '---',
      for (final ped in _pedidos)
        '• ${DateFormat('dd/MM HH:mm').format(ped.horaRegistro)}: '
            '${ped.cantidadPuerco}P / ${ped.cantidadElote}E = ${_moneda.format(ped.importeBruto)}',
      if (_devoluciones.isNotEmpty) ...[
        'Devoluciones:',
        for (final dev in _devoluciones)
          '• ${DateFormat('dd/MM HH:mm').format(dev.horaRegistro)}: '
              '-${dev.cantidadPuerco}P / -${dev.cantidadElote}E = ${_moneda.format(dev.totalPesos)}',
      ],
      '---',
      'Piezas netas: $_piezasNetasPuerco Puerco / $_piezasNetasElote Elote',
      '${widget.esHistorico ? 'TOTAL LIQUIDADO' : 'SALDO A LIQUIDAR'}: ${_moneda.format(_saldoNeto)}',
    ];

    await Clipboard.setData(ClipboardData(text: lineas.join('\n')));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Estado de cuenta copiado al portapapeles'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFFFFFBEF),
            border: Border.all(color: Colors.black54),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const TituloMarcador('Estado de cuenta'),
              const SizedBox(height: 10),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.cliente,
                          style: const TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Text(
                          'Tamales Lupin · ${DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now())}',
                          style: const TextStyle(
                            fontSize: 12,
                            color: Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: widget.esHistorico
                          ? const Color(0xFFD9F99D)
                          : Colors.amber.shade100,
                      borderRadius: BorderRadius.circular(5),
                    ),
                    child: Text(
                      widget.esHistorico ? 'SALDADO' : 'POR LIQUIDAR',
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const Divider(height: 22),

              // Lista de pedidos de la cuenta
              for (final ped in _pedidos)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          '${DateFormat('dd/MM HH:mm').format(ped.horaRegistro)} · '
                          '${ped.cantidadPuerco}P / ${ped.cantidadElote}E',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                      Text(
                        _moneda.format(ped.importeBruto),
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),

              // Devoluciones aplicadas si existen
              if (_devoluciones.isNotEmpty) ...[
                const SizedBox(height: 6),
                for (final dev in _devoluciones)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            'Dev. ${DateFormat('dd/MM HH:mm').format(dev.horaRegistro)} · '
                            '-${dev.cantidadPuerco}P / -${dev.cantidadElote}E',
                            style: const TextStyle(
                              fontSize: 13,
                              color: Color(0xFF8B1E3F),
                            ),
                          ),
                        ),
                        Text(
                          _moneda.format(dev.totalPesos),
                          style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF8B1E3F),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],

              const Divider(height: 22),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.esHistorico ? 'TOTAL PAGADO' : 'SALDO NETO',
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 16,
                        ),
                      ),
                      Text(
                        '$_piezasNetasPuerco Puerco · $_piezasNetasElote Elote',
                        style: const TextStyle(
                          fontSize: 12,
                          color: Colors.black54,
                        ),
                      ),
                    ],
                  ),
                  Text(
                    _moneda.format(_saldoNeto),
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 22,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 10),

        Row(
          children: [
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: _exportando ? null : _compartirEstadoCuenta,
                icon: _exportando
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.receipt_long, size: 18),
                label: const Text('Compartir estado'),
              ),
            ),
            const SizedBox(width: 8),
            OutlinedButton.icon(
              onPressed: _copiarTexto,
              icon: const Icon(Icons.copy, size: 18),
              label: const Text('Copiar'),
            ),
          ],
        ),
      ],
    );
  }
}
