# /supabase/functions/price_scraper/index.py
import httpx
from bs4 import BeautifulSoup
import os
from supabase import create_client, Client

# Configuración de Supabase
url: str = os.environ.get("https://xlrutqwvlowzntnjgmwa.supabase.co")
key: str = os.environ.get("eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhscnV0cXd2bG93em50bmpnbXdhIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc0MDk2MzY0MCwiZXhwIjoyMDU2NTM5NjQwfQ.cvbeyFrPN5axFksj0frOHIt1q9gFulIKR1DSCPDTVGA")
supabase: Client = create_client(url, key)

async def scrape_prices():
    # URL de la página de precios de la clínica - ajustar según tu sitio
    clinic_url = "https://clinicasloveshop.com/"
    
    async with httpx.AsyncClient() as client:
        response = await client.get(clinic_url)
        soup = BeautifulSoup(response.text, 'html.parser')
        
        # Los selectores deben ajustarse según la estructura de tu sitio web
        price_containers = soup.select('.tratamiento-precio')
        
        prices_data = []
        
        for container in price_containers:
            try:
                # Ajustar estos selectores según la estructura de tu página
                category_elem = container.select_one('.categoria')
                treatment_elem = container.select_one('.nombre-tratamiento')
                price_elem = container.select_one('.precio')
                description_elem = container.select_one('.descripcion')
                
                category = category_elem.text.strip() if category_elem else "General"
                treatment = treatment_elem.text.strip() if treatment_elem else ""
                price = price_elem.text.strip() if price_elem else ""
                description = description_elem.text.strip() if description_elem else ""
                
                if treatment and price:
                    prices_data.append({
                        "category": category,
                        "treatment": treatment,
                        "price": price,
                        "description": description,
                        "last_updated": "now()"
                    })
            except Exception as e:
                print(f"Error procesando elemento: {e}")
        
        return prices_data

async def update_database(prices_data):
    # Primero, vaciar la tabla de precios (o alternativamente, actualizar elementos existentes)
    await supabase.table('prices').delete().neq('id', 0).execute()
    
    # Insertar los nuevos datos
    for batch in chunks(prices_data, 50):  # Procesar en lotes para evitar límites de API
        await supabase.table('prices').insert(batch).execute()

def chunks(lst, n):
    """Divide una lista en lotes de tamaño n"""
    for i in range(0, len(lst), n):
        yield lst[i:i + n]

async def handler():
    try:
        prices_data = await scrape_prices()
        print(f"Se encontraron {len(prices_data)} precios")
        await update_database(prices_data)
        return {"success": True, "count": len(prices_data)}
    except Exception as e:
        print(f"Error en el proceso: {e}")
        return {"success": False, "error": str(e)}

# Punto de entrada para la función serverless
def main(req):
    return handler()