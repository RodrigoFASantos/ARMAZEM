import 'package:flutter/material.dart';
import '../SERVICE/API.dart';
import '../SERVICE/database_helper.dart';
import '../models/models.dart';
import 'equipamento_detail_screen.dart';
import 'produto_detail_screen.dart';
import 'materia_prima_detail_screen.dart';
import 'home_screen.dart';

// Classe auxiliar para combinar Artigo com Equipamento e Armazém
class ArtigoComEquipamento {
  final Artigo artigo;
  final Equipamento? equipamento;
  final String? armazemNome;

  ArtigoComEquipamento({
    required this.artigo,
    this.equipamento,
    this.armazemNome,
  });
  
  /// Verifica se este item é um EQUIPAMENTO (tem registo na tabela EQUIPAMENTO)
  bool get isEquipamento => equipamento != null;
  
  /// Verifica se este item é um ARTIGO normal (não tem registo na tabela EQUIPAMENTO)
  bool get isArtigo => equipamento == null;
}

class ArmazemScreen extends StatefulWidget {
  const ArmazemScreen({super.key});

  @override
  State<ArmazemScreen> createState() => _ArmazemScreenState();
}

class _ArmazemScreenState extends State<ArmazemScreen> {
  final _apiService = ApiService();
  final _searchController = TextEditingController();
  
  List<ArtigoComEquipamento> _itens = [];
  List<ArtigoComEquipamento> _itensFiltrados = [];
  List<Estado> _estados = [];
  bool _isLoading = true;
  String? _errorMessage;
  String? _filtroAtivo;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      // Carregar artigos e equipamentos
      final artigos = await _apiService.getAllArtigos();
      final equipamentos = await _apiService.getAllEquipamentos();
      
      // Carregar estados da base de dados
      await _loadEstados();
      
      // Criar mapa de equipamentos por ID_artigo
      final equipamentosMap = <int, Equipamento>{};
      for (var equip in equipamentos) {
        equipamentosMap[equip.idArtigo] = equip;
      }
      
      // Combinar artigos com equipamentos E buscar armazém
      final itensCompletos = <ArtigoComEquipamento>[];
      
      for (var artigo in artigos) {
        // Buscar armazém do artigo
        String? armazemNome;
        
        // Primeiro tenta das localizações do artigo
        if (artigo.localizacoes != null && artigo.localizacoes!.isNotEmpty) {
          armazemNome = artigo.localizacoes!.first.armazem;
        } else {
          // Se não tem, busca do último movimento
          final armazemData = await DatabaseHelper.instance.getArmazemByArtigo(artigo.id);
          if (armazemData != null) {
            armazemNome = armazemData['Descricao'] as String?;
          }
        }
        
        itensCompletos.add(ArtigoComEquipamento(
          artigo: artigo,
          equipamento: equipamentosMap[artigo.id],
          armazemNome: armazemNome,
        ));
      }
      
      setState(() {
        _itens = itensCompletos;
        _itensFiltrados = itensCompletos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar dados: $e';
        _isLoading = false;
      });
    }
  }

  Future<void> _loadEstados() async {
    try {
      final db = await DatabaseHelper.instance.database;
      final results = await db.query('ESTADO');
      
      _estados = results.map((row) => Estado.fromJson(row)).toList();
      print(' ${_estados.length} estados carregados');
    } catch (e) {
      print('Erro ao carregar estados: $e');
      _estados = [];
    }
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _itensFiltrados = _itens;
        _filtroAtivo = null;
      } else {
        _itensFiltrados = _itens.where((item) {
          // Para equipamentos, pesquisa no design; para artigos, pesquisa na designação
          final nome = item.isEquipamento 
              ? (item.artigo.designacao).toLowerCase()
              : item.artigo.designacao.toLowerCase();
          final referencia = (item.artigo.referencia ?? '').toLowerCase();
          final armazem = (item.armazemNome ?? '').toLowerCase();
          final searchLower = query.toLowerCase();
          
          return nome.contains(searchLower) || 
                 referencia.contains(searchLower) ||
                 armazem.contains(searchLower);
        }).toList();
        _filtroAtivo = 'Pesquisa: "$query"';
      }
    });
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.7,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Filtros',
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    if (_filtroAtivo != null)
                      TextButton.icon(
                        onPressed: () {
                          Navigator.pop(context);
                          _clearFilters();
                        },
                        icon: const Icon(Icons.clear, size: 18),
                        label: const Text('Limpar'),
                        style: TextButton.styleFrom(
                          foregroundColor: Colors.red,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
                
                if (_filtroAtivo != null)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.blue[50],
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: Colors.blue[200]!),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.filter_alt, color: Colors.blue, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Filtro ativo: $_filtroAtivo',
                            style: const TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                
                const SizedBox(height: 16),
                const Divider(),
                const Text(
                  'Estado do Equipamento',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.grey,
                  ),
                ),
                const SizedBox(height: 8),
                
                ..._buildEstadoFilterOptions(),
              ],
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildEstadoFilterOptions() {
    if (_estados.isEmpty) {
      return [
        const ListTile(
          leading: Icon(Icons.warning, color: Colors.orange),
          title: Text('Nenhum estado encontrado'),
          subtitle: Text('Sincronize os dados primeiro'),
        ),
      ];
    }
    
    return _estados.map((estado) {
      final colorInfo = _getEstadoColorInfo(estado.id);
      
      return ListTile(
        leading: Icon(Icons.circle, color: colorInfo['color'] as Color),
        title: Text(estado.designacao),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {
          Navigator.pop(context);
          _filterByEstado(estado.id, estado.designacao);
        },
      );
    }).toList();
  }

  /// Retorna cor e ícone baseado no ID_Estado
  Map<String, dynamic> _getEstadoColorInfo(int idEstado) {
    switch (idEstado) {
      case 1: // Operacional
        return {'color': Colors.green, 'icon': Icons.check_circle};
      case 2: // Em Manutenção
        return {'color': Colors.orange, 'icon': Icons.build};
      case 3: // Não Operacional
        return {'color': Colors.red, 'icon': Icons.cancel};
      default:
        return {'color': Colors.grey, 'icon': Icons.help};
    }
  }

  void _filterByEstado(int idEstado, String nomeEstado) {
    setState(() {
      _itensFiltrados = _itens.where((item) {
        return item.equipamento != null && item.equipamento!.idEstado == idEstado;
      }).toList();
      _filtroAtivo = nomeEstado;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('${_itensFiltrados.length} equipamentos "$nomeEstado"'),
        duration: const Duration(seconds: 2),
        action: SnackBarAction(
          label: 'Limpar',
          onPressed: _clearFilters,
        ),
      ),
    );
  }

  void _clearFilters() {
    setState(() {
      _itensFiltrados = _itens;
      _searchController.clear();
      _filtroAtivo = null;
    });
    
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Filtros limpos'),
        duration: Duration(seconds: 1),
      ),
    );
  }

  /// =========================================================================
  /// NAVEGAÇÃO CORRIGIDA
  /// =========================================================================
  /// PRIORIDADE 1: Se tem registo na tabela EQUIPAMENTO → EquipamentoDetailScreen
  /// PRIORIDADE 2: Se é ARTIGO (sem equipamento):
  ///   - ID_Tipo = 1 → MateriaPrimaDetailScreen
  ///   - ID_Tipo = 2 → ProdutoDetailScreen
  /// =========================================================================
  void _onItemTap(ArtigoComEquipamento item) {
    // PRIORIDADE 1: Verificar se é EQUIPAMENTO
    if (item.isEquipamento) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EquipamentoDetailScreen(
            artigo: item.artigo,
            equipamento: item.equipamento,
          ),
        ),
      );
      return;
    }
    
    // PRIORIDADE 2: É um ARTIGO normal - verificar ID_Tipo
    final idTipo = item.artigo.idTipo;
    
    if (idTipo == 1) {
      // Matéria-Prima
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MateriaPrimaDetailScreen(
            artigo: item.artigo,
          ),
        ),
      );
      return;
    }
    
    if (idTipo == 2) {
      // Produto Final
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProdutoDetailScreen(
            artigo: item.artigo,
          ),
        ),
      );
      return;
    }
    
    // FALLBACK: Se não tem ID_Tipo definido, usa designação
    final tipo = item.artigo.tipo?.designacao.toLowerCase() ?? '';
    
    if (tipo.contains('produto') || tipo.contains('final')) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => ProdutoDetailScreen(
            artigo: item.artigo,
          ),
        ),
      );
    } else {
      // Default: Matéria-Prima
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => MateriaPrimaDetailScreen(
            artigo: item.artigo,
          ),
        ),
      );
    }
  }

  void _handleBottomNavigation(int index) {
    if (index == 1) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const HomeScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        actions: [
          if (_filtroAtivo != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                label: Text(
                  _filtroAtivo!,
                  style: const TextStyle(fontSize: 12),
                ),
                deleteIcon: const Icon(Icons.close, size: 16),
                onDeleted: _clearFilters,
                backgroundColor: Colors.blue[100],
              ),
            ),
          IconButton(
            icon: Badge(
              isLabelVisible: _filtroAtivo != null,
              child: const Icon(Icons.filter_list),
            ),
            onPressed: _showFilters,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadData,
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Barra de pesquisa
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Pesquisar artigo...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear),
                          onPressed: () {
                            _searchController.clear();
                            _onSearch('');
                          },
                        )
                      : null,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  filled: true,
                  fillColor: Colors.grey[100],
                ),
                onChanged: _onSearch,
              ),
            ),
            
            // Contador de resultados
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Text(
                    '${_itensFiltrados.length} de ${_itens.length} itens',
                    style: TextStyle(
                      color: Colors.grey[600],
                      fontSize: 13,
                    ),
                  ),
                  const Spacer(),
                  if (_estados.isNotEmpty)
                    Text(
                      '${_estados.length} estados',
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 12,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            
            // Lista de itens
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.error_outline,
                                  size: 64, color: Colors.red[300]),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.red[700]),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: _loadData,
                                icon: const Icon(Icons.refresh),
                                label: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        )
                      : _itensFiltrados.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.search_off,
                                      size: 64, color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    _filtroAtivo != null
                                        ? 'Nenhum item encontrado com filtro "$_filtroAtivo"'
                                        : 'Nenhum item encontrado',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                  if (_filtroAtivo != null)
                                    TextButton(
                                      onPressed: _clearFilters,
                                      child: const Text('Limpar filtros'),
                                    ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadData,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: _itensFiltrados.length,
                                itemBuilder: (context, index) {
                                  final item = _itensFiltrados[index];
                                  return _buildItemCard(item);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
      
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 0,
        onTap: _handleBottomNavigation,
        selectedItemColor: Colors.blue,
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.warehouse, size: 28),
            label: 'Armazém',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt, size: 28),
            label: 'Câmara',
          ),
        ],
      ),
    );
  }

  /// =========================================================================
  /// CARD DO ITEM
  /// =========================================================================
  /// EQUIPAMENTOS: Cores baseadas no ID_Estado (Verde/Amarelo/Vermelho)
  /// ARTIGOS: Sem cores (fundo cinzento neutro)
  /// =========================================================================
  Widget _buildItemCard(ArtigoComEquipamento item) {
    Color backgroundColor;
    Color borderColor;
    
    if (item.isEquipamento) {
      // =====================================================================
      // É EQUIPAMENTO - Cor baseada no ID_Estado
      // =====================================================================
      final idEstado = item.equipamento!.idEstado;
      
      switch (idEstado) {
        case 1: // Operacional - VERDE
          backgroundColor = Colors.green[50]!;
          borderColor = Colors.green[400]!;
          break;
        case 2: // Em Manutenção - AMARELO
          backgroundColor = Colors.yellow[50]!;
          borderColor = Colors.yellow[700]!;
          break;
        case 3: // Não Operacional - VERMELHO
          backgroundColor = Colors.red[50]!;
          borderColor = Colors.red[400]!;
          break;
        default:
          backgroundColor = Colors.grey[100]!;
          borderColor = Colors.grey[400]!;
      }
    } else {
      // =====================================================================
      // É ARTIGO - Sem cores (fundo cinzento neutro)
      // =====================================================================
      backgroundColor = Colors.grey[50]!;
      borderColor = Colors.grey[300]!;
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: backgroundColor,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor, width: 1.5),
      ),
      child: InkWell(
        onTap: () => _onItemTap(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Ícone ou imagem
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: item.artigo.imagem != null && item.artigo.imagem!.isNotEmpty
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          item.artigo.imagem!,
                          fit: BoxFit.cover,
                          errorBuilder: (context, error, stackTrace) {
                            return _getItemIcon(item);
                          },
                        ),
                      )
                    : _getItemIcon(item),
              ),
              
              const SizedBox(width: 12),
              
              // Informações do item
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome do item:
                    // - EQUIPAMENTO: usa equipamento.design (fallback para artigo.designacao)
                    // - ARTIGO: usa artigo.designacao
                    Text(
                      item.isEquipamento 
                          ? (item.artigo.designacao)
                          : item.artigo.designacao,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Referência
                    if (item.artigo.referencia != null && item.artigo.referencia!.isNotEmpty)
                      Text(
                        'Ref: ${item.artigo.referencia}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    
                    // Badge de tipo/estado
                    const SizedBox(height: 4),
                    _buildBadge(item),
                    
                    // Família
                    if (item.artigo.familia != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          'Família: ${item.artigo.familia!.designacao}',
                          style: TextStyle(
                            fontSize: 12,
                            color: Colors.grey[600],
                          ),
                        ),
                      ),
                    
                    // Armazém
                    if (item.armazemNome != null && item.armazemNome!.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Row(
                          children: [
                            Icon(Icons.warehouse, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Text(
                              item.armazemNome!,
                              style: TextStyle(
                                fontSize: 12,
                                color: Colors.grey[600],
                              ),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// =========================================================================
  /// BADGE DO ITEM
  /// =========================================================================
  /// EQUIPAMENTOS: Badge com estado (Operacional/Manutenção/Não Operacional)
  /// ARTIGOS: Badge com tipo (Matéria-Prima/Produto Final)
  /// =========================================================================
  Widget _buildBadge(ArtigoComEquipamento item) {
    String texto;
    Color corFundo;
    Color corTexto;
    
    if (item.isEquipamento) {
      // Badge de ESTADO do equipamento
      final idEstado = item.equipamento!.idEstado;
      
      switch (idEstado) {
        case 1:
          texto = 'Operacional';
          corFundo = Colors.green[100]!;
          corTexto = Colors.green[800]!;
          break;
        case 2:
          texto = 'Em Manutenção';
          corFundo = Colors.yellow[100]!;
          corTexto = Colors.yellow[900]!;
          break;
        case 3:
          texto = 'Não Operacional';
          corFundo = Colors.red[100]!;
          corTexto = Colors.red[800]!;
          break;
        default:
          texto = item.equipamento!.estadoDesignacao ?? 'Equipamento';
          corFundo = Colors.grey[200]!;
          corTexto = Colors.grey[800]!;
      }
    } else {
      // Badge de TIPO do artigo
      final idTipo = item.artigo.idTipo;
      
      if (idTipo == 1) {
        texto = 'Matéria-Prima';
        corFundo = Colors.blue[100]!;
        corTexto = Colors.blue[800]!;
      } else if (idTipo == 2) {
        texto = 'Produto Final';
        corFundo = Colors.purple[100]!;
        corTexto = Colors.purple[800]!;
      } else {
        texto = item.artigo.tipo?.designacao ?? 'Artigo';
        corFundo = Colors.grey[200]!;
        corTexto = Colors.grey[800]!;
      }
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: corFundo,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        texto,
        style: TextStyle(
          fontSize: 11,
          color: corTexto,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  /// =========================================================================
  /// ÍCONE DO ITEM
  /// =========================================================================
  Widget _getItemIcon(ArtigoComEquipamento item) {
    IconData icon;
    Color color;
    
    if (item.isEquipamento) {
      // Ícone de equipamento com cor do estado
      icon = Icons.build;
      final idEstado = item.equipamento!.idEstado;
      
      switch (idEstado) {
        case 1:
          color = Colors.green[700]!;
          break;
        case 2:
          color = Colors.orange[700]!;
          break;
        case 3:
          color = Colors.red[700]!;
          break;
        default:
          color = Colors.grey[700]!;
      }
    } else {
      // Ícone de artigo
      final idTipo = item.artigo.idTipo;
      
      if (idTipo == 1) {
        icon = Icons.inventory_2;
        color = Colors.blue[700]!;
      } else if (idTipo == 2) {
        icon = Icons.shopping_bag;
        color = Colors.purple[700]!;
      } else {
        icon = Icons.category;
        color = Colors.grey[700]!;
      }
    }
    
    return Center(child: Icon(icon, size: 32, color: color));
  }
}