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
  final String? armazemNome; // ✅ NOVO: Armazém do artigo

  ArtigoComEquipamento({
    required this.artigo,
    this.equipamento,
    this.armazemNome,
  });
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
      
      // ✅ Combinar artigos com equipamentos E buscar armazém
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
      print('✅ ${_estados.length} estados carregados');
    } catch (e) {
      print('⚠️ Erro ao carregar estados: $e');
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
          final designacao = item.artigo.designacao.toLowerCase();
          final referencia = (item.artigo.referencia ?? '').toLowerCase();
          final armazem = (item.armazemNome ?? '').toLowerCase();
          final searchLower = query.toLowerCase();
          
          return designacao.contains(searchLower) || 
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
      final colorInfo = _getEstadoColorInfo(estado.designacao);
      
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

  Map<String, dynamic> _getEstadoColorInfo(String designacao) {
    final lower = designacao.toLowerCase();
    
    if (lower.contains('operacional') && !lower.contains('não') && !lower.contains('nao')) {
      return {'color': Colors.green, 'icon': Icons.check_circle};
    } else if (lower.contains('manutenção') || lower.contains('manutencao')) {
      return {'color': Colors.orange, 'icon': Icons.build};
    } else if (lower.contains('avariado') || lower.contains('não operacional') || 
               lower.contains('nao operacional') || lower.contains('inativo')) {
      return {'color': Colors.red, 'icon': Icons.cancel};
    } else if (lower.contains('reserva') || lower.contains('standby')) {
      return {'color': Colors.blue, 'icon': Icons.pause_circle};
    }
    
    return {'color': Colors.grey, 'icon': Icons.help};
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

  void _onItemTap(ArtigoComEquipamento item) {
    if (item.equipamento != null) {
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EquipamentoDetailScreen(
            artigo: item.artigo,
            equipamento: item.equipamento,
          ),
        ),
      );
    } else {
      final familia = item.artigo.familia?.designacao.toLowerCase() ?? '';
      final tipo = item.artigo.tipo?.designacao.toLowerCase() ?? '';
      
      if (familia.contains('produto') || tipo.contains('produto')) {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => ProdutoDetailScreen(
              artigo: item.artigo,
            ),
          ),
        );
      } else {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => MateriaPrimaDetailScreen(
              artigo: item.artigo,
            ),
          ),
        );
      }
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
        title: const Text('Armazém'),
        automaticallyImplyLeading: false,
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
                  hintText: 'Pesquisar artigo ou armazém...',
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

  Widget _buildItemCard(ArtigoComEquipamento item) {
    Color backgroundColor;
    Color? borderColor;
    
    if (item.equipamento != null) {
      final estadoDesig = item.equipamento!.estadoDesignacao?.toLowerCase() ?? '';
      
      if (estadoDesig.contains('operacional') && !estadoDesig.contains('não') && !estadoDesig.contains('nao')) {
        backgroundColor = Colors.green[50]!;
        borderColor = Colors.green[300];
      } else if (estadoDesig.contains('manutenção') || estadoDesig.contains('manutencao')) {
        backgroundColor = Colors.yellow[50]!;
        borderColor = Colors.yellow[600];
      } else if (estadoDesig.contains('avariado') || estadoDesig.contains('não operacional') || 
                 estadoDesig.contains('nao operacional') || estadoDesig.contains('inativo')) {
        backgroundColor = Colors.red[50]!;
        borderColor = Colors.red[300];
      } else {
        backgroundColor = Colors.grey[50]!;
        borderColor = Colors.grey[300];
      }
    } else {
      backgroundColor = Colors.grey[50]!;
      borderColor = Colors.grey[300];
    }
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: backgroundColor,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: borderColor!, width: 1.5),
      ),
      child: InkWell(
        onTap: () => _onItemTap(item),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
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
              
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.artigo.designacao,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    if (item.artigo.referencia != null && item.artigo.referencia!.isNotEmpty)
                      Text(
                        'Referência: ${item.artigo.referencia}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    
                    if (item.artigo.familia != null)
                      Text(
                        'Família: ${item.artigo.familia!.designacao}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    
                    // ✅ SEMPRE mostra o armazém (se existir)
                    if (item.armazemNome != null && item.armazemNome!.isNotEmpty)
                      Row(
                        children: [
                          Icon(Icons.warehouse, size: 14, color: Colors.grey[600]),
                          const SizedBox(width: 4),
                          Text(
                            item.armazemNome!,
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.grey[700],
                            ),
                          ),
                        ],
                      ),
                    
                    // ✅ REMOVIDO: Badge de estado para equipamentos
                    // A cor de fundo já indica o estado
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _getItemIcon(ArtigoComEquipamento item) {
    IconData icon;
    Color color;
    
    if (item.equipamento != null) {
      icon = Icons.handyman;
      color = _getEstadoColorFromDesignacao(item.equipamento!.estadoDesignacao ?? '');
    } else {
      final familia = item.artigo.familia?.designacao.toLowerCase() ?? '';
      
      if (familia.contains('parafuso')) {
        icon = Icons.construction;
        color = Colors.grey[700]!;
      } else if (familia.contains('produto')) {
        icon = Icons.inventory_2;
        color = Colors.grey[700]!;
      } else {
        icon = Icons.category;
        color = Colors.grey[700]!;
      }
    }
    
    return Icon(icon, size: 32, color: color);
  }

  Color _getEstadoColorFromDesignacao(String designacao) {
    final lower = designacao.toLowerCase();
    
    if (lower.contains('operacional') && !lower.contains('não') && !lower.contains('nao')) {
      return Colors.green[700]!;
    } else if (lower.contains('manutenção') || lower.contains('manutencao')) {
      return Colors.orange[700]!;
    } else if (lower.contains('avariado') || lower.contains('não operacional') || 
               lower.contains('nao operacional') || lower.contains('inativo')) {
      return Colors.red[700]!;
    } 
    
    return Colors.grey[700]!;
  }
}