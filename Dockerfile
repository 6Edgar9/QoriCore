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
