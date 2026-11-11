package br.com.ascensaodosoberano.character

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color

/**
 * Retrato compacto em pixel art para aventureiros encontrados no mundo.
 * A paleta muda conforme a classe para facilitar a leitura em escala pequena.
 */
@Composable
fun AventureiroPixelArt(
    classe: String,
    modifier: Modifier = Modifier
) {
    val roupa = when (classe.uppercase()) {
        "MAGA" -> Color(0xFF7054A6)
        "CURANDEIRA" -> Color(0xFF4E9A83)
        "ARQUEIRA", "EXPLORADORA", "EXPLORADOR" -> Color(0xFF557D4A)
        "ASSASSINA" -> Color(0xFF41465E)
        "CAVALEIRO" -> Color(0xFF8797A8)
        else -> Color(0xFF9A633D)
    }
    val detalhe = when (classe.uppercase()) {
        "MAGA" -> Color(0xFFC6A5F2)
        "CURANDEIRA" -> Color(0xFFA8E5C4)
        "ARQUEIRA", "EXPLORADORA", "EXPLORADOR" -> Color(0xFFB7D58A)
        "ASSASSINA" -> Color(0xFF9F9DBD)
        else -> Color(0xFFE8BD72)
    }

    Canvas(modifier = modifier) {
        val unit = size.minDimension / 16f
        val originX = (size.width - unit * 12f) / 2f
        val originY = (size.height - unit * 16f) / 2f

        fun pixel(color: Color, x: Int, y: Int, width: Int = 1, height: Int = 1) {
            drawRect(
                color = color,
                topLeft = Offset(originX + x * unit, originY + y * unit),
                size = Size(width * unit, height * unit)
            )
        }

        val contorno = Color(0xFF171C28)
        val pele = Color(0xFFE8B995)
        val cabelo = when (classe.uppercase()) {
            "MAGA" -> Color(0xFF302C48)
            "CURANDEIRA" -> Color(0xFF5A3D32)
            "ASSASSINA" -> Color(0xFF242735)
            else -> Color(0xFF49352B)
        }

        // Sombra, botas e pernas.
        pixel(Color(0x66000000), 2, 14, 8, 1)
        pixel(contorno, 3, 11, 3, 4)
        pixel(contorno, 6, 11, 3, 4)
        pixel(Color(0xFF35313A), 3, 13, 3, 2)
        pixel(Color(0xFF35313A), 6, 13, 3, 2)

        // Braços e silhueta da roupa.
        pixel(contorno, 1, 6, 3, 6)
        pixel(contorno, 8, 6, 3, 6)
        pixel(roupa, 2, 6, 8, 6)
        pixel(detalhe, 3, 7, 1, 4)
        pixel(detalhe, 8, 7, 1, 4)
        pixel(Color(0xFF4B352A), 2, 11, 8, 1)
        pixel(Color(0xFFE8BD72), 5, 10, 2, 2)

        // Cabeça, cabelo e rosto.
        pixel(contorno, 3, 1, 6, 6)
        pixel(pele, 4, 2, 4, 4)
        pixel(cabelo, 3, 1, 6, 2)
        pixel(cabelo, 3, 2, 1, 4)
        pixel(cabelo, 8, 2, 1, 4)
        pixel(Color(0xFF302C2A), 4, 4, 1, 1)
        pixel(Color(0xFF302C2A), 7, 4, 1, 1)

        // Insígnia de classe e acessórios.
        when (classe.uppercase()) {
            "MAGA" -> {
                pixel(contorno, 3, 0, 6, 2)
                pixel(detalhe, 5, 0, 2, 1)
                pixel(Color(0xFF9B82C8), 5, 8, 2, 2)
            }
            "ARQUEIRA", "EXPLORADORA", "EXPLORADOR" -> {
                pixel(Color(0xFF6B4B2E), 9, 5, 2, 7)
                pixel(detalhe, 10, 4, 1, 2)
            }
            "ASSASSINA" -> {
                pixel(contorno, 3, 2, 6, 2)
                pixel(Color(0xFFB9C5D6), 9, 8, 1, 4)
            }
            "CURANDEIRA" -> {
                pixel(Color(0xFFFFE6A6), 5, 8, 2, 2)
                pixel(Color(0xFFFFE6A6), 4, 9, 4, 1)
            }
            else -> {
                pixel(Color(0xFFB8C5CC), 2, 6, 2, 2)
                pixel(Color(0xFFB8C5CC), 8, 6, 2, 2)
            }
        }
    }
}
