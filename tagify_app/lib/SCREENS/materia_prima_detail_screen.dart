import 'package:flutter/material.dart';
import '../models/models.dart';
import '../SERVICE/database_helper.dart';

class MateriaPrimaDetailScreen extends StatefulWidget {
  final Artigo artigo;

  const MateriaPrimaDetailScreen({
    super.key,
    required this.artigo,
  });

  @override
  State<MateriaPrimaDetailScreen> createState() => _MateriaPrimaDetailScreenState();
}

class _MateriaPrimaDetailScreenState extends State<MateriaPrimaDetailScreen> {
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
      
      // Buscar movimentos do artigo para encontrar armazém, localização e stock
      final movimentos = await db.getMovimentosByArtigo(widget.artigo.id);
      
      if (movimentos.isNotEmpty) {
        // Calcular stock total
        double entradas = 0;
        double saidas = 0;
        
        for (var mov in movimentos) {
          entradas += (mov['Qtd_entrada'] ?? 0).toDouble();
          saidas += (mov['Qtd_saida'] ?? 0).toDouble();
        }
        
        _stockTotal = entradas - saidas;
        
        // Último movimento tem a localização atual
        _ultimoMovimento = Movimento.fromJson(movimentos.first);
        
        // Buscar dados do armazém
        final armazemData = await db.getArmazemById(_ultimoMovimento!.idArmazem);
        if (armazemData != null) {
          _armazem = Armazem.fromJson(armazemData);
        }
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      print('Erro ao carregar dados: $e');
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('MATÉRIA-PRIMA'),
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

                  // Card 1: Informações principais
                  _buildInfoCard(
                    context,
                    [
                      _buildInfoRow('Nome', widget.artigo.designacao),
                      _buildInfoRow('Categoria', widget.artigo.familia?.designacao ?? 'N/A'),
                      _buildInfoRow('Tipo', widget.artigo.tipo?.designacao ?? 'N/A'),
                      _buildInfoRow('Referência', widget.artigo.referencia ?? 'N/A'),
                      _buildInfoRow('Stock', _stockTotal.toStringAsFixed(0)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // Card 2: Localização (dados do MOVIMENTO)
                  _buildInfoCard(
                    context,
                    [
                      _buildInfoRow('Armazém', _armazem?.descricao ?? 'N/A'),
                      _buildInfoRow('Rack', _ultimoMovimento?.rackDisplay ?? 'N/A'),
                      _buildInfoRow('Prateleira', _ultimoMovimento?.prateleiraDisplay ?? 'N/A'),
                      _buildInfoRow('Corredor', _ultimoMovimento?.corredorDisplay ?? 'N/A'),
                      _buildInfoRow('Zona', _ultimoMovimento?.zonaDisplay ?? 'N/A'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  


                  // Imagem (apenas se existir)
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
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.image_not_supported, 
                                         size: 48, color: Colors.grey[400]),
                                    const SizedBox(height: 8),
                                    Text('Imagem não disponível',
                                         style: TextStyle(color: Colors.grey[500])),
                                  ],
                                ),
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

  Widget _buildInfoCard(BuildContext context, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
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
        children: children,
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: const TextStyle(
                fontSize: 14,
                color: Colors.black54,
              ),
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
}