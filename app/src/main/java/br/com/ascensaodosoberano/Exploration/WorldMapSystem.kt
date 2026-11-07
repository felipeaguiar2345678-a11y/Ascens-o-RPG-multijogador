
package br.com.ascensaodosoberano.exploration

import kotlin.math.sqrt

data class WorldPosition(
    val x: Float = 0.5f,
    val y: Float = 0.5f
)

data class MovementDirection(
    val x: Float = 0f,
    val y: Float = 0f
)

object WorldMapSystem {

    // Velocidade inicial do personagem
    const val MOVEMENT_SPEED = 0.12f

    // O personagem começa no centro do mapa
    fun initialPosition(): WorldPosition {
        return WorldPosition(
            x = 0.5f,
            y = 0.5f
        )
    }

    // Movimenta o personagem em qualquer direção
    fun move(
        position: WorldPosition,
        direction: MovementDirection,
        deltaTime: Float
    ): WorldPosition {

        val length = sqrt(
            direction.x * direction.x +
            direction.y * direction.y
        )

        if (length == 0f) return position

        val normalizedX = direction.x / length
        val normalizedY = direction.y / length

        val distance = MOVEMENT_SPEED * deltaTime

        return WorldPosition(
            x = (position.x + normalizedX * distance)
                .coerceIn(0f, 1f),

            y = (position.y + normalizedY * distance)
                .coerceIn(0f, 1f)
        )
    }
}
