
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

        drawCircle(
            color = Color(0x885D5140),
            radius = size.minDimension * 0.46f,
            center = center
        )

        drawCircle(
            color = Color(0xCCB99A65),
            radius = size.minDimension * 0.46f,
            center = center,
            style = androidx.compose.ui.graphics.drawscope.Stroke(
                width = 3.dp.toPx()
            )
        )

        drawCircle(
            color = Color(0xFFE0C58D),
            radius = size.minDimension * 0.16f,
            center = center + joystickOffset.value
        )

        drawCircle(
            color = Color(0xFF795B35),
            radius = size.minDimension * 0.16f,
            center = center + joystickOffset.value,
            style = androidx.compose.ui.graphics.drawscope.Stroke(
                width = 2.dp.toPx()
            )
        )
    }
}
