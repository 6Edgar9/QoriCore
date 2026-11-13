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
