package br.com.ascensaodosoberano.character

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color

/** Prévia em pixel art 16-bit que respeita as opções do criador de personagem. */
@Composable
fun PersonagemPixelArt(
    appearance: CharacterAppearance,
    modifier: Modifier = Modifier
) {
    val pele = when (appearance.skinId) {
        "pele_01" -> Color(0xFFFFDFC4)
        "pele_02" -> Color(0xFFEBC09A)
        "pele_03" -> Color(0xFFB87950)
        "pele_04" -> Color(0xFF75452F)
        "pele_05" -> Color(0xFF432719)
        else -> Color(0xFFEBC09A)
    }
    val cabelo = when (appearance.hairColorId) {
        "preto" -> Color(0xFF202020)
        "loiro" -> Color(0xFFE5C16B)
        "branco" -> Color(0xFFE8E8E8)
        "vermelho" -> Color(0xFFB83A32)
        "azul" -> Color(0xFF3768C5)
        "roxo" -> Color(0xFF8546B5)
        else -> Color(0xFF70452D)
    }
    val roupa = when (appearance.outfitId) {
        "roupa_inicial_02" -> Color(0xFF355B7A)
        "roupa_inicial_03" -> Color(0xFF65458F)
        "roupa_inicial_04" -> Color(0xFF34343F)
        "roupa_inicial_05" -> Color(0xFF8A653A)
        else -> Color(0xFF9E3542)
    }
    val sombraRoupa = Color(roupa.red * .52f, roupa.green * .52f, roupa.blue * .52f)
    val olhos = if (appearance.eyeId == "olhos_03" || appearance.eyeId == "olhos_04") {
        Color(0xFF70DCEB)
    } else {
        Color(0xFF332A26)
    }

    Canvas(modifier) {
        val p = size.minDimension / 30f
        val cx = size.width / 2f
        val cy = size.height / 2f
        fun bloco(c: Color, x: Float, y: Float, w: Float, h: Float) {
            drawRect(c, Offset(cx + x * p, cy + y * p), Size(w * p, h * p))
        }

        drawOval(Color(0x660B1420), Offset(cx - p * 10f, cy + p * 12f), Size(p * 20f, p * 3f))
        // Capa e pernas.
        bloco(sombraRoupa, -6f, 1f, 12f, 12f)
        bloco(roupa, -5f, 2f, 10f, 8f)
        bloco(Color(0xFF263344), -4f, 9f, 3f, 5f)
        bloco(Color(0xFF263344), 1f, 9f, 3f, 5f)
        bloco(Color(0xFF171D27), -4.5f, 13f, 4f, 1.5f)
        bloco(Color(0xFF171D27), .5f, 13f, 4f, 1.5f)
        // Tronco, peitoral e cinto.
        bloco(sombraRoupa, -6f, -5f, 12f, 10f)
        bloco(Color(0xFF8295A5), -4f, -4f, 8f, 7f)
        bloco(Color(0xFFB8C5CC), -3f, -4f, 6f, 2f)
        bloco(Color(0xFF8C673B), -6f, 3f, 12f, 2f)
        bloco(Color(0xFFE7C16F), -1f, 3f, 2f, 2f)
        // Braços e ombreiras.
        bloco(sombraRoupa, -8f, -4f, 3f, 8f)
        bloco(sombraRoupa, 5f, -4f, 3f, 8f)
        bloco(Color(0xFFB8C5CC), -8f, -5f, 3f, 2f)
        bloco(Color(0xFFB8C5CC), 5f, -5f, 3f, 2f)
        // Cabeça, rosto e cabelo.
        bloco(pele, -3.5f, -12f, 7f, 8f)
        if (appearance.hairId != "cabelo_06") {
            bloco(cabelo, -4f, -14f, 8f, 3f)
            when (appearance.hairId) {
                "cabelo_02", "cabelo_04" -> {
                    bloco(cabelo, -4f, -12f, 1.5f, 6f)
                    bloco(cabelo, 2.5f, -12f, 1.5f, 6f)
                }
                "cabelo_05" -> {
                    bloco(cabelo, -2f, -17f, 4f, 4f)
                    bloco(cabelo, 2f, -13f, 2f, 3f)
                }
                else -> bloco(cabelo, -4f, -12f, 2f, 3f)
            }
        }
        bloco(olhos, -2f, -9f, 1f, 1.2f)
        bloco(olhos, 1f, -9f, 1f, 1.2f)
        bloco(Color(0xFF9A5B50), -.7f, -6.5f, 1.4f, .7f)
        // Pequenos reflexos para separar os planos do sprite.
        bloco(Color.White.copy(alpha = .45f), -3f, -11f, 1.2f, 1f)
        bloco(Color.White.copy(alpha = .28f), -3f, -3f, 1.5f, 2f)
    }
}
