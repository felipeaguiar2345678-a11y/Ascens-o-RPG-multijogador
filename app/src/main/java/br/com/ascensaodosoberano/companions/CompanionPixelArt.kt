package br.com.ascensaodosoberano.companions

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color

/** Companheiro provisório em pixel art quando ainda não existe sprite oficial. */
@Composable
fun CompanionPixelArt(
    especie: String,
    rank: String,
    modifier: Modifier = Modifier
) {
    val nome = especie.lowercase()
    val corpo = when {
        "drag" in nome -> Color(0xFFC66B45)
        "lobo" in nome || "raposa" in nome -> Color(0xFF8796A5)
        "slime" in nome -> Color(0xFF69B98B)
        "ave" in nome || "fênix" in nome || "fenix" in nome -> Color(0xFFD99A48)
        else -> when (rank.uppercase()) {
            "S", "SS", "SSS" -> Color(0xFF9875D8)
            "A", "B" -> Color(0xFF4E9FC0)
            else -> Color(0xFF68A77A)
        }
    }
    Canvas(modifier) {
        val p = size.minDimension / 14f
        val x = size.width / 2f
        val y = size.height / 2f
        drawOval(Color(0x880D1715), Offset(x - p * 5f, y + p * 4.8f), Size(p * 10f, p * 2f))
        // Orelhas, chifres e cauda.
        drawRect(corpo.copy(red = (corpo.red * .78f).coerceIn(0f, 1f)),
            Offset(x - p * 4f, y - p * 4f), Size(p * 2f, p * 3f))
        drawRect(corpo.copy(red = (corpo.red * .78f).coerceIn(0f, 1f)),
            Offset(x + p * 2f, y - p * 4f), Size(p * 2f, p * 3f))
        drawRect(corpo, Offset(x + p * 3f, y + p), Size(p * 3f, p * 1.5f))
        // Corpo em blocos com luz na parte superior.
        drawRect(corpo, Offset(x - p * 4f, y - p * 2f), Size(p * 8f, p * 7f))
        drawRect(corpo.copy(red = (corpo.red * 1.18f).coerceIn(0f, 1f),
            green = (corpo.green * 1.18f).coerceIn(0f, 1f),
            blue = (corpo.blue * 1.18f).coerceIn(0f, 1f)),
            Offset(x - p * 2.5f, y - p * 2.5f), Size(p * 5f, p * 2f))
        drawRect(Color(0xFFF3E6C9), Offset(x - p * 2f, y + p * 1.5f), Size(p * 4f, p * 2f))
        // Olhos e focinho.
        drawRect(Color(0xFF17202A), Offset(x - p * 2.2f, y - p * .5f), Size(p, p))
        drawRect(Color(0xFF17202A), Offset(x + p * 1.2f, y - p * .5f), Size(p, p))
        drawRect(Color(0xFF342B2B), Offset(x - p * .5f, y + p * 1.5f), Size(p, p * .7f))
        // Patas.
        drawRect(corpo, Offset(x - p * 3f, y + p * 4f), Size(p * 2f, p * 2f))
        drawRect(corpo, Offset(x + p, y + p * 4f), Size(p * 2f, p * 2f))
        if (rank.uppercase() in setOf("S", "SS", "SSS")) {
            drawRect(Color(0xFFFFE18B), Offset(x - p * .5f, y - p * 5f), Size(p, p * 1.5f))
            drawRect(Color(0xFFFFE18B).copy(alpha = .7f), Offset(x - p * 5f, y - p * 1f), Size(p, p))
            drawRect(Color(0xFFFFE18B).copy(alpha = .7f), Offset(x + p * 4f, y - p * 1f), Size(p, p))
        }
    }
}
