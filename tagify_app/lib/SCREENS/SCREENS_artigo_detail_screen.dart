import 'package:flutter/material.dart';
import '../models/models.dart';
import '../SERVICE/database_helper.dart';

class ArtigoDetailScreen extends StatefulWidget {
  final Artigo artigo;

  const ArtigoDetailScreen({
    super.key,
    required this.artigo,
  });

  @override
  State<ArtigoDetailScreen> createState() => _ArtigoDetailScreenState();
}

class _ArtigoDetailScreenState extends State<ArtigoDetailScreen> {
  List<Map<String, dynamic>> _movimentos = [];
  List<Map<String, dynamic>> _equipamentos = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDetails();
  }

  Future<void> _loadDetails() async {
    setState(() => _isLoading = true);

    try {
      final db = await DatabaseHelper.instance.database;

      // Buscar movimentos do artigo
      final movimentosRaw = await db.query(
        'MOVIMENTOS',
        where: 'ID_artigo = ?',
        whereArgs: [widget.artigo.id],
        orderBy: 'Data_mov DESC',
        limit: 20,
      );

      // Buscar equipamentos associados
      final equipamentosRaw = await db.query(
        'EQUIPAMENTO',
        where: 'ID_artigo = ?',
        whereArgs: [widget.artigo.id],
      );

      setState(() {
        _movimentos = movimentosRaw;
        _equipamentos = equipamentosRaw;
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar detalhes: $e');
      setState(() => _isLoading = false);
    }
  }

  double _calcularStock() {
    double stock = 0;
    for (var mov in _movimentos) {
      final entrada = (mov['Qtd_entrada'] ?? 0.0) as double;
      final saida = (mov['Qtd_saida'] ?? 0.0) as double;
      stock += entrada - saida;
    }
    return stock;
  }

  @override
  Widget build(BuildContext context) {
    final stock = _calcularStock();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Detalhes do Artigo'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.edit),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Edição em desenvolvimento'),
                ),
              );
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadDetails,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Cabeçalho com imagem
                    _buildHeader(),

                    // Informação principal
                    _buildMainInfo(),

                    // Stock
                    _buildStockSection(stock),

                    // Equipamentos
                    if (_equipamentos.isNotEmpty) _buildEquipamentosSection(),

                    // Movimentos recentes
                    _buildMovimentosSection(),
                  ],
                ),
              ),
            ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Registar movimento em desenvolvimento'),
              backgroundColor: Colors.blue,
            ),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Novo Movimento'),
        backgroundColor: Colors.blue,
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      width: double.infinity,
      height: 200,
      color: Colors.grey[200],
      child: widget.artigo.imagem != null
          ? Image.network(
              widget.artigo.imagem!,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return _buildPlaceholderImage();
              },
            )
          : _buildPlaceholderImage(),
    );
  }

  Widget _buildPlaceholderImage() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.inventory_2,
            size: 80,
            color: Colors.grey[400],
          ),
          const SizedBox(height: 8),
          Text(
            'Sem imagem',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainInfo() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.artigo.designacao,
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          _buildInfoRow(
            Icons.tag,
            'Referência',
            widget.artigo.referencia ?? 'N/A',
          ),
          if (widget.artigo.familia != null)
            _buildInfoRow(
              Icons.category,
              'Família',
              widget.artigo.familia!.designacao,
            ),
          if (widget.artigo.tipo != null)
            _buildInfoRow(
              Icons.label,
              'Tipo',
              widget.artigo.tipo!.designacao,
            ),
          if (widget.artigo.codBar != null)
            _buildInfoRow(
              Icons.qr_code,
              'Código Barras',
              widget.artigo.codBar!,
            ),
          if (widget.artigo.codNfc != null)
            _buildInfoRow(
              Icons.nfc,
              'NFC',
              widget.artigo.codNfc!,
            ),
          if (widget.artigo.codRfid != null)
            _buildInfoRow(
              Icons.contactless,
              'RFID',
              widget.artigo.codRfid!,
            ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.grey[600]),
          const SizedBox(width: 12),
          Text(
            '$label: ',
            style: TextStyle(
              fontSize: 14,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStockSection(double stock) {
    final cor = stock > 0 ? Colors.green : Colors.red;

    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: cor),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Stock Atual',
                style: TextStyle(
                  fontSize: 16,
                  color: Colors.grey[700],
                ),
              ),
              const SizedBox(height: 4),
              Text(
                stock.toStringAsFixed(2),
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: cor,
                ),
              ),
            ],
          ),
          Icon(
            stock > 0 ? Icons.check_circle : Icons.warning,
            size: 48,
            color: cor,
          ),
        ],
      ),
    );
  }

  Widget _buildEquipamentosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Text(
            'Equipamentos (${_equipamentos.length})',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _equipamentos.length,
          itemBuilder: (context, index) {
            final equip = _equipamentos[index];
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.devices, color: Colors.blue),
                title: Text(equip['Marca'] ?? 'Sem marca'),
                subtitle: Text(equip['Modelo'] ?? 'Sem modelo'),
                trailing: Text(
                  'S/N: ${equip['N_serie'] ?? 'N/A'}',
                  style: const TextStyle(fontSize: 12),
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _buildMovimentosSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Movimentos Recentes (${_movimentos.length})',
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              TextButton(
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Ver todos em desenvolvimento'),
                    ),
                  );
                },
                child: const Text('Ver Todos'),
              ),
            ],
          ),
        ),
        if (_movimentos.isEmpty)
          Padding(
            padding: const EdgeInsets.all(32),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.inbox_outlined, size: 64, color: Colors.grey[400]),
                  const SizedBox(height: 8),
                  Text(
                    'Sem movimentos registados',
                    style: TextStyle(color: Colors.grey[600]),
                  ),
                ],
              ),
            ),
          )
        else
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: _movimentos.length,
            itemBuilder: (context, index) {
              final mov = _movimentos[index];
              final entrada = (mov['Qtd_entrada'] ?? 0.0) as double;
              final saida = (mov['Qtd_saida'] ?? 0.0) as double;
              final data = mov['Data_mov'] as String;
              final isEntrada = entrada > 0;

              return Card(
                margin: const EdgeInsets.only(bottom: 8),
                child: ListTile(
                  leading: CircleAvatar(
                    backgroundColor: isEntrada ? Colors.green : Colors.red,
                    child: Icon(
                      isEntrada ? Icons.arrow_downward : Icons.arrow_upward,
                      color: Colors.white,
                    ),
                  ),
                  title: Text(
                    isEntrada
                        ? 'Entrada: ${entrada.toStringAsFixed(2)}'
                        : 'Saída: ${saida.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(_formatarData(data)),
                  trailing: Icon(
                    isEntrada ? Icons.add_circle : Icons.remove_circle,
                    color: isEntrada ? Colors.green : Colors.red,
                  ),
                ),
              );
            },
          ),
        const SizedBox(height: 80), // Espaço para FAB
      ],
    );
  }

  String _formatarData(String dataIso) {
    try {
      final data = DateTime.parse(dataIso);
      return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year} ${data.hour.toString().padLeft(2, '0')}:${data.minute.toString().padLeft(2, '0')}';
    } catch (e) {
      return dataIso;
    }
  }
}