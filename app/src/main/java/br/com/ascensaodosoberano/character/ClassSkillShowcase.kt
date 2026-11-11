package br.com.ascensaodosoberano.character

import androidx.compose.animation.core.FastOutSlowInEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
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
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
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
    modifier: Modifier = Modifier
) {
    val scene = sceneForClass(className)
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
        Text("APRESENTAÇÃO DA CLASSE", color = Color(0xFFFFD995), style = MaterialTheme.typography.labelLarge)
        Text(scene.title, color = Color.White, style = MaterialTheme.typography.titleLarge)
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
                    "arrow" -> {
                        val x = center.x + sweep * radius * 1.2f
                        drawLine(scene.colors.first(), Offset(x - radius * 1.6f, center.y), Offset(x + radius * 1.6f, center.y), 4.dp.toPx(), cap = StrokeCap.Round)
                        drawCircle(scene.colors.last(), 5.dp.toPx(), Offset(center.x + radius * 1.7f, center.y))
                    }
                    else -> {
                        for (i in 0..7) {
                            val angle = (i * Math.PI / 4.0) + sweep * 0.55
                            val start = Offset(center.x + kotlin.math.cos(angle).toFloat() * radius * 0.65f, center.y + kotlin.math.sin(angle).toFloat() * radius * 0.65f)
                            val end = Offset(center.x + kotlin.math.cos(angle).toFloat() * radius * (1.5f + pulse * 0.35f), center.y + kotlin.math.sin(angle).toFloat() * radius * (1.5f + pulse * 0.35f))
                            drawLine(scene.colors[i % scene.colors.size], start, end, 4.dp.toPx(), cap = StrokeCap.Round)
                        }
                    }
                }
            }
            Text("✦  ${className.uppercase()}  ✦", color = Color.White, style = MaterialTheme.typography.titleMedium)
        }
        Text(scene.action, color = Color(0xFFD6DFED), style = MaterialTheme.typography.bodyMedium)
        if (classDescription.isNotBlank()) {
            Text(classDescription, color = Color(0xFF9EADC2), style = MaterialTheme.typography.bodySmall, maxLines = 3)
        }
        Text("Demonstração animada • arte definitiva carregada em seguida", color = Color(0xFFFFD995), style = MaterialTheme.typography.labelSmall)
    }
}
