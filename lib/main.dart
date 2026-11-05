

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:latlong2/latlong.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

final FlutterLocalNotificationsPlugin notificacoes =
FlutterLocalNotificationsPlugin();

Future<void> inicializarNotificacoes() async {
  const androidSettings = AndroidInitializationSettings(
    '@mipmap/ic_launcher',
  );

  const settings = InitializationSettings(
    android: androidSettings,
  );

  await notificacoes.initialize(
    settings: settings,
  );

  final androidPlugin =
  notificacoes.resolvePlatformSpecificImplementation<
      AndroidFlutterLocalNotificationsPlugin>();

  await androidPlugin?.requestNotificationsPermission();
}

Future<void> mostrarNotificacaoStatus(String novoStatus) async {
  const androidDetails = AndroidNotificationDetails(
    'status_ocorrencias',
    'AtualizaÃ§Ãµes de ocorrÃªncias',
    channelDescription:
    'NotificaÃ§Ãµes sobre alteraÃ§Ãµes no status das suas ocorrÃªncias.',
    importance: Importance.high,
    priority: Priority.high,
  );

  const detalhes = NotificationDetails(
    android: androidDetails,
  );

  await notificacoes.show(
    id: DateTime.now().millisecondsSinceEpoch.remainder(2147483647),
    title: 'GuardiÃ£oUrbano',
    body:
    'Sua ocorrÃªncia foi atualizada para ${nomeStatus(novoStatus)}.',
    notificationDetails: detalhes,
  );
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await inicializarNotificacoes();

  runApp(const GuardiaoUrbanoApp());
}

class GuardiaoUrbanoApp extends StatelessWidget {
  const GuardiaoUrbanoApp({super.key});

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF1B5E20);
    const fundo = Color(0xFFF4F7F6);

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'GuardiÃ£oUrbano',
      theme: ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: fundo,
        colorScheme: ColorScheme.fromSeed(
          seedColor: verde,
          brightness: Brightness.light,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: fundo,
          foregroundColor: verde,
          elevation: 0,
        ),
      ),
      home: const LoginPage(),
    );
  }
}


String formatarDataHora(dynamic valor) {
  if (valor == null) {
    return 'Data nÃ£o informada';
  }

  try {
    final data = DateTime.parse(valor.toString()).toLocal();

    String dois(int numero) => numero.toString().padLeft(2, '0');

    return '${dois(data.day)}/${dois(data.month)}/${data.year} '
        '${dois(data.hour)}:${dois(data.minute)}';
  } catch (erro) {
    return valor.toString();
  }
}

String nomeStatus(String status) {
  switch (status) {
    case 'ABERTA':
      return 'Aberta';
    case 'EM_ANALISE':
      return 'Em anÃ¡lise';
    case 'EM_ATENDIMENTO':
      return 'Em atendimento';
    case 'CONCLUIDA':
      return 'ConcluÃ­da';
    case 'PENDENTE':
      return 'Pendente';
    default:
      return status;
  }
}

Color corStatus(String status) {
  switch (status) {
    case 'CONCLUIDA':
      return const Color(0xFF2E7D32);
    case 'EM_ATENDIMENTO':
      return const Color(0xFF1565C0);
    case 'EM_ANALISE':
      return const Color(0xFFEF6C00);
    case 'PENDENTE':
      return const Color(0xFF757575);
    default:
      return const Color(0xFF1B5E20);
  }
}

Future<String> buscarEndereco(double latitude, double longitude) async {
  try {
    final resposta = await http.get(
      Uri.parse(
        'https://nominatim.openstreetmap.org/reverse',
      ).replace(
        queryParameters: {
          'format': 'jsonv2',
          'lat': latitude.toString(),
          'lon': longitude.toString(),
          'zoom': '18',
          'addressdetails': '1',
          'accept-language': 'pt-BR',
        },
      ),
      headers: {
        'User-Agent': 'GuardiaoUrbano/1.0',
      },
    );

    if (resposta.statusCode == 200) {
      final dados = jsonDecode(resposta.body);
      final address = Map<String, dynamic>.from(
        dados['address'] ?? {},
      );

      final partes = <String>[
        if (address['road'] != null) address['road'].toString(),
        if (address['house_number'] != null)
          address['house_number'].toString(),
        if (address['neighbourhood'] != null)
          address['neighbourhood'].toString(),
        if (address['suburb'] != null &&
            address['suburb'] != address['neighbourhood'])
          address['suburb'].toString(),
        if (address['city'] != null) address['city'].toString(),
        if (address['town'] != null && address['city'] == null)
          address['town'].toString(),
        if (address['state'] != null) address['state'].toString(),
      ];

      if (partes.isNotEmpty) {
        return partes.join(', ');
      }

      return dados['display_name']?.toString() ??
          'EndereÃ§o nÃ£o identificado';
    }
  } catch (erro) {
    return 'EndereÃ§o indisponÃ­vel no momento';
  }

  return 'EndereÃ§o nÃ£o identificado';
}

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final emailController = TextEditingController();
  final senhaController = TextEditingController();

  bool carregando = false;

  Future<void> fazerLogin() async {
    setState(() {
      carregando = true;
    });

    try {
      final resposta = await http.post(
        Uri.parse('http://192.168.0.247:8000/auth/login'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'email': emailController.text.trim(),
          'senha': senhaController.text,
        }),
      );

      final dados = jsonDecode(resposta.body);

      if (!mounted) {
        return;
      }

      if (resposta.statusCode == 200) {
        if (dados['usuario']['tipo'] == 'ADMIN') {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => AdminPage(
                token: dados['access_token'],
              ),
            ),
          );
        } else {
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(
              builder: (context) => MapaPage(
                token: dados['access_token'],
              ),
            ),
          );
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dados['detail'] ?? 'Erro ao realizar login',
            ),
          ),
        );
      }
    } catch (erro) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NÃ£o foi possÃ­vel conectar ao servidor'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F7F6),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 82,
                  height: 82,
                  decoration: BoxDecoration(
                    color: const Color(0xFF1B5E20),
                    borderRadius: BorderRadius.circular(22),
                  ),
                  child: const Icon(
                    Icons.location_city,
                    color: Colors.white,
                    size: 44,
                  ),
                ),
                const SizedBox(height: 20),
                const Text(
                  'GuardiÃ£oUrbano',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF1B5E20),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Cuide da sua cidade.',
                  style: TextStyle(
                    fontSize: 15,
                    color: Colors.black54,
                  ),
                ),
                const SizedBox(height: 40),
                TextField(
                  controller: emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: InputDecoration(
                    labelText: 'E-mail',
                    prefixIcon: const Icon(Icons.email_outlined),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF1B5E20),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: senhaController,
                  obscureText: true,
                  decoration: InputDecoration(
                    labelText: 'Senha',
                    prefixIcon: const Icon(Icons.lock_outline),
                    filled: true,
                    fillColor: Colors.white,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide.none,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFFE0E0E0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF1B5E20),
                        width: 2,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: carregando ? null : fazerLogin,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF1B5E20),
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    child: carregando
                        ? const SizedBox(
                      width: 24,
                      height: 24,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: Colors.white,
                      ),
                    )
                        : const Text(
                      'Entrar',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                TextButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CadastroPage(),
                      ),
                    );
                  },
                  child: const Text(
                    'Ainda nÃ£o possui uma conta? Cadastre-se',
                    style: TextStyle(
                      color: Color(0xFF1B5E20),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class CadastroPage extends StatefulWidget {
  const CadastroPage({super.key});

  @override
  State<CadastroPage> createState() => _CadastroPageState();
}

class _CadastroPageState extends State<CadastroPage> {
  final nomeController = TextEditingController();
  final emailController = TextEditingController();
  final senhaController = TextEditingController();
  final confirmarSenhaController = TextEditingController();

  bool carregando = false;

  Future<void> cadastrar() async {
    if (nomeController.text.isEmpty ||
        emailController.text.isEmpty ||
        senhaController.text.isEmpty ||
        confirmarSenhaController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Preencha todos os campos'),
        ),
      );
      return;
    }

    if (senhaController.text != confirmarSenhaController.text) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('As senhas nÃ£o coincidem'),
        ),
      );
      return;
    }

    setState(() {
      carregando = true;
    });

    try {
      final resposta = await http.post(
        Uri.parse('http://192.168.0.247:8000/auth/register'),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'nome': nomeController.text.trim(),
          'email': emailController.text.trim(),
          'senha': senhaController.text,
        }),
      );

      final dados = jsonDecode(resposta.body);

      if (!mounted) {
        return;
      }

      if (resposta.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Cadastro realizado com sucesso'),
          ),
        );

        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              dados['detail'] ?? 'Erro ao realizar cadastro',
            ),
          ),
        );
      }
    } catch (erro) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NÃ£o foi possÃ­vel conectar ao servidor'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          carregando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text(
          'Criar conta',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B5E20),
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Icon(
                  Icons.person_add_alt_1,
                  size: 36,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 20),
              const Text(
                'Crie sua conta',
                style: TextStyle(
                  fontSize: 25,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF1B5E20),
                ),
              ),
              const SizedBox(height: 6),
              const Text(
                'Cadastre-se para registrar ocorrÃªncias na sua cidade.',
                style: TextStyle(
                  fontSize: 14,
                  color: Colors.black54,
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: nomeController,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: 'Nome',
                  prefixIcon: const Icon(Icons.person_outline),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF1B5E20),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: emailController,
                keyboardType: TextInputType.emailAddress,
                decoration: InputDecoration(
                  labelText: 'E-mail',
                  prefixIcon: const Icon(Icons.email_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF1B5E20),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: senhaController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Senha',
                  prefixIcon: const Icon(Icons.lock_outline),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF1B5E20),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: confirmarSenhaController,
                obscureText: true,
                decoration: InputDecoration(
                  labelText: 'Confirmar senha',
                  prefixIcon: const Icon(Icons.lock_reset_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(
                      color: Color(0xFF1B5E20),
                      width: 2,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 52,
                child: ElevatedButton(
                  onPressed: carregando ? null : cadastrar,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  child: carregando
                      ? const SizedBox(
                    width: 24,
                    height: 24,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: Colors.white,
                    ),
                  )
                      : const Text(
                    'Cadastrar',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
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

void fazerLogout(BuildContext context) {
  Navigator.pushAndRemoveUntil(
    context,
    MaterialPageRoute(
      builder: (context) => const LoginPage(),
    ),
        (route) => false,
  );
}

class MapaPage extends StatefulWidget {
  final String token;

  const MapaPage({
    super.key,
    required this.token,
  });

  @override
  State<MapaPage> createState() => _MapaPageState();
}

class _MapaPageState extends State<MapaPage> {
  Position? posicao;
  bool carregando = true;

  Future<void> obterLocalizacao() async {
    bool servicoAtivo = await Geolocator.isLocationServiceEnabled();

    if (!servicoAtivo) {
      setState(() {
        carregando = false;
      });
      return;
    }

    LocationPermission permissao = await Geolocator.checkPermission();

    if (permissao == LocationPermission.denied) {
      permissao = await Geolocator.requestPermission();
    }

    if (permissao == LocationPermission.denied ||
        permissao == LocationPermission.deniedForever) {
      setState(() {
        carregando = false;
      });
      return;
    }

    final novaPosicao = await Geolocator.getCurrentPosition();

    setState(() {
      posicao = novaPosicao;
      carregando = false;
    });
  }

  @override
  void initState() {
    super.initState();
    obterLocalizacao();
  }

  @override
  Widget build(BuildContext context) {
    if (carregando || posicao == null) {
      return Scaffold(
        backgroundColor: const Color(0xFFF5F7F5),
        appBar: AppBar(
          title: const Text(
            'GuardiÃ£oUrbano',
            style: TextStyle(fontWeight: FontWeight.w600),
          ),
          centerTitle: true,
          backgroundColor: Colors.white,
          foregroundColor: const Color(0xFF1B5E20),
          elevation: 0,
        ),
        body: const Center(
          child: CircularProgressIndicator(
            color: Color(0xFF1B5E20),
          ),
        ),
      );
    }

    final ponto = LatLng(
      posicao!.latitude,
      posicao!.longitude,
    );

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7F5),
      appBar: AppBar(
        title: const Text(
          'GuardiÃ£oUrbano',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
        centerTitle: true,
        backgroundColor: Colors.white,
        foregroundColor: const Color(0xFF1B5E20),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Minhas ocorrÃªncias',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => MinhasOcorrenciasPage(
                    token: widget.token,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.list_alt_outlined),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: () => fazerLogout(context),
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: ponto,
              initialZoom: 16,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.guardiaourbano.guardiao_urbano',
              ),
              MarkerLayer(
                markers: [
                  Marker(
                    point: ponto,
                    width: 54,
                    height: 54,
                    child: Container(
                      decoration: BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.18),
                            blurRadius: 6,
                            offset: const Offset(0, 2),
                          ),
                        ],
                      ),
                      child: const Icon(
                        Icons.location_on,
                        size: 42,
                        color: Color(0xFF1B5E20),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
          Positioned(
            left: 16,
            top: 16,
            right: 16,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.12),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ],
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.info_outline,
                    color: Color(0xFF1B5E20),
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Sua localizaÃ§Ã£o atual',
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          FloatingActionButton(
            heroTag: 'localizacao',
            backgroundColor: Colors.white,
            foregroundColor: const Color(0xFF1B5E20),
            elevation: 4,
            onPressed: () async {
              setState(() {
                carregando = true;
              });

              await obterLocalizacao();
            },
            child: const Icon(Icons.my_location),
          ),
          const SizedBox(height: 14),
          FloatingActionButton.extended(
            heroTag: 'ocorrencia',
            backgroundColor: const Color(0xFF1B5E20),
            foregroundColor: Colors.white,
            elevation: 4,
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => NovaOcorrenciaPage(
                    posicao: posicao!,
                    token: widget.token,
                  ),
                ),
              );
            },
            icon: const Icon(Icons.add_location_alt_outlined),
            label: const Text(
              'Nova ocorrÃªncia',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}


class NovaOcorrenciaPage extends StatefulWidget {
  final Position posicao;
  final String token;

  const NovaOcorrenciaPage({
    super.key,
    required this.posicao,
    required this.token,
  });

  @override
  State<NovaOcorrenciaPage> createState() => _NovaOcorrenciaPageState();
}

class _NovaOcorrenciaPageState extends State<NovaOcorrenciaPage> {
  final descricaoController = TextEditingController();

  List<Map<String, dynamic>> categorias = [];
  int? categoriaSelecionada;
  bool carregandoCategorias = true;
  bool enviando = false;
  XFile? foto;
  String endereco = 'Obtendo endereÃ§o...';

  @override
  void initState() {
    super.initState();
    carregarCategorias();
    carregarEndereco();
  }

  Future<void> carregarCategorias() async {
    try {
      final resposta = await http.get(
        Uri.parse('http://192.168.0.247:8000/categorias/'),
      );

      if (!mounted) return;

      if (resposta.statusCode != 200) {
        throw Exception('Falha ao carregar categorias: ${resposta.statusCode}');
      }

      final dados = List<Map<String, dynamic>>.from(
        jsonDecode(resposta.body),
      );

      setState(() {
        categorias = dados;
        carregandoCategorias = false;
      });
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        carregandoCategorias = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('NÃ£o foi possÃ­vel carregar as categorias. Verifique a conexÃ£o.'),
        ),
      );
    }
  }

  Future<void> carregarEndereco() async {
    try {
      final resposta = await http.get(
        Uri.parse(
          'https://nominatim.openstreetmap.org/reverse',
        ).replace(
          queryParameters: {
            'format': 'jsonv2',
            'lat': widget.posicao.latitude.toString(),
            'lon': widget.posicao.longitude.toString(),
            'zoom': '18',
            'addressdetails': '1',
            'accept-language': 'pt-BR',
          },
        ),
        headers: {
          'User-Agent': 'GuardiaoUrbano/1.0',
        },
      );

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body);
        final address = Map<String, dynamic>.from(
          dados['address'] ?? {},
        );

        final partes = <String>[
          if (address['road'] != null) address['road'].toString(),
          if (address['house_number'] != null) address['house_number'].toString(),
          if (address['neighbourhood'] != null)
            address['neighbourhood'].toString(),
          if (address['suburb'] != null &&
              address['suburb'] != address['neighbourhood'])
            address['suburb'].toString(),
          if (address['city'] != null) address['city'].toString(),
          if (address['town'] != null && address['city'] == null)
            address['town'].toString(),
          if (address['state'] != null) address['state'].toString(),
        ];

        setState(() {
          endereco = partes.isEmpty
              ? (dados['display_name'] ?? 'EndereÃ§o nÃ£o identificado')
              : partes.join(', ');
        });
      } else {
        setState(() {
          endereco = 'NÃ£o foi possÃ­vel identificar o endereÃ§o';
        });
      }
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        endereco = 'EndereÃ§o indisponÃ­vel no momento';
      });
    }
  }

  Future<void> selecionarFoto() async {
    final imagem = await ImagePicker().pickImage(
      source: ImageSource.camera,
    );

    if (imagem != null) {
      setState(() {
        foto = imagem;
      });
    }
  }

  Future<void> enviarOcorrencia() async {
    if (categoriaSelecionada == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Selecione uma categoria')),
      );
      return;
    }

    if (descricaoController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Informe uma descriÃ§Ã£o')),
      );
      return;
    }

    setState(() {
      enviando = true;
    });

    try {
      final requisicao = http.MultipartRequest(
        'POST',
        Uri.parse('http://192.168.0.247:8000/ocorrencias/'),
      );

      requisicao.headers['Authorization'] = 'Bearer ${widget.token}';
      requisicao.fields['categoria_id'] = categoriaSelecionada.toString();
      requisicao.fields['descricao'] = descricaoController.text.trim();
      requisicao.fields['latitude'] = widget.posicao.latitude.toString();
      requisicao.fields['longitude'] = widget.posicao.longitude.toString();

      if (foto != null) {
        requisicao.files.add(
          await http.MultipartFile.fromPath('foto', foto!.path),
        );
      }

      final resposta = await requisicao.send();
      final corpo = await resposta.stream.bytesToString();

      if (!mounted) return;

      if (resposta.statusCode == 200 || resposta.statusCode == 201) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('OcorrÃªncia enviada com sucesso')),
        );
        Navigator.pop(context);
      } else {
        var mensagem = 'NÃ£o foi possÃ­vel enviar a ocorrÃªncia';

        try {
          final dados = jsonDecode(corpo);
          mensagem = dados['detail']?.toString() ?? mensagem;
        } catch (_) {}

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(mensagem)),
        );
      }
    } catch (erro) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Sem conexÃ£o com o servidor. Tente novamente.'),
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          enviando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Nova ocorrÃªncia'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: const Color(0xFFE8F5E9),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.report_problem_outlined,
                      size: 32,
                      color: const Color(0xFF1B5E20),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Registrar ocorrÃªncia',
                            style: Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Informe o problema encontrado para enviar a ocorrÃªncia.',
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Categoria',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              carregandoCategorias
                  ? const Center(
                child: Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator(),
                ),
              )
                  : DropdownButtonFormField<int>(
                value: categoriaSelecionada,
                decoration: InputDecoration(
                  hintText: 'Selecione uma categoria',
                  prefixIcon: const Icon(Icons.category_outlined),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                items: categorias.map((categoria) {
                  return DropdownMenuItem<int>(
                    value: categoria['id'],
                    child: Text(categoria['nome']),
                  );
                }).toList(),
                onChanged: (valor) {
                  setState(() {
                    categoriaSelecionada = valor;
                  });
                },
              ),
              const SizedBox(height: 20),
              Text(
                'DescriÃ§Ã£o',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: descricaoController,
                maxLines: 5,
                decoration: InputDecoration(
                  hintText: 'Descreva o problema encontrado...',
                  alignLabelWithHint: true,
                  prefixIcon: const Padding(
                    padding: EdgeInsets.only(bottom: 78),
                    child: Icon(Icons.description_outlined),
                  ),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: selecionarFoto,
                style: OutlinedButton.styleFrom(
                  foregroundColor: const Color(0xFF1B5E20),
                  side: const BorderSide(color: Color(0xFF1B5E20)),
                  minimumSize: const Size.fromHeight(52),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: Icon(
                  foto == null
                      ? Icons.camera_alt_outlined
                      : Icons.check_circle_outline,
                ),
                label: Text(
                  foto == null ? 'Adicionar foto' : 'Foto adicionada',
                ),
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: const Color(0xFFE0E0E0),
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.location_on_outlined),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'LocalizaÃ§Ã£o registrada',
                            style: Theme.of(context)
                                .textTheme
                                .titleMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            endereco,
                            style: Theme.of(context).textTheme.bodyLarge,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                height: 54,
                child: ElevatedButton.icon(
                  onPressed: enviando ? null : enviarOcorrencia,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF1B5E20),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: enviando
                      ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                      : const Icon(Icons.send_outlined),
                  label: Text(
                    enviando ? 'Enviando...' : 'Enviar ocorrÃªncia',
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

class MinhasOcorrenciasPage extends StatefulWidget {
  final String token;

  const MinhasOcorrenciasPage({
    super.key,
    required this.token,
  });

  @override
  State<MinhasOcorrenciasPage> createState() =>
      _MinhasOcorrenciasPageState();
}

class _MinhasOcorrenciasPageState
    extends State<MinhasOcorrenciasPage> {
  List<Map<String, dynamic>> ocorrencias = [];
  bool carregando = true;
  late WebSocketChannel canalWebSocket;

  @override
  void initState() {
    super.initState();
    conectarWebSocket();
    carregarOcorrencias();
  }

  void conectarWebSocket() {
    canalWebSocket = WebSocketChannel.connect(
      Uri.parse('ws://192.168.0.247:8000/ws'),
    );

    canalWebSocket.stream.listen(
          (mensagem) {
        final dados = jsonDecode(mensagem);

        if (dados['tipo'] == 'STATUS_ATUALIZADO') {
          final ocorrenciaId = dados['ocorrencia_id'].toString();
          final novoStatus = dados['status_novo'].toString();

          final pertenceAoUsuario = ocorrencias.any(
                (ocorrencia) =>
            ocorrencia['id'].toString() == ocorrenciaId &&
                ocorrencia['local'] != true,
          );

          atualizarStatusOcorrencia(
            ocorrenciaId,
            novoStatus,
          );

          if (pertenceAoUsuario) {
            mostrarNotificacaoStatus(novoStatus);
          }
        }
      },
      onError: (erro) {
        print('WebSocket erro: $erro');
      },
      onDone: () {
        print('WebSocket desconectado');
      },
    );

    print('WebSocket conectado');
  }

  void atualizarStatusOcorrencia(
      String ocorrenciaId,
      String novoStatus,
      ) {
    if (!mounted) {
      return;
    }

    setState(() {
      for (final ocorrencia in ocorrencias) {
        if (ocorrencia['id'] == ocorrenciaId) {
          ocorrencia['status'] = novoStatus;
          break;
        }
      }
    });
  }

  Future<void> carregarOcorrencias() async {
    try {
      final resposta = await http.get(
        Uri.parse('http://192.168.0.247:8000/ocorrencias/'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (!mounted) return;

      if (resposta.statusCode == 200) {
        final dados = List<Map<String, dynamic>>.from(
          jsonDecode(resposta.body),
        );

        setState(() {
          ocorrencias = dados;
          carregando = false;
        });
      } else {
        setState(() {
          carregando = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'NÃ£o foi possÃ­vel carregar as ocorrÃªncias (${resposta.statusCode})',
            ),
          ),
        );
      }
    } catch (erro) {
      if (!mounted) return;

      setState(() {
        carregando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Erro de conexÃ£o ao carregar ocorrÃªncias.'),
        ),
      );
    }
  }

  void abrirDetalhes(String id) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => DetalhesOcorrenciaPage(
          token: widget.token,
          ocorrenciaId: id,
        ),
      ),
    );
  }

  @override
  void dispose() {
    canalWebSocket.sink.close();
    super.dispose();
  }

  String nomeStatus(String status) {
    switch (status) {
      case 'ABERTA':
        return 'Aberta';
      case 'EM_ANALISE':
        return 'Em anÃ¡lise';
      case 'EM_ATENDIMENTO':
        return 'Em atendimento';
      case 'CONCLUIDA':
        return 'ConcluÃ­da';
      case 'PENDENTE':
        return 'Pendente';
      default:
        return status;
    }
  }

  Color corStatus(String status) {
    switch (status) {
      case 'CONCLUIDA':
        return const Color(0xFF2E7D32);
      case 'EM_ATENDIMENTO':
        return const Color(0xFF1565C0);
      case 'EM_ANALISE':
        return const Color(0xFFEF6C00);
      case 'PENDENTE':
        return const Color(0xFF757575);
      default:
        return const Color(0xFF1B5E20);
    }
  }

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF1B5E20);
    const fundo = Color(0xFFF4F7F6);

    return Scaffold(
      backgroundColor: fundo,
      appBar: AppBar(
        backgroundColor: fundo,
        elevation: 0,
        foregroundColor: verde,
        title: const Text(
          'Minhas ocorrÃªncias',
          style: TextStyle(
            fontWeight: FontWeight.bold,
          ),
        ),
        actions: [
          IconButton(
            onPressed: carregarOcorrencias,
            icon: const Icon(Icons.refresh),
            tooltip: 'Atualizar',
          ),
        ],
      ),
      body: carregando
          ? const Center(
        child: CircularProgressIndicator(
          color: verde,
        ),
      )
          : ocorrencias.isEmpty
          ? Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 76,
                height: 76,
                decoration: BoxDecoration(
                  color: verde.withOpacity(0.10),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.assignment_outlined,
                  size: 38,
                  color: verde,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'Nenhuma ocorrÃªncia encontrada',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Suas ocorrÃªncias aparecerÃ£o aqui.',
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      )
          : RefreshIndicator(
        color: verde,
        onRefresh: carregarOcorrencias,
        child: ListView.builder(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          itemCount: ocorrencias.length,
          itemBuilder: (context, index) {
            final ocorrencia = ocorrencias[index];
            final status = ocorrencia['status'].toString();
            final cor = corStatus(status);

            return Card(
              color: Colors.white,
              elevation: 1,
              margin: const EdgeInsets.only(bottom: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () {
                  if (ocorrencia['local'] == true) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text(
                          'OcorrÃªncia aguardando sincronizaÃ§Ã£o.',
                        ),
                      ),
                    );
                    return;
                  }

                  abrirDetalhes(ocorrencia['id']);
                },
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: verde.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.report_problem_outlined,
                          color: verde,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              ocorrencia['categoria'].toString(),
                              style: const TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              ocorrencia['descricao'].toString(),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                color: Colors.black54,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: cor.withOpacity(0.10),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Text(
                                nomeStatus(status),
                                style: TextStyle(
                                  color: cor,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      const Icon(
                        Icons.chevron_right,
                        color: Colors.black38,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
class DetalhesOcorrenciaPage extends StatefulWidget {
  final String token;
  final String ocorrenciaId;

  const DetalhesOcorrenciaPage({
    super.key,
    required this.token,
    required this.ocorrenciaId,
  });

  @override
  State<DetalhesOcorrenciaPage> createState() =>
      _DetalhesOcorrenciaPageState();
}

class _DetalhesOcorrenciaPageState
    extends State<DetalhesOcorrenciaPage> {
  Map<String, dynamic>? ocorrencia;
  bool carregando = true;
  String endereco = 'Obtendo endereÃ§o...';

  @override
  void initState() {
    super.initState();
    carregarDetalhes();
  }

  Future<void> carregarEndereco() async {
    if (ocorrencia == null) {
      return;
    }

    final resultado = await buscarEndereco(
      double.parse(ocorrencia!['latitude'].toString()),
      double.parse(ocorrencia!['longitude'].toString()),
    );

    if (!mounted) {
      return;
    }

    setState(() {
      endereco = resultado;
    });
  }

  Future<void> carregarDetalhes() async {
    try {
      final resposta = await http.get(
        Uri.parse(
          'http://192.168.0.247:8000/ocorrencias/${widget.ocorrenciaId}',
        ),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (!mounted) {
        return;
      }

      if (resposta.statusCode == 200) {
        setState(() {
          ocorrencia = jsonDecode(resposta.body);
          carregando = false;
        });

        carregarEndereco();
      } else {
        setState(() {
          carregando = false;
        });
      }
    } catch (erro) {
      if (!mounted) {
        return;
      }

      setState(() {
        carregando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'NÃ£o foi possÃ­vel conectar ao servidor',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF1B5E20);
    const fundo = Color(0xFFF4F7F6);

    if (carregando) {
      return const Scaffold(
        backgroundColor: fundo,
        body: Center(
          child: CircularProgressIndicator(
            color: verde,
          ),
        ),
      );
    }

    if (ocorrencia == null) {
      return Scaffold(
        backgroundColor: fundo,
        appBar: AppBar(
          title: const Text('Detalhes'),
        ),
        body: const Center(
          child: Text('OcorrÃªncia nÃ£o encontrada'),
        ),
      );
    }

    final status = ocorrencia!['status'].toString();
    final cor = corStatus(status);

    return Scaffold(
      backgroundColor: fundo,
      appBar: AppBar(
        title: const Text(
          'Detalhes da ocorrÃªncia',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(
                  color: const Color(0xFFE0E0E0),
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 52,
                    height: 52,
                    decoration: BoxDecoration(
                      color: verde.withOpacity(0.10),
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: const Icon(
                      Icons.report_problem_outlined,
                      color: verde,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          ocorrencia!['categoria'].toString(),
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: verde,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: cor.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Text(
                            nomeStatus(status),
                            style: TextStyle(
                              color: cor,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _InfoCard(
              titulo: 'DescriÃ§Ã£o',
              icone: Icons.description_outlined,
              conteudo: ocorrencia!['descricao'].toString(),
            ),
            const SizedBox(height: 16),
            _InfoCard(
              titulo: 'LocalizaÃ§Ã£o',
              icone: Icons.location_on_outlined,
              conteudo: endereco,
            ),
          ],
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String titulo;
  final IconData icone;
  final String conteudo;

  const _InfoCard({
    required this.titulo,
    required this.icone,
    required this.conteudo,
  });

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF1B5E20);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: const Color(0xFFE0E0E0),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                icone,
                color: verde,
                size: 21,
              ),
              const SizedBox(width: 8),
              Text(
                titulo,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.bold,
                  color: verde,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            conteudo,
            style: const TextStyle(
              fontSize: 15,
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }
}
class AdminPage extends StatefulWidget {
  final String token;

  const AdminPage({
    super.key,
    required this.token,
  });

  @override
  State<AdminPage> createState() => _AdminPageState();
}

class _AdminPageState extends State<AdminPage> {
  List<Map<String, dynamic>> ocorrencias = [];
  final Map<String, String> enderecos = {};
  bool carregando = true;

  final List<String> statusValidos = [
    'ABERTA',
    'EM_ANALISE',
    'EM_ATENDIMENTO',
    'CONCLUIDA',
  ];

  @override
  void initState() {
    super.initState();
    carregarOcorrencias();
  }

  Future<void> carregarEnderecos() async {
    for (final ocorrencia in ocorrencias) {
      final id = ocorrencia['id'].toString();

      if (enderecos.containsKey(id)) {
        continue;
      }

      final endereco = await buscarEndereco(
        double.parse(ocorrencia['latitude'].toString()),
        double.parse(ocorrencia['longitude'].toString()),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        enderecos[id] = endereco;
      });
    }
  }

  Future<void> carregarOcorrencias() async {
    try {
      final resposta = await http.get(
        Uri.parse('http://192.168.0.247:8000/admin/ocorrencias'),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (!mounted) {
        return;
      }

      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body);

        setState(() {
          ocorrencias = List<Map<String, dynamic>>.from(dados);
          carregando = false;
        });

        carregarEnderecos();
      } else {
        setState(() {
          carregando = false;
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'NÃ£o foi possÃ­vel carregar as ocorrÃªncias',
            ),
          ),
        );
      }
    } catch (erro) {
      if (!mounted) {
        return;
      }

      setState(() {
        carregando = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'NÃ£o foi possÃ­vel conectar ao servidor',
          ),
        ),
      );
    }
  }

  Future<void> alterarStatus(
      String ocorrenciaId,
      String novoStatus,
      ) async {
    try {
      final resposta = await http.put(
        Uri.parse(
          'http://192.168.0.247:8000/admin/ocorrencias/$ocorrenciaId/status',
        ).replace(
          queryParameters: {
            'novo_status': novoStatus,
          },
        ),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (!mounted) {
        return;
      }

      if (resposta.statusCode == 200) {
        setState(() {
          for (final ocorrencia in ocorrencias) {
            if (ocorrencia['id'] == ocorrenciaId) {
              ocorrencia['status'] = novoStatus;
              break;
            }
          }
        });

        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Status atualizado'),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'NÃ£o foi possÃ­vel alterar o status',
            ),
          ),
        );
      }
    } catch (erro) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'NÃ£o foi possÃ­vel conectar ao servidor',
          ),
        ),
      );
    }
  }

  Future<void> abrirHistorico(String ocorrenciaId) async {
    try {
      final resposta = await http.get(
        Uri.parse(
          'http://192.168.0.247:8000/admin/ocorrencias/$ocorrenciaId/historico',
        ),
        headers: {
          'Authorization': 'Bearer ${widget.token}',
        },
      );

      if (!mounted) {
        return;
      }

      if (resposta.statusCode == 200) {
        final dados = jsonDecode(resposta.body);

        showModalBottomSheet(
          context: context,
          isScrollControlled: true,
          backgroundColor: Colors.white,
          shape: const RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(
              top: Radius.circular(24),
            ),
          ),
          builder: (context) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
                child: SizedBox(
                  height: 430,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 42,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(10),
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      const Text(
                        'HistÃ³rico da ocorrÃªncia',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(height: 14),
                      Expanded(
                        child: dados.isEmpty
                            ? const Center(
                          child: Text(
                            'Nenhum histÃ³rico encontrado',
                          ),
                        )
                            : ListView.separated(
                          itemCount: dados.length,
                          separatorBuilder: (_, __) =>
                          const SizedBox(height: 10),
                          itemBuilder: (context, index) {
                            final item = dados[index];
                            final statusNovo =
                            item['status_novo'].toString();

                            return Container(
                              padding: const EdgeInsets.all(14),
                              decoration: BoxDecoration(
                                color: const Color(0xFFF4F7F6),
                                borderRadius: BorderRadius.circular(14),
                              ),
                              child: Row(
                                crossAxisAlignment:
                                CrossAxisAlignment.start,
                                children: [
                                  const Icon(
                                    Icons.history,
                                    color: Color(0xFF1B5E20),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${nomeStatus(item['status_anterior'].toString())} â†’ '
                                              '${nomeStatus(statusNovo)}',
                                          style: const TextStyle(
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(
                                          'Alterado por: ${item['alterado_por']}',
                                        ),
                                        const SizedBox(height: 3),
                                        Text(
                                          formatarDataHora(
                                            item['created_at'],
                                          ),
                                          style: TextStyle(
                                            color: Colors.grey.shade700,
                                            fontSize: 12,
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
                    ],
                  ),
                ),
              ),
            );
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'NÃ£o foi possÃ­vel carregar o histÃ³rico',
            ),
          ),
        );
      }
    } catch (erro) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'NÃ£o foi possÃ­vel conectar ao servidor',
          ),
        ),
      );
    }
  }

  void abrirMapa() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AdminMapaPage(
          ocorrencias: ocorrencias,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF1B5E20);
    const fundo = Color(0xFFF4F7F6);

    return Scaffold(
      backgroundColor: fundo,
      appBar: AppBar(
        title: const Text(
          'Dashboard',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            tooltip: 'Mapa',
            onPressed: abrirMapa,
            icon: const Icon(Icons.map_outlined),
          ),
          IconButton(
            tooltip: 'Atualizar',
            onPressed: () {
              setState(() {
                carregando = true;
              });

              carregarOcorrencias();
            },
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Sair',
            onPressed: () => fazerLogout(context),
            icon: const Icon(Icons.logout_outlined),
          ),
        ],
      ),
      body: carregando
          ? const Center(
        child: CircularProgressIndicator(
          color: verde,
        ),
      )
          : ocorrencias.isEmpty
          ? const Center(
        child: Text('Nenhuma ocorrÃªncia encontrada'),
      )
          : ListView.builder(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        itemCount: ocorrencias.length,
        itemBuilder: (context, index) {
          final ocorrencia = ocorrencias[index];
          final status = ocorrencia['status'].toString();
          final cor = corStatus(status);
          final id = ocorrencia['id'].toString();
          final fotoUrl = ocorrencia['foto_url']?.toString();

          return Card(
            elevation: 0,
            margin: const EdgeInsets.only(bottom: 14),
            color: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
              side: const BorderSide(
                color: Color(0xFFE0E0E0),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: verde.withOpacity(0.10),
                          borderRadius: BorderRadius.circular(13),
                        ),
                        child: const Icon(
                          Icons.report_problem_outlined,
                          color: verde,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              ocorrencia['categoria'].toString(),
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: verde,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: cor.withOpacity(0.10),
                                borderRadius:
                                BorderRadius.circular(20),
                              ),
                              child: Text(
                                nomeStatus(status),
                                style: TextStyle(
                                  color: cor,
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    ocorrencia['descricao'].toString(),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 14,
                      height: 1.35,
                    ),
                  ),
                  if (fotoUrl != null && fotoUrl.isNotEmpty) ...[
                    const SizedBox(height: 14),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(14),
                      child: Image.network(
                        'http://192.168.0.247:8000$fotoUrl',
                        width: double.infinity,
                        height: 180,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Container(
                            width: double.infinity,
                            height: 180,
                            color: fundo,
                            alignment: Alignment.center,
                            child: const Icon(
                              Icons.broken_image_outlined,
                              size: 40,
                              color: Colors.grey,
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                  const SizedBox(height: 14),
                  _AdminInfoLine(
                    icon: Icons.person_outline,
                    text: 'UsuÃ¡rio: ${ocorrencia['usuario']}',
                  ),
                  const SizedBox(height: 7),
                  _AdminInfoLine(
                    icon: Icons.email_outlined,
                    text: 'E-mail: ${ocorrencia['email']}',
                  ),
                  const SizedBox(height: 7),
                  _AdminInfoLine(
                    icon: Icons.location_on_outlined,
                    text: enderecos[id] ??
                        'Obtendo endereÃ§o...',
                  ),
                  const SizedBox(height: 16),
                  DropdownButtonFormField<String>(
                    value: status,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      prefixIcon: const Icon(
                        Icons.flag_outlined,
                      ),
                      filled: true,
                      fillColor: fundo,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    items: statusValidos.map((statusItem) {
                      return DropdownMenuItem<String>(
                        value: statusItem,
                        child: Text(
                          nomeStatus(statusItem),
                        ),
                      );
                    }).toList(),
                    onChanged: (novoStatus) {
                      if (novoStatus == null ||
                          novoStatus == status) {
                        return;
                      }

                      alterarStatus(
                        ocorrencia['id'],
                        novoStatus,
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () {
                        abrirHistorico(
                          ocorrencia['id'],
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: verde,
                        side: const BorderSide(
                          color: verde,
                        ),
                        minimumSize:
                        const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius:
                          BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.history),
                      label: const Text('Ver histÃ³rico'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}

class _AdminInfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _AdminInfoLine({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          icon,
          size: 19,
          color: const Color(0xFF1B5E20),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: const TextStyle(
              fontSize: 13,
              height: 1.3,
            ),
          ),
        ),
      ],
    );
  }
}

class AdminMapaPage extends StatefulWidget {
  final List<Map<String, dynamic>> ocorrencias;

  const AdminMapaPage({
    super.key,
    required this.ocorrencias,
  });

  @override
  State<AdminMapaPage> createState() => _AdminMapaPageState();
}

class _AdminMapaPageState extends State<AdminMapaPage> {
  final Map<String, String> enderecos = {};

  @override
  void initState() {
    super.initState();
    carregarEnderecos();
  }

  Future<void> carregarEnderecos() async {
    for (final ocorrencia in widget.ocorrencias) {
      final id = ocorrencia['id'].toString();

      final endereco = await buscarEndereco(
        double.parse(ocorrencia['latitude'].toString()),
        double.parse(ocorrencia['longitude'].toString()),
      );

      if (!mounted) {
        return;
      }

      setState(() {
        enderecos[id] = endereco;
      });
    }
  }

  void abrirOcorrencia(
      BuildContext context,
      Map<String, dynamic> ocorrencia,
      ) {
    final status = ocorrencia['status'].toString();
    final cor = corStatus(status);
    final id = ocorrencia['id'].toString();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(26),
        ),
      ),
      builder: (context) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 42,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey.shade300,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 48,
                        height: 48,
                        decoration: BoxDecoration(
                          color: const Color(0xFFE8F5E9),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: const Icon(
                          Icons.location_on_outlined,
                          color: Color(0xFF1B5E20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                          CrossAxisAlignment.start,
                          children: [
                            Text(
                              ocorrencia['categoria'].toString(),
                              style: const TextStyle(
                                fontSize: 19,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF1B5E20),
                              ),
                            ),
                            const SizedBox(height: 7),
                            Align(
                              alignment: Alignment.centerLeft,
                              child: Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 10,
                                  vertical: 5,
                                ),
                                decoration: BoxDecoration(
                                  color: cor.withOpacity(0.10),
                                  borderRadius:
                                  BorderRadius.circular(20),
                                ),
                                child: Text(
                                  nomeStatus(status),
                                  style: TextStyle(
                                    color: cor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _AdminInfoLine(
                    icon: Icons.person_outline,
                    text: 'UsuÃ¡rio: ${ocorrencia['usuario']}',
                  ),
                  const SizedBox(height: 8),
                  _AdminInfoLine(
                    icon: Icons.description_outlined,
                    text: ocorrencia['descricao'].toString(),
                  ),
                  const SizedBox(height: 8),
                  _AdminInfoLine(
                    icon: Icons.location_on_outlined,
                    text: enderecos[id] ?? 'Obtendo endereÃ§o...',
                  ),
                  if (ocorrencia['created_at'] != null) ...[
                    const SizedBox(height: 8),
                    _AdminInfoLine(
                      icon: Icons.schedule_outlined,
                      text: formatarDataHora(
                        ocorrencia['created_at'],
                      ),
                    ),
                  ],
                  const SizedBox(height: 18),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.pop(context),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF1B5E20),
                        side: const BorderSide(
                          color: Color(0xFF1B5E20),
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      icon: const Icon(Icons.close),
                      label: const Text('Fechar'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    const verde = Color(0xFF1B5E20);
    const fundo = Color(0xFFF4F7F6);

    if (widget.ocorrencias.isEmpty) {
      return Scaffold(
        backgroundColor: fundo,
        appBar: AppBar(
          title: const Text(
            'Mapa das ocorrÃªncias',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
        body: const Center(
          child: Text('Nenhuma ocorrÃªncia encontrada'),
        ),
      );
    }

    final primeiraOcorrencia = widget.ocorrencias.first;

    final centro = LatLng(
      double.parse(
        primeiraOcorrencia['latitude'].toString(),
      ),
      double.parse(
        primeiraOcorrencia['longitude'].toString(),
      ),
    );

    return Scaffold(
      backgroundColor: fundo,
      appBar: AppBar(
        title: const Text(
          'Mapa das ocorrÃªncias',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: Stack(
        children: [
          FlutterMap(
            options: MapOptions(
              initialCenter: centro,
              initialZoom: 13,
            ),
            children: [
              TileLayer(
                urlTemplate:
                'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                'com.guardiaourbano.guardiao_urbano',
              ),
              MarkerLayer(
                markers: widget.ocorrencias.map((ocorrencia) {
                  final ponto = LatLng(
                    double.parse(
                      ocorrencia['latitude'].toString(),
                    ),
                    double.parse(
                      ocorrencia['longitude'].toString(),
                    ),
                  );

                  final cor = corStatus(
                    ocorrencia['status'].toString(),
                  );

                  return Marker(
                    point: ponto,
                    width: 48,
                    height: 48,
                    child: GestureDetector(
                      onTap: () {
                        abrirOcorrencia(
                          context,
                          ocorrencia,
                        );
                      },
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          shape: BoxShape.circle,
                          border: Border.all(
                            color: cor,
                            width: 3,
                          ),
                          boxShadow: const [
                            BoxShadow(
                              blurRadius: 6,
                              offset: Offset(0, 2),
                              color: Colors.black26,
                            ),
                          ],
                        ),
                        child: Icon(
                          Icons.location_on,
                          size: 30,
                          color: cor,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ],
          ),
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 11,
              ),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [
                  BoxShadow(
                    blurRadius: 8,
                    offset: Offset(0, 3),
                    color: Colors.black26,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.location_on_outlined,
                    color: verde,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      '${widget.ocorrencias.length} '
                          '${widget.ocorrencias.length == 1 ? 'ocorrÃªncia' : 'ocorrÃªncias'} no mapa',
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
