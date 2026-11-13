# QoriCore ⚡🔐

> **Microservicio Acelerador Criptográfico Nativo (C++ / Crow / GMP) para Escrutinio en Blockchain**

[![C++17](https://img.shields.io/badge/C%2B%2B-17%20%7C%20Crow%20%7C%20GNU%20GMP-blue.svg)](https://crowcpp.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg)](https://www.docker.com/)
[![k6](https://img.shields.io/badge/Grafana%20k6-Audited%20%7C%203k%20VUs-purple.svg)](https://k6.io/)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](#licencia)

---

## 📌 Visión General

**QoriCore** es un microservicio de computación acelerada off-chain diseñado para sistemas de votación digital transparente y gobernanza descentralizada en blockchain.

En votaciones con preservación de privacidad, los sufragios se emiten cifrados mediante el **criptosistema de Paillier**. Sin embargo, la computación modular con enteros de miles de bits (2048 - 4096 bits) en smart contracts (como EVM) resulta prohibitivamente costosa en consumo de *gas* o impracticable en tiempo real.

**QoriCore Fase 2** elimina cualquier puente de scripting externo y se ejecuta como un **servidor nativo multihilo en C++17** utilizando el micro-framework **Crow** y la biblioteca **GNU Multiple Precision Arithmetic Library (GMP)** para cómputo directo en memoria, soportando más de **13,000 req/s** con latencias internas de **20 microsegundos**.

---

## 🔬 Fundamento Criptográfico: Suma Homomórfica de Paillier

El criptosistema de Paillier posee la propiedad de **homomorfismo aditivo**.

Dado un módulo público $N$ (donde $N = p \cdot q$ para primos seguros $p, q$) y la clave pública $(N, g)$ bajo el espacio de texto cifrado $\mathbb{Z}^*_{N^2}$:

1. **Cifrado de votos individuales:**
   $$c_1 = g^{m_1} \cdot r_1^N \pmod{N^2}$$
   $$c_2 = g^{m_2} \cdot r_2^N \pmod{N^2}$$

2. **Propiedad homomórfica aditiva:**
   Al multiplicar algebraicamente los dos textos cifrados módulo $N^2$:
   $$c_{\text{sum}} = (c_1 \cdot c_2) \pmod{N^2}$$

3. **Descifrado de la suma final:**
   $$\mathcal{D}(c_{\text{sum}}) = (m_1 + m_2) \pmod{N}$$

> [!IMPORTANT]
> **QoriCore** ejecuta exclusivamente la operación modular $(c_1 \cdot c_2) \pmod{N^2}$. El servicio **no conoce ni requiere la clave privada** del escrutador, preservando el secreto absoluto del voto de cada elector.

---

## 🏗️ Arquitectura del Sistema (Fase 2)

```
+--------------------------------------------------------------+
|                     Cliente / Nodo Blockchain                |
+--------------------------------------------------------------+
                               |
                   POST /api/tally (JSON)
            { votoA, votoB, n_cuadrado }
                               |
                               v
+--------------------------------------------------------------+
|             Contenedor Docker (qoricore-prod:8080)           |
|                                                              |
|  +--------------------------------------------------------+  |
|  |     Servidor Nativo Multihilo C++17 (main.cpp)         |  |
|  |  - Micro-framework Crow (Asio / multithreaded pool)    |  |
|  |  - Parser JSON en memoria y validación zero-allocation |  |
|  |  - Medición de latencia std::chrono alta resolución    |  |
|  +--------------------------------------------------------+  |
|                              |                               |
|                   Aritmética Directa en RAM                  |
|                              |                               |
|  +--------------------------------------------------------+  |
|  |         Núcleo Criptográfico: GNU GMP (gmpxx)          |  |
|  |  - mpz_class enteros gigantes (2048 - 4096 bits)       |  |
|  |  - Reducción modular: (A * B) % N^2                    |  |
|  |  - Compilado con g++ -O3 SIMD vectorization            |  |
|  +--------------------------------------------------------+  |
|                                                              |
+--------------------------------------------------------------+
```

---

## 📁 Estructura del Repositorio Limpio

```
QoriCore/
├── .gitignore                     # Filtros para binarios, temporales y objetos
├── Dockerfile                     # Imagen de producción nativa (Ubuntu 22.04 + Crow + GMP)
├── deploy_qoricore_prod.sh        # Orquestador del microservicio de producción
├── main.cpp                       # Servidor nativo C++ multihilo con Crow y GMP
├── run_stress_test.sh             # Herramienta aislada de auditoría y pruebas de carga
├── k6_stress.js                   # Escenario k6 (hasta 3,000 VUs y números de 60 dígitos)
├── README.md                      # Documentación de arquitectura y benchmarks
├── EXPLICACION_LINEA_POR_LINEA.md # Guía pedagógica línea por línea del código
└── LICENSE                        # Licencia MIT (Copyright © 2026 Edrem)
```

---

## 🚀 Despliegue y Operación

### 1. Despliegue en Producción
Para compilar la imagen nativa `qoricore-native` y levantar el contenedor `qoricore-prod` en el puerto 8080:

```bash
chmod +x deploy_qoricore_prod.sh
./deploy_qoricore_prod.sh
```

### 2. Auditoría y Pruebas de Estrés (Grafana k6)
Para ejecutar de forma aislada la auditoría con hasta **3,000 usuarios concurrentes**:

```bash
chmod +x run_stress_test.sh
./run_stress_test.sh
```

---

## 📡 Referencia de la API REST

### `POST /api/tally`

Calcula la suma homomórfica de dos votos cifrados de Paillier.

#### Headers
```http
Content-Type: application/json
```

#### Request Body
Acepta enteros arbitrariamente grandes representados como cadenas de texto en **base 10 (decimal)** o **base 16 (hexadecimal con prefijo `0x`)**.

```json
{
  "votoA": "123456789012345678901234567890123456789012345678901234567890",
  "votoB": "987654321098765432109876543210987654321098765432109876543210",
  "n_cuadrado": "999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999"
}
```

#### Response Body (`200 OK`)
```json
{
  "status": "success",
  "operation": "Paillier Homomorphic Addition ((votoA * votoB) mod n_cuadrado)",
  "resultado": "121932631137021795226185032733866788594511507391563633592367367779295611949397448712086533622923332237463801111263526900",
  "executionTimeMs": 0.0204
}
```

---

## ⚡ Rendimiento y Benchmarks Auditados

| Métrica | Fase 1 (Node.js + execSync) | Fase 2 (Nativo C++ Crow + GMP) | Mejora |
|---|---|---|---|
| **Latencia de Cómputo C++** | $\approx 3.60\text{ ms}$ | $\approx 0.020\text{ ms}$ ($20\ \mu\text{s}$) | **180x más veloz** |
| **Throughput Pico (k6)** | $\approx 250\text{ req/s}$ | **13,782.46 req/s** | **55x más capacidad** |
| **Peticiones Totales (70s)** | $\approx 15,000$ | **964,717** | **Escalabilidad masiva** |
| **Tasa de Error (3k VUs)** | $> 2.5\%$ (por agotamiento de pipes) | **0.00%** (0 fallas) | **Cero pérdida de votos** |

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.

---
Dios, Assembly y la Patria
Edrem