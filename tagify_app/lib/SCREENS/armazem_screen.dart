import 'package:flutter/material.dart';
import '../SERVICE/API.dart';
import '../models/models.dart';
import 'equipamento_detail_screen.dart';
import 'produto_detail_screen.dart';
import 'materia_prima_detail_screen.dart';

// Classe auxiliar para combinar Artigo com Equipamento
class ArtigoComEquipamento {
  final Artigo artigo;
  final Equipamento? equipamento;

  ArtigoComEquipamento({
    required this.artigo,
    this.equipamento,
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
  bool _isLoading = true;
  String? _errorMessage;

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
      
      // Criar mapa de equipamentos por ID_artigo para acesso rápido
      final equipamentosMap = <int, Equipamento>{};
      for (var equip in equipamentos) {
        equipamentosMap[equip.idArtigo] = equip;
      }
      
      // Combinar artigos com seus equipamentos
      final itensCompletos = artigos.map((artigo) {
        return ArtigoComEquipamento(
          artigo: artigo,
          equipamento: equipamentosMap[artigo.id],
        );
      }).toList();
      
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

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _itensFiltrados = _itens;
      } else {
        _itensFiltrados = _itens.where((item) {
          final designacao = item.artigo.designacao.toLowerCase();
          final referencia = (item.artigo.referencia ?? '').toLowerCase();
          final searchLower = query.toLowerCase();
          
          return designacao.contains(searchLower) || 
                 referencia.contains(searchLower);
        }).toList();
      }
    });
  }

  void _showFilters() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext context) {
        return Container(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Filtros',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              ListTile(
                leading: const Icon(Icons.category),
                title: const Text('Por Família'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Filtro por Família - Em desenvolvimento'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.warehouse),
                title: const Text('Por Armazém'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Filtro por Armazém - Em desenvolvimento'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.inventory),
                title: const Text('Com Stock'),
                onTap: () {
                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Filtro por Stock - Em desenvolvimento'),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.circle, color: Colors.green),
                title: const Text('Operacional'),
                onTap: () {
                  Navigator.pop(context);
                  _filterByEstado(1);
                },
              ),
              ListTile(
                leading: const Icon(Icons.circle, color: Colors.orange),
                title: const Text('Em Manutenção'),
                onTap: () {
                  Navigator.pop(context);
                  _filterByEstado(2);
                },
              ),
              ListTile(
                leading: const Icon(Icons.circle, color: Colors.red),
                title: const Text('Avariado'),
                onTap: () {
                  Navigator.pop(context);
                  _filterByEstado(3);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _filterByEstado(int idEstado) {
    setState(() {
      _itensFiltrados = _itens.where((item) {
        return item.equipamento?.idEstado == idEstado;
      }).toList();
    });
  }

  void _onItemTap(ArtigoComEquipamento item) {
    // Determinar qual tela abrir baseado no tipo de item
    if (item.equipamento != null) {
      // É equipamento
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (context) => EquipamentoDetailScreen(
            artigo: item.artigo,
            equipamento: item.equipamento,
          ),
        ),
      );
    } else {
      // Verificar se é produto ou matéria-prima baseado na família ou tipo
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Column(
          children: [
            // Barra de pesquisa no topo
            Container(
              padding: const EdgeInsets.all(16),
              color: Colors.white,
              child: Row(
                children: [
                  // Botão de filtros (roda dentada)
                  IconButton(
                    icon: const Icon(Icons.settings, size: 28),
                    onPressed: _showFilters,
                    color: Colors.grey[700],
                  ),
                  
                  const SizedBox(width: 8),
                  
                  // Barra de pesquisa
                  Expanded(
                    child: TextField(
                      controller: _searchController,
                      onChanged: _onSearch,
                      decoration: InputDecoration(
                        hintText: 'Pesquisar...',
                        border: InputBorder.none,
                        hintStyle: TextStyle(color: Colors.grey[400]),
                      ),
                    ),
                  ),
                  
                  // Botão de pesquisa (lupa)
                  IconButton(
                    icon: const Icon(Icons.search, size: 28),
                    onPressed: () => _onSearch(_searchController.text),
                    color: Colors.grey[700],
                  ),
                ],
              ),
            ),
            
            // Divisor
            Divider(height: 1, color: Colors.grey[300]),
            
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
                                   size: 64, 
                                   color: Colors.grey[400]),
                              const SizedBox(height: 16),
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 32),
                                child: Text(
                                  _errorMessage!,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(color: Colors.grey[600]),
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadData,
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        )
                      : _itensFiltrados.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inbox_outlined, 
                                       size: 64, 
                                       color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nenhum item encontrado',
                                    style: TextStyle(color: Colors.grey[600]),
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
      
      // Barra inferior com navegação (igual à home)
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: 1, // ArmazÃ©m está selecionado
        onTap: (index) {
          if (index == 0) {
            // Voltar para CÃ¢mara (Home)
            Navigator.of(context).pop();
          }
          // Se index == 1, já estamos no Armazém
        },
        selectedItemColor: Colors.amber[800],
        unselectedItemColor: Colors.grey[600],
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.camera_alt, size: 28),
            label: 'Câmara',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.warehouse, size: 28),
            label: 'Armazém',
          ),
        ],
      ),
    );
  }

  Widget _buildItemCard(ArtigoComEquipamento item) {
    // Determinar cor de fundo baseada no estado do equipamento
    Color backgroundColor;
    Color? borderColor;
    
    if (item.equipamento != null) {
      // É equipamento - aplicar cor baseada no estado
      switch (item.equipamento!.idEstado) {
        case 1: // Operacional
          backgroundColor = Colors.green[50]!;
          borderColor = Colors.green[300];
          break;
        case 2: // Em Manutenção
          backgroundColor = Colors.orange[50]!;
          borderColor = Colors.orange[300];
          break;
        case 3: // Avariado
          backgroundColor = Colors.red[50]!;
          borderColor = Colors.red[300];
          break;
        default:
          backgroundColor = Colors.grey[50]!;
          borderColor = Colors.grey[300];
      }
    } else {
      // Produto ou matéria-prima - cinzento
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
              // Ícone do item
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _getItemIcon(item),
              ),
              
              const SizedBox(width: 12),
              
              // Informações do item
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome
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
                    
                    // Referência
                    if (item.artigo.referencia != null)
                      Text(
                        'Referência: ${item.artigo.referencia}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    
                    // Família
                    if (item.artigo.familia != null)
                      Text(
                        'Família: ${item.artigo.familia!.designacao}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    
                    // Estado (se for equipamento)
                    if (item.equipamento?.estadoDesignacao != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: _getEstadoColor(item.equipamento!.idEstado),
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: Text(
                            item.equipamento!.estadoDesignacao!,
                            style: const TextStyle(
                              fontSize: 11,
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
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

  Widget _getItemIcon(ArtigoComEquipamento item) {
    IconData icon;
    Color color;
    
    if (item.equipamento != null) {
      // É equipamento
      icon = Icons.handyman;
      color = _getEstadoColor(item.equipamento!.idEstado);
    } else {
      // Produto ou matéria-prima
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

  Color _getEstadoColor(int? idEstado) {
    switch (idEstado) {
      case 1: // Operacional
        return Colors.green[700]!;
      case 2: // Em Manutenção
        return Colors.orange[700]!;
      case 3: // Avariado
        return Colors.red[700]!;
      default:
        return Colors.grey[700]!;
    }
  }
}