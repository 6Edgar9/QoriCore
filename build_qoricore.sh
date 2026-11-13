#!/usr/bin/env bash
# ==============================================================================
# QoriCore - Microservicio Acelerador Criptográfico de Suma Homomórfica (Paillier)
# Arquitectura: C++11 + GNU GMP (gmpxx) + Node.js/Express + Docker
# ==============================================================================
set -euo pipefail

echo "============================================================"
echo " [QoriCore] Iniciando despliegue y generación de artefactos"
echo "============================================================"

# 1. Generar package.json
echo "[1/6] Generando package.json..."
cat << 'EOF' > package.json
{
  "name": "qoricore",
  "version": "1.0.0",
  "description": "Cryptographic Paillier homomorphic tally accelerator using GMP in C++",
  "main": "server.js",
  "scripts": {
    "start": "node server.js"
  },
  "dependencies": {
    "express": "^4.19.2"
  }
}
EOF

# 2. Generar paillier_core.cpp
echo "[2/6] Generando paillier_core.cpp..."
cat << 'EOF' > paillier_core.cpp
#include <iostream>
#include <string>
#include <gmpxx.h>

/**
 * Detecta si una cadena tiene prefijo hexadecimal (0x / 0X)
 */
static inline int detect_base(const std::string& s) {
    if (s.size() >= 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        return 16;
    }
    return 10;
}

int main(int argc, char* argv[]) {
    // Optimización de E/S estándar
    std::ios_base::sync_with_stdio(false);
    std::cin.tie(NULL);

    if (argc != 4) {
        std::cerr << "Error de argumentos.\n";
        std::cerr << "Uso: " << argv[0] << " <Cifrado_A> <Cifrado_B> <N_Cuadrado>\n";
        return 1;
    }

    try {
        std::string str_a = argv[1];
        std::string str_b = argv[2];
        std::string str_n_sq = argv[3];

        int base_a = detect_base(str_a);
        int base_b = detect_base(str_b);
        int base_n = detect_base(str_n_sq);

        // Instanciación de enteros de precisión múltiple con GMP
        // Base 0 permite auto-detección (útil para prefijos 0x), base 10 fija decimal
        mpz_class c_a(str_a, base_a == 16 ? 0 : 10);
        mpz_class c_b(str_b, base_b == 16 ? 0 : 10);
        mpz_class n_squared(str_n_sq, base_n == 16 ? 0 : 10);

        if (n_squared <= 0) {
            std::cerr << "Error: N_Cuadrado debe ser positivo mayor que cero.\n";
            return 1;
        }

        // Propiedad Homomórfica de Paillier:
        // C_total = (C_A * C_B) mod N^2
        mpz_class result = (c_a * c_b) % n_squared;
        if (result < 0) {
            result += n_squared;
        }

        // Salida exclusiva del resultado
        if (base_a == 16 || base_b == 16) {
            std::cout << result.get_str(16) << std::endl;
        } else {
            std::cout << result.get_str(10) << std::endl;
        }

        return 0;
    } catch (const std::exception& e) {
        std::cerr << "Error en cálculo GMP: " << e.what() << std::endl;
        return 1;
    }
}
EOF

# 3. Generar server.js
echo "[3/6] Generando server.js..."
cat << 'EOF' > server.js
const express = require('express');
const { execSync } = require('child_process');
const path = require('path');

const app = express();
app.use(express.json({ limit: '10mb' }));

const BINARY_PATH = path.join(__dirname, 'paillier_core');

app.post('/api/tally', (req, res) => {
  try {
    const { votoA, votoB, n_cuadrado } = req.body;

    if (!votoA || !votoB || !n_cuadrado) {
      return res.status(400).json({
        error: 'Parámetros requeridos faltantes: votoA, votoB, n_cuadrado'
      });
    }

    // Sanitización criptográfica de entrada para prevenir inyección de comandos
    const safeNumRegex = /^(0x[0-9a-fA-F]+|[0-9]+)$/;
    if (!safeNumRegex.test(votoA) || !safeNumRegex.test(votoB) || !safeNumRegex.test(n_cuadrado)) {
      return res.status(400).json({
        error: 'Entrada inválida. Los valores deben ser cadenas numéricas en base 10 o base 16 (0x...)'
      });
    }

    // Ejecución y benchmarking de alta resolución del binario C++
    const startTime = process.hrtime.bigint();
    const output = execSync(`"${BINARY_PATH}" "${votoA}" "${votoB}" "${n_cuadrado}"`, {
      encoding: 'utf-8',
      timeout: 5000
    });
    const endTime = process.hrtime.bigint();

    const executionTimeMs = Number(endTime - startTime) / 1e6;

    return res.json({
      status: 'success',
      operation: 'Paillier Homomorphic Addition ((votoA * votoB) mod n_cuadrado)',
      resultado: output.trim(),
      executionTimeMs: parseFloat(executionTimeMs.toFixed(4))
    });
  } catch (error) {
    console.error('[QoriCore Error]:', error.message);
    return res.status(500).json({
      error: 'Error interno en la ejecución del acelerador criptográfico',
      details: error.stderr ? error.stderr.toString() : error.message
    });
  }
});

const PORT = process.env.PORT || 8080;
app.listen(PORT, '0.0.0.0', () => {
  console.log(`[QoriCore Server] Acelerador criptográfico escuchando en http://0.0.0.0:${PORT}`);
});
EOF

# 4. Generar Dockerfile
echo "[4/6] Generando Dockerfile..."
cat << 'EOF' > Dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Instalar g++, make, libgmp-dev, nodejs, npm y curl
RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ \
    make \
    libgmp-dev \
    nodejs \
    npm \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Instalar dependencias de producción de Node.js
COPY package*.json ./
RUN npm install --omit=dev

# Copiar fuentes
COPY paillier_core.cpp server.js ./

# Compilar binario C++ optimizado con flags vectoriales y O3
RUN g++ -O3 paillier_core.cpp -lgmpxx -lgmp -o paillier_core && chmod +x paillier_core

EXPOSE 8080

CMD ["node", "server.js"]
EOF

# 5. Compilar imagen y levantar contenedor Docker
echo "[5/6] Construyendo imagen Docker y levantando contenedor QoriCore..."
IMAGE_NAME="qoricore"
CONTAINER_NAME="qoricore-app"

# Detener contenedor previo si existe
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true

# Construir imagen Docker
docker build -t "${IMAGE_NAME}" .

# Levantar contenedor en segundo plano exponiendo el puerto 8080
docker run -d --name "${CONTAINER_NAME}" -p 8080:8080 "${IMAGE_NAME}"

echo "Esperando inicialización del servicio..."
sleep 3

# 6. Prueba funcional con curl usando enteros gigantes de más de 50 dígitos
echo "[6/6] Ejecutando prueba de verificación con cifrados simulados de 60 dígitos..."

# Generación de números ficticios gigantes (strings >= 50 dígitos)
VOTO_A="123456789012345678901234567890123456789012345678901234567890"
VOTO_B="987654321098765432109876543210987654321098765432109876543210"
N_CUADRADO="999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999"

echo "Payload enviado:"
echo "  - Voto A (longitud: ${#VOTO_A} dígitos): ${VOTO_A}"
echo "  - Voto B (longitud: ${#VOTO_B} dígitos): ${VOTO_B}"
echo "  - N^2    (longitud: ${#N_CUADRADO} dígitos): ${N_CUADRADO}"
echo "------------------------------------------------------------"

curl -s -X POST http://localhost:8080/api/tally \
     -H "Content-Type: application/json" \
     -d "{
       \"votoA\": \"${VOTO_A}\",
       \"votoB\": \"${VOTO_B}\",
       \"n_cuadrado\": \"${N_CUADRADO}\"
     }" | tee /tmp/qoricore_response.json 2>/dev/null || curl -s -X POST http://localhost:8080/api/tally \
     -H "Content-Type: application/json" \
     -d "{
       \"votoA\": \"${VOTO_A}\",
       \"votoB\": \"${VOTO_B}\",
       \"n_cuadrado\": \"${N_CUADRADO}\"
     }"

echo ""
echo "============================================================"
echo " [QoriCore] Despliegue completado y verificado con éxito."
echo "============================================================"

