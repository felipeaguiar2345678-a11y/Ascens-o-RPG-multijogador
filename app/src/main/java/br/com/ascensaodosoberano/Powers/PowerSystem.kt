
package br.com.ascensaodosoberano.powers

enum class PowerType {
    PHYSICAL,
    MAGIC,
    DEFENSE,
    AGILITY,
    SUMMONING,
    ELEMENTAL,
    SPATIAL,
    GRAVITY,
    HYBRID,
    UNKNOWN
}

enum class PowerStatus {
    DESIRED,
    IN_DEVELOPMENT,
    AWAKENED,
    EVOLVING,
    MASTERED
}

enum class PowerOrigin {
    TRAINING,
    QUEST,
    BOSS_DEFEAT,
    EXPLORATION,
    SURVIVAL,
    DISCOVERY,
    COMBINATION,
    WORLD_EVENT,
    SPECIAL_EVENT
}

data class PowerDesire(
    val id: String,
    val name: String,
    val description: String,
    val desiredType: PowerType,
    val progress: Int = 0,
    val createdAt: Long = System.currentTimeMillis()
)

data class AwakenedPower(
    val id: String,
    val name: String,
    val description: String,
    val type: PowerType,
    val origin: PowerOrigin,
    val status: PowerStatus = PowerStatus.AWAKENED,
    val level: Int = 1,
    val experience: Int = 0,
    val manaCost: Int = 0,
    val baseDamage: Int = 0,
    val cooldown: Int = 0,
    val effects: List<String> = emptyList(),
    val limitations: List<String> = emptyList()
)

data class PowerObservation(
    val action: String,
    val category: String,
    val intensity: Int,
    val timestamp: Long = System.currentTimeMillis(),

    val difficulty: Int = 1,
    val origin: PowerOrigin? = null,
    val successful: Boolean = true,
    val tags: List<String> = emptyList()
)

data class CharacterPowerProfile(
    val desires: List<PowerDesire> = emptyList(),
    val powers: List<AwakenedPower> = emptyList(),
    val observations: List<PowerObservation> = emptyList()
)
