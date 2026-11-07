

package br.com.ascensaodosoberano.exploration

import kotlin.math.sqrt

object CompanionFollowSystem {

    // Distância que o companheiro mantém do jogador
    const val FOLLOW_DISTANCE = 0.035f

    // Velocidade de acompanhamento
    const val FOLLOW_SPEED =
        WorldMapSystem.MOVEMENT_SPEED * 1.35f

    fun follow(
        playerPosition: WorldPosition,
        companionPosition: WorldPosition,
        deltaTime: Float
    ): WorldPosition {

        val dx = playerPosition.x - companionPosition.x
        val dy = playerPosition.y - companionPosition.y

        val distance = sqrt(dx * dx + dy * dy)

        if (distance <= FOLLOW_DISTANCE || deltaTime <= 0f) {
            return companionPosition
        }

        val normalizedX = dx / distance
        val normalizedY = dy / distance

        val distanciaRestante = distance - FOLLOW_DISTANCE

        val movimento = minOf(
            FOLLOW_SPEED * deltaTime,
            distanciaRestante
        )

        return WorldPosition(
            x = (companionPosition.x + normalizedX * movimento)
                .coerceIn(0f, 1f),
            y = (companionPosition.y + normalizedY * movimento)
                .coerceIn(0f, 1f)
        )
    }
}
