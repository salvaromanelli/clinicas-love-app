import 'package:flutter/material.dart';


class OfertasPromosPage extends StatelessWidget {
  const OfertasPromosPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF111418),
      body: SafeArea(
        child: Column(
          children: [
                       Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                // Back button
                IconButton(
                  icon: const Icon(
                    Icons.arrow_back_ios,
                    color: Colors.white,
                  ),
                  onPressed: () {
                    Navigator.pop(context);
                  },
                ),
                // Logo in center
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    child: Center(
                      child: ColorFiltered(
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                        child: Image.asset(
                          'assets/images/logo.png',
                          height: 80.0,
                        ),
                      ),
                    ),
                  ),
                ),
                // Empty space to balance the layout
                const SizedBox(width: 48.0),
              ],
            ),
        
            // Header
            const Text(
              'Clínica estética',
              style: TextStyle(
                color: Colors.white,
                fontSize: 14.0,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8.0),
            const Text(
              'Ofertas exclusivas para ti',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24.0,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16.0),
            // Treatments
            Expanded(
              child: SingleChildScrollView(
                child: Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    children: [
                      _buildTreatmentCard(
                        'Cavitación',
                        'Pierde grasa localizada',
                        'Hasta 40% de descuento',
                        'https://oaidalleapiprodscus.blob.core.windows.net/private/org-JsMmTpMTupl8qQOeSP9nxnyl/user-Z8HSZWg342MFjGWDLCusJSCE/img-raX4JexTUomrbBsjBa7LwmHH.png',
                      ),
                      const SizedBox(height: 16.0),
                      _buildTreatmentCard(
                        'Radiofrecuencia',
                        'Reafirma tu piel',
                        'Hasta 50% de descuento',
                        'https://placehold.co/600x300',
                      ),
                      const SizedBox(height: 16.0),
                      _buildTreatmentCard(
                        'Limpieza facial',
                        'Elimina impurezas de la piel',
                        'Hasta 60% de descuento',
                        'https://oaidalleapiprodscus.blob.core.windows.net/private/org-JsMmTpMTupl8qQOeSP9nxnyl/user-Z8HSZWg342MFjGWDLCusJSCE/img-EELWEaKQLTOZh9OowhiDUYSy.png',
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Buttons
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                children: [
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[600],
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text('Ver todos los tratamientos'),
                  ),
                  const SizedBox(height: 8.0),
                  ElevatedButton(
                    onPressed: () {},
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF293038),
                      minimumSize: const Size(double.infinity, 48),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8.0),
                      ),
                    ),
                    child: const Text('Comprar'),
                  ),
                ],
              ),
            ),
            // Navigation Bar

          ],
        ),
      ),
    );
  }

  Widget _buildTreatmentCard(String title, String subtitle, String discount, String imageUrl) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF293038),
        borderRadius: BorderRadius.circular(12.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12.0)),
            child: Image.network(
              imageUrl,
              width: double.infinity,
              height: 200.0,
              fit: BoxFit.cover,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18.0,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14.0,
                  ),
                ),
                const SizedBox(height: 4.0),
                Text(
                  discount,
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 14.0,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}