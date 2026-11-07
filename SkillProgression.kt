
package br.com.ascensaodosoberano.character

data class SkillProgress(
    val skillName: String,
    val domain: SkillDomain,
    val level: Int = 1,
    val trainingXp: Int = 0
)

object SkillProgression {

    fun xpRequired(
        characterClass: CharacterClass,
        domain: SkillDomain,
        skillLevel: Int
    ): Int {
        val affinity = CharacterSystem.getLearningEfficiency(
            characterClass,
            domain
        )

        val baseCost = 100 + (skillLevel - 1) * 50

        return (baseCost / affinity).toInt()
    }

    fun train(
        characterClass: CharacterClass,
        skill: SkillProgress,
        earnedTrainingXp: Int
    ): SkillProgress {

        var level = skill.level
        var xp = skill.trainingXp + earnedTrainingXp.coerceAtLeast(0)

        while (xp >= xpRequired(
                characterClass,
                skill.domain,
                level
            )
        ) {
            xp -= xpRequired(
                characterClass,
                skill.domain,
                level
            )

            level++
        }

        return skill.copy(
            level = level,
            trainingXp = xp
        )
    }

    fun getAffinityDescription(
        characterClass: CharacterClass,
        domain: SkillDomain
    ): String {
        return when (
            characterClass.affinities[domain] ?: Affinity.MEDIUM
        ) {
            Affinity.HIGH -> "Afinidade alta: aprendizado rápido."
            Affinity.MEDIUM -> "Afinidade média: aprendizado equilibrado."
            Affinity.LOW -> "Afinidade baixa: exige mais treinamento."
        }
    }
}
