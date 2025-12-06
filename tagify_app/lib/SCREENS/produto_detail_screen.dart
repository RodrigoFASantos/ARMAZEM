import 'package:flutter/material.dart';
import '../models/models.dart';
import '../SERVICE/database_helper.dart';

class ProdutoDetailScreen extends StatefulWidget {
  final Artigo artigo;
  final DateTime? dataProduzido;

  const ProdutoDetailScreen({
    super.key,
    required this.artigo,
    this.dataProduzido,
  });

  @override
  State<ProdutoDetailScreen> createState() => _ProdutoDetailScreenState();
}

class _ProdutoDetailScreenState extends State<ProdutoDetailScreen> {
  Armazem? _armazem;
  Movimento? _ultimoMovimento;
  bool _isLoading = true;
  double _stockTotal = 0;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final db = DatabaseHelper.instance;
      
      // Buscar stock total
      _stockTotal = await db.getStockByArtigo(widget.artigo.id);
      
      // Buscar movimentos para obter localização detalhada
      final movimentos = await db.getMovimentosByArtigo(widget.artigo.id);
      
      if (movimentos.isNotEmpty) {
        // Último movimento tem a localização atual
        _ultimoMovimento = Movimento.fromJson(movimentos.first);
        
        // Buscar dados do armazém
        final armazemData = await db.getArmazemById(_ultimoMovimento!.idArmazem);
        if (armazemData != null) {
          _armazem = Armazem.fromJson(armazemData);
        }
      }
      
      setState(() => _isLoading = false);
    } catch (e) {
      print('Erro ao carregar dados: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('PRODUTO'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Tipo/Estado (badge)
                  if (widget.artigo.tipo?.designacao != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.artigo.tipo!.designacao,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 16),

                  // Card 1: Informações principais
                  _buildInfoCard(
                    'Informações',
                    [
                      _buildInfoRow('Nome', widget.artigo.designacao),
                      _buildInfoRow('Categoria', widget.artigo.familia?.designacao ?? 'N/A'),
                      _buildInfoRow('Tipo', widget.artigo.tipo?.designacao ?? 'N/A'),
                      _buildInfoRow('Referência', widget.artigo.referencia ?? 'N/A'),
                      _buildInfoRow('Stock', _stockTotal.toStringAsFixed(0)),
                      _buildInfoRow('Produzido em', _formatarData(widget.dataProduzido)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Card 2: Localização (dados do MOVIMENTO)
                  _buildInfoCard(
                    'Localização',
                    [
                      _buildInfoRow('Armazém', _armazem?.descricao ?? 'N/A'),
                      _buildInfoRow('Rack', _ultimoMovimento?.rackDisplay ?? 'N/A'),
                      _buildInfoRow('Prateleira', _ultimoMovimento?.prateleiraDisplay ?? 'N/A'),
                      _buildInfoRow('Corredor', _ultimoMovimento?.corredorDisplay ?? 'N/A'),
                      _buildInfoRow('Zona', _ultimoMovimento?.zonaDisplay ?? 'N/A'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Card 3: Códigos
                  _buildInfoCard(
                    'Códigos',
                    [
                      _buildInfoRow('Cód. Barras', widget.artigo.codBar ?? 'N/A'),
                      _buildInfoRow('Cód. NFC', widget.artigo.codNfc ?? 'N/A'),
                      _buildInfoRow('Cód. RFID', widget.artigo.codRfid ?? 'N/A'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Imagem
                  if (widget.artigo.imagem != null && widget.artigo.imagem!.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        width: double.infinity,
                        height: 250,
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: Colors.grey[300]!),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            widget.artigo.imagem!,
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              return Center(
                                child: Icon(Icons.image_not_supported,
                                    size: 48, color: Colors.grey[400]),
                              );
                            },
                          ),
                        ),
                      ),
                    ),

                  const SizedBox(height: 24),
                ],
              ),
            ),
    );
  }

  Widget _buildInfoCard(String titulo, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12),
                topRight: Radius.circular(12),
              ),
            ),
            child: Text(
              titulo,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.bold,
                color: Colors.black54,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
          Expanded(
            child: Text(
              value,
              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }

  String _formatarData(DateTime? data) {
    if (data == null) return 'N/A';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }
}