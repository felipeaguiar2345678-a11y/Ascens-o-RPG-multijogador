package br.com.ascensaodosoberano.combat

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke

/** Bioma visual da arena; não altera a localização nem a navegação do jogo. */
enum class CombatSceneKind {
    FLORESTA, SOMBRAS, NEVE, DESERTO, MAR, RUINAS, IMPERIO, CENTRAL
}

object CombatSceneProfile {
    fun resolve(biome: String): CombatSceneKind {
        val value = biome.lowercase()
        return when {
            listOf("nevada", "gélida", "gelida", "gelo", "montanha").any(value::contains) -> CombatSceneKind.NEVE
            listOf("deserto", "duna", "areia").any(value::contains) -> CombatSceneKind.DESERTO
            listOf("mar", "costa", "ilha", "oceano").any(value::contains) -> CombatSceneKind.MAR
            listOf("ruína", "ruina", "antiga", "masmorra", "catacumba").any(value::contains) -> CombatSceneKind.RUINAS
            listOf("império", "imperio", "fronteiras imperiais", "campos imperiais").any(value::contains) -> CombatSceneKind.IMPERIO
            listOf("região central", "terras selvagens centrais", "central_wilds").any(value::contains) -> CombatSceneKind.CENTRAL
            listOf("terras das sombras", "vale do abismo", "terras mortas", "nhar-zul", "sombras", "dark_forest").any(value::contains) -> CombatSceneKind.SOMBRAS
            else -> CombatSceneKind.FLORESTA
        }
    }
}

/**
 * Camada de cenário 2.5D para a arena de combate.
 * Construída localmente, sem chamadas pagas ou dependência de imagens externas.
 */
@Composable
fun CombatSceneVisual(
    biome: String,
    destructionLevel: Int = 0,
    modifier: Modifier = Modifier
) {
    val kind = CombatSceneProfile.resolve(biome)
    val transition = rememberInfiniteTransition(label = "ambiente_combate")
    val flame by transition.animateFloat(
        initialValue = .72f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(620), RepeatMode.Reverse),
        label = "chama_cenario"
    )
    val glow by transition.animateFloat(
        initialValue = .55f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(1800), RepeatMode.Reverse),
        label = "brilho_cenario"
    )

    Canvas(modifier) {
        val w = size.width
        val h = size.height
        val horizon = h * .57f
        val night = kind == CombatSceneKind.SOMBRAS || kind == CombatSceneKind.RUINAS
        val skyTop = when (kind) {
            CombatSceneKind.NEVE -> Color(0xFF182E50)
            CombatSceneKind.DESERTO -> Color(0xFF49304A)
            CombatSceneKind.MAR -> Color(0xFF102E4D)
            CombatSceneKind.RUINAS -> Color(0xFF100D27)
            CombatSceneKind.IMPERIO -> Color(0xFF39233E)
            CombatSceneKind.CENTRAL -> Color(0xFF202D57)
            CombatSceneKind.SOMBRAS -> Color(0xFF09091E)
            CombatSceneKind.FLORESTA -> Color(0xFF102A35)
        }
        val skyBottom = when (kind) {
            CombatSceneKind.NEVE -> Color(0xFF657D9C)
            CombatSceneKind.DESERTO -> Color(0xFFB36C54)
            CombatSceneKind.MAR -> Color(0xFF276A83)
            CombatSceneKind.RUINAS -> Color(0xFF38284D)
            CombatSceneKind.IMPERIO -> Color(0xFF97614E)
            CombatSceneKind.CENTRAL -> Color(0xFF52648C)
            CombatSceneKind.SOMBRAS -> Color(0xFF281A42)
            CombatSceneKind.FLORESTA -> Color(0xFF315B4A)
        }
        drawRect(Brush.verticalGradient(listOf(skyTop, skyBottom), endY = horizon))
        // Lua/sol e halo atmosférico.
        val celestial = if (kind == CombatSceneKind.DESERTO || kind == CombatSceneKind.IMPERIO) Color(0xFFFFD49A) else Color(0xFFD6D4FF)
        val celestialCenter = Offset(w * .73f, h * .22f)
        drawCircle(celestial.copy(alpha = .10f), w * .14f, celestialCenter)
        drawCircle(celestial.copy(alpha = .20f), w * .085f, celestialCenter)
        drawCircle(celestial, w * .055f, celestialCenter)

        // Silhueta de montanhas e muralhas em três planos.
        val distant = Path().apply {
            moveTo(0f, horizon)
            for (i in 0..8) {
                val x = w * i / 8f
                val peak = horizon - h * (.12f + (i % 3) * .055f)
                lineTo(x, peak)
                lineTo(x + w / 16f, horizon)
            }
            lineTo(w, horizon)
            close()
        }
        drawPath(distant, if (kind == CombatSceneKind.NEVE) Color(0xFF405D7A) else Color(0xFF1B2039))
        val middle = Path().apply {
            moveTo(0f, horizon)
            lineTo(w * .16f, h * .35f)
            lineTo(w * .24f, h * .48f)
            lineTo(w * .36f, h * .31f)
            lineTo(w * .48f, horizon)
            lineTo(w * .61f, h * .40f)
            lineTo(w * .70f, h * .49f)
            lineTo(w * .83f, h * .33f)
            lineTo(w, horizon)
            close()
        }
        drawPath(middle, if (night) Color(0xFF17152F) else Color(0xFF26364A))

        // Estrutura arquitetônica central: castelo, ruína ou fortaleza por bioma.
        if (kind == CombatSceneKind.RUINAS || kind == CombatSceneKind.IMPERIO || kind == CombatSceneKind.CENTRAL || kind == CombatSceneKind.SOMBRAS) {
            val wall = if (night) Color(0xFF28203E) else Color(0xFF4D526A)
            drawRect(wall, Offset(w * .35f, h * .30f), Size(w * .30f, h * .27f))
            drawRect(wall, Offset(w * .29f, h * .37f), Size(w * .10f, h * .20f))
            drawRect(wall, Offset(w * .61f, h * .36f), Size(w * .10f, h * .21f))
            for (i in 0..4) {
                val x = w * (.34f + i * .075f)
                drawRect(wall, Offset(x, h * (.24f + (i % 2) * .055f)), Size(w * .055f, h * .34f))
                val roof = Path().apply {
                    moveTo(x - w * .008f, h * (.24f + (i % 2) * .055f))
                    lineTo(x + w * .027f, h * (.15f + (i % 2) * .055f))
                    lineTo(x + w * .062f, h * (.24f + (i % 2) * .055f))
                    close()
                }
                drawPath(roof, if (kind == CombatSceneKind.SOMBRAS) Color(0xFF754C91) else Color(0xFF8A7191))
            }
            for (i in 0..7) {
                val x = w * (.365f + (i % 4) * .07f)
                val y = h * (.34f + (i / 4) * .10f)
                drawRect(Color(0xFFFFC879).copy(alpha = .55f + glow * .35f), Offset(x, y), Size(w * .012f, h * .035f))
            }
        }

        // Árvores em camadas nas florestas e cristais nos biomas mágicos.
        if (kind == CombatSceneKind.FLORESTA || kind == CombatSceneKind.SOMBRAS) {
            for (i in 0..12) {
                val x = w * (i / 12f)
                val treeHeight = h * (.18f + (i % 4) * .055f)
                drawRect(Color(0xFF211D2C), Offset(x, horizon - treeHeight), Size(w * .014f, treeHeight))
                drawCircle(if (night) Color(0xFF241B3A) else Color(0xFF1B493D), w * (.035f + (i % 3) * .006f), Offset(x + w * .006f, horizon - treeHeight))
                drawCircle(if (night) Color(0xFF35234C) else Color(0xFF2C6248), w * .026f, Offset(x - w * .012f, horizon - treeHeight * .78f))
            }
        }
        if (kind == CombatSceneKind.SOMBRAS || kind == CombatSceneKind.RUINAS) {
            for (i in 0..5) {
                val x = w * (.12f + i * .15f)
                val baseY = h * (.61f + (i % 2) * .035f)
                val crystal = Path().apply {
                    moveTo(x, baseY)
                    lineTo(x - w * .018f, baseY - h * .10f)
                    lineTo(x, baseY - h * .17f)
                    lineTo(x + w * .022f, baseY - h * .08f)
                    close()
                }
                drawPath(crystal, Color(0xFFB76BFF).copy(alpha = .38f + glow * .35f))
                drawPath(crystal, Color(0xFFE5B8FF).copy(alpha = .45f), style = Stroke(width = 1.dp.toPx()))
            }
        }

        // Chamas laterais, partículas e névoa para dar profundidade.
        for (side in 0..1) {
            val x = if (side == 0) w * .055f else w * .945f
            drawRect(Color(0xFF5B443C), Offset(x - w * .008f, h * .48f), Size(w * .016f, h * .15f))
            drawCircle(Color(0xFFFF8B42).copy(alpha = .18f * flame), w * .055f, Offset(x, h * .47f))
            drawOval(Color(0xFFFFB35C).copy(alpha = .55f * flame), Offset(x - w * .009f, h * .43f), Size(w * .018f, h * .055f))
        }
        for (i in 0..24) {
            val x = w * ((i * 37 % 97) / 97f)
            val y = h * (.12f + (i * 19 % 70) / 100f)
            val particle = if (kind == CombatSceneKind.NEVE) Color.White else if (night) Color(0xFFD39BFF) else Color(0xFFFFD18A)
            drawCircle(particle.copy(alpha = .25f + glow * .45f), (w * .002f).coerceAtLeast(1f), Offset(x, y))
        }

        // Piso em perspectiva com placas e linhas convergentes.
        val floor = when (kind) {
            CombatSceneKind.NEVE -> Color(0xFF788D9B)
            CombatSceneKind.DESERTO -> Color(0xFF98663F)
            CombatSceneKind.MAR -> Color(0xFF24586B)
            CombatSceneKind.RUINAS, CombatSceneKind.SOMBRAS -> Color(0xFF30283E)
            CombatSceneKind.IMPERIO -> Color(0xFF69513E)
            CombatSceneKind.CENTRAL -> Color(0xFF4B5268)
            CombatSceneKind.FLORESTA -> Color(0xFF344B40)
        }
        drawRect(Brush.verticalGradient(listOf(floor.copy(alpha = .82f), Color(0xFF111522)), startY = horizon, endY = h), Offset(0f, horizon), Size(w, h - horizon))
        drawLine(Color(0x88E5CFA4), Offset(0f, horizon), Offset(w, horizon), 2.dp.toPx())
        for (i in 0..10) {
            val x = w * i / 10f
            drawLine(Color(0x3389B5C0), Offset(w * .5f, horizon), Offset(x, h), 1.dp.toPx())
        }
        for (i in 1..5) {
            val y = horizon + (h - horizon) * (i / 5f) * (i / 5f)
            drawLine(Color(0x227BA1A9), Offset(0f, y), Offset(w, y), 1.dp.toPx())
        }
        // Plataformas e sombras de contato reforçam a perspectiva sobre o ombro.
        drawOval(Color(0x99050810), Offset(w * .015f, h * .855f), Size(w * .47f, h * .125f))
        drawOval(Color(0x557ABF9A), Offset(w * .005f, h * .825f), Size(w * .49f, h * .115f))
        drawOval(Color(0x99050810), Offset(w * .70f, h * .555f), Size(w * .20f, h * .060f))
        drawOval(Color(0x668FCF9B), Offset(w * .695f, h * .535f), Size(w * .21f, h * .055f))
        // A destruição deixa marcas persistentes até o encerramento da batalha.
        for (i in 0 until destructionLevel.coerceIn(0, 5)) {
            val x = w * (.18f + (i * 17 % 62) / 100f)
            val y = h * (.78f + (i * 7 % 12) / 100f)
            drawLine(Color(0xFF090B12), Offset(x, y), Offset(x + w * .08f, y + h * .07f), (1.5f + i).dp.toPx())
            drawCircle(Color(0xFF0B0D16), w * (.018f + i * .003f), Offset(x + w * .04f, y + h * .025f))
        }
    }
}
