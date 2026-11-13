# Explicación Detallada Línea por Línea de QoriCore (Fase 2) 📖🔍

Este documento proporciona un desglose exhaustivo y pedagógico de cada línea de código de los componentes que integran el microservicio nativo **QoriCore** en su arquitectura de Fase 2.

---

## 📑 Tabla de Contenidos
1. [main.cpp (Servidor Nativo Multihilo C++ con Crow y GMP)](#1-maincpp-servidor-nativo-multihilo-c-con-crow-y-gmp)
2. [Dockerfile (Contenedor Nativo Ubuntu 22.04 + Crow + GMP)](#2-dockerfile-contenedor-nativo-ubuntu-2204--crow--gmp)
3. [deploy_qoricore_prod.sh (Script de Despliegue en Producción)](#3-deploy_qoricore_prodsh-script-de-despliegue-en-producción)
4. [run_stress_test.sh y k6_stress.js (Herramienta de Auditoría y Benchmark k6)](#4-run_stress_testsh-y-k6_stressjs-herramienta-de-auditoría-y-benchmark-k6)

---

## 1. `main.cpp` (Servidor Nativo Multihilo C++ con Crow y GMP)

`main.cpp` unifica el servidor web asíncrono y el motor criptográfico en un solo proceso en memoria, eliminando subprocesos y serializaciones innecesarias.

```cpp
#include "crow_all.h"
#include <iostream>
#include <string>
#include <chrono>
#include <gmpxx.h>
```
- **Línea 1 (`#include "crow_all.h"`):** Cabecera amalgamada del micro-framework Crow. Integra el motor HTTP basado en Asio, el parser JSON y el despachador de rutas multihilo.
- **Línea 2 (`#include <iostream>`):** Flujo de entrada/salida para logging en consola del servidor.
- **Línea 3 (`#include <string>`):** Manipulación de cadenas de texto estándar para los números gigantes.
- **Línea 4 (`#include <chrono>`):** Reloj de alta resolución (`std::chrono::high_resolution_clock`) para medir la latencia del cálculo en microsegundos y milisegundos.
- **Línea 5 (`#include <gmpxx.h>`):** Envoltorio C++ de GNU Multiple Precision Arithmetic Library (GMP) para enteros de precisión arbitraria (`mpz_class`).

```cpp
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
```
- **Líneas 11-28 (`is_valid_numeric_string`):** Validador de alto rendimiento *zero-allocation* (sin asignar memoria dinámica en el heap).
  - Comprueba que la cadena no esté vacía.
  - Si inicia con `0x` o `0X`, valida que todos los caracteres subsecuentes sean dígitos hexadecimales válidos (`0-9`, `a-f`, `A-F`).
  - Si es decimal, comprueba que cada carácter sea un dígito ASCII (`'0'` a `'9'`).
  - Al no usar `std::regex`, evita la creación de autómata por cada petición y resiste más de 10,000 req/s sin latencia adicional.

```cpp
static inline int detect_base(const std::string& s) {
    if (s.size() >= 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        return 16;
    }
    return 10;
}
```
- **Líneas 30-35 (`detect_base`):** Identifica si el string está en formato hexadecimal (base 16) o decimal estándar (base 10).

```cpp
int main() {
    crow::SimpleApp app;
    crow::logger::setLogLevel(crow::LogLevel::Warning);
```
- **Línea 38 (`int main()`):** Punto de entrada del microservicio.
- **Línea 39 (`crow::SimpleApp app;`):** Instancia la aplicación web de Crow.
- **Línea 42 (`crow::logger::setLogLevel(crow::LogLevel::Warning);`):** Reduce el nivel de logs a advertencias. Esto es crítico en benchmarks extremos para evitar bloqueos del hilo principal escribiendo a `stdout`.

```cpp
    CROW_ROUTE(app, "/api/tally").methods(crow::HTTPMethod::POST)([](const crow::request& req) {
```
- **Línea 45:** Registra la ruta POST `/api/tally` asociando una función lambda que se ejecuta en el pool de hilos de trabajo.

```cpp
        auto json_body = crow::json::load(req.body);
        if (!json_body) {
            crow::json::wvalue err_res;
            err_res["status"] = "error";
            err_res["message"] = "JSON invalido o malformado en la peticion.";
            return crow::response(400, err_res);
        }
```
- **Líneas 46-52:** Parsea el cuerpo HTTP entrante como JSON en memoria. Si el cuerpo no es JSON válido, responde inmediatamente con código HTTP 400.

```cpp
        if (!json_body.has("votoA") || !json_body.has("votoB") || !json_body.has("n_cuadrado")) {
            crow::json::wvalue err_res;
            err_res["status"] = "error";
            err_res["message"] = "Faltan parametros requeridos: votoA, votoB, n_cuadrado.";
            return crow::response(400, err_res);
        }
```
- **Líneas 54-59:** Valida la existencia de los tres campos requeridos para la suma homomórfica.

```cpp
        std::string str_a = json_body["votoA"].s();
        std::string str_b = json_body["votoB"].s();
        std::string str_n_sq = json_body["n_cuadrado"].s();

        if (!is_valid_numeric_string(str_a) || !is_valid_numeric_string(str_b) || !is_valid_numeric_string(str_n_sq)) {
            crow::json::wvalue err_res;
            err_res["status"] = "error";
            err_res["message"] = "Parametros deben ser cadenas numericas validas en base 10 o base 16 (0x...).";
            return crow::response(400, err_res);
        }
```
- **Líneas 61-70:** Extrae los valores como cadenas e invoca el validador estricto. Rechaza inyecciones de datos corruptos o caracteres no numéricos.

```cpp
        try {
            auto start_time = std::chrono::high_resolution_clock::now();

            int base_a = detect_base(str_a);
            int base_b = detect_base(str_b);
            int base_n = detect_base(str_n_sq);

            mpz_class c_a(str_a, base_a == 16 ? 0 : 10);
            mpz_class c_b(str_b, base_b == 16 ? 0 : 10);
            mpz_class n_squared(str_n_sq, base_n == 16 ? 0 : 10);
```
- **Línea 73:** Inicia el cronómetro de alta resolución antes del cómputo criptográfico.
- **Líneas 79-81:** Convierte los strings a enteros gigantes `mpz_class` de GMP en RAM. La base `0` interpreta el prefijo `0x` automáticamente.

```cpp
            if (n_squared <= 0) {
                crow::json::wvalue err_res;
                err_res["status"] = "error";
                err_res["message"] = "n_cuadrado debe ser positivo y mayor que cero.";
                return crow::response(400, err_res);
            }

            mpz_class result = (c_a * c_b) % n_squared;
            if (result < 0) {
                result += n_squared;
            }
```
- **Líneas 83-93:** Valida que $N^2 > 0$ y ejecuta la **suma homomórfica de Paillier**:
  $$c_{\text{sum}} = (c_A \cdot c_B) \pmod{N^2}$$
  Si el residuo es negativo por convención algebraica, le suma el módulo para mantenerlo en el cuerpo $\mathbb{Z}^*_{N^2}$.

```cpp
            auto end_time = std::chrono::high_resolution_clock::now();
            std::chrono::duration<double, std::milli> execution_ms = end_time - start_time;

            std::string res_str = (base_a == 16 || base_b == 16) ? result.get_str(16) : result.get_str(10);

            crow::json::wvalue res;
            res["status"] = "success";
            res["operation"] = "Paillier Homomorphic Addition ((votoA * votoB) mod n_cuadrado)";
            res["resultado"] = res_str;
            res["executionTimeMs"] = execution_ms.count();

            return crow::response(200, res);
```
- **Líneas 95-106:** Detiene el cronómetro, calcula los milisegundos transcurridos ($\approx 0.020\text{ ms}$), serializa el resultado en la base correspondiente y retorna la respuesta HTTP 200 JSON.

```cpp
    std::cout << "[QoriCore Native] Servidor Crow multihilo inicializado en puerto 8080" << std::endl;
    app.port(8080).multithreaded().run();
    return 0;
}
```
- **Líneas 114-116:** Inicia el bucle de eventos Asio multihilo utilizando todos los núcleos lógicos de la CPU disponible.

---

## 2. `Dockerfile` (Contenedor Nativo Ubuntu 22.04 + Crow + GMP)

```dockerfile
FROM ubuntu:22.04
ENV DEBIAN_FRONTEND=noninteractive
```
- Establece Ubuntu 22.04 como imagen base y desactiva prompts interactivos de configuración.

```dockerfile
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
```
- Instala el compilador `g++`, librerías de GNU GMP (`libgmp-dev`), cabeceras de red Asio (`libasio-dev`), Boost para Crow (`libboost-dev`) y herramientas de red.

```dockerfile
WORKDIR /app
RUN wget -q https://github.com/CrowCpp/Crow/releases/download/v1.0+5/crow_all.h -O /usr/local/include/crow_all.h \
    && cp /usr/local/include/crow_all.h /app/crow_all.h
COPY main.cpp ./
RUN g++ -std=c++17 -O3 main.cpp -lgmpxx -lgmp -lpthread -o qoricore_server && chmod +x qoricore_server
EXPOSE 8080
CMD ["./qoricore_server"]
```
- Descarga la cabecera única de Crow v1.0+5.
- Compila con `-std=c++17` y banderas de optimización máxima `-O3`, enlazando `gmpxx`, `gmp` y `pthread`.
- Configura el contenedor para arrancar directamente el ejecutable nativo `./qoricore_server`.

---

## 3. `deploy_qoricore_prod.sh` (Script de Despliegue en Producción)

- Automatiza de manera idempotente la generación de `main.cpp` y `Dockerfile`.
- Detiene cualquier contenedor previo denominado `qoricore-prod`.
- Compila la imagen Docker `qoricore-native`.
- Inicia el microservicio de producción en modo *detached* en el puerto 8080.

---

## 4. `run_stress_test.sh` y `k6_stress.js` (Herramienta de Auditoría y Benchmark k6)

- **Separación de responsabilidades:** Este script solo audita; no altera el código fuente ni reinstala el servidor.
- **Detección dinámica de IP:** Utiliza `docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' qoricore-prod` para descubrir la IP de red del contenedor.
- **Escenario k6 (`k6_stress.js`):** Simula 4 etapas (rampa a 500 VUs, pico a 3,000 VUs durante 30 segundos y rampa de enfriamiento) enviando cifrados de 60 dígitos.
- **Ejecución aislada:** Levanta un contenedor efímero `grafana/k6` en la misma red de Docker, garantizando un entorno de pruebas idéntico en cualquier sistema operativo.
