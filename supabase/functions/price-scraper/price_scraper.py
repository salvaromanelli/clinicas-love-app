import requests
from bs4 import BeautifulSoup
import json
from supabase import create_client
import os
import time
from dotenv import load_dotenv
from selenium import webdriver
from webdriver_manager.chrome import ChromeDriverManager
from selenium.webdriver.chrome.options import Options
from selenium.webdriver.chrome.service import Service
from datetime import datetime
import sys

print("🚀 Iniciando price_scraper.py")

# Cargar variables de entorno desde el archivo .env
dotenv_path = os.path.join(os.path.dirname(os.path.abspath(__file__)), '.env')
if os.path.exists(dotenv_path):
    print(f"📂 Cargando variables de entorno desde: {dotenv_path}")
    load_dotenv(dotenv_path)
else:
    print(f"⚠️ Archivo .env no encontrado en: {dotenv_path}")
    load_dotenv()  # Intentar cargar de la ubicación predeterminada

# ===== CONFIGURACIÓN =====
# Supabase 
SUPABASE_URL = os.environ.get("SUPABASE_URL")
SUPABASE_KEY = os.environ.get("SUPABASE_KEY")

# Configuración de scraping
SCRAPE_DELAY = int(os.environ.get("SCRAPE_DELAY", "5"))
DEBUG_MODE = os.environ.get("DEBUG_MODE", "false").lower() == "true"
MAX_RETRIES = int(os.environ.get("MAX_RETRIES", "3"))

# URLs objetivo (convertir de string separado por comas a lista)
default_urls = [
    "https://clinicasloveshop.com/mas-vendidos",
    "https://clinicasloveshop.com/", 
    "https://clinicasloveshop.com/productos-rebajados"
]
target_urls_str = os.environ.get("TARGET_URLS", "")
TARGET_URLS = target_urls_str.split(",") if target_urls_str and "," in target_urls_str else default_urls

# Verificar configuración crítica
if not SUPABASE_URL or not SUPABASE_KEY:
    raise SystemExit("⚠️ Faltan SUPABASE_URL y SUPABASE_KEY en las variables de entorno.")

# Mostrar configuración (sin mostrar la clave completa por seguridad)
print(f"📌 URL de Supabase: {SUPABASE_URL}")
print(f"🔑 API Key: {SUPABASE_KEY[:4]}...{SUPABASE_KEY[-4:]}")
print(f"⏱️ Delay entre peticiones: {SCRAPE_DELAY} segundos")
print(f"🐞 Modo debug: {DEBUG_MODE}")
print(f"🔄 Número máximo de reintentos: {MAX_RETRIES}")
print(f"🌐 URLs objetivo ({len(TARGET_URLS)}): {', '.join(TARGET_URLS)}")

# Inicializar cliente de Supabase
try:
    supabase = create_client(SUPABASE_URL, SUPABASE_KEY)
    print("✅ Cliente Supabase inicializado correctamente")
except Exception as e:
    print(f"❌ Error al inicializar cliente Supabase: {e}")
    sys.exit(1)

def create_debug_folder():
    """Crea una carpeta para los archivos de depuración con marca de tiempo"""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    debug_folder = f"debug_{timestamp}"
    os.makedirs(debug_folder, exist_ok=True)
    return debug_folder

def scrape_prices():
    print("🔍 Iniciando scraping de precios...")
    debug_folder = create_debug_folder()
    print(f"📁 Archivos de depuración se guardarán en: {debug_folder}")
    
    # Usar las URLs de las variables de entorno
    urls = TARGET_URLS
    
    # Headers to mimic a real browser
    headers = {
        "User-Agent": "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.0.0 Safari/537.36",
        "Accept": "text/html,application/xhtml+xml,application/xml;q=0.9,image/avif,image/webp,*/*;q=0.8",
        "Accept-Language": "en-US,en;q=0.5",
        "Accept-Encoding": "gzip, deflate, br",
        "Connection": "keep-alive",
        "Upgrade-Insecure-Requests": "1",
        "Sec-Fetch-Dest": "document",
        "Sec-Fetch-Mode": "navigate",
        "Sec-Fetch-Site": "none",
        "Sec-Fetch-User": "?1",
        "Cache-Control": "max-age=0"
    }
    
    all_prices = []
    
    # Si estamos en modo debug, guardar más información
    if DEBUG_MODE:
        print("🐞 Modo debug activado - se guardarán archivos HTML completos")
    
    # Método 1: Usar requests (contenido estático)
    print("\n🌐 MÉTODO 1: Scraping con Requests (contenido estático)")
    for url in urls:
        for attempt in range(MAX_RETRIES):
            try:
                print(f"\nAnalizando URL con Requests: {url} (intento {attempt+1}/{MAX_RETRIES})")
                # Add headers and a timeout
                response = requests.get(url, headers=headers, timeout=20)
                
                # Guardar HTML para inspección en modo debug
                static_html_path = f"{debug_folder}/static_{url.split('/')[-1] or 'index'}.html"
                with open(static_html_path, "w", encoding="utf-8") as f:
                    f.write(response.text)
                print(f"💾 HTML estático guardado en: {static_html_path}")
                
                if response.status_code != 200:
                    print(f"❌ Error al acceder a la página: {response.status_code}")
                    if attempt < MAX_RETRIES - 1:
                        wait_time = (attempt + 1) * SCRAPE_DELAY
                        print(f"⏳ Esperando {wait_time} segundos antes de reintentar...")
                        time.sleep(wait_time)
                        continue
                    else:
                        break
                
                print(f"📊 Tamaño de la respuesta estática: {len(response.text)} bytes")
                
                soup = BeautifulSoup(response.text, "html.parser")
                
                # Debug: Check title to confirm we're getting the right page
                page_title = soup.title.text if soup.title else "No title found"
                print(f"📑 Título de la página: {page_title}")
                
                # Intentar encontrar productos y precios con múltiples selectores
                static_prices = extract_prices_from_soup(soup, "Requests")
                all_prices.extend(static_prices)
                
                # Si fue exitoso, salir del bucle de reintentos
                break
                
            except Exception as e:
                print(f"❌ Error procesando URL con Requests {url} (intento {attempt+1}/{MAX_RETRIES}): {str(e)}")
                if attempt < MAX_RETRIES - 1:
                    wait_time = (attempt + 1) * SCRAPE_DELAY
                    print(f"⏳ Esperando {wait_time} segundos antes de reintentar...")
                    time.sleep(wait_time)
                else:
                    print(f"⚠️ Máximo número de intentos alcanzado para {url}")
    
    # Método 2: Usar Selenium (para contenido renderizado por JavaScript)
    print("\n🤖 MÉTODO 2: Scraping con Selenium (contenido dinámico)")
    
    # Configurar opciones de Chrome
    options = Options()
    options.add_argument("--headless")  # Ejecutar sin interfaz gráfica
    options.add_argument("--no-sandbox")
    options.add_argument("--disable-dev-shm-usage")
    options.add_argument(f"user-agent={headers['User-Agent']}")
    
    try:
        print("🔧 Configurando Selenium WebDriver...")
        service = Service(ChromeDriverManager().install())
        driver = webdriver.Chrome(service=service, options=options)
        print("✅ WebDriver configurado correctamente")
        
        for url in urls:
            for attempt in range(MAX_RETRIES):
                try:
                    print(f"\nAnalizando URL con Selenium: {url} (intento {attempt+1}/{MAX_RETRIES})")
                    driver.get(url)
                    
                    # Esperar a que la página cargue completamente
                    wait_time = SCRAPE_DELAY
                    print(f"⏳ Esperando {wait_time} segundos para que el JavaScript se ejecute...")
                    time.sleep(wait_time)
                    
                    # Obtener el HTML después de la ejecución de JavaScript
                    dynamic_html = driver.page_source
                    
                    # Guardar HTML para inspección
                    dynamic_html_path = f"{debug_folder}/dynamic_{url.split('/')[-1] or 'index'}.html"
                    with open(dynamic_html_path, "w", encoding="utf-8") as f:
                        f.write(dynamic_html)
                    print(f"💾 HTML dinámico guardado en: {dynamic_html_path}")
                    
                    print(f"📊 Tamaño de la respuesta dinámica: {len(dynamic_html)} bytes")
                    
                    # Crear objeto BeautifulSoup con el HTML dinámico
                    soup = BeautifulSoup(dynamic_html, "html.parser")
                    
                    # Extraer título para verificar
                    page_title = soup.title.text if soup.title else "No title found"
                    print(f"📑 Título de la página: {page_title}")
                    
                    # Intentar encontrar productos y precios con múltiples selectores
                    dynamic_prices = extract_prices_from_soup(soup, "Selenium")
                    all_prices.extend(dynamic_prices)
                    
                    # Si fue exitoso, salir del bucle de reintentos
                    break
                    
                except Exception as e:
                    print(f"❌ Error procesando URL con Selenium {url} (intento {attempt+1}/{MAX_RETRIES}): {str(e)}")
                    if attempt < MAX_RETRIES - 1:
                        wait_time = (attempt + 1) * SCRAPE_DELAY
                        print(f"⏳ Esperando {wait_time} segundos antes de reintentar...")
                        time.sleep(wait_time)
                    else:
                        print(f"⚠️ Máximo número de intentos alcanzado para {url} con Selenium")
        
        # Cerrar el navegador al terminar
        driver.quit()
        print("🔒 Navegador cerrado correctamente")
        
    except Exception as e:
        print(f"❌ Error configurando Selenium: {str(e)}")
    
    # Eliminar duplicados
    unique_prices = []
    seen_treatments = set()
    for item in all_prices:
        treatment = item["treatment"].lower()
        if treatment not in seen_treatments:
            seen_treatments.add(treatment)
            unique_prices.append(item)
    
    # Si no se encontraron precios reales, usar datos de ejemplo
    if len(unique_prices) < 3:
        print(f"⚠️ No se detectaron suficientes precios ({len(unique_prices)}). Usando datos de ejemplo.")
        example_prices = [
            {"category": "Facial", "treatment": "Botox", "price": "300€", "description": "Tratamiento por zona"},
            {"category": "Facial", "treatment": "Ácido hialurónico", "price": "450€", "description": "Relleno facial"},
            {"category": "Facial", "treatment": "Vitaminas", "price": "80€", "description": "Limpieza profesional"},
            {"category": "Corporal", "treatment": "Lanluma", "price": "250€", "description": "Sesión completa"}
        ]
        return example_prices
    else:
        print(f"✅ Se encontraron {len(unique_prices)} precios reales")
        return unique_prices

def extract_prices_from_soup(soup, method_name):
    """Extrae precios de un objeto BeautifulSoup usando múltiples selectores"""
    prices = []
    
    # Método 1: Selectores originales
    print(f"🔍 [{method_name}] Buscando con selectores originales...")
    products = soup.select(".grid-product__content, .product-card, .product")
    print(f"  📊 Se encontraron {len(products)} posibles productos")
    
    # Método 2: Selectores más genéricos
    if len(products) < 3:
        print(f"🔍 [{method_name}] Buscando con selectores genéricos...")
        products = soup.select("div.product, li.product, div[class*='product'], div[id*='product'], .card, .item, article")
        print(f"  📊 Se encontraron {len(products)} posibles productos")
    
    # Método 3: Selectores específicos para tiendas online
    if len(products) < 3:
        print(f"🔍 [{method_name}] Buscando con selectores específicos para tiendas...")
        products = soup.select(".collection-grid__item, .product-single__meta, .product-item, .shogun-root div[class*='product']")
        print(f"  📊 Se encontraron {len(products)} posibles productos")
    
    # Método 4: Buscar directamente elementos de precio
    print(f"🔍 [{method_name}] Buscando precios directamente...")
    try:
        price_selectors = [".price", ".product-price", ".money", "[class*='price']"] 
        
        # Estos selectores pueden causar errores en algunas versiones de BeautifulSoup
        if DEBUG_MODE:
            # Intentar con selectores avanzados solo en modo debug
            price_selectors.extend([
                "span:contains('€')", "div:contains('€')", "p:contains('€')",
                "span:contains('$')", "div:contains('$')", "p:contains('$')"
            ])
        
        price_selector_str = ", ".join(price_selectors)
        all_price_elements = soup.select(price_selector_str)
        print(f"  📊 Se encontraron {len(all_price_elements)} posibles elementos de precio")
    except Exception as e:
        print(f"  ⚠️ Error con selectores avanzados: {e}")
        # Fallback a selectores básicos
        all_price_elements = soup.select(".price, .product-price, .money, [class*='price']")
        print(f"  📊 Se encontraron {len(all_price_elements)} posibles elementos de precio (selectores básicos)")
    
    # Procesar productos encontrados
    for product in products:
        try:
            # Buscar título y precio (selector genérico para tiendas)
            title = product.select_one(".grid-product__title, .product-title, .product-name, h2, h3, h4, [class*='title'], [class*='name']")
            price = product.select_one(".grid-product__price, .product-price, .price, [class*='price'], .money")
            
            if title and price:
                title_text = title.get_text().strip()
                price_text = price.get_text().strip()
                
                # Solo agregar si parece un precio válido
                if ('€' in price_text or '$' in price_text) and len(title_text) > 3:
                    # Determinar categoría basada en título
                    category = "Productos"
                    if "facial" in title_text.lower() or "cara" in title_text.lower():
                        category = "Facial"
                    elif "corp" in title_text.lower() or "cuerpo" in title_text.lower():
                        category = "Corporal"
                    
                    prices.append({
                        "category": category,
                        "treatment": title_text,
                        "price": price_text,
                        "description": f"Encontrado por {method_name}"
                    })
                    print(f"  ✅ Encontrado: {title_text} - {price_text}")
        except Exception as e:
            print(f"  ⚠️ Error procesando producto: {e}")
    
    # Método 5: Buscar tablas de precios
    print(f"🔍 [{method_name}] Buscando tablas de precios...")
    tables = soup.select("table")
    print(f"  📊 Se encontraron {len(tables)} tablas")
    
    for table in tables:
        rows = table.select("tr")
        for row in rows:
            cols = row.select("td")
            if len(cols) >= 2:
                treatment = cols[0].get_text().strip()
                price = cols[-1].get_text().strip()
                if ('€' in price or '$' in price) and len(treatment) > 3:
                    prices.append({
                        "category": "Servicios",
                        "treatment": treatment,
                        "price": price,
                        "description": f"Tabla de precios ({method_name})"
                    })
                    print(f"  ✅ Encontrado en tabla: {treatment} - {price}")
    
    # Método 6: Búsqueda directa de texto con formato de precio
    for price_elem in all_price_elements:
        try:
            price_text = price_elem.get_text().strip()
            if ('€' in price_text or '$' in price_text):
                # Buscar un elemento de título cercano (hacia arriba en el DOM)
                parent = price_elem.parent
                title_elem = None
                
                # Buscar hacia arriba hasta 3 niveles para encontrar un título
                for _ in range(3):
                    if parent:
                        title_elem = parent.select_one("h1, h2, h3, h4, [class*='title'], [class*='name']")
                        if title_elem:
                            break
                        parent = parent.parent
                
                if title_elem:
                    title_text = title_elem.get_text().strip()
                    if len(title_text) > 3:
                        # Determinar categoría
                        category = "Productos"
                        if "facial" in title_text.lower() or "cara" in title_text.lower():
                            category = "Facial"
                        elif "corp" in title_text.lower() or "cuerpo" in title_text.lower():
                            category = "Corporal"
                        
                        prices.append({
                            "category": category,
                            "treatment": title_text,
                            "price": price_text,
                            "description": f"Búsqueda directa ({method_name})"
                        })
                        print(f"  ✅ Encontrado con búsqueda directa: {title_text} - {price_text}")
        except Exception as e:
            print(f"  ⚠️ Error procesando elemento de precio: {e}")
    
    print(f"📊 [{method_name}] Total de precios encontrados: {len(prices)}")
    return prices

def update_database(prices_data):
    if not prices_data:
        print("⚠️ No hay datos para actualizar")
        return False
    
    try:
        print(f"📊 Actualizando base de datos con {len(prices_data)} precios...")
        
        try:
            # Método 1: Usar is_not
            print("🗑️ Eliminando registros anteriores (método 1)...")
            supabase.table("prices").delete().is_('id', 'not.null').execute()
            print("✅ Registros anteriores eliminados")
        except Exception as e1:
            print(f"Error en método 1: {e1}")
            try:
                # Método 2: Usar gt con valor mínimo
                print("🗑️ Intentando método 2...")
                supabase.table("prices").delete().gt('id', '00000000-0000-0000-0000-000000000000').execute()
                print("✅ Registros anteriores eliminados")
            except Exception as e2:
                print(f"Error en método 2: {e2}")
                # Continuar de todos modos
        
        print("📝 Insertando nuevos registros...")
        result = supabase.table("prices").insert(prices_data).execute()
        
        print(f"✅ Base de datos actualizada correctamente con {len(prices_data)} registros")
        return True
    
    except Exception as e:
        print(f"❌ Error al actualizar la base de datos: {e}")
        # Intentar solo la inserción si la eliminación falló
        try:
            print("Intentando solo inserción sin eliminación previa...")
            result = supabase.table("prices").insert(prices_data).execute()
            print("✅ Datos insertados (sin eliminar anteriores)")
            return True
        except Exception as ie:
            print(f"❌ Error también al insertar: {ie}")
            return False
        
def save_backup(prices_data):
    """Guarda una copia local de los datos extraídos"""
    timestamp = datetime.now().strftime('%Y%m%d_%H%M%S')
    backup_path = f"prices_backup_{timestamp}.json"
    try:
        with open(backup_path, "w", encoding="utf-8") as f:
            json.dump(prices_data, f, ensure_ascii=False, indent=2)
        print(f"💾 Backup guardado en {backup_path}")
        
        # Si estamos en modo debug, también crear un archivo con información adicional
        if DEBUG_MODE:
            debug_info = {
                "timestamp": timestamp,
                "config": {
                    "supabase_url": SUPABASE_URL,
                    "urls_scrapeadas": TARGET_URLS,
                    "delay": SCRAPE_DELAY,
                    "max_retries": MAX_RETRIES
                },
                "stats": {
                    "total_items": len(prices_data),
                    "categorias": {}
                }
            }
            
            # Contar productos por categoría
            for item in prices_data:
                cat = item.get("category", "Sin categoría")
                if cat in debug_info["stats"]["categorias"]:
                    debug_info["stats"]["categorias"][cat] += 1
                else:
                    debug_info["stats"]["categorias"][cat] = 1
                    
            debug_path = f"debug_info_{timestamp}.json"
            with open(debug_path, "w", encoding="utf-8") as f:
                json.dump(debug_info, f, ensure_ascii=False, indent=2)
            print(f"🔍 Información de debug guardada en {debug_path}")
            
    except Exception as e:
        print(f"⚠️ Error al guardar backup: {e}")

# Ejecutar script
if __name__ == "__main__":
    print("🚀 Iniciando actualización de precios...")
    
    # 1. Extraer datos
    prices = scrape_prices()
    
    # 2. Guardar backup local
    save_backup(prices)
    
    # 3. Actualizar base de datos
    if prices:
        update_database(prices)
    
    print("✨ Proceso completado")