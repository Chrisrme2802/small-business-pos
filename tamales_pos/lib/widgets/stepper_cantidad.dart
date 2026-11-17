import 'package:flutter/material.dart';

/// Control táctil con botones circulares (`IconButton.filledTonal`) y un
/// número central tocable para escribir cualquier cantidad exacta a mano.
///
/// Cuando [mostrarBotonesDeCinco] es `true` (por ejemplo en inventario u ollas),
/// añade botones secundarios de `-5` y `+5` a los extremos.
class StepperCantidad extends StatelessWidget {
  /// Etiqueta opcional mostrada encima del control (`null` para modo compacto en fila).
  final String? etiqueta;

  /// Valor numérico actual.
  final int valor;

  /// Límite máximo permitido (por defecto `9999`).
  final int maximo;

  /// Muestra botones extra `-5` y `+5` a los lados de los círculos `-` y `+`.
  final bool mostrarBotonesDeCinco;

  /// Callback disparado con el nuevo valor validado (`0 <= nuevo <= maximo`).
  final ValueChanged<int> onChanged;

  /// Crea una instancia de [StepperCantidad].
  const StepperCantidad({
    super.key,
    this.etiqueta,
    required this.valor,
    required this.onChanged,
    this.maximo = 9999,
    this.mostrarBotonesDeCinco = true,
  });

  /// Abre un diálogo modal con ciclo de vida propio para capturar una cifra exacta.
  Future<void> _editarManualmente(BuildContext context) async {
    final nuevoValor = await showDialog<int>(
      context: context,
      builder: (_) => _DialogoCantidadExacta(
        titulo: etiqueta ?? 'Cantidad',
        valorInicial: valor,
      ),
    );

    if (nuevoValor != null) {
      onChanged(nuevoValor.clamp(0, maximo));
    }
  }

  @override
  Widget build(BuildContext context) {
    final control = Row(
      mainAxisSize: etiqueta == null ? MainAxisSize.min : MainAxisSize.max,
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        if (mostrarBotonesDeCinco)
          IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            onPressed: valor > 0
                ? () => onChanged((valor - 5).clamp(0, maximo))
                : null,
            icon: const Text(
              '-5',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
        IconButton.filledTonal(
          onPressed: valor > 0
              ? () => onChanged((valor - 1).clamp(0, maximo))
              : null,
          icon: const Icon(Icons.remove),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => _editarManualmente(context),
          child: Container(
            constraints: const BoxConstraints(minWidth: 52),
            padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$valor',
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                decoration: TextDecoration.underline,
                decorationStyle: TextDecorationStyle.dotted,
              ),
            ),
          ),
        ),
        IconButton.filledTonal(
          onPressed: valor < maximo
              ? () => onChanged((valor + 1).clamp(0, maximo))
              : null,
          icon: const Icon(Icons.add),
        ),
        if (mostrarBotonesDeCinco)
          IconButton.filledTonal(
            visualDensity: VisualDensity.compact,
            onPressed: valor < maximo
                ? () => onChanged((valor + 5).clamp(0, maximo))
                : null,
            icon: const Text(
              '+5',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
            ),
          ),
      ],
    );

    if (etiqueta == null) return control;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          etiqueta!,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 6),
        control,
      ],
    );
  }
}

/// Diálogo privado que gestiona y libera su propio [TextEditingController]
/// únicamente cuando la animación de cierre ha finalizado.
class _DialogoCantidadExacta extends StatefulWidget {
  final String titulo;
  final int valorInicial;

  const _DialogoCantidadExacta({
    required this.titulo,
    required this.valorInicial,
  });

  @override
  State<_DialogoCantidadExacta> createState() => _DialogoCantidadExactaState();
}

class _DialogoCantidadExactaState extends State<_DialogoCantidadExacta> {
  late final TextEditingController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = TextEditingController(text: '${widget.valorInicial}');
    _ctrl.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _ctrl.text.length,
    );
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _confirmar() {
    final parsed = int.tryParse(_ctrl.text.trim());
    Navigator.of(context).pop(parsed);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.titulo),
      content: TextField(
        controller: _ctrl,
        keyboardType: TextInputType.number,
        autofocus: true,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        decoration: const InputDecoration(
          labelText: 'Cantidad exacta',
          border: OutlineInputBorder(),
        ),
        onSubmitted: (_) => _confirmar(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _confirmar, child: const Text('Aceptar')),
      ],
    );
  }
}
