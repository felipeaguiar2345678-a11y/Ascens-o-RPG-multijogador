package br.com.ascensaodosoberano.combat

import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color

/**
 * Sprite provisório em pixel art 16-bit. Silhuetas variam por família de criatura
 * e usam contorno, luz e sombra para combinar com a perspectiva do mundo.
 */
@Composable
fun CriaturaPixelArt(
    nome: String,
    rank: String,
    chefe: Boolean,
    modifier: Modifier = Modifier
) {
    val especie = nome.lowercase()
    val lobo = "lobo" in especie || "raposa" in especie
    val slime = "slime" in especie || "gosma" in especie
    val dragao = "drag" in especie || "draco" in especie
    val rato = "rato" in especie || "roedor" in especie
    val aranha = "aranha" in especie || "inseto" in especie
    val osseo = "esqueleto" in especie || "morto" in especie
    val serpente = "serpente" in especie || "cobra" in especie || "víbora" in especie
    val ave = "ave" in especie || "fênix" in especie || "fenix" in especie || "harpia" in especie
    val aquatico = "peixe" in especie || "tubara" in especie || "kraken" in especie || "marinho" in especie
    val brutal = "urso" in especie || "ogro" in especie || "troll" in especie || "golem" in especie
    val planta = "treant" in especie || "planta" in especie || "raiz" in especie || "musgo" in especie
    val humanoide = listOf("saqueador", "bandido", "mercenario", "mercenário", "soldado", "guerreiro", "humano").any { it in especie }
    val fantasma = "fantasma" in especie || "espectro" in especie || "wraith" in especie
    val base = when {
        lobo -> Color(0xFF8998A8)
        slime -> Color(0xFF62B98B)
        dragao -> Color(0xFFC86B4D)
        rato -> Color(0xFF9B8068)
        aranha -> Color(0xFF805E9E)
        serpente -> Color(0xFF65A66C)
        ave -> Color(0xFFC77B42)
        aquatico -> Color(0xFF4E9EBB)
        brutal -> Color(0xFF8B7765)
        planta -> Color(0xFF638B48)
        humanoide -> Color(0xFF858B98)
        fantasma -> Color(0xFF9AB9C9)
        osseo -> Color(0xFFB6B7A5)
        else -> when (rank.uppercase()) {
            "S", "SS", "SSS" -> Color(0xFF8B65BD)
            "A", "B" -> Color(0xFF4D8FAD)
            "C", "D" -> Color(0xFF9B8054)
            else -> Color(0xFF668B61)
        }
    }
    val sombra = Color(
        red = base.red * .48f,
        green = base.green * .48f,
        blue = base.blue * .48f
    )
    val luz = Color(
        red = (base.red * 1.28f).coerceAtMost(1f),
        green = (base.green * 1.28f).coerceAtMost(1f),
        blue = (base.blue * 1.28f).coerceAtMost(1f)
    )
    val elite = chefe || rank.uppercase() in setOf("S", "SS", "SSS")

    Canvas(modifier) {
        val p = size.minDimension / 24f
        val x = size.width / 2f
        val y = size.height / 2f
        fun bloco(c: Color, gx: Float, gy: Float, w: Float, h: Float) {
            drawRect(c, Offset(x + gx * p, y + gy * p), Size(w * p, h * p))
        }

        drawOval(Color(0x99070B12), Offset(x - p * 8f, y + p * 8f), Size(p * 16f, p * 3f))
        if (elite) {
            drawCircle(Color(0xFFB88BFF).copy(alpha = .16f), p * 10f, Offset(x, y))
            drawCircle(Color(0xFFFFD879).copy(alpha = .24f), p * 7f, Offset(x, y))
        }

        // Pernas e silhueta variam por família.
        if (aranha || brutal || ave || planta) {
            for (side in listOf(-1f, 1f)) {
                for (leg in 0..2) {
                    val yy = -2f + leg * 3f
                    bloco(sombra, side * 5f, yy, 4f, 1.4f)
                    bloco(base, side * 7f, yy - 1f, 2f, 1.2f)
                }
            }
        } else if (!serpente && !aquatico && !fantasma) {
            bloco(sombra, -5f, 4f, 3f, 5f)
            bloco(sombra, 2f, 4f, 3f, 5f)
            bloco(Color(0xFF171923), -5f, 8f, 3f, 1.5f)
            bloco(Color(0xFF171923), 2f, 8f, 3f, 1.5f)
        }

        // Cauda, corpo e placas de luz.
        when {
            serpente -> {
                bloco(sombra, -10f, 1f, 20f, 5f)
                bloco(base, -9f, 0f, 18f, 4f)
                bloco(luz, -7f, -1f, 12f, 1.5f)
                bloco(sombra, 6f, -3f, 5f, 4f)
                bloco(base, 8f, -5f, 4f, 4f)
            }
            aquatico -> {
                bloco(sombra, -7f, -3f, 14f, 10f)
                bloco(base, -6f, -5f, 12f, 10f)
                bloco(luz, -4f, -5f, 7f, 2f)
                bloco(Color(0xFFB7E9E7), 5f, -1f, 4f, 3f)
                bloco(sombra, -10f, -2f, 4f, 7f)
                bloco(base, -12f, -4f, 4f, 5f)
            }
            ave -> {
                bloco(sombra, -9f, -3f, 18f, 7f)
                bloco(base, -7f, -5f, 14f, 7f)
                bloco(luz, -5f, -6f, 9f, 2f)
                bloco(Color(0xFFFFD58A), 5f, -3f, 4f, 2f)
            }
            brutal -> {
                bloco(sombra, -9f, -5f, 18f, 13f)
                bloco(base, -8f, -7f, 16f, 13f)
                bloco(luz, -6f, -7f, 10f, 3f)
                bloco(sombra, -10f, -2f, 4f, 7f)
                bloco(sombra, 6f, -2f, 4f, 7f)
            }
            planta -> {
                bloco(sombra, -7f, -4f, 14f, 12f)
                bloco(base, -6f, -6f, 12f, 12f)
                bloco(Color(0xFFB7C96C), -4f, -7f, 8f, 2f)
                bloco(Color(0xFF416B3D), -9f, -1f, 3f, 6f)
                bloco(Color(0xFF416B3D), 6f, -1f, 3f, 6f)
            }
            humanoide -> {
                // Silhueta de saqueador: ombros, braços separados, túnica e cinto.
                bloco(sombra, -5f, -5f, 10f, 13f)
                bloco(base, -4f, -7f, 8f, 13f)
                bloco(luz, -3f, -7f, 3f, 7f)
                bloco(Color(0xFF4D5665), -8f, -5f, 3f, 9f)
                bloco(Color(0xFF4D5665), 5f, -5f, 3f, 9f)
                bloco(Color(0xFF242A35), -4f, 4f, 3f, 5f)
                bloco(Color(0xFF242A35), 1f, 4f, 3f, 5f)
                bloco(Color(0xFFC19A5B), -4f, 1f, 8f, 2f)
                bloco(Color(0xFFE1C27C), -1f, 1f, 2f, 2f)
            }
            fantasma -> {
                bloco(sombra.copy(alpha = .65f), -7f, -7f, 14f, 14f)
                bloco(base.copy(alpha = .82f), -6f, -9f, 12f, 15f)
                bloco(luz.copy(alpha = .8f), -4f, -9f, 7f, 3f)
                bloco(base.copy(alpha = .55f), -7f, 4f, 4f, 4f)
                bloco(base.copy(alpha = .55f), 3f, 4f, 4f, 4f)
            }
            slime -> {
                bloco(sombra, -7f, 1f, 14f, 7f)
                bloco(base, -6f, -2f, 12f, 10f)
                bloco(luz, -4f, -3f, 7f, 2f)
                bloco(Color.White.copy(alpha = .65f), -4f, -1f, 2f, 2f)
            }
            aranha -> {
                bloco(sombra, -6f, -5f, 12f, 12f)
                bloco(base, -5f, -6f, 10f, 10f)
                bloco(luz, -3f, -6f, 5f, 2f)
            }
            osseo -> {
                bloco(Color(0xFF514D4A), -6f, -4f, 12f, 11f)
                bloco(base, -5f, -5f, 10f, 10f)
                bloco(Color(0xFFE1DCC8), -3f, -4f, 6f, 2f)
                bloco(Color(0xFF514D4A), -4f, 2f, 8f, 1f)
            }
            else -> {
                bloco(sombra, -7f, -3f, 14f, 11f)
                bloco(base, -6f, -5f, 12f, 11f)
                bloco(luz, -4f, -6f, 8f, 3f)
                bloco(sombra, -5f, 3f, 10f, 2f)
                if (lobo || dragao) {
                    bloco(sombra, 4f, 1f, 5f, 2f)
                    bloco(base, 7f, 0f, 3f, 2f)
                } else if (rato) {
                    bloco(Color(0xFFC58B9B), 5f, 2f, 5f, 1.5f)
                }
            }
        }

        // Cabeça, orelhas/chifres e focinho.
        if (!slime && !aranha && !fantasma && !aquatico) {
            bloco(sombra, -5f, -9f, if (brutal) 12f else 10f, 6f)
            bloco(base, -4f, -10f, 8f, 6f)
            bloco(luz, -3f, -10f, 5f, 2f)
            if (dragao || elite || ave || brutal) {
                bloco(Color(0xFF392638), -5f, -13f, 3f, 4f)
                bloco(Color(0xFF392638), 2f, -13f, 3f, 4f)
                bloco(Color(0xFFFFD879), -4f, -12f, 1f, 2f)
                bloco(Color(0xFFFFD879), 3f, -12f, 1f, 2f)
            } else {
                bloco(sombra, -5f, -12f, 3f, 4f)
                bloco(sombra, 2f, -12f, 3f, 4f)
            }
        } else if (aranha) {
            bloco(sombra, -4f, -10f, 8f, 5f)
            bloco(base, -3f, -10f, 6f, 4f)
        } else if (fantasma) {
            bloco(luz.copy(alpha = .7f), -3f, -8f, 6f, 2f)
            bloco(base.copy(alpha = .5f), -5f, 4f, 3f, 4f)
            bloco(base.copy(alpha = .5f), 2f, 4f, 3f, 4f)
        }

        // Marcas de espécie: escamas, penas, placas, espinhos e brilho elemental.
        if (serpente) {
            for (i in 0..4) bloco(if (i % 2 == 0) luz else sombra, -6f + i * 3f, 1f, 1.5f, 1.5f)
            bloco(Color(0xFFFFD879), 10f, -4f, 1.5f, 1.5f)
        }
        if (ave) {
            bloco(Color(0xFFFFD879), 7f, -2f, 4f, 1.5f)
            bloco(luz, -10f, -4f, 4f, 2f)
            bloco(sombra, 6f, 2f, 4f, 2f)
        }
        if (aquatico) {
            bloco(Color(0xFFB9F2E8), -2f, -2f, 2f, 1.5f)
            bloco(Color(0xFFB9F2E8), 2f, 1f, 2f, 1.5f)
            bloco(Color(0xFF2F647E), -5f, 5f, 10f, 1.5f)
        }
        if (planta) {
            bloco(Color(0xFFFFD879), -8f, -9f, 2f, 2f)
            bloco(Color(0xFF416B3D), -10f, -6f, 3f, 5f)
            bloco(Color(0xFF416B3D), 7f, -6f, 3f, 5f)
        }

        val olho = if (elite) Color(0xFFFFD879) else Color(0xFF20202A)
        bloco(olho, -3f, -7f, 2f, 2f)
        bloco(olho, 2f, -7f, 2f, 2f)
        if (!slime && !aranha) {
            bloco(Color(0xFF34252A), -1f, -3f, 2f, 1.5f)
        }
        if (elite) {
            bloco(Color(0xFFFFD879), -9f, -2f, 1.5f, 5f)
            bloco(Color(0xFFFFD879), 7.5f, -2f, 1.5f, 5f)
        }
    }
}
