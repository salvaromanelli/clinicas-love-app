import requests
from bs4 import BeautifulSoup
import pandas as pd
import json
import uuid
from datetime import datetime
import time
import re

# URL de la página con los tratamientos
url = "https://clinicaslove.com/"

# Configurar headers para evitar bloqueos
headers = {
    "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36"
}

# Hacer la petición a la página
print("Obteniendo página principal...")
response = requests.get(url, headers=headers)

if response.status_code != 200:
    print(f"Error: No se pudo acceder a la página. Código: {response.status_code}")
    exit()

# Crear objeto BeautifulSoup para analizar el HTML
soup = BeautifulSoup(response.text, 'html.parser')

# Encontrar el menú de navegación principal
print("Buscando menú de navegación...")

# Lista para almacenar todos los tratamientos
all_treatments = []

# Categorías que queremos buscar
categories = [
    "Medicina Estética Facial", 
    "Cirugía Estética Facial", 
    "Cirugía Corporal"
]

# Buscar los elementos del menú principal - ajusta estos selectores según la estructura de tu página
# Opciones comunes donde se encuentran los menús de navegación:
menu_elements = soup.select("nav ul li, .menu-item, .dropdown, .main-menu li, header .nav-item")

if not menu_elements:
    print("No se encontró el menú principal. Intentando con otra estrategia...")
    # Intentar encontrar por texto de enlace en toda la página
    all_links = soup.find_all('a')
    menu_elements = [link for link in all_links if any(cat.lower() in link.text.lower() for cat in categories)]

if not menu_elements:
    print("No se encontraron elementos de menú con las categorías buscadas.")
    
    # Mostrar la estructura para debug
    print("\nMostrando estructura del HTML para depuración:")
    for i, tag in enumerate(soup.select("header, nav, .header, .main-header")[:2]):
        print(f"\n--- Elemento {i+1} ---")
        print(tag.prettify()[:1000])  # Mostrar los primeros 1000 caracteres
    exit()

print(f"Se encontraron {len(menu_elements)} posibles elementos de menú")

# Procesar cada categoría
for category_name in categories:
    print(f"\nBuscando categoría: {category_name}")
    
    # Intentar encontrar el elemento de menú que contiene esta categoría
    category_elements = [el for el in menu_elements if category_name.lower() in el.text.lower()]
    
    if not category_elements:
        print(f"No se encontró la categoría '{category_name}'. Saltando...")
        continue
        
    category_element = category_elements[0]
    print(f"Categoría encontrada: {category_name}")
    
    # Buscar los tratamientos en los submenús (diferentes métodos según la estructura)
    treatments = []
    
    # Método 1: Buscar enlaces dentro del elemento de categoría
    submenu = category_element.select("ul li a, .dropdown-menu a, .sub-menu a")
    
    # Método 2: Si no hay submenu directo, buscar si hay enlaces en elementos hermanos
    if not submenu and hasattr(category_element, 'next_sibling'):
        next_element = category_element.next_sibling
        if next_element:
            submenu = next_element.select("a")
    
    # Método 3: Buscar por ID o clase que podría estar relacionada
    if not submenu:
        # Extraer posible ID del elemento
        element_id = category_element.get('id', '')
        if element_id:
            submenu_selector = f"#{element_id}-submenu a, #{element_id}-dropdown a, .{element_id}-submenu a"
            submenu = soup.select(submenu_selector)
    
    # Si encontramos tratamientos
    if submenu:
        print(f"Se encontraron {len(submenu)} posibles tratamientos en {category_name}")
        
        for treatment_link in submenu:
            treatment_name = treatment_link.text.strip()
            treatment_url = treatment_link.get('href', '')
            
            # Normalizar URL
            if treatment_url and not treatment_url.startswith(('http://', 'https://')):
                from urllib.parse import urljoin
                treatment_url = urljoin(url, treatment_url)
            
            print(f"Encontrado: {treatment_name}")
            
            # Crear diccionario base del tratamiento
            treatment = {
                "id": str(uuid.uuid4()),
                "name": treatment_name,
                "description": f"Tratamiento de {treatment_name.lower()}",  # Descripción por defecto
                "price": 0.0,  # Precio por defecto
                "duration": 60,  # Duración por defecto en minutos
                "category": category_name,
                "image_url": None,
                "created_at": datetime.now().isoformat()
            }
            
            # Si hay URL, intentar extraer más detalles de la página del tratamiento
            if treatment_url and treatment_url != '#' and not treatment_url.endswith('#'):
                try:
                    print(f"Visitando página del tratamiento: {treatment_url}")
                    treatment_response = requests.get(treatment_url, headers=headers)
                    
                    if treatment_response.status_code == 200:
                        treatment_soup = BeautifulSoup(treatment_response.text, 'html.parser')
                        
                        # Intentar encontrar la descripción - ajusta estos selectores
                        description_elements = treatment_soup.select(".description, .treatment-description, .content p, article p, .entry-content p")
                        if description_elements:
                            # Tomar los primeros 3 párrafos como descripción
                            description = ' '.join([elem.text.strip() for elem in description_elements[:3]])
                            if description:
                                treatment["description"] = description
                        
                        # Intentar encontrar el precio - busca texto que contenga $ o "precio"
                        price_pattern = r'(\$\s*[\d,.]+|\d[\d,.]*\s*(?:USD|MXN|pesos)|\bprecio[:\s]*[\d,.]+)'
                        price_tags = treatment_soup.find_all(text=re.compile(price_pattern, re.IGNORECASE))
                        
                        if price_tags:
                            for tag in price_tags:
                                price_match = re.search(price_pattern, tag, re.IGNORECASE)
                                if price_match:
                                    price_text = price_match.group(0)
                                    # Extraer solo los números
                                    price_digits = re.search(r'[\d,.]+', price_text)
                                    if price_digits:
                                        try:
                                            price_value = price_digits.group(0).replace(',', '')
                                            treatment["price"] = float(price_value)
                                            break
                                        except ValueError:
                                            continue
                        
                        # Intentar encontrar una imagen
                        image_elements = treatment_soup.select(".treatment-image, .featured-image img, .wp-post-image, article img, .entry-content img")
                        if image_elements:
                            img_src = image_elements[0].get('src') or image_elements[0].get('data-src')
                            if img_src:
                                # Normalizar URL de imagen
                                if not img_src.startswith(('http://', 'https://')):
                                    from urllib.parse import urljoin
                                    img_src = urljoin(treatment_url, img_src)
                                treatment["image_url"] = img_src
                    
                except Exception as e:
                    print(f"Error al procesar la página del tratamiento: {e}")
                
                # Pausa para no sobrecargar el servidor
                time.sleep(1)
            
            all_treatments.append(treatment)
    else:
        print(f"No se encontraron tratamientos en la categoría {category_name}")

# Guardar datos en formato JSON
with open("tratamientos.json", "w", encoding="utf-8") as f:
    json.dump(all_treatments, f, ensure_ascii=False, indent=2)

# Guardar también en CSV
df = pd.DataFrame(all_treatments)
df.to_csv("tratamientos.csv", index=False)

print(f"\nSe extrajeron {len(all_treatments)} tratamientos en total")
print("Datos guardados en 'tratamientos.json' y 'tratamientos.csv'")

# Mostrar resumen por categoría
for category_name in categories:
    count = len([t for t in all_treatments if t['category'] == category_name])
    print(f"{category_name}: {count} tratamientos")
 