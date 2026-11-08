package br.com.ascensaodosoberano.companions

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color

/** Companheiro em pixel art 16-bit, com silhueta e detalhes próprios por espécie. */
@Composable
fun CompanionPixelArt(
    especie: String,
    rank: String,
    modifier: Modifier = Modifier,
    mutacao: String = "NORMAL",
    estagio: String = "FILHOTE"
) {
    val nome = especie.lowercase()
    val dragao = "drag" in nome || "draco" in nome
    val lobo = "lobo" in nome || "raposa" in nome
    val slime = "slime" in nome || "gosma" in nome
    val ave = "ave" in nome || "fênix" in nome || "fenix" in nome
    val corpoBase = when {
        dragao -> Color(0xFFC66B45)
        lobo -> Color(0xFF8796A5)
        slime -> Color(0xFF69B98B)
        ave -> Color(0xFFD99A48)
        else -> when (rank.uppercase()) {
            "S", "SS", "SSS" -> Color(0xFF9875D8)
            "A", "B" -> Color(0xFF4E9FC0)
            else -> Color(0xFF68A77A)
        }
    }
    val corpo = when (mutacao.uppercase()) {
        "VENENOSA" -> Color(0xFF69B978)
        "ESPINHOSA" -> Color(0xFF8A79A8)
        "ANCESTRAL" -> Color(0xFFD8A94F)
        else -> corpoBase
    }
    val sombra = Color(corpo.red * .48f, corpo.green * .48f, corpo.blue * .48f)
    val luz = Color(
        (corpo.red * 1.3f).coerceAtMost(1f),
        (corpo.green * 1.3f).coerceAtMost(1f),
        (corpo.blue * 1.3f).coerceAtMost(1f)
    )
    Canvas(modifier) {
        val escalaEstagio = if (estagio.uppercase() == "ADULTO") 18f else if (estagio.uppercase() == "ADOLESCENTE") 19f else 20f
        val p = size.minDimension / escalaEstagio
        val x = size.width / 2f
        val y = size.height / 2f
        fun bloco(c: Color, gx: Float, gy: Float, w: Float, h: Float) {
            drawRect(c, Offset(x + gx * p, y + gy * p), Size(w * p, h * p))
        }
        drawOval(Color(0x88070D12), Offset(x - p * 7f, y + p * 7f), Size(p * 14f, p * 2.5f))

        if (ave) {
            bloco(sombra, -8f, -1f, 5f, 6f)
            bloco(corpo, -10f, -3f, 6f, 5f)
            bloco(sombra, 3f, -1f, 5f, 6f)
            bloco(corpo, 4f, -3f, 6f, 5f)
            bloco(Color(0xFFE8C56F), -1f, -11f, 2f, 5f)
        } else {
            bloco(sombra, -6f, -2f, 12f, 10f)
            bloco(corpo, -5f, -4f, 10f, 10f)
            bloco(luz, -3f, -5f, 6f, 3f)
            if (lobo || dragao) {
                bloco(sombra, 4f, 1f, 5f, 2f)
                bloco(corpo, 7f, 0f, 3f, 2f)
            }
            if (!slime) {
                bloco(sombra, -4f, -9f, 8f, 6f)
                bloco(corpo, -3f, -10f, 6f, 6f)
                bloco(luz, -2f, -10f, 4f, 2f)
                bloco(sombra, -4f, -12f, 2f, 3f)
                bloco(sombra, 2f, -12f, 2f, 3f)
            } else {
                bloco(Color.White.copy(alpha = .65f), -3f, -2f, 2f, 2f)
            }
        }

        val olho = if (rank.uppercase() in setOf("S", "SS", "SSS")) Color(0xFFFFE18B) else Color(0xFF17202A)
        bloco(olho, -2.5f, -6f, 1.5f, 1.5f)
        bloco(olho, 1.5f, -6f, 1.5f, 1.5f)
        if (!slime && !ave) bloco(Color(0xFF342B2B), -1f, -2f, 2f, 1f)

        // Patas com botas/sombra para dar leitura em tamanho pequeno.
        if (!ave && !slime) {
            bloco(sombra, -4f, 5f, 2.5f, 3f)
            bloco(sombra, 1.5f, 5f, 2.5f, 3f)
        }
        if (rank.uppercase() in setOf("S", "SS", "SSS")) {
            bloco(Color(0xFFFFE18B), -1f, -14f, 2f, 2f)
            bloco(Color(0xFFFFE18B).copy(alpha = .8f), -7f, -2f, 1.5f, 1.5f)
            bloco(Color(0xFFFFE18B).copy(alpha = .8f), 5.5f, -2f, 1.5f, 1.5f)
        }

        when (mutacao.uppercase()) {
            "VENENOSA" -> {
                bloco(Color(0xFFB8F27A), -7f, 1f, 2f, 2f)
                bloco(Color(0xFFB8F27A), 5f, -3f, 2f, 2f)
                bloco(Color(0xFF4D8F58), -1f, 3f, 2f, 2f)
            }
            "ESPINHOSA" -> {
                bloco(Color(0xFFC9B6E8), -7f, -3f, 2f, 3f)
                bloco(Color(0xFFC9B6E8), 5f, -3f, 2f, 3f)
                bloco(Color(0xFFC9B6E8), -6f, 3f, 2f, 3f)
                bloco(Color(0xFFC9B6E8), 4f, 3f, 2f, 3f)
            }
            "ANCESTRAL" -> {
                bloco(Color(0xFFFFE18B), -1f, -16f, 2f, 3f)
                bloco(Color(0xFFFFE18B).copy(alpha = .8f), -9f, -1f, 2f, 2f)
                bloco(Color(0xFFFFE18B).copy(alpha = .8f), 7f, -1f, 2f, 2f)
            }
        }
    }
}
