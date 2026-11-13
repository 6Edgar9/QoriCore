# QoriCore ⚡🔐

> **Microservicio Acelerador Criptográfico de Suma Homomórfica para Escrutinio en Blockchain**

[![C++11](https://img.shields.io/badge/C%2B%2B-11%20%7C%20GNU%20GMP-blue.svg)](https://gmplib.org/)
[![Node.js](https://img.shields.io/badge/Node.js-18%2B-green.svg)](https://nodejs.org/)
[![Docker](https://img.shields.io/badge/Docker-Ready-2496ED.svg)](https://www.docker.com/)
[![License](https://img.shields.io/badge/License-MIT-purple.svg)](#licencia)

---

## 📌 Visión General

**QoriCore** es un microservicio de alto rendimiento diseñado como capa de aceleración criptográfica off-chain para sistemas de votación digital y gobernanza descentralizada en blockchain.

En elecciones transparentes con preservación de la privacidad, los votos se emiten cifrados utilizando el **criptosistema de Paillier**. Sin embargo, la computación modular con enteros de miles de bits (2048 - 4096 bits) en smart contracts (como EVM) resulta prohibitivamente costosa en consumo de *gas* o impracticable en tiempo real. 

**QoriCore** resuelve este cuello de botella ejecutando las operaciones aritméticas homomórficas en C++ nativo utilizando **GNU Multiple Precision Arithmetic Library (GMP)**, expuesto mediante un API REST liviano en Node.js y encapsulado en Docker.

---

## 🔬 Fundamento Criptográfico: Suma Homomórfica de Paillier

El criptosistema de Paillier posee la propiedad de **homomorfismo aditivo**. 

Dado un módulo público $N$ (donde $N = p \cdot q$ para primos seguros $p, q$) y la clave pública $(N, g)$ bajo el espacio de texto cifrado $\mathbb{Z}^*_{N^2}$:

1. **Cifrado de votos:**
   $$c_1 = g^{m_1} \cdot r_1^N \pmod{N^2}$$
   $$c_2 = g^{m_2} \cdot r_2^N \pmod{N^2}$$

2. **Propiedad homomórfica aditiva:**
   Al multiplicar algebraicamente los dos textos cifrados módulo $N^2$:
   $$c_{\text{sum}} = (c_1 \cdot c_2) \pmod{N^2}$$

3. **Descifrado de la suma:**
   $$\mathcal{D}(c_{\text{sum}}) = (m_1 + m_2) \pmod{N}$$

> [!IMPORTANT]
> **QoriCore** ejecuta exclusivamente la operación modular $(c_1 \cdot c_2) \pmod{N^2}$. Esto garantiza que **el servicio no conoce ni necesita la clave privada** del escrutador, preservando el secreto absoluto del voto de cada elector.

---

## 🏗️ Arquitectura del Sistema

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
|                    Contenedor Docker (QoriCore)              |
|                                                              |
|  +--------------------------------------------------------+  |
|  |       Capa API: Node.js / Express (server.js)          |  |
|  |  - Validación & sanitización de expresiones regex      |  |
|  |  - Medición de latencia de precisión (hrtime.bigint)   |  |
|  +--------------------------------------------------------+  |
|                              |                               |
|                     child_process.execSync                   |
|                              |                               |
|  +--------------------------------------------------------+  |
|  |      Núcleo Nativo: C++ / GNU GMP (paillier_core)      |  |
|  |  - Aritmética multiprecisión con mpz_class             |  |
|  |  - Multiplicación y reducción modular (A * B) % N^2    |  |
|  |  - Compilado con g++ -O3 para máxima vectorización     |  |
|  +--------------------------------------------------------+  |
|                                                              |
+--------------------------------------------------------------+
```

---

## 📁 Estructura del Repositorio

```
QoriCore/
├── .gitignore                     # Filtros para binarios, dependencias y temporales
├── build_qoricore.sh              # Script unificado de despliegue, build y test
├── Dockerfile                     # Imagen contenedor basada en Ubuntu 22.04 + GMP
├── package.json                   # Manifiesto y dependencias de Node.js (Express)
├── paillier_core.cpp              # Acelerador criptográfico en C++ con <gmpxx.h>
├── server.js                      # API REST en Node.js/Express
├── README.md                      # Documentación general de arquitectura
└── EXPLICACION_LINEA_POR_LINEA.md # Análisis detallado línea por línea del código
```

---

## 🚀 Despliegue Rápido

### Requisitos Previos
- **Docker Engine** (20.10+) o Docker Desktop en ejecución.
- Entorno de terminal tipo **Bash** (Linux, macOS, WSL o Git Bash en Windows).
- Utilidad `curl` instalada.

### Ejecución Automática (One-Click)

Ejecuta el script unificado de orquestación:

```bash
chmod +x build_qoricore.sh
./build_qoricore.sh
```

El script se encargará de:
1. Generar todos los archivos fuente de manera limpia.
2. Construir la imagen Docker multi-etapa con las banderas de optimización `g++ -O3`.
3. Desplegar el contenedor exponiendo el puerto `8080`.
4. Ejecutar una prueba de estrés funcional enviando cifrados gigantes de 60 dígitos contra un módulo $N^2$ de 120 dígitos, mostrando la respuesta JSON y el tiempo de cálculo.

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
  "executionTimeMs": 3.6685
}
```

---

## ⚡ Rendimiento y Seguridad

- **Tiempo de ejecución nativo:** $< 4 \text{ ms}$ por operación para módulos estándar de 2048 a 4096 bits.
- **Protección contra inyección:** Toda entrada es validada estrictamente contra la expresión regular `/^(0x[0-9a-fA-F]+|[0-9]+)$/`, eliminando riesgos de inyección de comandos en `child_process`.
- **Aislamiento Docker:** La compilación y ejecución se realizan dentro de un contenedor no privilegiado sin persistencia de estado ni acceso a llaves criptográficas privadas.

---

## 📄 Licencia

Este proyecto está bajo la Licencia MIT. Consulta el archivo [LICENSE](LICENSE) para más detalles.

---
Dios, Assembly y la Patria
Edrem
