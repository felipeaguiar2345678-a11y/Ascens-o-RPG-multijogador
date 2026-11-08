
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
            x = 0.52f,
            y = 0.78f
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

        // Movimento contínuo: não há uma parede invisível no limite da área.
        return WorldPosition(
            x = position.x + normalizedX * distance,
            y = position.y + normalizedY * distance
        )
    }
}
