# Explicación Detallada Línea por Línea de QoriCore 📖🔍

Este documento proporciona un desglose exhaustivo y pedagógico de cada línea de código de los componentes que integran el microservicio **QoriCore**.

---

## 📑 Tabla de Contenidos
1. [paillier_core.cpp (Núcleo C++ con GMP)](#1-paillier_corecpp-núcleo-c-con-gmp)
2. [server.js (Servidor API REST Express)](#2-serverjs-servidor-api-rest-express)
3. [Dockerfile (Contenedor de Compilación y Runtime)](#3-dockerfile-contenedor-de-compilación-y-runtime)
4. [build_qoricore.sh (Script Unificado de Automatización)](#4-build_qoricoresh-script-unificado-de-automatización)

---

## 1. `paillier_core.cpp` (Núcleo C++ con GMP)

El archivo `paillier_core.cpp` es el motor criptográfico nativo. Implementa aritmética modular de precisión infinita mediante la biblioteca GNU GMP en C++.

```cpp
#include <iostream>
#include <string>
#include <gmpxx.h>
```
- **Línea 1 (`#include <iostream>`):** Incluye la biblioteca estándar de flujo de entrada/salida de C++ (`std::cin`, `std::cout`, `std::cerr`).
- **Línea 2 (`#include <string>`):** Permite el uso de cadenas de texto estándar (`std::string`) para manipular los argumentos recibidos por línea de comandos.
- **Línea 3 (`#include <gmpxx.h>`):** Incluye el envoltorio oficial de C++ de la biblioteca GNU Multiple Precision Arithmetic Library (GMP). Proporciona la clase `mpz_class` para operar enteros gigantes con sobrecarga de operadores algebraicos (`+`, `*`, `%`, etc.).

```cpp
/**
 * Detecta si una cadena tiene prefijo hexadecimal (0x / 0X)
 */
static inline int detect_base(const std::string& s) {
    if (s.size() >= 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        return 16;
    }
    return 10;
}
```
- **Línea 7 (`static inline int detect_base(...)`):** Función auxiliar optimizada en línea (*inlined*) con enlace interno (*static*). Evalúa el formato numérico de la cadena de entrada.
- **Línea 8 (`if (s.size() >= 2 ...)`):** Verifica si la cadena tiene al menos dos caracteres y comienza con `0x` o `0X`.
- **Línea 9 (`return 16;`):** Si detecta el prefijo, retorna base 16 (hexadecimal), común en direcciones y hashes de blockchain.
- **Línea 11 (`return 10;`):** En caso contrario, asume representación decimal estándar (base 10).

```cpp
int main(int argc, char* argv[]) {
    std::ios_base::sync_with_stdio(false);
    std::cin.tie(NULL);
```
- **Línea 14 (`int main(int argc, char* argv[])`):** Punto de entrada del programa. Recibe `argc` (conteo de argumentos) y `argv` (vector de punteros a cadenas con los argumentos pasados por consola).
- **Línea 16 (`std::ios_base::sync_with_stdio(false);`):** Desactiva la sincronización obligatoria entre los flujos estándar de C (`stdio`) y C++ (`iostream`). Reduce el overhead de impresión al mínimo.
- **Línea 17 (`std::cin.tie(NULL);`):** Desvincula `std::cin` de `std::cout`, evitando que `std::cout` se vacíe innecesariamente antes de una operación de lectura.

```cpp
    if (argc != 4) {
        std::cerr << "Error de argumentos.\n";
        std::cerr << "Uso: " << argv[0] << " <Cifrado_A> <Cifrado_B> <N_Cuadrado>\n";
        return 1;
    }
```
- **Línea 19 (`if (argc != 4)`):** Comprueba que se hayan proporcionado exactamente 3 parámetros (el nombre del binario cuenta como `argv[0]`).
- **Líneas 20-21:** Si faltan argumentos o sobran, emite un mensaje de error explicativo hacia `std::cerr` (canal de error estándar).
- **Línea 22 (`return 1;`):** Finaliza el proceso con código de salida `1` para señalar error al proceso padre (Node.js).

```cpp
    try {
        std::string str_a = argv[1];
        std::string str_b = argv[2];
        std::string str_n_sq = argv[3];
```
- **Línea 25 (`try {`):** Bloque protegido para capturar excepciones numéricas o de parseo lanzadas por GMP.
- **Líneas 26-28:** Convierte los punteros de caracteres estilo C (`char*`) a objetos seguros `std::string` (`str_a`, `str_b`, `str_n_sq`).

```cpp
        int base_a = detect_base(str_a);
        int base_b = detect_base(str_b);
        int base_n = detect_base(str_n_sq);
```
- **Líneas 30-32:** Determina dinámicamente si cada argumento está expresado en base 10 o base 16.

```cpp
        mpz_class c_a(str_a, base_a == 16 ? 0 : 10);
        mpz_class c_b(str_b, base_b == 16 ? 0 : 10);
        mpz_class n_squared(str_n_sq, base_n == 16 ? 0 : 10);
```
- **Líneas 36-38:** Instancia objetos multiprecisión `mpz_class`. 
  - Si la base detectada es 16, pasa base `0` a GMP, lo cual le indica que interprete automáticamente el prefijo `0x`.
  - Si no, fija base `10` explícita, evitando que cadenas con ceros a la izquierda sean interpretadas erróneamente como octal.

```cpp
        if (n_squared <= 0) {
            std::cerr << "Error: N_Cuadrado debe ser positivo mayor que cero.\n";
            return 1;
        }
```
- **Líneas 40-43:** Validación de seguridad criptográfica: el módulo cuadrático $N^2$ debe ser estrictamente positivo.

```cpp
        mpz_class result = (c_a * c_b) % n_squared;
        if (result < 0) {
            result += n_squared;
        }
```
- **Línea 47 (`mpz_class result = (c_a * c_b) % n_squared;`):** Ejecuta la **suma homomórfica de Paillier**. Multiplica algebraicamente los dos textos cifrados $C_A$ y $C_B$, y aplica reducción modular respecto a $N^2$. En Paillier:
  $$c_{\text{sum}} \equiv c_A \cdot c_B \pmod{N^2}$$
- **Líneas 48-50:** Asegura que el residuo matemático sea no negativo (comportamiento de módulo euclidiano).

```cpp
        if (base_a == 16 || base_b == 16) {
            std::cout << result.get_str(16) << std::endl;
        } else {
            std::cout << result.get_str(10) << std::endl;
        }

        return 0;
```
- **Líneas 53-57:** Formatea la salida. Si los votos entraron en hexadecimal, imprime el resultado en base 16. En caso contrario, imprime en base 10. **Solo se escribe el resultado en `std::cout`**, permitiendo que el servidor Node.js lea el valor limpio por el pipe.
- **Línea 59 (`return 0;`):** Retorna código de salida exitoso.

```cpp
    } catch (const std::exception& e) {
        std::cerr << "Error en cálculo GMP: " << e.what() << std::endl;
        return 1;
    }
}
```
- **Líneas 60-63:** Captura cualquier excepción de memoria o formato en GMP, la reporta en `std::cerr` y devuelve código de falla `1`.

---

## 2. `server.js` (Servidor API REST Express)

`server.js` orquesta las solicitudes HTTP entrantes, valida la seguridad de los parámetros, delega el cómputo pesado al binario compilado de C++ y mide la latencia con precisión de nanosegundos.

```javascript
const express = require('express');
const { execSync } = require('child_process');
const path = require('path');
```
- **Línea 1 (`const express = require('express');`):** Importa el framework Express para levantar el servidor web.
- **Línea 2 (`const { execSync } = require('child_process');`):** Importa la función síncrona `execSync` de Node.js para ejecutar procesos binarios del sistema operativo.
- **Línea 3 (`const path = require('path');`):** Utilidad para manejar rutas del sistema de archivos de forma agnóstica a la plataforma.

```javascript
const app = express();
app.use(express.json({ limit: '10mb' }));

const BINARY_PATH = path.join(__dirname, 'paillier_core');
```
- **Línea 5 (`const app = express();`):** Crea la instancia de la aplicación Express.
- **Línea 6 (`app.use(express.json({ limit: '10mb' }));`):** Middleware para parsear cuerpos de peticiones JSON, elevando el límite a 10MB para acomodar claves criptográficas de miles de dígitos.
- **Línea 8 (`const BINARY_PATH = ...`):** Resuelve la ruta absoluta hacia el ejecutable `paillier_core`.

```javascript
app.post('/api/tally', (req, res) => {
  try {
    const { votoA, votoB, n_cuadrado } = req.body;
```
- **Línea 10 (`app.post('/api/tally', ...)`):** Define el endpoint HTTP POST `/api/tally` para la totalización de votos.
- **Línea 11-12:** Extrae del cuerpo del request los tres campos obligatorios: `votoA`, `votoB` y `n_cuadrado`.

```javascript
    if (!votoA || !votoB || !n_cuadrado) {
      return res.status(400).json({
        error: 'Parámetros requeridos faltantes: votoA, votoB, n_cuadrado'
      });
    }
```
- **Líneas 14-18:** Valida que ninguno de los tres argumentos sea nulo o indefinido. En caso de ausencia, responde con código HTTP 400 (Bad Request).

```javascript
    const safeNumRegex = /^(0x[0-9a-fA-F]+|[0-9]+)$/;
    if (!safeNumRegex.test(votoA) || !safeNumRegex.test(votoB) || !safeNumRegex.test(n_cuadrado)) {
      return res.status(400).json({
        error: 'Entrada inválida. Los valores deben ser cadenas numéricas en base 10 o base 16 (0x...)'
      });
    }
```
- **Línea 21 (`const safeNumRegex = ...`):** Expresión regular que garantiza que los parámetros contengan **únicamente** dígitos decimales (`[0-9]+`) o hexadecimales con prefijo `0x`.
- **Líneas 22-26:** **Mitigación de seguridad crítica**: previene ataques de inyección de comandos en `execSync` al bloquear metacaracteres shell (como `;`, `|`, `&`, `$`, comillas o backticks).

```javascript
    const startTime = process.hrtime.bigint();
    const output = execSync(`"${BINARY_PATH}" "${votoA}" "${votoB}" "${n_cuadrado}"`, {
      encoding: 'utf-8',
      timeout: 5000
    });
    const endTime = process.hrtime.bigint();
```
- **Línea 29 (`const startTime = process.hrtime.bigint();`):** Marca de tiempo de alta precisión en nanosegundos antes de invocar el binario.
- **Líneas 30-33 (`execSync(...)`):** Ejecuta el binario C++ compilado pasando los tres parámetros entrecomillados. Configura un timeout defensivo de 5 segundos y codificación UTF-8.
- **Línea 34 (`const endTime = process.hrtime.bigint();`):** Marca de tiempo posterior a la finalización del binario.

```javascript
    const executionTimeMs = Number(endTime - startTime) / 1e6;

    return res.json({
      status: 'success',
      operation: 'Paillier Homomorphic Addition ((votoA * votoB) mod n_cuadrado)',
      resultado: output.trim(),
      executionTimeMs: parseFloat(executionTimeMs.toFixed(4))
    });
```
- **Línea 36:** Calcula el tiempo transcurrido en milisegundos dividiendo la diferencia de nanosegundos entre $10^6$.
- **Líneas 38-43:** Responde al cliente con un objeto JSON que incluye el estado, el resultado matemático limpio (`output.trim()`) y el tiempo de cómputo en milisegundos.

```javascript
  } catch (error) {
    console.error('[QoriCore Error]:', error.message);
    return res.status(500).json({
      error: 'Error interno en la ejecución del acelerador criptográfico',
      details: error.stderr ? error.stderr.toString() : error.message
    });
  }
});
```
- **Líneas 44-51:** Captura errores de ejecución (errores de C++, violaciones de timeout o problemas de memoria), registrándolos en consola y respondiendo con un error HTTP 500 estructurado.

```javascript
const PORT = process.env.PORT || 8080;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`[QoriCore Server] Acelerador criptográfico escuchando en http://0.0.0.0:${PORT}`);
});
```
- **Línea 53 (`const PORT = ...`):** Configura el puerto de escucha (8080 por defecto).
- **Líneas 54-56:** Enlaza el servidor en todas las interfaces de red (`0.0.0.0`), indispensable para recibir tráfico dentro de un contenedor Docker.

---

## 3. `Dockerfile` (Contenedor de Compilación y Runtime)

Empaqueta tanto el compilador C++ como el runtime de Node.js en una imagen autocontenida sobre Ubuntu 22.04 LTS.

```dockerfile
FROM ubuntu:22.04
```
- **Línea 1:** Imagen base oficial Ubuntu 22.04 (Jammy Jellyfish), compatible y estable para paquetes C++ y Node.

```dockerfile
ENV DEBIAN_FRONTEND=noninteractive
```
- **Línea 3:** Variable de entorno que suprime cualquier prompt interactivo durante la instalación de paquetes.

```dockerfile
RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ \
    make \
    libgmp-dev \
    nodejs \
    npm \
    curl \
    && rm -rf /var/lib/apt/lists/*
```
- **Líneas 6-13:** Actualiza los repositorios de paquetes e instala:
  - `g++` y `make`: Cadena de compilación de C++.
  - `libgmp-dev`: Cabeceras y bibliotecas estáticas/dinámicas de GNU GMP (`<gmpxx.h>`, `libgmp`, `libgmpxx`).
  - `nodejs` y `npm`: Entorno de ejecución de JavaScript y gestor de paquetes.
  - `curl`: Utilidad cliente para comprobaciones de salud del servicio.
  - `rm -rf /var/lib/apt/lists/*`: Elimina la caché de índices de apt para mantener la imagen lo más ligera posible.

```dockerfile
WORKDIR /app
```
- **Línea 15:** Establece el directorio de trabajo interno en `/app`.

```dockerfile
COPY package*.json ./
RUN npm install --omit=dev
```
- **Líneas 18-19:** Copia los manifiestos de dependencias e instala únicamente dependencias de producción (`express`), aprovechando la caché de capas de Docker.

```dockerfile
COPY paillier_core.cpp server.js ./
```
- **Línea 22:** Copia el código fuente del programa C++ y el servidor Node.js al contenedor.

```dockerfile
RUN g++ -O3 paillier_core.cpp -lgmpxx -lgmp -o paillier_core && chmod +x paillier_core
```
- **Línea 25:** Compila el ejecutable nativo:
  - `-O3`: Nivel máximo de optimización del compilador (desenrollado de bucles, auto-vectorización SIMD y *inlining* agresivo).
  - `-lgmpxx`: Enlaza la capa C++ de GMP.
  - `-lgmp`: Enlaza la biblioteca central de C de GMP.
  - `-o paillier_core`: Nombre del binario generado.
  - `chmod +x paillier_core`: Asigna permisos de ejecución.

```dockerfile
EXPOSE 8080
CMD ["node", "server.js"]
```
- **Línea 27:** Documenta que el contenedor escucha en el puerto 8080.
- **Línea 29:** Comando por defecto al levantar el contenedor: inicia el servidor Express.

---

## 4. `build_qoricore.sh` (Script Unificado de Automatización)

Automatiza la creación de los archivos fuente mediante *heredocs* (`cat << 'EOF'`), compila la imagen Docker, levanta el contenedor y ejecuta una prueba de estrés criptográfica con `curl`.

```bash
#!/usr/bin/env bash
set -euo pipefail
```
- **Línea 1:** Shebang que especifica el intérprete Bash mediante el entorno del sistema.
- **Línea 5 (`set -euo pipefail`):** Modo estricto de Bash:
  - `-e`: Aborta el script inmediatamente si cualquier comando falla.
  - `-u`: Trata variables no declaradas como error.
  - `-o pipefail`: Si un pipe falla en cualquier eslabón, todo el pipeline retorna ese código de fallo.

```bash
cat << 'EOF' > package.json
...
EOF
```
- **Líneas 14-27:** Genera el archivo `package.json` de manera idempotente usando comillas en `'EOF'` para evitar que variables de Bash se expandan dentro del bloque.

```bash
cat << 'EOF' > paillier_core.cpp
...
EOF
```
- **Líneas 30-98:** Escribe el código fuente en C++ para `paillier_core.cpp`.

```bash
cat << 'EOF' > server.js
...
EOF
```
- **Líneas 101-163:** Escribe el código del microservicio en Node.js para `server.js`.

```bash
cat << 'EOF' > Dockerfile
...
EOF
```
- **Líneas 166-196:** Escribe el `Dockerfile`.

```bash
IMAGE_NAME="qoricore"
CONTAINER_NAME="qoricore-app"

docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
docker build -t "${IMAGE_NAME}" .
docker run -d --name "${CONTAINER_NAME}" -p 8080:8080 "${IMAGE_NAME}"
```
- **Líneas 200-201:** Define variables de configuración para el nombre de la imagen y el contenedor.
- **Línea 204:** Limpieza preventiva: detiene y elimina cualquier contenedor previo con el mismo nombre si estuviera activo.
- **Línea 205:** Construye la imagen Docker etiquetada como `qoricore`.
- **Línea 206:** Inicia el contenedor en modo *detached* (`-d`), mapeando el puerto `8080:8080`.

```bash
echo "Esperando inicialización del servicio..."
sleep 3
```
- **Líneas 208-209:** Pausa de 3 segundos para garantizar que el servidor Node.js haya inicializado completamente y esté aceptando conexiones en el socket.

```bash
VOTO_A="123456789012345678901234567890123456789012345678901234567890"
VOTO_B="987654321098765432109876543210987654321098765432109876543210"
N_CUADRADO="999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999"
```
- **Líneas 214-216:** Define el payload criptográfico con cadenas gigantes de 60 dígitos simulando textos cifrados de Paillier y un módulo $N^2$ de 120 dígitos.

```bash
curl -s -X POST http://localhost:8080/api/tally \
     -H "Content-Type: application/json" \
     -d "{
       \"votoA\": \"${VOTO_A}\",
       \"votoB\": \"${VOTO_B}\",
       \"n_cuadrado\": \"${N_CUADRADO}\"
     }"
```
- **Líneas 224-230:** Ejecuta la petición HTTP POST contra el contenedor local y muestra directamente en la terminal el JSON con la respuesta y el tiempo de ejecución en milisegundos.

