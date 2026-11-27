import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'controllers/pos_controller.dart';
import 'models/configuracion_precios.dart';
import 'screens/operacion_screen.dart';
import 'screens/resumen_screen.dart';
import 'screens/tomar_pedido_screen.dart';
import 'screens/login_screen.dart';
import 'widgets/titulo_marcador.dart';

/// Variables de entorno
const _supabaseUrl = String.fromEnvironment('SUPABASE_URL');
const _supabaseKey = String.fromEnvironment('SUPABASE_KEY');

const esProduccion = String.fromEnvironment('ENTORNO') == 'prod';

/// Punto de entrada principal de la aplicación **Tamales POS**.
/// Inicializa el formato regional en español de México (`es_MX`), conecta el
/// cliente de Supabase e inyecta una instancia global de [PosController].
Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es_MX');

  assert(_supabaseUrl.isNotEmpty, 'Falta --dart-define-from-file=env/dev.json');

  await Supabase.initialize(
    url: _supabaseUrl,
    publishableKey: _supabaseKey,
  );

  runApp(const Raiz());
}

/// Widget raíz que configura el tema Material 3 y alterna entre la pantalla
/// de carga inicial y la interfaz principal del punto de venta.
class TamalesApp extends StatelessWidget {
  /// Maneja login
  final bool logueado;

  /// Crea una instancia de [TamalesApp].
  const TamalesApp({super.key, required this.logueado});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Tamales POS',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: colorMarcador,
        scaffoldBackgroundColor: Colors.white,
      ),
      home: !logueado
          ? const LoginScreen()
          : Consumer<PosController>(
              builder: (context, controller, _) {
                if (controller.estaCargando) return const _PantallaCarga();
                return const Shell();
              },
            ),
    );
  }
}

class Raiz extends StatelessWidget {
  const Raiz({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: Supabase.instance.client.auth.onAuthStateChange,
      builder: (context, _) {
        final logueado = Supabase.instance.client.auth.currentSession != null;
        if (!logueado) return const TamalesApp(logueado: false);
        return ChangeNotifierProvider(
          create: (_) => PosController(),
          child: const TamalesApp(logueado: true),
        );
      },
    );
  }
}

/// Pantalla de carga inicial mostrada mientras [PosController] descarga
/// tarifas, inventario y pedidos desde Supabase.
class _PantallaCarga extends StatelessWidget {
  const _PantallaCarga();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFFBEF),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFD9F99D),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.black87, width: 1.5),
              ),
              child: const Icon(
                Icons.soup_kitchen,
                size: 56,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Tamales POS',
              style: Theme.of(context).textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Sincronizando inventario y pedidos...',
              style: Theme.of(context).textTheme.bodyMedium
                  ?.copyWith(color: Colors.black54),
            ),
            const SizedBox(height: 24),
            const SizedBox(
              width: 180,
              child: LinearProgressIndicator(
                borderRadius: BorderRadius.all(Radius.circular(8)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Contenedor principal con barra de navegación inferior de 3 pestañas.
///
/// En pantallas de escritorio restringe el ancho máximo a `480 px` para
/// mantener las proporciones móviles diseñadas para operación con una mano.
class Shell extends StatefulWidget {
  /// Crea una instancia de [Shell].
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  /// Índice de la pestaña actualmente visible (`0` Negocio, `1` Pedido, `2` Resumen).
  int _i = 0;

  /// Títulos mostrados en la barra superior según la pestaña activa.
  static const List<String> _titulos = ['Negocio', 'Tomar pedido', 'Resumen'];

  /// Color resaltador usado en el indicador de la barra de navegación inferior.
  static const Color _colorActivo = Color(0xFFD9F99D);

  /// Abre un diálogo modal para editar las tarifas vigentes de público y tienda.
  Future<void> _ajustes() async {
    final controller = context.read<PosController>();
    final actuales = controller.precios;

    final puercoPubCtrl = TextEditingController(
      text: actuales.puercoPublico.toStringAsFixed(2),
    );
    final puercoTndCtrl = TextEditingController(
      text: actuales.puercoTienda.toStringAsFixed(2),
    );
    final elotePubCtrl = TextEditingController(
      text: actuales.elotePublico.toStringAsFixed(2),
    );
    final eloteTndCtrl = TextEditingController(
      text: actuales.eloteTienda.toStringAsFixed(2),
    );

    final guardar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Ajustar tarifas'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _campoPrecio(puercoPubCtrl, 'Puerco · Público (\$)'),
              const SizedBox(height: 10),
              _campoPrecio(puercoTndCtrl, 'Puerco · Tienda (\$)'),
              const SizedBox(height: 10),
              _campoPrecio(elotePubCtrl, 'Elote · Público (\$)'),
              const SizedBox(height: 10),
              _campoPrecio(eloteTndCtrl, 'Elote · Tienda (\$)'),
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
            child: const Text('Guardar'),
          ),
        ],
      ),
    );

    if (guardar == true) {
      controller.actualizarPrecios(
        ConfiguracionPrecios(
          puercoPublico:
              double.tryParse(puercoPubCtrl.text) ?? actuales.puercoPublico,
          puercoTienda:
              double.tryParse(puercoTndCtrl.text) ?? actuales.puercoTienda,
          elotePublico:
              double.tryParse(elotePubCtrl.text) ?? actuales.elotePublico,
          eloteTienda:
              double.tryParse(eloteTndCtrl.text) ?? actuales.eloteTienda,
        ),
      );
    }

    puercoPubCtrl.dispose();
    puercoTndCtrl.dispose();
    elotePubCtrl.dispose();
    eloteTndCtrl.dispose();
  }

  /// Construye un campo numérico compacto para capturar precios unitarios.
  Widget _campoPrecio(TextEditingController ctrl, String etiqueta) {
    return TextField(
      controller: ctrl,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: etiqueta,
        isDense: true,
        border: const OutlineInputBorder(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final error = context.watch<PosController>().errorConexion;
    return Scaffold(
      backgroundColor: const Color(0xFFEDEDED),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 480),
          child: Scaffold(
            appBar: AppBar(
              backgroundColor: esProduccion ? Colors.white : Colors.red.shade100,
              surfaceTintColor: Colors.transparent,
              title: Text(esProduccion ? _titulos[_i] : '${_titulos[_i]} · PRUEBAS'),
              actions: [
                IconButton(
                  tooltip: 'Ajustes',
                  icon: const Icon(Icons.settings),
                  onPressed: _ajustes,
                ),
                IconButton(
                  tooltip: 'Cerrar sesión',
                  icon: const Icon(Icons.logout),
                  onPressed: () => Supabase.instance.client.auth.signOut(),
                ),
              ],
            ),
            body: Column(
              children: [
                if (error != null)
                  MaterialBanner(
                    content: Text(error),
                    actions: [
                      TextButton(
                        onPressed: () =>
                            context.read<PosController>().inicializar(),
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                Expanded(
                  child: IndexedStack(
                    index: _i,
                    children: const [
                      OperacionScreen(),
                      TomarPedidoScreen(),
                      ResumenScreen(),
                    ],
                  ),
                ),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _i,
              indicatorColor: _colorActivo,
              onDestinationSelected: (v) => setState(() => _i = v),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.soup_kitchen_outlined),
                  selectedIcon: Icon(Icons.soup_kitchen),
                  label: 'Negocio',
                ),
                NavigationDestination(
                  icon: Icon(Icons.edit_note_outlined),
                  selectedIcon: Icon(Icons.edit_note),
                  label: 'Pedido',
                ),
                NavigationDestination(
                  icon: Icon(Icons.bar_chart_outlined),
                  selectedIcon: Icon(Icons.bar_chart),
                  label: 'Resumen',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
