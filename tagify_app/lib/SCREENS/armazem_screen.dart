import 'package:flutter/material.dart';
import '../SERVICE/API.dart';
import '../models/models.dart';

class ArmazemScreen extends StatefulWidget {
  const ArmazemScreen({super.key});

  @override
  State<ArmazemScreen> createState() => _ArmazemScreenState();
}

class _ArmazemScreenState extends State<ArmazemScreen> {
  final _apiService = ApiService();
  final _searchController = TextEditingController();
  
  List<Artigo> _artigos = [];
  List<Artigo> _artigosFiltrados = [];
  bool _isLoading = true;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _loadArtigos();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadArtigos() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final artigos = await _apiService.getAllArtigos();
      setState(() {
        _artigos = artigos;
        _artigosFiltrados = artigos;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = 'Erro ao carregar artigos: $e';
        _isLoading = false;
      });
    }
  }

  void _onSearch(String query) {
    setState(() {
      if (query.isEmpty) {
        _artigosFiltrados = _artigos;
      } else {
        _artigosFiltrados = _artigos.where((artigo) {
          final designacao = artigo.designacao.toLowerCase();
          final referencia = (artigo.referencia ?? '').toLowerCase();
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
            ],
          ),
        );
      },
    );
  }

  void _onArtigoTap(Artigo artigo) {
    // TODO: Navegar para página de detalhes do artigo
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(artigo.designacao),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (artigo.referencia != null)
                Text('Referência: ${artigo.referencia}'),
              if (artigo.familia != null)
                Text('Família: ${artigo.familia!.designacao}'),
              if (artigo.tipo != null)
                Text('Tipo: ${artigo.tipo!.designacao}'),
              if (artigo.stockTotal != null)
                Text('Stock: ${artigo.stockTotal}'),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Fechar'),
            ),
          ],
        );
      },
    );
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
            
            // Lista de artigos
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
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: TextStyle(color: Colors.grey[600]),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _loadArtigos,
                                child: const Text('Tentar novamente'),
                              ),
                            ],
                          ),
                        )
                      : _artigosFiltrados.isEmpty
                          ? Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.inbox_outlined, 
                                       size: 64, 
                                       color: Colors.grey[400]),
                                  const SizedBox(height: 16),
                                  Text(
                                    'Nenhum artigo encontrado',
                                    style: TextStyle(color: Colors.grey[600]),
                                  ),
                                ],
                              ),
                            )
                          : RefreshIndicator(
                              onRefresh: _loadArtigos,
                              child: ListView.builder(
                                padding: const EdgeInsets.all(8),
                                itemCount: _artigosFiltrados.length,
                                itemBuilder: (context, index) {
                                  final artigo = _artigosFiltrados[index];
                                  return _buildArtigoCard(artigo);
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
      
      // Barra inferior com navegação
      bottomNavigationBar: BottomAppBar(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            IconButton(
              icon: const Icon(Icons.home, size: 32),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Voltar',
            ),
            IconButton(
              icon: const Icon(Icons.camera_alt, size: 32),
              onPressed: () => Navigator.of(context).pop(),
              tooltip: 'Scanner',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildArtigoCard(Artigo artigo) {
    // Define cor de fundo alternada
    final backgroundColor = artigo.familia?.designacao.contains('Aparafusadora') ?? false
        ? Colors.green[50]
        : Colors.white;
    
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      color: backgroundColor,
      elevation: 1,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[300]!),
      ),
      child: InkWell(
        onTap: () => _onArtigoTap(artigo),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Imagem/Ícone do artigo
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[200],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: _getArtigoIcon(artigo),
              ),
              
              const SizedBox(width: 12),
              
              // Informações do artigo
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nome
                    Text(
                      artigo.designacao,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    
                    // Referência
                    if (artigo.referencia != null)
                      Text(
                        'Referência: ${artigo.referencia}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    
                    // Família
                    if (artigo.familia != null)
                      Text(
                        'Família: ${artigo.familia!.designacao}',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.grey[700],
                        ),
                      ),
                    
                    // Armazém (placeholder por agora)
                    Text(
                      'Armazém: 1',
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.grey[700],
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

  Widget _getArtigoIcon(Artigo artigo) {
    // Define ícone baseado na família
    IconData icon;
    Color color;
    
    if (artigo.familia?.designacao.contains('Aparafusadora') ?? false) {
      icon = Icons.handyman;
      color = Colors.blue;
    } else if (artigo.familia?.designacao.contains('Parafuso') ?? false) {
      icon = Icons.construction;
      color = Colors.grey[700]!;
    } else {
      icon = Icons.inventory_2;
      color = Colors.orange;
    }
    
    return Icon(icon, size: 32, color: color);
  }
}