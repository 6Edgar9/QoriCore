#!/usr/bin/env bash
set -euo pipefail

echo "======================================================================"
echo " [QoriCore] Benchmark de Estrés en Memoria (20 Millones de Votos)"
echo "======================================================================"

# 1. Generar el código C++ del Benchmark
cat << 'EOF' > benchmark.cpp
#include <iostream>
#include <string>
#include <chrono>
#include <vector>
#include <thread>
#include <gmpxx.h>
#include <iomanip>

// Función que ejecutará cada hilo del procesador
void perform_tally_batch(size_t iterations, const std::string& str_a, const std::string& str_b, const std::string& str_n) {
    mpz_class c_a(str_a, 10);
    mpz_class c_b(str_b, 10);
    mpz_class n_squared(str_n, 10);
    mpz_class result;

    for (size_t i = 0; i < iterations; ++i) {
        // (c_A * c_B) mod N^2
        result = (c_a * c_b) % n_squared;
        if (result < 0) result += n_squared;
        
        // Evitamos que el compilador O3 borre el bucle considerándolo "código inútil"
        if (result == 0) c_a = 1; 
    }
}

int main() {
    // Objetivo: 20 Millones de operaciones
    size_t total_iterations = 20000000; 
    
    // Detectar los hilos lógicos de tu procesador (ej. Intel Core i7)
    size_t num_threads = std::thread::hardware_concurrency();
    if(num_threads == 0) num_threads = 4;

    size_t iterations_per_thread = total_iterations / num_threads;

    std::string votoA = "123456789012345678901234567890123456789012345678901234567890";
    std::string votoB = "987654321098765432109876543210987654321098765432109876543210";
    std::string n_cuadrado = "999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999";

    std::cout << "[*] Iniciando Benchmark Homomorfico (Fuerza Bruta C++ nativo)" << std::endl;
    std::cout << "[*] Total de Votos a Procesar: " << total_iterations << std::endl;
    std::cout << "[*] Hilos concurrentes de CPU detectados: " << num_threads << std::endl;
    std::cout << "[*] Procesando (esto exigira tu procesador al 100%)..." << std::endl;

    auto start_time = std::chrono::high_resolution_clock::now();

    // Lanzar la artillería multihilo
    std::vector<std::thread> threads;
    for (size_t i = 0; i < num_threads; ++i) {
        size_t iters = iterations_per_thread;
        if (i == num_threads - 1) iters += (total_iterations % num_threads);
        threads.emplace_back(perform_tally_batch, iters, votoA, votoB, n_cuadrado);
    }

    // Esperar a que todos los hilos terminen
    for (auto& t : threads) {
        t.join();
    }

    auto end_time = std::chrono::high_resolution_clock::now();
    std::chrono::duration<double> duration_seconds = end_time - start_time;
    double ops_per_second = total_iterations / duration_seconds.count();

    std::cout << "\n========================================================" << std::endl;
    std::cout << " [ RESULTADOS DEL BENCHMARK ]" << std::endl;
    std::cout << "========================================================" << std::endl;
    std::cout << " Tiempo Total de Ejecucion: " << std::fixed << std::setprecision(2) << duration_seconds.count() << " segundos" << std::endl;
    std::cout << " Throughput Matematico:     " << std::fixed << std::setprecision(0) << ops_per_second << " operaciones/seg" << std::endl;
    std::cout << "========================================================\n" << std::endl;
    
    return 0;
}
EOF

# 2. Generar el Dockerfile para el Benchmark
cat << 'EOF' > Dockerfile.bench
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
RUN apt-get update && apt-get install -y --no-install-recommends g++ make libgmp-dev && rm -rf /var/lib/apt/lists/*
WORKDIR /app
COPY benchmark.cpp ./
# Compilación con máxima optimización vectorial y pthreads
RUN g++ -std=c++17 -O3 benchmark.cpp -lgmpxx -lgmp -lpthread -o qoricore_benchmark && chmod +x qoricore_benchmark
CMD ["./qoricore_benchmark"]
EOF

# 3. Compilar y Ejecutar
docker build -f Dockerfile.bench -t qoricore-benchmark .
echo " "
echo ">> INICIANDO CONTENEDOR DE PRUEBA EXTREMA <<"
docker run --rm qoricore-benchmark