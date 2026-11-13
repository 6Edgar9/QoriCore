#!/usr/bin/env bash
# ==============================================================================
# QoriCore - Fase 2: Microservicio de Producción Nativo C++ con Crow
# Script 1: deploy_qoricore_prod.sh
# Responsabilidad exclusiva: Construcción y despliegue del entorno funcional
# ==============================================================================
set -euo pipefail

echo "======================================================================"
echo " [QoriCore Fase 2] Despliegue de Servidor Nativo C++ (Producción)"
echo "======================================================================"

# 1. Generar main.cpp (Servidor nativo Crow con GMP)
echo "[1/4] Generando main.cpp con micro-framework Crow y aceleración GMP..."
cat << 'EOF' > main.cpp
#include "crow_all.h"
#include <iostream>
#include <string>
#include <chrono>
#include <gmpxx.h>

/**
 * Validador de alto rendimiento para números en base 10 o base 16 (0x/0X).
 * Implementación 'zero-allocation' para maximizar el throughput bajo alta concurrencia.
 */
static inline bool is_valid_numeric_string(const std::string& s) {
    if (s.empty()) return false;
    size_t i = 0;
    if (s.size() >= 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        if (s.size() == 2) return false;
        for (i = 2; i < s.size(); ++i) {
            char c = s[i];
            if (!((c >= '0' && c <= '9') || (c >= 'a' && c <= 'f') || (c >= 'A' && c <= 'F'))) {
                return false;
            }
        }
        return true;
    }
    for (; i < s.size(); ++i) {
        if (s[i] < '0' || s[i] > '9') return false;
    }
    return true;
}

static inline int detect_base(const std::string& s) {
    if (s.size() >= 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        return 16;
    }
    return 10;
}

int main() {
    crow::SimpleApp app;

    // Nivel de logging a Warning para minimizar contención de E/S en benchmarks extremos
    crow::logger::setLogLevel(crow::LogLevel::Warning);

    // Endpoint POST /api/tally
    CROW_ROUTE(app, "/api/tally").methods(crow::HTTPMethod::POST)([](const crow::request& req) {
        auto json_body = crow::json::load(req.body);
        if (!json_body) {
            crow::json::wvalue err_res;
            err_res["status"] = "error";
            err_res["message"] = "JSON invalido o malformado en la peticion.";
            return crow::response(400, err_res);
        }

        if (!json_body.has("votoA") || !json_body.has("votoB") || !json_body.has("n_cuadrado")) {
            crow::json::wvalue err_res;
            err_res["status"] = "error";
            err_res["message"] = "Faltan parametros requeridos: votoA, votoB, n_cuadrado.";
            return crow::response(400, err_res);
        }

        std::string str_a = json_body["votoA"].s();
        std::string str_b = json_body["votoB"].s();
        std::string str_n_sq = json_body["n_cuadrado"].s();

        if (!is_valid_numeric_string(str_a) || !is_valid_numeric_string(str_b) || !is_valid_numeric_string(str_n_sq)) {
            crow::json::wvalue err_res;
            err_res["status"] = "error";
            err_res["message"] = "Parametros deben ser cadenas numericas validas en base 10 o base 16 (0x...).";
            return crow::response(400, err_res);
        }

        try {
            // Medición de latencia de precisión del cálculo homomórfico nativo
            auto start_time = std::chrono::high_resolution_clock::now();

            int base_a = detect_base(str_a);
            int base_b = detect_base(str_b);
            int base_n = detect_base(str_n_sq);

            mpz_class c_a(str_a, base_a == 16 ? 0 : 10);
            mpz_class c_b(str_b, base_b == 16 ? 0 : 10);
            mpz_class n_squared(str_n_sq, base_n == 16 ? 0 : 10);

            if (n_squared <= 0) {
                crow::json::wvalue err_res;
                err_res["status"] = "error";
                err_res["message"] = "n_cuadrado debe ser positivo y mayor que cero.";
                return crow::response(400, err_res);
            }

            // Suma homomórfica de Paillier: (c_A * c_B) mod N^2
            mpz_class result = (c_a * c_b) % n_squared;
            if (result < 0) {
                result += n_squared;
            }

            auto end_time = std::chrono::high_resolution_clock::now();
            std::chrono::duration<double, std::milli> execution_ms = end_time - start_time;

            std::string res_str = (base_a == 16 || base_b == 16) ? result.get_str(16) : result.get_str(10);

            crow::json::wvalue res;
            res["status"] = "success";
            res["operation"] = "Paillier Homomorphic Addition ((votoA * votoB) mod n_cuadrado)";
            res["resultado"] = res_str;
            res["executionTimeMs"] = execution_ms.count();

            return crow::response(200, res);

        } catch (const std::exception& e) {
            crow::json::wvalue err_res;
            err_res["status"] = "error";
            err_res["message"] = std::string("Fallo en computo GMP: ") + e.what();
            return crow::response(500, err_res);
        }
    });

    std::cout << "[QoriCore Native] Servidor Crow multihilo inicializado en puerto 8080" << std::endl;
    app.port(8080).multithreaded().run();
    return 0;
}
EOF

# 2. Generar Dockerfile de producción
echo "[2/4] Generando Dockerfile optimizado para C++ nativo y Crow..."
cat << 'EOF' > Dockerfile
FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

# Instalación de compilador, librerías criptográficas y cabeceras Asio/Boost
RUN apt-get update && apt-get install -y --no-install-recommends \
    g++ \
    make \
    libgmp-dev \
    libasio-dev \
    libboost-dev \
    wget \
    ca-certificates \
    curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app

# Descarga de la cabecera amalgamada oficial de Crow (v1.0+5)
RUN wget -q https://github.com/CrowCpp/Crow/releases/download/v1.0+5/crow_all.h -O /usr/local/include/crow_all.h \
    && cp /usr/local/include/crow_all.h /app/crow_all.h

# Copiar el código fuente
COPY main.cpp ./

# Compilación con soporte C++17, nivel O3, multihilo y enlace con GNU GMP
RUN g++ -std=c++17 -O3 main.cpp -lgmpxx -lgmp -lpthread -o qoricore_server && chmod +x qoricore_server

EXPOSE 8080

CMD ["./qoricore_server"]
EOF

# 3. Construir la imagen Docker nativa
IMAGE_NAME="qoricore-native"
CONTAINER_NAME="qoricore-prod"

echo "[3/4] Construyendo imagen Docker '${IMAGE_NAME}'..."
docker build -t "${IMAGE_NAME}" .

# 4. Levantar contenedor de producción
echo "[4/4] Levantando contenedor de producción '${CONTAINER_NAME}' en el puerto 8080..."
docker rm -f "${CONTAINER_NAME}" 2>/dev/null || true
docker run -d --name "${CONTAINER_NAME}" -p 8080:8080 "${IMAGE_NAME}"

echo "======================================================================"
echo " [QoriCore] Microservicio de producción desplegado exitosamente!"
echo " Contenedor: ${CONTAINER_NAME}"
echo " Puerto:     http://localhost:8080"
echo " Endpoint:   http://localhost:8080/api/tally"
echo "======================================================================"

