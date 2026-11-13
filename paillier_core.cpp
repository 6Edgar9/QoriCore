#include <iostream>
#include <string>
#include <gmpxx.h>

/**
 * Detecta si una cadena tiene prefijo hexadecimal (0x / 0X)
 */
static inline int detect_base(const std::string& s) {
    if (s.size() >= 2 && s[0] == '0' && (s[1] == 'x' || s[1] == 'X')) {
        return 16;
    }
    return 10;
}

int main(int argc, char* argv[]) {
    // Optimización de E/S estándar
    std::ios_base::sync_with_stdio(false);
    std::cin.tie(NULL);

    if (argc != 4) {
        std::cerr << "Error de argumentos.\n";
        std::cerr << "Uso: " << argv[0] << " <Cifrado_A> <Cifrado_B> <N_Cuadrado>\n";
        return 1;
    }

    try {
        std::string str_a = argv[1];
        std::string str_b = argv[2];
        std::string str_n_sq = argv[3];

        int base_a = detect_base(str_a);
        int base_b = detect_base(str_b);
        int base_n = detect_base(str_n_sq);

        // Instanciación de enteros de precisión múltiple con GMP
        // Base 0 permite auto-detección (útil para prefijos 0x), base 10 fija decimal
        mpz_class c_a(str_a, base_a == 16 ? 0 : 10);
        mpz_class c_b(str_b, base_b == 16 ? 0 : 10);
        mpz_class n_squared(str_n_sq, base_n == 16 ? 0 : 10);

        if (n_squared <= 0) {
            std::cerr << "Error: N_Cuadrado debe ser positivo mayor que cero.\n";
            return 1;
        }

        // Propiedad Homomórfica de Paillier:
        // C_total = (C_A * C_B) mod N^2
        mpz_class result = (c_a * c_b) % n_squared;
        if (result < 0) {
            result += n_squared;
        }

        // Salida exclusiva del resultado
        if (base_a == 16 || base_b == 16) {
            std::cout << result.get_str(16) << std::endl;
        } else {
            std::cout << result.get_str(10) << std::endl;
        }

        return 0;
    } catch (const std::exception& e) {
        std::cerr << "Error en cálculo GMP: " << e.what() << std::endl;
        return 1;
    }
}
