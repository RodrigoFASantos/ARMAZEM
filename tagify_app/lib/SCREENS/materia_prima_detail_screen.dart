import 'package:flutter/material.dart';
import '../models/models.dart';
import '../SERVICE/database_helper.dart';

/// =============================================================================
/// ECRÃ DE DETALHE DE MATÉRIA-PRIMA
/// =============================================================================
/// Este ecrã mostra toda a informação duma matéria-prima específica.
/// Carrega os dados do armazém e localização a partir dos movimentos.
/// O stock é calculado somando entradas e subtraindo saídas de todos os movimentos.
/// =============================================================================
class MateriaPrimaDetailScreen extends StatefulWidget {
  /// O artigo associado à matéria-prima (contém designação, códigos, etc.)
  final Artigo artigo;

  const MateriaPrimaDetailScreen({
    super.key,
    required this.artigo,
  });

  @override
  State<MateriaPrimaDetailScreen> createState() => _MateriaPrimaDetailScreenState();
}

class _MateriaPrimaDetailScreenState extends State<MateriaPrimaDetailScreen> {
  /// Armazém onde está a matéria-prima (carregado da BD)
  Armazem? _armazem;
  
  /// Último movimento da matéria-prima (tem a localização atual)
  Movimento? _ultimoMovimento;
  
  /// Flag pra saber se ainda está a carregar dados
  bool _isLoading = true;
  
  /// Stock total (soma das entradas menos saídas)
  double _stockTotal = 0;

  @override
  void initState() {
    super.initState();
    // Mal o widget arranca, vai buscar os dados à BD
    _carregarDados();
  }

  /// =========================================================================
  /// CARREGAR DADOS
  /// =========================================================================
  /// Vai buscar os movimentos do artigo pra calcular stock e localização.
  /// Percorre todos os movimentos e soma entradas/saídas.
  /// O último movimento tem a localização atual (armazém, rack, prateleira, etc.)
  /// =========================================================================
  Future<void> _carregarDados() async {
    try {
      final db = DatabaseHelper.instance;
      
      // Buscar movimentos do artigo pra encontrar armazém, localização e stock
      final movimentos = await db.getMovimentosByArtigo(widget.artigo.id);
      
      if (movimentos.isNotEmpty) {
        // Calcular stock total percorrendo todos os movimentos
        double entradas = 0;
        double saidas = 0;
        
        for (var mov in movimentos) {
          entradas += (mov['Qtd_entrada'] ?? 0).toDouble();
          saidas += (mov['Qtd_saida'] ?? 0).toDouble();
        }
        
        _stockTotal = entradas - saidas;
        
        // O último movimento (mais recente) tem a localização atual
        _ultimoMovimento = Movimento.fromJson(movimentos.first);
        
        // Buscar dados do armazém pelo ID
        final armazemData = await db.getArmazemById(_ultimoMovimento!.idArmazem);
        if (armazemData != null) {
          _armazem = Armazem.fromJson(armazemData);
        }
      }
      
      // Dados carregados, atualiza o ecrã
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      // Se der erro, mostra na consola e para o loading
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
      
      // AppBar cinzento claro como pedido
      appBar: AppBar(
        title: const Text(
          'MATÉRIA-PRIMA',
          style: TextStyle(
            color: Colors.black87,
            fontWeight: FontWeight.bold,
          ),
        ),
        backgroundColor: Colors.grey[200], // Cinzento quase branco
        foregroundColor: Colors.black87,   // Ícones e texto escuros
        centerTitle: true,
        elevation: 1, // Sombra suave pra destacar
      ),
      
      // Corpo do ecrã
      body: _isLoading
          // Se ainda está a carregar, mostra spinner
          ? const Center(child: CircularProgressIndicator())
          // Se já carregou, mostra o conteúdo
          : SingleChildScrollView(
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // =========================================================
                  // CARD 1: INFORMAÇÕES PRINCIPAIS
                  // =========================================================
                  _buildInfoCard(
                    context,
                    [
                      _buildInfoRow('Nome', widget.artigo.designacao),
                      _buildInfoRow('Referência', widget.artigo.referencia ?? 'N/A'),
                      _buildInfoRow('Stock', _stockTotal.toStringAsFixed(0)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // =========================================================
                  // CARD 2: LOCALIZAÇÃO
                  // =========================================================
                  // Dados vêm do último movimento na BD
                  // =========================================================
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

                  // =========================================================
                  // IMAGEM DA MATÉRIA-PRIMA (se existir)
                  // =========================================================
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
                            // Se a imagem não carregar, mostra ícone de erro
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

  /// =========================================================================
  /// CONSTRUIR CARD DE INFORMAÇÃO
  /// =========================================================================
  /// Cria um card bonito com lista de informações.
  /// Usado pra agrupar dados relacionados (info, localização, etc.)
  /// =========================================================================
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

  /// =========================================================================
  /// CONSTRUIR LINHA DE INFORMAÇÃO
  /// =========================================================================
  /// Cria uma linha com label à esquerda e valor à direita.
  /// Formato: "Label          Valor"
  /// =========================================================================
  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          // Label (largura fixa pra alinhar tudo)
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
          // Valor (ocupa o resto do espaço)
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