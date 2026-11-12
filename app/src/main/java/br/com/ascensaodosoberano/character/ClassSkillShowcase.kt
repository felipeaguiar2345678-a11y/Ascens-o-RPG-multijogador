package br.com.ascensaodosoberano.character

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import kotlinx.coroutines.delay
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.graphics.drawscope.rotate
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.layout.ContentScale
import coil.compose.AsyncImage
import androidx.compose.ui.unit.dp

private data class SkillScene(
    val title: String,
    val action: String,
    val colors: List<Color>,
    val kind: String
)

private fun sceneForClass(name: String): SkillScene {
    val value = name.lowercase()
    return when {
        "drag" in value || "drac" in value || "dracôn" in value ->
            SkillScene("Presença dracônica", "Uma energia ancestral percorre o corpo humanoide, unindo distorção temporal e poder de destruição.", listOf(Color(0xFF9A8BFF), Color(0xFF63D8FF)), "dragon")
        "arque" in value || "atir" in value || "caçador" in value ->
            SkillScene("Precisão absoluta", "O aventureiro tensiona o arco e acerta o centro de um alvo distante.", listOf(Color(0xFF8DE5C0), Color(0xFFFFE6A3)), "arrow")
        "guer" in value || "cavaleiro" in value || "espad" in value ->
            SkillScene("Corte devastador", "Uma sequência de movimentos termina em um golpe de espada cheio de energia.", listOf(Color(0xFFFFD17A), Color(0xFFFF795E)), "sword")
        "necrom" in value || "morte" in value ->
            SkillScene("Chamado das almas", "Energias espirituais se erguem e giram ao redor do aventureiro.", listOf(Color(0xFFB69AFF), Color(0xFF63D8C7)), "soul")
        "tempo" in value || "cron" in value ->
            SkillScene("Distorção temporal", "O tempo desacelera; anéis rúnicos se expandem ao redor do aventureiro.", listOf(Color(0xFF8BD7FF), Color(0xFFC5A4FF)), "time")
        "luz" in value || "sagrado" in value || "clér" in value ->
            SkillScene("Explosão radiante", "Uma onda de luz envolve o aventureiro e ilumina todo o salão.", listOf(Color(0xFFFFF0A6), Color(0xFFFFC86B)), "light")
        "mago" in value || "feitice" in value || "pirom" in value || "fogo" in value ->
            SkillScene("Chama arcana", "Os olhos brilham e uma magia flamejante se forma na palma da mão.", listOf(Color(0xFFFFB15E), Color(0xFFFF5D45)), "fire")
        else ->
            SkillScene("Demonstração de poder", "O aventureiro reúne sua energia e demonstra uma técnica característica da classe.", listOf(Color(0xFF8CCBFF), Color(0xFFC5A4FF)), "arcane")
    }
}

@Composable
fun ClassSkillShowcase(
    className: String,
    classDescription: String,
    imageUrl: String = "",
    modifier: Modifier = Modifier
) {
    val scene = sceneForClass(className)
    var showDescription by remember(className) { mutableStateOf(false) }
    LaunchedEffect(className) {
        showDescription = false
        delay(4200)
        showDescription = true
    }
    val transition = rememberInfiniteTransition(label = "class_skill_scene")
    val pulse by transition.animateFloat(
        initialValue = 0.18f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1150, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "skill_pulse"
    )
    val rotation by transition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec = infiniteRepeatable(tween(2600, easing = LinearEasing)),
        label = "arcane_light_rotation"
    )
    val actionPhase by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(1800, easing = FastOutSlowInEasing),
            repeatMode = RepeatMode.Reverse
        ),
        label = "character_action_motion"
    )
    val sweep by transition.animateFloat(
        initialValue = -1f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(1900, easing = FastOutSlowInEasing)),
        label = "skill_sweep"
    )

    Column(
        modifier = modifier
            .fillMaxWidth()
            .background(Color(0xFF171D2B), RoundedCornerShape(18.dp))
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .height(190.dp)
                .background(
                    Brush.verticalGradient(listOf(Color(0xFF28334A), Color(0xFF111827))),
                    RoundedCornerShape(14.dp)
                ),
            contentAlignment = Alignment.Center
        ) {
            Canvas(Modifier.fillMaxWidth().height(190.dp)) {
                val center = Offset(size.width * 0.5f, size.height * 0.52f)
                val radius = size.minDimension * (0.18f + pulse * 0.08f)
                drawCircle(
                    brush = Brush.radialGradient(
                        colors = listOf(scene.colors.first().copy(alpha = 0.34f), Color.Transparent),
                        center = center,
                        radius = radius * 2.8f
                    ),
                    radius = radius * 2.8f,
                    center = center
                )
                drawCircle(scene.colors.first().copy(alpha = 0.7f), radius, center, style = Stroke(width = 3.dp.toPx()))
                drawCircle(scene.colors.last().copy(alpha = 0.45f), radius * 1.45f, center, style = Stroke(width = 2.dp.toPx()))
                when (scene.kind) {
                    "sword" -> {
                        drawLine(scene.colors.first(), Offset(center.x - radius * 1.7f, center.y + radius), Offset(center.x + radius * 1.6f, center.y - radius), 7.dp.toPx(), cap = StrokeCap.Round)
                        drawLine(Color.White.copy(alpha = 0.8f), Offset(center.x - radius * 1.1f, center.y + radius * 0.8f), Offset(center.x + radius * 1.9f, center.y - radius * 1.2f), 2.dp.toPx())
                    }
                    "dragon" -> {
                        rotate(degrees = rotation, pivot = center) {
                            drawArc(scene.colors.first(), -35f, 145f, false, Offset(center.x - radius * 1.7f, center.y - radius * 1.7f), androidx.compose.ui.geometry.Size(radius * 3.4f, radius * 3.4f), style = Stroke(width = 5.dp.toPx()))
                            drawArc(scene.colors.last(), 145f, 145f, false, Offset(center.x - radius * 1.7f, center.y - radius * 1.7f), androidx.compose.ui.geometry.Size(radius * 3.4f, radius * 3.4f), style = Stroke(width = 5.dp.toPx()))
                        }
                        drawLine(scene.colors.first(), Offset(center.x - radius * 1.4f, center.y + radius * 0.8f), Offset(center.x + radius * 1.4f, center.y - radius * 0.8f), 5.dp.toPx(), cap = StrokeCap.Round)
                        drawLine(scene.colors.last(), Offset(center.x - radius * 1.2f, center.y - radius * 0.8f), Offset(center.x + radius * 1.2f, center.y + radius * 0.8f), 5.dp.toPx(), cap = StrokeCap.Round)
                    }
                    "arrow" -> {
                        val x = center.x + sweep * radius * 1.2f
                        drawLine(scene.colors.first(), Offset(x - radius * 1.6f, center.y), Offset(x + radius * 1.6f, center.y), 4.dp.toPx(), cap = StrokeCap.Round)
                        drawCircle(scene.colors.last(), 5.dp.toPx(), Offset(center.x + radius * 1.7f, center.y))
                    }
                    else -> {
                        // Raios de energia giram continuamente em torno do núcleo.
                        rotate(degrees = rotation, pivot = center) {
                            for (i in 0..7) {
                                val angle = i * Math.PI / 4.0
                                val start = Offset(center.x + kotlin.math.cos(angle).toFloat() * radius * 0.65f, center.y + kotlin.math.sin(angle).toFloat() * radius * 0.65f)
                                val end = Offset(center.x + kotlin.math.cos(angle).toFloat() * radius * (1.5f + pulse * 0.35f), center.y + kotlin.math.sin(angle).toFloat() * radius * (1.5f + pulse * 0.35f))
                                drawLine(scene.colors[i % scene.colors.size], start, end, 4.dp.toPx(), cap = StrokeCap.Round)
                            }
                        }
                        // Pequeno brilho orbital acompanha a rotação.
                        val orbitAngle = rotation * Math.PI / 180.0
                        val orbit = Offset(
                            center.x + kotlin.math.cos(orbitAngle).toFloat() * radius * 1.62f,
                            center.y + kotlin.math.sin(orbitAngle).toFloat() * radius * 1.62f
                        )
                        drawCircle(Color.White.copy(alpha = 0.9f), 3.5.dp.toPx(), orbit)
                    }
                }
            }
            if (imageUrl.isNotBlank()) {
                AsyncImage(
                    model = imageUrl,
                    contentDescription = "Personagem da classe ${className} executando sua habilidade",
                    modifier = Modifier
                        .fillMaxWidth()
                        .height(190.dp)
                        .graphicsLayer {
                            val movement = kotlin.math.sin(actionPhase * Math.PI).toFloat()
                            translationX = when (scene.kind) {
                                "sword" -> movement * 24f
                                "arrow" -> movement * 9f
                                else -> movement * 13f
                            }
                            translationY = -movement * 7f
                            rotationZ = when (scene.kind) {
                                "sword" -> movement * -4f
                                "arrow" -> movement * 1.5f
                                else -> movement * -1.5f
                            }
                            scaleX = 0.98f + movement * 0.045f
                            scaleY = 0.98f + movement * 0.045f
                        },
                    contentScale = ContentScale.Fit
                )
            }
            Canvas(Modifier.fillMaxWidth().height(190.dp)) {
                val center = Offset(size.width * 0.5f, size.height * 0.52f)
                val radius = size.minDimension * (0.18f + pulse * 0.08f)
                when (scene.kind) {
                    "sword" -> {
                        val slash = sweep * radius * 0.8f
                        drawLine(Color.White.copy(alpha = 0.75f * pulse), Offset(center.x - radius * 1.4f + slash, center.y + radius), Offset(center.x + radius * 1.6f + slash, center.y - radius), 3.dp.toPx(), cap = StrokeCap.Round)
                    }
                    "arrow" -> {
                        val arrowX = center.x + sweep * radius * 1.6f
                        drawLine(scene.colors.first(), Offset(arrowX - radius, center.y), Offset(arrowX + radius, center.y), 3.dp.toPx(), cap = StrokeCap.Round)
                        drawCircle(Color.White, 3.dp.toPx(), Offset(arrowX + radius, center.y))
                    }
                    "fire" -> {
                        for (i in 0..5) {
                            val flicker = (pulse + i * 0.13f) % 1f
                            val x = center.x + (i - 2.5f) * radius * 0.32f
                            val y = center.y + radius * (0.75f - flicker * 1.3f)
                            drawCircle(scene.colors[i % scene.colors.size].copy(alpha = 0.7f), (3f + flicker * 5f).dp.toPx(), Offset(x, y))
                        }
                    }
                    else -> Unit
                }
            }
        }
        if (showDescription) {
            if (scene.title.isNotBlank()) {
                Text(scene.title, color = Color(0xFFFFD995), style = MaterialTheme.typography.titleMedium)
            }
            if (scene.action.isNotBlank()) {
                Text(scene.action, color = Color(0xFFD6DFED), style = MaterialTheme.typography.bodyMedium)
            }
            if (classDescription.isNotBlank()) {
                Text(classDescription, color = Color(0xFF9EADC2), style = MaterialTheme.typography.bodySmall)
            }
        }
    }
}
