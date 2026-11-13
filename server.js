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
