import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../controllers/pos_controller.dart';
import '../models/olla_coccion.dart';
import 'stepper_cantidad.dart';

/// Carrusel deslizable de vaporeras activas con temporizador en tiempo real,
/// animación personalizada de vapor con [CustomPaint] y diálogo para agregar
/// nuevas tandas de cocción (`+ Poner olla`).
class CarruselOllas extends StatefulWidget {
  /// Crea una instancia de [CarruselOllas].
  const CarruselOllas({super.key});

  @override
  State<CarruselOllas> createState() => _CarruselOllasState();
}

class _CarruselOllasState extends State<CarruselOllas> {
  final PageController _page = PageController();
  int _actual = 0;
  Timer? _timer;

  static const Color _colorMarcador = Color(0xFFD9F99D);

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _page.dispose();
    super.dispose();
  }

  String _mmss(Duration d) {
    if (d == Duration.zero || d.isNegative) return '¡Lista!';
    final m = d.inMinutes.toString().padLeft(2, '0');
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s min';
  }

  /// Abre el diálogo de cocción limitando los valores al máximo de tamales
  /// congelados disponibles en inventario.
  Future<void> _ponerOlla() async {
    final inv = context.read<PosController>().inventario;
    final maxPuerco = inv.puercoCongelados;
    final maxElote = inv.eloteCongelados;

    if (maxPuerco <= 0 && maxElote <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'No hay tamales congelados disponibles. Inicializa o edita el inventario primero.',
          ),
        ),
      );
      return;
    }

    int puerco = 20.clamp(0, maxPuerco);
    int elote = 15.clamp(0, maxElote);
    int minutos = 25;
    bool esCustom = false;
    final customCtrl = TextEditingController(text: '35');

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setS) {
          final minutosFinales = esCustom
              ? (int.tryParse(customCtrl.text.trim()) ?? 0)
              : minutos;

          return AlertDialog(
            title: const Text('Poner olla'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  StepperCantidad(
                    etiqueta: 'Puerco (disp. $maxPuerco)',
                    valor: puerco,
                    maximo: maxPuerco,
                    onChanged: (v) => setS(() => puerco = v),
                  ),
                  const SizedBox(height: 12),
                  StepperCantidad(
                    etiqueta: 'Elote (disp. $maxElote)',
                    valor: elote,
                    maximo: maxElote,
                    onChanged: (v) => setS(() => elote = v),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Tiempo de cocción',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 6,
                    children: [
                      for (final m in [20, 25, 30, 45])
                        ChoiceChip(
                          label: Text('$m min'),
                          selected: !esCustom && minutos == m,
                          selectedColor: _colorMarcador,
                          onSelected: (_) => setS(() {
                            esCustom = false;
                            minutos = m;
                          }),
                        ),
                      ChoiceChip(
                        label: const Text('Custom'),
                        selected: esCustom,
                        selectedColor: _colorMarcador,
                        onSelected: (_) => setS(() => esCustom = true),
                      ),
                    ],
                  ),
                  if (esCustom) ...[
                    const SizedBox(height: 12),
                    TextField(
                      controller: customCtrl,
                      keyboardType: TextInputType.number,
                      autofocus: true,
                      decoration: const InputDecoration(
                        labelText: 'Minutos personalizados',
                        suffixText: 'min',
                        isDense: true,
                        border: OutlineInputBorder(),
                      ),
                      onChanged: (_) => setS(() {}),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancelar'),
              ),
              FilledButton(
                onPressed: (puerco + elote) > 0 && minutosFinales > 0
                    ? () => Navigator.pop(ctx, true)
                    : null,
                child: const Text('Poner'),
              ),
            ],
          );
        },
      ),
    );

    final minutosElegidos = esCustom
        ? (int.tryParse(customCtrl.text.trim()) ?? 25)
        : minutos;
    customCtrl.dispose();

    if (ok == true && mounted && minutosElegidos > 0) {
      context.read<PosController>().ponerOlla(
        puerco: puerco,
        elote: elote,
        minutosCoccion: minutosElegidos,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PosController>();
    final List<OllaCoccion> ollas = p.inventario.ollasActivas;
    final hayCongelados =
        (p.inventario.puercoCongelados + p.inventario.eloteCongelados) > 0;

    final indiceSeguro = ollas.isEmpty ? 0 : _actual.clamp(0, ollas.length - 1);

    return Column(
      children: [
        SizedBox(
          height: 155,
          child: ollas.isEmpty
              ? Center(
                  child: Text(
                    'No hay ollas al fuego. Pon una para empezar.',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                )
              : PageView.builder(
                  controller: _page,
                  itemCount: ollas.length,
                  onPageChanged: (i) => setState(() => _actual = i),
                  itemBuilder: (_, i) {
                    final o = ollas[i];
                    final restante = o.tiempoRestante;
                    return Card(
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: o.estaLista ? Colors.green : Colors.black38,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          const SizedBox(width: 16),
                          _IconoOllaAnimado(estaLista: o.estaLista),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  '${o.nombre} · ${o.cantidadPuerco}P / ${o.cantidadElote}E',
                                  style: Theme.of(context)
                                      .textTheme
                                      .titleMedium,
                                ),
                                Text(
                                  _mmss(restante),
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineMedium
                                      ?.copyWith(
                                        fontWeight: FontWeight.w800,
                                        color: o.estaLista
                                            ? Colors.green.shade700
                                            : null,
                                      ),
                                ),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: TextButton(
                                    onPressed: () => p.sacarOlla(o.id),
                                    child: const Text('Sacar olla'),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < ollas.length; i++)
              Container(
                width: 8,
                height: 8,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: i == indiceSeguro ? _colorMarcador : Colors.black26,
                ),
              ),
          ],
        ),
        Align(
          alignment: Alignment.centerRight,
          child: FilledButton.tonalIcon(
            onPressed: hayCongelados ? _ponerOlla : null,
            icon: const Icon(Icons.add),
            label: Text(hayCongelados ? 'Poner olla' : 'Sin congelados'),
          ),
        ),
      ],
    );
  }
}

class _IconoOllaAnimado extends StatefulWidget {
  final bool estaLista;

  const _IconoOllaAnimado({required this.estaLista});

  @override
  State<_IconoOllaAnimado> createState() => _IconoOllaAnimadoState();
}

class _IconoOllaAnimadoState extends State<_IconoOllaAnimado>
    with SingleTickerProviderStateMixin {
  static const _duracionCoccion = Duration(milliseconds: 2400);
  static const _duracionLista = Duration(milliseconds: 800);
  static const _aumentoPulso = 0.12;
  static const _tamano = 64.0;

  late final AnimationController _controller;

  Duration get _duracion =>
      widget.estaLista ? _duracionLista : _duracionCoccion;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _duracion)
      ..repeat();
  }

  @override
  void didUpdateWidget(covariant _IconoOllaAnimado oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.estaLista != widget.estaLista) {
      _controller
        ..duration = _duracion
        ..repeat();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorOlla = Theme.of(context).colorScheme.onSurface;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = _controller.value;

        if (widget.estaLista) {
          final escala =
              1.0 + _aumentoPulso * (1 - math.cos(t * 2 * math.pi)) / 2;
          return Transform.scale(
            scale: escala,
            child: CustomPaint(
              size: const Size.square(_tamano),
              painter: _OllaPainter(
                colorOlla: Colors.green,
                progreso: t,
                conVapor: false,
              ),
            ),
          );
        }

        return CustomPaint(
          size: const Size.square(_tamano),
          painter: _OllaPainter(
            colorOlla: colorOlla,
            progreso: t,
            conVapor: true,
          ),
        );
      },
    );
  }
}

class _OllaPainter extends CustomPainter {
  static const colorVapor = Color(0xFF8B1E3F);

  final Color colorOlla;
  final double progreso;
  final bool conVapor;

  const _OllaPainter({
    required this.colorOlla,
    required this.progreso,
    required this.conVapor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.scale(size.width / 64, size.height / 64);

    final relleno = Paint()..color = colorOlla;

    canvas.drawRRect(
      RRect.fromLTRBAndCorners(
        10,
        34,
        54,
        58,
        bottomLeft: const Radius.circular(9),
        bottomRight: const Radius.circular(9),
      ),
      relleno,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(7, 30, 57, 35, const Radius.circular(2.5)),
      relleno,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(29, 26, 35, 30, const Radius.circular(2)),
      relleno,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(3, 40, 10, 44, const Radius.circular(2)),
      relleno,
    );
    canvas.drawRRect(
      RRect.fromLTRBR(54, 40, 61, 44, const Radius.circular(2)),
      relleno,
    );

    if (conVapor) _pintarVapor(canvas);

    canvas.restore();
  }

  void _pintarVapor(Canvas canvas) {
    const base = 24.0;
    const alto = 22.0;
    final fase = progreso * 2 * math.pi;

    final pincel = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round
      ..shader = LinearGradient(
        begin: Alignment.bottomCenter,
        end: Alignment.topCenter,
        colors: [colorVapor, colorVapor.withAlpha(0)],
      ).createShader(const Rect.fromLTWH(0, base - alto, 64, alto));

    for (var i = 0; i < 3; i++) {
      final x0 = 20.0 + i * 12;
      final camino = Path();
      for (var y = base; y >= base - alto; y -= 1) {
        final altura = (base - y) / alto;
        final x =
            x0 +
            math.sin(altura * 2 * math.pi * 1.2 - fase + i * 2.1) *
                (1.5 + 2.5 * altura);
        if (y == base) {
          camino.moveTo(x, y);
        } else {
          camino.lineTo(x, y);
        }
      }
      canvas.drawPath(camino, pincel);
    }
  }

  @override
  bool shouldRepaint(covariant _OllaPainter old) =>
      old.progreso != progreso ||
      old.colorOlla != colorOlla ||
      old.conVapor != conVapor;
}
