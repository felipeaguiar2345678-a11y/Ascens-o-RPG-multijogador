package br.com.ascensaodosoberano.companions

import androidx.compose.foundation.Canvas
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke

@Composable
private fun lembrarEfeitoWorld(ativo: Boolean): Pair<Float, Float> {
    if (!ativo) return 0.35f to 0f
    val transicao = rememberInfiniteTransition(label = "efeito-world")
    val pulso by transicao.animateFloat(
        initialValue = 0.28f, targetValue = 0.9f,
        animationSpec = infiniteRepeatable(tween(780), RepeatMode.Reverse),
        label = "pulso-world"
    )
    val falha by transicao.animateFloat(
        initialValue = -2f, targetValue = 2f,
        animationSpec = infiniteRepeatable(tween(190), RepeatMode.Reverse),
        label = "glitch-world"
    )
    return pulso to falha
}

/** Ícone provisório em pixel art para armas, armaduras, acessórios e escudos. */
@Composable
fun EquipamentoPixelArt(
    tipo: EquipmentType,
    raridade: String,
    modifier: Modifier = Modifier
) {
    val tier = RarityVisuals.normalize(raridade)
    val brilho = RarityVisuals.color(raridade)
    val (pulso, falha) = lembrarEfeitoWorld(tier == RarityTier.WORLD)
    val metal = Color(0xFFB9C8D4)
    val sombra = Color(0xFF354454)
    val couro = Color(0xFF765039)
    Canvas(modifier) {
        val u = size.minDimension / 24f
        val cx = size.width / 2f
        val cy = size.height / 2f
        fun bloco(c: Color, x: Float, y: Float, w: Float, h: Float) {
            drawRect(c, Offset(cx + x * u, cy + y * u), Size(w * u, h * u))
        }
        drawCircle(brilho.copy(alpha = if (tier == RarityTier.WORLD) pulso * .34f else .16f), size.minDimension * .46f, Offset(cx, cy))
        if (tier == RarityTier.MYTHIC) {
            drawCircle(
                brush = Brush.sweepGradient(listOf(Color(0xFFFF4D6D), Color(0xFFFFD166), Color(0xFF7AE582), Color(0xFF4CC9F0), Color(0xFF9B5DE5), Color(0xFFFF4D6D))),
                radius = size.minDimension * .46f,
                center = Offset(cx, cy),
                style = Stroke(width = u * 1.8f)
            )
        }
        when (tipo) {
            EquipmentType.WEAPON -> {
                bloco(couro, -2f, 4f, 4f, 7f)
                bloco(brilho, -6f, 3f, 12f, 2f)
                bloco(sombra, -1.5f, -8f, 3f, 12f)
                bloco(metal, -1f, -10f, 2f, 12f)
                bloco(Color.White, -.5f, -9f, .7f, 8f)
                bloco(brilho, -2f, -12f, 4f, 2f)
            }
            EquipmentType.SHIELD -> {
                bloco(sombra, -8f, -9f, 16f, 16f)
                bloco(brilho, -7f, -8f, 14f, 13f)
                bloco(metal, -5f, -6f, 10f, 9f)
                bloco(brilho, -1.5f, -7f, 3f, 11f)
                bloco(brilho, -5f, -2f, 10f, 2f)
                bloco(sombra, -3f, 7f, 6f, 2f)
            }
            EquipmentType.ARMOR -> {
                bloco(sombra, -8f, -7f, 16f, 14f)
                bloco(brilho, -7f, -8f, 14f, 12f)
                bloco(metal, -5f, -6f, 10f, 8f)
                bloco(brilho, -3f, -10f, 6f, 3f)
                bloco(sombra, -2f, 2f, 4f, 5f)
                bloco(Color(0xFFE7C16F), -1f, -3f, 2f, 3f)
            }
            EquipmentType.HELMET -> {
                bloco(sombra, -8f, -5f, 16f, 11f)
                bloco(brilho, -7f, -8f, 14f, 9f)
                bloco(metal, -5f, -6f, 10f, 5f)
                bloco(sombra, -6f, 2f, 12f, 3f)
                bloco(brilho, -2f, -11f, 4f, 3f)
            }
            EquipmentType.BOOTS -> {
                bloco(sombra, -7f, -8f, 5f, 14f)
                bloco(sombra, 2f, -8f, 5f, 14f)
                bloco(couro, -8f, 3f, 7f, 5f)
                bloco(couro, 1f, 3f, 7f, 5f)
                bloco(brilho, -6f, -7f, 3f, 8f)
                bloco(brilho, 3f, -7f, 3f, 8f)
            }
            EquipmentType.GLOVES -> {
                bloco(sombra, -8f, -5f, 6f, 13f)
                bloco(sombra, 2f, -5f, 6f, 13f)
                bloco(brilho, -7f, -6f, 4f, 10f)
                bloco(brilho, 3f, -6f, 4f, 10f)
                bloco(metal, -6f, -8f, 3f, 4f)
                bloco(metal, 3f, -8f, 3f, 4f)
            }
            EquipmentType.RING -> {
                drawCircle(brilho, radius = u * 7f, center = Offset(cx, cy), style = Stroke(width = u * 3f))
                drawCircle(Color.White.copy(alpha = .8f), radius = u * 2f, center = Offset(cx - u * 5f, cy - u * 5f))
            }
            EquipmentType.NECKLACE -> {
                drawArc(brilho, 205f, 130f, false, Offset(cx - u * 8f, cy - u * 8f), Size(u * 16f, u * 17f), style = Stroke(width = u * 2f))
                bloco(brilho, -2f, 5f, 4f, 5f)
                bloco(Color.White, -1f, 6f, 2f, 2f)
            }
        }
        drawRect(brilho.copy(alpha = .9f), Offset(cx - u * 10f, cy + u * 10f), Size(u * 20f, u * 1f))
        if (tier == RarityTier.WORLD) {
            drawCircle(Color(0xFFFF2028).copy(alpha = pulso), size.minDimension * .49f, Offset(cx, cy), style = Stroke(width = u * 1.5f))
            drawRect(Color(0xFFFF2028).copy(alpha = pulso), Offset(cx - u * 10f + falha, cy - u * 5f), Size(u * 5f, u * 1.2f))
            drawRect(Color(0xFFFF6870).copy(alpha = pulso * .8f), Offset(cx + u * 4f - falha, cy + u * 3f), Size(u * 6f, u * 1.1f))
        }
    }
}

/** Ovo de companheiro com marca visual da raridade e da mutação herdada. */
@Composable
fun OvoCompanheiroPixelArt(
    rank: String,
    mutacao: String = "COMUM",
    modifier: Modifier = Modifier
) {
    val cor = RarityVisuals.creatureRankColor(rank)
    val marca = RarityVisuals.color(mutacao)
    Canvas(modifier) {
        val u = size.minDimension / 24f
        val c = Offset(size.width / 2f, size.height / 2f)
        drawOval(Color(0xFF17212D).copy(alpha = .35f), Offset(c.x - u * 8f, c.y + u * 8f), Size(u * 16f, u * 3f))
        drawOval(Color(0xFF4A5362), Offset(c.x - u * 8f, c.y - u * 10f), Size(u * 16f, u * 20f))
        drawOval(cor, Offset(c.x - u * 7f, c.y - u * 9f), Size(u * 14f, u * 18f))
        drawOval(Color.White.copy(alpha = .55f), Offset(c.x - u * 4f, c.y - u * 6f), Size(u * 3f, u * 8f))
        drawLine(marca, Offset(c.x - u * 5f, c.y), Offset(c.x + u * 5f, c.y - u * 4f), u * 2.2f, cap = StrokeCap.Square)
        drawCircle(Color.White.copy(alpha = .8f), u * 1.3f, Offset(c.x + u * 3f, c.y - u * 5f))
    }
}

/** Ícone de materiais e recursos obtidos na exploração e em criaturas. */
@Composable
fun MaterialPixelArt(
    tipo: String,
    rank: String = "COMUM",
    modifier: Modifier = Modifier
) {
    val nome = tipo.lowercase()
    val cor = when {
        "osso" in nome || "dente" in nome -> Color(0xFFE4D8B9)
        "pele" in nome || "couro" in nome -> Color(0xFF9B6845)
        "carne" in nome -> Color(0xFFB95C58)
        "cristal" in nome || "gema" in nome -> Color(0xFF65CBE5)
        "madeira" in nome || "raiz" in nome -> Color(0xFF8D633C)
        "minério" in nome || "minerio" in nome || "metal" in nome -> Color(0xFF9CAAB8)
        else -> Color(0xFF8C9A72)
    }
    val sombra = Color(cor.red * .48f, cor.green * .48f, cor.blue * .48f)
    val tier = RarityVisuals.normalize(rank)
    val (pulso, falha) = lembrarEfeitoWorld(tier == RarityTier.WORLD)
    Canvas(modifier) {
        val u = size.minDimension / 20f
        val c = Offset(size.width / 2f, size.height / 2f)
        drawOval(Color(0xFF111923).copy(alpha = .35f), Offset(c.x - u * 7f, c.y + u * 6f), Size(u * 14f, u * 3f))
        if ("cristal" in nome || "gema" in nome) {
            val path = androidx.compose.ui.graphics.Path().apply {
                moveTo(c.x, c.y - u * 9f); lineTo(c.x + u * 7f, c.y - u); lineTo(c.x + u * 2f, c.y + u * 8f)
                lineTo(c.x - u * 6f, c.y + u * 4f); lineTo(c.x - u * 5f, c.y - u * 3f); close()
            }
            drawPath(path, cor)
            drawLine(Color.White.copy(alpha = .7f), Offset(c.x - u * 3f, c.y - u * 3f), Offset(c.x, c.y - u * 8f), u)
        } else {
            drawRect(sombra, Offset(c.x - u * 7f, c.y - u * 4f), Size(u * 14f, u * 10f))
            drawRect(cor, Offset(c.x - u * 6f, c.y - u * 6f), Size(u * 12f, u * 10f))
            drawRect(Color.White.copy(alpha = .55f), Offset(c.x - u * 4f, c.y - u * 5f), Size(u * 4f, u * 2f))
            drawRect(sombra, Offset(c.x - u * 2f, c.y + u * 2f), Size(u * 5f, u * 2f))
        }
        val raridade = RarityVisuals.color(rank)
        drawCircle(raridade, u * 1.7f, Offset(c.x + u * 7f, c.y - u * 7f))
        if (tier == RarityTier.MYTHIC) {
            drawCircle(
                brush = Brush.sweepGradient(listOf(Color(0xFFFF4D6D), Color(0xFFFFD166), Color(0xFF7AE582), Color(0xFF4CC9F0), Color(0xFF9B5DE5), Color(0xFFFF4D6D))),
                radius = u * 9f, center = c, style = Stroke(width = u * 1.5f)
            )
        }
        if (tier == RarityTier.WORLD) {
            drawCircle(Color(0xFFFF2028).copy(alpha = pulso), u * 9f, c, style = Stroke(width = u * 1.5f))
            drawRect(Color(0xFFFF3038).copy(alpha = pulso), Offset(c.x - u * 8f + falha, c.y - u * 3f), Size(u * 5f, u))
            drawRect(Color(0xFFFF8A8F).copy(alpha = pulso * .75f), Offset(c.x + u * 3f - falha, c.y + u * 2f), Size(u * 6f, u))
        }
    }
}
