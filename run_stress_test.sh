#!/usr/bin/env bash
# ==============================================================================
# QoriCore - Fase 2: Herramienta de Auditoría y Pruebas de Carga
# Script 2: run_stress_test.sh
# Responsabilidad exclusiva: Pruebas de estrés y benchmarking aislado (Grafana k6)
# ==============================================================================
set -euo pipefail

echo "======================================================================"
echo " [QoriCore Auditoría] Iniciando Suite de Pruebas de Estrés con k6"
echo "======================================================================"

CONTAINER_NAME="qoricore-prod"

# 1. Verificar estado del contenedor de producción
echo "[1/4] Verificando que el contenedor '${CONTAINER_NAME}' esté activo..."
IS_RUNNING=$(docker inspect -f '{{.State.Running}}' "${CONTAINER_NAME}" 2>/dev/null || echo "false")
if [ "${IS_RUNNING}" != "true" ]; then
    echo "[-] ERROR: El contenedor '${CONTAINER_NAME}' no está en ejecución."
    echo "[-] Ejecute primero el script de despliegue: ./deploy_qoricore_prod.sh"
    exit 1
fi
echo "[+] Contenedor de producción activo y listo."

# 2. Obtener automáticamente la IP del contenedor usando docker inspect
echo "[2/4] Extrayendo la dirección IP interna mediante 'docker inspect'..."
TARGET_IP=$(docker inspect -f '{{range .NetworkSettings.Networks}}{{.IPAddress}}{{end}}' "${CONTAINER_NAME}")

if [ -n "${TARGET_IP}" ]; then
    echo "[+] IP interna detectada: ${TARGET_IP}"
    TARGET_ENDPOINT="http://${TARGET_IP}:8080/api/tally"
else
    echo "[!] Red sin IP directa de bridge detectada. Utilizando gateway del host..."
    TARGET_ENDPOINT="http://host.docker.internal:8080/api/tally"
fi

# 3. Generar el script de prueba k6_stress.js (hasta 3,000 usuarios concurrentes)
echo "[3/4] Generando k6_stress.js (simulación de 3,000 usuarios concurrentes y cifrados de 60 dígitos)..."
cat << 'EOF' > k6_stress.js
import http from 'k6/http';
import { check, sleep } from 'k6';

export const options = {
  stages: [
    { duration: '10s', target: 500 },   // Fase de calentamiento: rampa a 500 VUs
    { duration: '20s', target: 3000 },  // Rampa de estrés masivo a 3,000 VUs
    { duration: '30s', target: 3000 },  // Saturación sostenida a 3,000 VUs concurrentes
    { duration: '10s', target: 0 },     // Enfriamiento controlado
  ],
  thresholds: {
    // 95% de las transacciones criptográficas bajo saturación extrema (3,000 VUs)
    http_req_duration: ['p(95)<200'],
    // Tasa de error estricta permitida inferior al 1% bajo saturación
    http_req_failed: ['rate<0.01'],
  },
};

// URL objetivo inyectada mediante variable de entorno o fallback
const TARGET_URL = __ENV.TARGET_URL || 'http://localhost:8080/api/tally';

// Payload criptográfico de Paillier: números de 60 dígitos con módulo de 120 dígitos
const payload = JSON.stringify({
  votoA: "123456789012345678901234567890123456789012345678901234567890",
  votoB: "987654321098765432109876543210987654321098765432109876543210",
  n_cuadrado: "999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999"
});

const params = {
  headers: {
    'Content-Type': 'application/json',
  },
  timeout: '5s',
};

export default function () {
  const res = http.post(TARGET_URL, payload, params);

  check(res, {
    'código de respuesta es 200': (r) => r.status === 200,
    'suma homomórfica procesada': (r) => r.body && r.body.includes('resultado'),
  });
}
EOF

# 4. Ejecutar el contenedor temporal de k6 apuntando al microservicio
echo "[4/4] Ejecutando contenedor efímero de Grafana k6 contra: ${TARGET_ENDPOINT}..."
echo "======================================================================"

# Se conecta a la misma red Docker y se añade host-gateway para máxima compatibilidad
DOCKER_NET=$(docker inspect -f '{{range $net, $val := .NetworkSettings.Networks}}{{$net}}{{end}}' "${CONTAINER_NAME}")
DOCKER_NET=${DOCKER_NET:-bridge}

docker run --rm -i \
    --network "${DOCKER_NET}" \
    --add-host=host.docker.internal:host-gateway \
    -e TARGET_URL="${TARGET_ENDPOINT}" \
    grafana/k6 run - < k6_stress.js || true

echo "======================================================================"
echo " [QoriCore Auditoría] Prueba de estrés completada."
echo "======================================================================"

