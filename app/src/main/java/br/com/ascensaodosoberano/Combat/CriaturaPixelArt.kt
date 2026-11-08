package br.com.ascensaodosoberano.combat

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color

/** Retrato provisório em pixel art para criaturas ainda sem arte oficial. */
@Composable
fun CriaturaPixelArt(
    nome: String,
    rank: String,
    chefe: Boolean,
    modifier: Modifier = Modifier
) {
    val especie = nome.lowercase()
    val base = when {
        "lobo" in especie || "raposa" in especie -> Color(0xFF8796A5)
        "slime" in especie || "gosma" in especie -> Color(0xFF62B98B)
        "drag" in especie || "draco" in especie -> Color(0xFFC86B4D)
        "rato" in especie || "roedor" in especie -> Color(0xFF9B8068)
        "aranha" in especie || "inseto" in especie -> Color(0xFF805E9E)
        "esqueleto" in especie || "morto" in especie -> Color(0xFFB6B7A5)
        else -> when (rank.uppercase()) {
            "S", "SS", "SSS" -> Color(0xFF8B65BD)
            "A", "B" -> Color(0xFF4D8FAD)
            "C", "D" -> Color(0xFF9B8054)
            else -> Color(0xFF668B61)
        }
    }
    Canvas(modifier) {
        val p = size.minDimension / 18f
        val x = size.width / 2f
        val y = size.height / 2f
        val sombra = base.copy(red = (base.red * .62f).coerceIn(0f, 1f),
            green = (base.green * .62f).coerceIn(0f, 1f),
            blue = (base.blue * .62f).coerceIn(0f, 1f))
        drawOval(Color(0xAA080D13), Offset(x - p * 6f, y + p * 6f), Size(p * 12f, p * 2f))
        if (chefe) {
            drawCircle(Color(0xFFB88BFF).copy(alpha = .20f), p * 8f, Offset(x, y))
            drawCircle(Color(0xFFFFD879).copy(alpha = .35f), p * 6.5f, Offset(x, y))
        }
        // Cauda e pernas.
        drawRect(sombra, Offset(x + p * 4f, y + p), Size(p * 3f, p * 2f))
        drawRect(sombra, Offset(x - p * 4f, y + p * 4f), Size(p * 2f, p * 3f))
        drawRect(sombra, Offset(x + p * 2f, y + p * 4f), Size(p * 2f, p * 3f))
        // Corpo e cabeça em volumes pixelados.
        drawRect(sombra, Offset(x - p * 5f, y - p * 2f), Size(p * 10f, p * 7f))
        drawRect(base, Offset(x - p * 4f, y - p * 4f), Size(p * 8f, p * 8f))
        drawRect(base.copy(red = (base.red * 1.2f).coerceAtMost(1f),
            green = (base.green * 1.2f).coerceAtMost(1f),
            blue = (base.blue * 1.2f).coerceAtMost(1f)),
            Offset(x - p * 2.5f, y - p * 3.5f), Size(p * 5f, p * 2f))
        // Orelhas ou chifres.
        if (chefe || rank.uppercase() in setOf("S", "SS", "SSS")) {
            drawRect(Color(0xFF3A293B), Offset(x - p * 4f, y - p * 7f), Size(p * 2f, p * 4f))
            drawRect(Color(0xFF3A293B), Offset(x + p * 2f, y - p * 7f), Size(p * 2f, p * 4f))
            drawRect(Color(0xFFFFD879), Offset(x - p * 3.5f, y - p * 6f), Size(p, p * 2f))
            drawRect(Color(0xFFFFD879), Offset(x + p * 2.5f, y - p * 6f), Size(p, p * 2f))
        } else {
            drawRect(sombra, Offset(x - p * 4f, y - p * 6f), Size(p * 2f, p * 3f))
            drawRect(sombra, Offset(x + p * 2f, y - p * 6f), Size(p * 2f, p * 3f))
        }
        // Olhos, focinho e marcas.
        val olho = if (chefe || rank.uppercase() in setOf("S", "SS", "SSS")) Color(0xFFFFD879) else Color(0xFF20202A)
        drawRect(olho, Offset(x - p * 2.5f, y - p * 1f), Size(p * 1.4f, p * 1.4f))
        drawRect(olho, Offset(x + p * 1.1f, y - p * 1f), Size(p * 1.4f, p * 1.4f))
        drawRect(Color(0xFF33252A), Offset(x - p, y + p * 2f), Size(p * 2f, p))
        if (chefe) {
            drawRect(Color(0xFFFFD879), Offset(x - p * 6f, y - p * 2f), Size(p, p * 4f))
            drawRect(Color(0xFFFFD879), Offset(x + p * 5f, y - p * 2f), Size(p, p * 4f))
        }
    }
}
