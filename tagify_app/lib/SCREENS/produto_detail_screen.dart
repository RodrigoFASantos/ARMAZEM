import 'package:flutter/material.dart';
import '../models/models.dart';

class ProdutoDetailScreen extends StatelessWidget {
  final Artigo artigo;
  final DateTime? dataProduzido;

  const ProdutoDetailScreen({
    super.key,
    required this.artigo,
    this.dataProduzido,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('PRODUTO'),
        backgroundColor: Colors.blue,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            const SizedBox(height: 16),
            
            // Estado (pode vir do tipo ou família)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                artigo.tipo?.designacao ?? 'ESTADO',
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
                _buildInfoRow('Modelo', artigo.tipo?.designacao ?? 'N/A'),
                _buildInfoRow('Nº Série', artigo.referencia ?? 'N/A'),
                _buildInfoRow('Produzido em:', _formatarData(dataProduzido)),
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
            width: 110,
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
    if (data == null) return 'N/A';
    return '${data.day.toString().padLeft(2, '0')}/${data.month.toString().padLeft(2, '0')}/${data.year}';
  }
}