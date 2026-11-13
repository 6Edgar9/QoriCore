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
