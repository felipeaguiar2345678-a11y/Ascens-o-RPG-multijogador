
package br.com.ascensaodosoberano.exploration

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.size
import androidx.compose.runtime.Composable
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.unit.dp
import kotlin.math.sqrt

@Composable
fun ControleVirtual(
    onDirectionChange: (MovementDirection) -> Unit,
    modifier: Modifier = Modifier
) {
    val joystickOffset = remember {
        mutableStateOf(Offset.Zero)
    }

    val maxRadius = 48.dp
val density = androidx.compose.ui.platform.LocalDensity.current
val limitePx = with(density) {
    maxRadius.toPx()
}

    Canvas(
        modifier = modifier
            .size(150.dp)
            .pointerInput(limitePx) {
             val limite = limitePx

                detectDragGestures(
                    onDragStart = { position ->
                        val center = Offset(
                            size.width / 2f,
                            size.height / 2f
                        )

                        val dx = position.x - center.x
                        val dy = position.y - center.y
                        val distance = sqrt(dx * dx + dy * dy)

                        val factor = if (distance > limite) {
                            limite / distance
                        } else {
                            1f
                        }

                        joystickOffset.value = Offset(
                            dx * factor,
                            dy * factor
                        )

                        onDirectionChange(
                            MovementDirection(
                                joystickOffset.value.x / limite,
                                joystickOffset.value.y / limite
                            )
                        )
                    },
                    onDragEnd = {
                        joystickOffset.value = Offset.Zero
                        onDirectionChange(MovementDirection())
                    },
                    onDragCancel = {
                        joystickOffset.value = Offset.Zero
                        onDirectionChange(MovementDirection())
                    },
                    onDrag = { change, dragAmount ->
                        change.consume()

                        val novoX = joystickOffset.value.x + dragAmount.x
                        val novoY = joystickOffset.value.y + dragAmount.y

                        val distance = sqrt(
                            novoX * novoX + novoY * novoY
                        )

                        val factor = if (distance > limite) {
                            limite / distance
                        } else {
                            1f
                        }

                        joystickOffset.value = Offset(
                            novoX * factor,
                            novoY * factor
                        )

                        onDirectionChange(
                            MovementDirection(
                                joystickOffset.value.x / limite,
                                joystickOffset.value.y / limite
                            )
                        )
                    }
                )
            }
    ) {
        val center = Offset(
            size.width / 2f,
            size.height / 2f
        )

        // Base metálica com profundidade, aro externo e marcações direcionais.
        drawCircle(
            color = Color(0xAA080D16),
            radius = size.minDimension * 0.47f,
            center = center + Offset(0f, 3.dp.toPx())
        )
        drawCircle(
            brush = androidx.compose.ui.graphics.Brush.radialGradient(
                colors = listOf(Color(0xFF596B7A), Color(0xFF273747), Color(0xFF121D2A)),
                center = center,
                radius = size.minDimension * .48f
            ),
            radius = size.minDimension * .46f,
            center = center
        )
        drawCircle(
            color = Color(0xFFE0C58D),
            radius = size.minDimension * 0.46f,
            center = center,
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 3.dp.toPx())
        )
        drawCircle(
            color = Color(0xFFB9C8D4).copy(alpha = .55f),
            radius = size.minDimension * .36f,
            center = center,
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 1.dp.toPx())
        )
        for (i in 0..7) {
            val angulo = i * (Math.PI / 4.0)
            val externo = size.minDimension * .405f
            val interno = size.minDimension * .35f
            val inicio = Offset(
                center.x + kotlin.math.cos(angulo).toFloat() * interno,
                center.y + kotlin.math.sin(angulo).toFloat() * interno
            )
            val fim = Offset(
                center.x + kotlin.math.cos(angulo).toFloat() * externo,
                center.y + kotlin.math.sin(angulo).toFloat() * externo
            )
            drawLine(Color(0xFFFFE3A6).copy(alpha = .72f), inicio, fim, 1.5.dp.toPx())
        }
        drawCircle(
            color = Color(0xFF101A26).copy(alpha = .65f),
            radius = size.minDimension * .25f,
            center = center
        )
        // Alavanca com reflexo superior e sombra deslocada.
        drawCircle(
            color = Color(0xFF101722).copy(alpha = .75f),
            radius = size.minDimension * .17f,
            center = center + joystickOffset.value + Offset(0f, 2.dp.toPx())
        )
        drawCircle(
            brush = androidx.compose.ui.graphics.Brush.radialGradient(
                colors = listOf(Color(0xFFFFF0C8), Color(0xFFE0C58D), Color(0xFF8A6840)),
                center = center + joystickOffset.value + Offset(-5.dp.toPx(), -6.dp.toPx()),
                radius = size.minDimension * .25f
            ),
            radius = size.minDimension * 0.16f,
            center = center + joystickOffset.value
        )
        drawCircle(
            color = Color(0xFF795B35),
            radius = size.minDimension * 0.16f,
            center = center + joystickOffset.value,
            style = androidx.compose.ui.graphics.drawscope.Stroke(width = 2.dp.toPx())
        )
        drawCircle(
            color = Color.White.copy(alpha = .55f),
            radius = size.minDimension * .035f,
            center = center + joystickOffset.value + Offset(-5.dp.toPx(), -6.dp.toPx())
        )
    }
}
