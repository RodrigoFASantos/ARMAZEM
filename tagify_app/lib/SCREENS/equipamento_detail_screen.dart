import 'package:flutter/material.dart';
import '../models/models.dart';

class EquipamentoDetailScreen extends StatelessWidget {
  final Artigo artigo;
  final Equipamento? equipamento;

  const EquipamentoDetailScreen({
    super.key,
    required this.artigo,
    this.equipamento,
  });

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
      body: SingleChildScrollView(
        padding: const EdgeInsets.only(bottom: 24), // PADDING EXTRA NO BOTTOM
        child: Column(
          children: [
            const SizedBox(height: 16),
            
            // Estado
            if (equipamento?.estadoDesignacao != null)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Text(
                  equipamento!.estadoDesignacao!,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            
            const SizedBox(height: 16),

            // Card 1: Informações principais
            _buildInfoCard(
              context,
              [
                _buildInfoRow('Nome', artigo.designacao),
                _buildInfoRow('Categoria', artigo.familia?.designacao ?? 'N/A'),
                _buildInfoRow('Modelo', equipamento?.modelo ?? 'N/A'),
                _buildInfoRow('Nº Série', equipamento?.nSerie ?? 'N/A'),
              ],
            ),

            const SizedBox(height: 16),

            // Card 2: Localização
            _buildInfoCard(
              context,
              [
                _buildInfoRow('Armazém', 'Nome Equipamento'),
                _buildInfoRow('Rack', 'Categoria'),
                _buildInfoRow('Prateleira', 'Modelo'),
                _buildInfoRow('Corredor', 'Número de Série'),
                _buildInfoRow('Zona', 'Zona'),
              ],
            ),

            const SizedBox(height: 16),

            // Seção Manutenção
            if (equipamento?.requerInspecao == true)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    const Text(
                      'Manutenção',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Próxima  ${_formatarData(equipamento?.proximaInspecao)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    Text(
                      'Última  ${_formatarData(equipamento?.dataAquisicao)}',
                      style: const TextStyle(fontSize: 14),
                    ),
                    const SizedBox(height: 16),
                    
                    // Campo de descrição
                    Container(
                      width: double.infinity,
                      height: 100,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        border: Border.all(color: Colors.grey[400]!),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Align(
                        alignment: Alignment.topLeft,
                        child: Text(
                          'Descrição',
                          style: TextStyle(
                            color: Colors.grey,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            const SizedBox(height: 16),

            // Imagem (apenas se existir)
            if (artigo.imagem != null)
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
                      artigo.imagem!,
                      fit: BoxFit.contain,
                      errorBuilder: (context, error, stackTrace) {
                        return const SizedBox.shrink();
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

  Widget _buildInfoCard(BuildContext context, List<Widget> children) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
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
                color: Colors.black87,
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

  String _formatarData(DateTime? data) {
    if (data == null) return 'XX/XX/XXXX';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }
}