import 'package:flutter/material.dart';
import '../models/models.dart';
import '../SERVICE/database_helper.dart';

/// =============================================================================
/// ECRÃ DE DETALHE DE EQUIPAMENTO
/// =============================================================================
/// Este ecrã mostra toda a informação dum equipamento específico.
/// Carrega os dados do armazém e localização a partir dos movimentos.
/// O estado do equipamento aparece com cores baseadas no ID_Estado:
///   - ID_Estado = 1: Verde (Operacional)
///   - ID_Estado = 2: Amarelo/Laranja (Em Manutenção)
///   - ID_Estado = 3: Vermelho (Não Operacional)
/// =============================================================================
class EquipamentoDetailScreen extends StatefulWidget {
  /// O artigo associado ao equipamento (contém designação, códigos, etc.)
  final Artigo artigo;
  
  /// O equipamento em si (pode ser null se não houver dados específicos)
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
  /// Armazém onde está o equipamento (carregado da BD)
  Armazem? _armazem;
  
  /// Último movimento do equipamento (tem a localização atual)
  Movimento? _ultimoMovimento;
  
  /// Flag pra saber se ainda está a carregar dados
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    // Mal o widget arranca, vai buscar os dados à BD
    _carregarDados();
  }

  /// =========================================================================
  /// CARREGAR DADOS
  /// =========================================================================
  /// Vai buscar os movimentos do artigo pra saber onde está o equipamento.
  /// O último movimento tem a localização atual (armazém, rack, prateleira, etc.)
  /// =========================================================================
  Future<void> _carregarDados() async {
    try {
      final db = DatabaseHelper.instance;
      
      // Buscar movimentos do artigo pra obter localização detalhada
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
          'EQUIPAMENTO',
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
              padding: const EdgeInsets.only(bottom: 24),
              child: Column(
                children: [
                  const SizedBox(height: 16),

                  // =========================================================
                  // BADGE DO ESTADO
                  // =========================================================
                  // Mostra o estado do equipamento com cor baseada no ID_Estado
                  // =========================================================
                  if (widget.equipamento != null)
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        decoration: BoxDecoration(
                          // Cor depende do ID_Estado
                          color: _getEstadoColorById(widget.equipamento!.idEstado),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          _getEstadoNome(widget.equipamento!.idEstado),
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
                      _buildInfoRow('Categoria', widget.artigo.familia?.designacao ?? 'N/A'),
                      _buildInfoRow('Marca', widget.equipamento?.marca ?? 'N/A'),
                      _buildInfoRow('Modelo', widget.equipamento?.modelo ?? 'N/A'),
                      _buildInfoRow('Nº Série', widget.equipamento?.nSerie ?? 'N/A'),
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
                  // CARD 3: MANUTENÇÃO (só aparece se equipamento requer)
                  // =========================================================
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

                  // =========================================================
                  // CARD 4: CÓDIGOS DE IDENTIFICAÇÃO
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
                  // IMAGEM DO EQUIPAMENTO (se existir)
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
                ],
              ),
            ),
    );
  }

  /// =========================================================================
  /// OBTER COR DO ESTADO POR ID
  /// =========================================================================
  /// Retorna a cor apropriada baseada no ID_Estado:
  ///   - 1: Verde (Operacional)
  ///   - 2: Laranja (Em Manutenção)
  ///   - 3: Vermelho (Não Operacional)
  /// =========================================================================
  Color _getEstadoColorById(int? idEstado) {
    switch (idEstado) {
      case 1: // Operacional
        return Colors.green;
      case 2: // Em Manutenção
        return Colors.orange;
      case 3: // Não Operacional
        return Colors.red;
      default:
        return Colors.grey;
    }
  }

  /// =========================================================================
  /// OBTER NOME DO ESTADO
  /// =========================================================================
  /// Retorna o nome do estado. Usa a designação do equipamento se disponível,
  /// caso contrário usa o nome padrão baseado no ID.
  /// =========================================================================
  String _getEstadoNome(int? idEstado) {
    // Se tem designação do equipamento, usa ela
    if (widget.equipamento?.estadoDesignacao != null) {
      return widget.equipamento!.estadoDesignacao!;
    }
    
    // Caso contrário, usa nome padrão
    switch (idEstado) {
      case 1:
        return 'Operacional';
      case 2:
        return 'Em Manutenção';
      case 3:
        return 'Não Operacional';
      default:
        return 'Desconhecido';
    }
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
            width: 100,
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