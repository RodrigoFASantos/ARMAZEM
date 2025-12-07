import 'package:flutter/material.dart';
import '../models/models.dart';
import '../SERVICE/database_helper.dart';

/// =============================================================================
/// ECRÃ DE DETALHE DE PRODUTO
/// =============================================================================
/// Este ecrã mostra toda a informação dum produto acabado.
/// Carrega os dados do armazém e localização a partir dos movimentos.
/// Mostra também o stock total calculado dos movimentos (entradas - saídas).
/// =============================================================================
class ProdutoDetailScreen extends StatefulWidget {
  /// O artigo associado ao produto (contém designação, códigos, etc.)
  final Artigo artigo;
  
  /// Data de produção (opcional, pode vir de fora)
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
  /// Armazém onde está o produto (carregado da BD)
  Armazem? _armazem;
  
  /// Último movimento do produto (tem a localização atual)
  Movimento? _ultimoMovimento;
  
  /// Flag pra saber se ainda está a carregar dados
  bool _isLoading = true;
  
  /// Stock total do produto (soma das entradas menos saídas)
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
  /// Vai buscar o stock e os movimentos do artigo.
  /// O último movimento tem a localização atual (armazém, rack, prateleira, etc.)
  /// =========================================================================
  Future<void> _carregarDados() async {
    try {
      final db = DatabaseHelper.instance;
      
      // Buscar stock total (calcula entradas - saídas)
      _stockTotal = await db.getStockByArtigo(widget.artigo.id);
      
      // Buscar movimentos pra obter localização detalhada
      final movimentos = await db.getMovimentosByArtigo(widget.artigo.id);
      
      if (movimentos.isNotEmpty) {
        // O último movimento (mais recente) tem a localização atual
        _ultimoMovimento = Movimento.fromJson(movimentos.first);
        
        // Buscar dados do armazém pelo ID
        final armazemData = await db.getArmazemById(_ultimoMovimento!.idArmazem);
        if (armazemData != null) {
          _armazem = Armazem.fromJson(armazemData);
        }
      }
      
      // Dados carregados, atualiza o ecrã
      setState(() => _isLoading = false);
    } catch (e) {
      // Se der erro, mostra na consola e para o loading
      print('Erro ao carregar dados: $e');
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      
      // AppBar cinzento claro como pedido
      appBar: AppBar(
        title: const Text(
          'PRODUTO FINAL',
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
                  // BADGE DO TIPO (se existir)
                  // =========================================================
                  // Mostra o tipo do produto com fundo verde
                  // =========================================================
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

                  // =========================================================
                  // CARD 1: INFORMAÇÕES PRINCIPAIS
                  // =========================================================
                  _buildInfoCard(
                    'Informações',
                    [
                      _buildInfoRow('Nome', widget.artigo.designacao),
                      _buildInfoRow('Referência', widget.artigo.referencia ?? 'N/A'),
                      _buildInfoRow('Stock', _stockTotal.toStringAsFixed(0)),
                      _buildInfoRow('Produzido em', _formatarData(widget.dataProduzido)),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // =========================================================
                  // CARD 2: LOCALIZAÇÃO
                  // =========================================================
                  // Dados vêm do último movimento na BD
                  // =========================================================
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

                  // =========================================================
                  // CARD 3: CÓDIGOS DE IDENTIFICAÇÃO
                  // =========================================================
                  _buildInfoCard(
                    'Códigos',
                    [
                      _buildInfoRow('Cód. Barras', widget.artigo.codBar ?? 'N/A'),
                      _buildInfoRow('Cód. NFC', widget.artigo.codNfc ?? 'N/A'),
                      _buildInfoRow('Cód. RFID', widget.artigo.codRfid ?? 'N/A'),
                    ],
                  ),

                  const SizedBox(height: 16),

                  // =========================================================
                  // IMAGEM DO PRODUTO (se existir)
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

  /// =========================================================================
  /// CONSTRUIR CARD DE INFORMAÇÃO
  /// =========================================================================
  /// Cria um card bonito com título e lista de informações.
  /// Usado pra agrupar dados relacionados (info, localização, códigos, etc.)
  /// =========================================================================
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
          // Cabeçalho do card com o título
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
          // Conteúdo do card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: children),
          ),
        ],
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
            width: 110,
            child: Text(
              label,
              style: const TextStyle(fontSize: 14, color: Colors.black54),
            ),
          ),
          // Valor (ocupa o resto do espaço)
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

  /// =========================================================================
  /// FORMATAR DATA
  /// =========================================================================
  /// Converte DateTime pra string no formato DD/MM/AAAA.
  /// Se a data for null, retorna 'N/A'.
  /// =========================================================================
  String _formatarData(DateTime? data) {
    if (data == null) return 'N/A';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }
}