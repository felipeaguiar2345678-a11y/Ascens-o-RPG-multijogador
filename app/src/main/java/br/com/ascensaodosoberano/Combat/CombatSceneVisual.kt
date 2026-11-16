package br.com.ascensaodosoberano.combat

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.Image
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.res.painterResource
import br.com.ascensaodosoberano.R
import androidx.compose.ui.unit.dp
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
            listOf("floresta arcana", "floresta das sombras", "floresta sombria", "dark_forest").any(value::contains) -> CombatSceneKind.FLORESTA
            listOf("terras das sombras", "vale do abismo", "terras mortas", "nhar-zul", "sombras").any(value::contains) -> CombatSceneKind.SOMBRAS
            else -> CombatSceneKind.FLORESTA
        }
    }
}

/**
 * Camada de cenário 2.5D para a arena de combate.
 * Construída localmente, sem chamadas pagas ou dependência de imagens externas.
 */
@Composable
private fun CombatSceneCanvasVisual(
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

        // Silhueta exclusiva de cada ecossistema: a composição muda, não apenas a paleta.
        when (kind) {
            CombatSceneKind.NEVE -> {
                for (i in 0..4) {
                    val x = w * (i * .23f - .08f)
                    val peakY = h * (.27f + (i % 2) * .08f)
                    val peak = Path().apply {
                        moveTo(x, horizon)
                        lineTo(x + w * .12f, peakY)
                        lineTo(x + w * .24f, horizon)
                        close()
                    }
                    drawPath(peak, Color(0xFF536F91))
                    val snow = Path().apply {
                        moveTo(x + w * .075f, peakY + h * .075f)
                        lineTo(x + w * .12f, peakY)
                        lineTo(x + w * .165f, peakY + h * .075f)
                        lineTo(x + w * .135f, peakY + h * .06f)
                        lineTo(x + w * .12f, peakY + h * .085f)
                        lineTo(x + w * .105f, peakY + h * .06f)
                        close()
                    }
                    drawPath(snow, Color(0xFFD9E8F2))
                }
            }
            CombatSceneKind.DESERTO -> {
                for (i in 0..2) {
                    val x = w * (.18f + i * .29f)
                    val base = horizon + h * .015f
                    val pyramid = Path().apply {
                        moveTo(x - w * .10f, base)
                        lineTo(x, h * (.30f + (i % 2) * .06f))
                        lineTo(x + w * .12f, base)
                        close()
                    }
                    drawPath(pyramid, Color(0xFF79513E))
                    drawPath(pyramid, Color(0xFFD9A36B), style = Stroke(width = 2.dp.toPx()))
                    drawLine(Color(0xFFE6BC82), Offset(x, h * (.30f + (i % 2) * .06f)), Offset(x + w * .045f, base), 2.dp.toPx())
                }
                for (i in 0..3) {
                    val x = w * (.12f + i * .25f)
                    drawRect(Color(0xFF8A6048), Offset(x, horizon - h * .10f), Size(w * .025f, h * .10f))
                    drawRect(Color(0xFFB98259), Offset(x - w * .012f, horizon - h * .105f), Size(w * .05f, h * .018f))
                }
            }
            CombatSceneKind.MAR -> {
                val seaLine = horizon - h * .025f
                drawRect(Color(0xFF16465D), Offset(0f, seaLine), Size(w, h * .15f))
                for (i in 0..5) {
                    val x = w * (.08f + i * .17f)
                    drawLine(Color(0xFF8ED9DF).copy(alpha = .55f), Offset(x, seaLine + h * (.025f + (i % 2) * .035f)), Offset(x + w * .11f, seaLine + h * (.025f + (i % 2) * .035f)), 2.dp.toPx())
                }
                // Navio distante com velas reconhecíveis.
                drawRect(Color(0xFF342B35), Offset(w * .62f, horizon - h * .035f), Size(w * .19f, h * .025f))
                drawLine(Color(0xFF2B2634), Offset(w * .71f, horizon - h * .035f), Offset(w * .71f, h * .22f), 2.dp.toPx())
                val sail = Path().apply {
                    moveTo(w * .70f, h * .24f); lineTo(w * .70f, horizon - h * .04f); lineTo(w * .61f, horizon - h * .04f); close()
                }
                drawPath(sail, Color(0xFFE5D8B8))
                val sail2 = Path().apply {
                    moveTo(w * .725f, h * .30f); lineTo(w * .725f, horizon - h * .04f); lineTo(w * .80f, horizon - h * .04f); close()
                }
                drawPath(sail2, Color(0xFFC6B99E))
            }
            CombatSceneKind.FLORESTA -> {
                // Árvores ancestrais muito maiores que a vegetação de fundo comum.
                for (i in 0..3) {
                    val x = w * (i * .34f - .05f)
                    val trunkWidth = w * (.035f + (i % 2) * .012f)
                    drawRect(Color(0xFF182D29), Offset(x, h * .20f), Size(trunkWidth, horizon - h * .20f))
                    drawCircle(Color(0xFF24513E), w * .105f, Offset(x + trunkWidth * .5f, h * .24f))
                    drawCircle(Color(0xFF32684A), w * .075f, Offset(x + trunkWidth * .5f, h * .31f))
                    drawLine(Color(0xFF8BB77A).copy(alpha = .28f), Offset(x + trunkWidth * .5f, h * .40f), Offset(x + trunkWidth * .5f, horizon), 2.dp.toPx())
                }
                // Arco de pedra antigo entre as árvores.
                drawRect(Color(0xFF596653), Offset(w * .40f, h * .40f), Size(w * .20f, h * .16f))
                drawRect(Color(0xFF1B493D), Offset(w * .445f, h * .445f), Size(w * .11f, h * .115f))
                drawRect(Color(0xFF596653), Offset(w * .38f, h * .38f), Size(w * .24f, h * .035f))
            }
            CombatSceneKind.IMPERIO -> {
                // Muralhas fortificadas, torres quadradas e bandeiras imperiais.
                drawRect(Color(0xFF62505A), Offset(w * .18f, h * .39f), Size(w * .64f, h * .18f))
                for (i in 0..3) {
                    val x = w * (.20f + i * .20f)
                    drawRect(Color(0xFF77606A), Offset(x, h * .27f), Size(w * .075f, h * .30f))
                    drawRect(Color(0xFF9A7880), Offset(x - w * .01f, h * .25f), Size(w * .095f, h * .035f))
                    drawLine(Color(0xFFD8B77A), Offset(x + w * .038f, h * .25f), Offset(x + w * .038f, h * .13f), 2.dp.toPx())
                    val flag = Path().apply {
                        moveTo(x + w * .04f, h * .14f); lineTo(x + w * .12f, h * .17f); lineTo(x + w * .04f, h * .20f); close()
                    }
                    drawPath(flag, Color(0xFFB84E50))
                }
            }
            CombatSceneKind.SOMBRAS -> {
                // Obeliscos quebrados e portais suspensos no horizonte.
                for (i in 0..3) {
                    val x = w * (.13f + i * .24f)
                    val obelisk = Path().apply {
                        moveTo(x - w * .025f, horizon); lineTo(x - w * .012f, h * .30f)
                        lineTo(x + w * .012f, h * .24f); lineTo(x + w * .035f, horizon); close()
                    }
                    drawPath(obelisk, Color(0xFF30213F))
                    drawLine(Color(0xFFB66AE0).copy(alpha = .55f), Offset(x + w * .005f, h * .31f), Offset(x + w * .015f, horizon - h * .02f), 2.dp.toPx())
                }
                drawOval(Color(0xFF8D4DBA).copy(alpha = .14f + glow * .08f), Offset(w * .39f, h * .18f), Size(w * .22f, h * .30f), style = Stroke(width = 5.dp.toPx()))
            }
            CombatSceneKind.RUINAS -> {
                // Colunas partidas e frontão de um templo abandonado.
                for (i in 0..4) {
                    val x = w * (.22f + i * .14f)
                    val height = h * (.13f + (i % 2) * .04f)
                    drawRect(Color(0xFF62566D), Offset(x, horizon - height), Size(w * .035f, height))
                    drawRect(Color(0xFF8B7C91), Offset(x - w * .01f, horizon - height), Size(w * .055f, h * .018f))
                }
                val pediment = Path().apply {
                    moveTo(w * .18f, horizon - h * .14f); lineTo(w * .50f, horizon - h * .29f); lineTo(w * .82f, horizon - h * .14f); close()
                }
                drawPath(pediment, Color(0xFF51445E))
                drawPath(pediment, Color(0xFFA18BA7), style = Stroke(width = 2.dp.toPx()))
            }
            CombatSceneKind.CENTRAL -> {
                // Planície central com estrada de pedra e marcos distantes.
                drawLine(Color(0xFFB3A18A).copy(alpha = .45f), Offset(w * .48f, horizon), Offset(w * .52f, h * .42f), 5.dp.toPx())
                drawLine(Color(0xFFB3A18A).copy(alpha = .35f), Offset(w * .52f, h * .42f), Offset(w * .57f, horizon), 5.dp.toPx())
                for (i in 0..6) {
                    val x = w * (.08f + i * .14f)
                    drawCircle(Color(0xFF69718A), w * .018f, Offset(x, horizon - h * (.04f + (i % 3) * .02f)))
                }
            }
        }

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

        // Detalhes de cenário por ecossistema: vegetação, rochas, ruínas e destroços.
        // A quantidade se adapta à largura disponível para preservar fluidez em celulares.
        val detalheCount = if (w < 520f) 8 else 16
        when (kind) {
            CombatSceneKind.NEVE -> {
                for (i in 0 until detalheCount) {
                    val x = w * ((i * 29 % 97) / 97f)
                    val y = horizon + h * (.025f + (i % 5) * .018f)
                    drawRect(Color(0xFFB8D1E2), Offset(x, y), Size(w * .018f, h * .012f))
                    drawRect(Color(0xFF526F87), Offset(x + w * .012f, y + h * .012f), Size(w * .012f, h * .009f))
                }
            }
            CombatSceneKind.DESERTO -> {
                for (i in 0 until detalheCount) {
                    val x = w * ((i * 31 % 95) / 95f)
                    val y = horizon + h * (.04f + (i % 4) * .025f)
                    drawOval(Color(0xFF5E402F).copy(alpha = .42f), Offset(x, y), Size(w * .045f, h * .012f))
                    drawLine(Color(0xFFE6B979).copy(alpha = .45f), Offset(x, y), Offset(x + w * .025f, y - h * .008f), 1.5f)
                }
            }
            CombatSceneKind.MAR -> {
                for (i in 0 until detalheCount) {
                    val x = w * ((i * 23 % 96) / 96f)
                    val y = horizon + h * (.035f + (i % 5) * .022f)
                    drawLine(Color(0xFF8ED9DF).copy(alpha = .38f), Offset(x, y), Offset(x + w * .055f, y - h * .006f), 2f)
                }
            }
            CombatSceneKind.RUINAS, CombatSceneKind.IMPERIO, CombatSceneKind.CENTRAL, CombatSceneKind.SOMBRAS -> {
                for (i in 0 until detalheCount) {
                    val x = w * ((i * 37 % 95) / 95f)
                    val y = horizon + h * (.025f + (i % 4) * .026f)
                    val pedra = if (night) Color(0xFF171323) else Color(0xFF343747)
                    drawRect(pedra, Offset(x, y), Size(w * (.018f + (i % 3) * .006f), h * (.018f + (i % 2) * .008f)))
                    drawLine(Color(0xFFB3A3A0).copy(alpha = .22f), Offset(x, y), Offset(x + w * .018f, y - h * .008f), 1f)
                }
            }
            else -> {
                for (i in 0 until detalheCount) {
                    val x = w * ((i * 41 % 95) / 95f)
                    val y = horizon + h * (.02f + (i % 5) * .023f)
                    drawRect(Color(0xFF172B28), Offset(x, y), Size(w * .012f, h * .045f))
                    drawRect(Color(0xFF56704A), Offset(x - w * .009f, y - h * .012f), Size(w * .03f, h * .018f))
                }
            }
        }

        // Chamas laterais, partículas e névoa para dar profundidade.
        for (side in 0..1) {
            val x = if (side == 0) w * .055f else w * .945f
            drawRect(Color(0xFF5B443C), Offset(x - w * .008f, h * .48f), Size(w * .016f, h * .15f))
            drawCircle(Color(0xFFFF8B42).copy(alpha = .18f * flame), w * .055f, Offset(x, h * .47f))
            drawOval(Color(0xFFFFB35C).copy(alpha = .55f * flame), Offset(x - w * .009f, h * .43f), Size(w * .018f, h * .055f))
        }
        val particleCount = if (w < 520f) 12 else 28
        for (i in 0 until particleCount) {
            val x = w * ((i * 37 % 97) / 97f)
            val y = h * (.12f + (i * 19 % 70) / 100f)
            val particle = if (kind == CombatSceneKind.NEVE) Color.White else if (night) Color(0xFFD39BFF) else Color(0xFFFFD18A)
            drawCircle(particle.copy(alpha = .25f + glow * .45f), (w * .002f).coerceAtLeast(1f), Offset(x, y))
        }

        // Chão atmosférico sem grade geométrica: a perspectiva vem da luz,
        // das sombras de contato e das camadas de profundidade, não de linhas neon.
        val floor = when (kind) {
            CombatSceneKind.NEVE -> Color(0xFF788D9B)
            CombatSceneKind.DESERTO -> Color(0xFF98663F)
            CombatSceneKind.MAR -> Color(0xFF24586B)
            CombatSceneKind.RUINAS, CombatSceneKind.SOMBRAS -> Color(0xFF30283E)
            CombatSceneKind.IMPERIO -> Color(0xFF69513E)
            CombatSceneKind.CENTRAL -> Color(0xFF4B5268)
            CombatSceneKind.FLORESTA -> Color(0xFF344B40)
        }
        drawRect(
            Brush.verticalGradient(
                listOf(floor.copy(alpha = .72f), floor.copy(alpha = .92f), Color(0xFF111522)),
                startY = horizon,
                endY = h
            ),
            Offset(0f, horizon),
            Size(w, h - horizon)
        )
        // Faixas irregulares de luz e névoa quebram a aparência de tabuleiro.
        for (i in 0..5) {
            val x = w * ((i * 23 % 91) / 100f)
            val y = horizon + h * (.10f + (i % 3) * .075f)
            drawOval(
                Color.White.copy(alpha = .025f + glow * .018f),
                Offset(x, y),
                Size(w * (.12f + (i % 2) * .06f), h * .018f)
            )
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

@Composable
fun CombatSceneVisual(
    biome: String,
    destructionLevel: Int = 0,
    modifier: Modifier = Modifier
) {
    val kind = CombatSceneProfile.resolve(biome)
    Box(modifier.clip(RoundedCornerShape(12.dp))) {
        if (kind == CombatSceneKind.FLORESTA) {
            Image(
                painter = painterResource(R.drawable.arena_floresta_arcana),
                contentDescription = null,
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Crop
            )
            Canvas(Modifier.fillMaxSize()) {
                drawRect(
                    brush = Brush.verticalGradient(
                        colorStops = arrayOf(
                            0f to Color(0x22040A14),
                            .48f to Color.Transparent,
                            1f to Color(0x77040A12)
                        ),
                        startY = 0f,
                        endY = size.height
                    )
                )
                val pontos = listOf(
                    Offset(size.width * .14f, size.height * .31f),
                    Offset(size.width * .28f, size.height * .47f),
                    Offset(size.width * .62f, size.height * .28f),
                    Offset(size.width * .79f, size.height * .43f),
                    Offset(size.width * .91f, size.height * .24f)
                )
                pontos.forEachIndexed { index, ponto ->
                    val raio = (2.2f + (index % 3) * 1.2f).dp.toPx()
                    drawCircle(Color(0xFF8FF7F0).copy(alpha = .18f), raio * 2.5f, ponto)
                    drawCircle(Color(0xFFB8FFF5).copy(alpha = .72f), raio, ponto)
                }
                if (destructionLevel > 0) {
                    val alpha = (destructionLevel / 5f).coerceIn(.08f, .34f)
                    drawRect(
                        Color(0xFF27131E).copy(alpha = alpha),
                        topLeft = Offset(0f, size.height * .72f),
                        size = androidx.compose.ui.geometry.Size(size.width, size.height * .28f)
                    )
                }
            }
        } else {
            CombatSceneCanvasVisual(
                biome = biome,
                destructionLevel = destructionLevel,
                modifier = Modifier.fillMaxSize()
            )
        }
    }
}
