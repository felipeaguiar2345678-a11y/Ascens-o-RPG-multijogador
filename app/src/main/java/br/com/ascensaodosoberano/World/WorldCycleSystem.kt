package br.com.ascensaodosoberano.world

/**
 * Relógio mundial calculado a partir de um instante UTC fornecido por uma fonte confiável.
 * O cliente não escolhe o horário: todos calculam a mesma fase a partir do mesmo epoch.
 */
enum class WorldTimePhase { DAY, SUNSET, NIGHT, DAWN }

data class WorldTimeSnapshot(
    val cycleNumber: Long,
    val secondOfCycle: Int,
    val phase: WorldTimePhase,
    val secondsUntilPhaseChange: Int,
    val isNight: Boolean,
    val daylightFactor: Float,
    val nocturnalCreatureMultiplier: Float,
    val nightLootMultiplier: Float
)

object WorldCycleSystem {
    const val CYCLE_SECONDS = 15 * 60
    const val DAY_SECONDS = 10 * 60
    const val NIGHT_SECONDS = 5 * 60
    private const val SUNSET_SECONDS = 60
    private const val DAWN_SECONDS = 60

    fun calculate(serverEpochMillis: Long): WorldTimeSnapshot {
        val totalSeconds = Math.floorDiv(serverEpochMillis, 1_000L)
        val cycle = Math.floorDiv(totalSeconds, CYCLE_SECONDS.toLong())
        val second = Math.floorMod(totalSeconds, CYCLE_SECONDS.toLong()).toInt()
        val sunsetStart = DAY_SECONDS - SUNSET_SECONDS
        val nightStart = DAY_SECONDS
        val dawnStart = CYCLE_SECONDS - DAWN_SECONDS

        val phase = when {
            second >= dawnStart -> WorldTimePhase.DAWN
            second >= nightStart -> WorldTimePhase.NIGHT
            second >= sunsetStart -> WorldTimePhase.SUNSET
            else -> WorldTimePhase.DAY
        }
        val nextBoundary = when (phase) {
            WorldTimePhase.DAY -> sunsetStart
            WorldTimePhase.SUNSET -> nightStart
            WorldTimePhase.NIGHT -> dawnStart
            WorldTimePhase.DAWN -> CYCLE_SECONDS
        }
        val daylight = when (phase) {
            WorldTimePhase.DAY -> 1f
            WorldTimePhase.SUNSET -> 1f - ((second - sunsetStart).toFloat() / SUNSET_SECONDS)
            WorldTimePhase.NIGHT -> 0f
            WorldTimePhase.DAWN -> ((second - dawnStart).toFloat() / DAWN_SECONDS).coerceIn(0f, 1f)
        }
        val night = phase == WorldTimePhase.NIGHT
        return WorldTimeSnapshot(
            cycleNumber = cycle,
            secondOfCycle = second,
            phase = phase,
            secondsUntilPhaseChange = (nextBoundary - second).coerceAtLeast(0),
            isNight = night,
            daylightFactor = daylight,
            nocturnalCreatureMultiplier = if (night) 2f else 1f,
            nightLootMultiplier = if (night) 1.5f else 1f
        )
    }

    fun combatMultiplier(snapshot: WorldTimeSnapshot, nocturnal: Boolean): Float =
        if (snapshot.isNight && nocturnal) snapshot.nocturnalCreatureMultiplier else 1f
}
