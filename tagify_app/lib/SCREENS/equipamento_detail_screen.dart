import 'package:flutter/material.dart';
import '../models/models.dart';
import '../SERVICE/database_helper.dart';

class EquipamentoDetailScreen extends StatefulWidget {
  final Artigo artigo;
  final Equipamento? equipamento;

  const EquipamentoDetailScreen({
    super.key,
    required this.artigo,
    this.equipamento,
  });

  @override
  State<EquipamentoDetailScreen> createState() => _EquipamentoDetailScreenState();
}

class _EquipamentoDetailScreenState extends State<EquipamentoDetailScreen> {
  Armazem? _armazem;
  Movimento? _ultimoMovimento;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _carregarDados();
  }

  Future<void> _carregarDados() async {
    try {
      final db = DatabaseHelper.instance;
      
      // Buscar movimentos do artigo para obter localização detalhada
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
        title: const Text('EQUIPAMENTO'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // Estado (badge colorido)
                  if (widget.equipamento?.estadoDesignacao != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          color: _getEstadoColor(widget.equipamento!.estadoDesignacao!),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          widget.equipamento!.estadoDesignacao!,
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
                      _buildInfoRow('Marca', widget.equipamento?.marca ?? 'N/A'),
                      _buildInfoRow('Modelo', widget.equipamento?.modelo ?? 'N/A'),
                      _buildInfoRow('Nº Série', widget.equipamento?.nSerie ?? 'N/A'),
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

                  // Card 3: Manutenção (se aplicável)
                  if (widget.equipamento?.requerInspecao == true)
                    _buildInfoCard(
                      'Manutenção',
                      [
                        _buildInfoRow('Próxima', _formatarData(widget.equipamento?.proximaInspecao)),
                        _buildInfoRow('Última', _formatarData(widget.equipamento?.dataAquisicao)),
                        _buildInfoRow('Ciclo', '${widget.equipamento?.cicloInspecaoDias ?? 0} dias'),
                      ],
                    ),

                  const SizedBox(height: 16),

                  // Card 4: Códigos
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
                ],
              ),
            ),
    );
  }

  Color _getEstadoColor(String estado) {
    final estadoLower = estado.toLowerCase();
    if (estadoLower.contains('operacional') || estadoLower.contains('ativo') || estadoLower.contains('bom')) {
      return Colors.green;
    } else if (estadoLower.contains('manutenção') || estadoLower.contains('manutencao') || estadoLower.contains('revisão')) {
      return Colors.orange;
    } else if (estadoLower.contains('avariado') || estadoLower.contains('danificado') || estadoLower.contains('inativo')) {
      return Colors.red;
    }
    return Colors.blue;
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
            width: 100,
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