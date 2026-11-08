package br.com.ascensaodosoberano.exploration

import org.junit.Assert.assertEquals
import org.junit.Test

class WorldMapSystemTest {

    @Test
    fun movementContinuesBeyondFormerInvisibleBoundary() {
        val start = WorldPosition(x = 0.5f, y = 0.5f)
        val moved = WorldMapSystem.move(
            start,
            MovementDirection(x = 1f, y = 0f),
            deltaTime = 10f
        )

        assertEquals(1.7f, moved.x, 0.0001f)
        assertEquals(0.5f, moved.y, 0.0001f)
    }

    @Test
    fun diagonalMovementIsNormalized() {
        val start = WorldPosition(x = 0.5f, y = 0.5f)
        val moved = WorldMapSystem.move(
            start,
            MovementDirection(x = 1f, y = 1f),
            deltaTime = 1f
        )

        assertEquals(0.12f / kotlin.math.sqrt(2f), moved.x - start.x, 0.0001f)
        assertEquals(0.12f / kotlin.math.sqrt(2f), moved.y - start.y, 0.0001f)
    }
}
