
package br.com.ascensaodosoberano.powers

object PowerAwakeningEngine {

    private data class AwakeningPath(
        val id: String,
        val name: String,
        val description: String,
        val type: PowerType,
        val categories: Set<String>
    )

    private val awakeningPaths = listOf(
        AwakeningPath(
            "despertar_magico",
            "Afinidade Mágica",
            "Seu contato com forças mágicas pode despertar um poder próprio.",
            PowerType.MAGIC,
            setOf("magia", "magic")
        ),
        AwakeningPath(
            "despertar_fisico",
            "Domínio do Combate",
            "Sua experiência em combate físico pode despertar uma técnica exclusiva.",
            PowerType.PHYSICAL,
            setOf("fisico", "físico", "physical")
        ),
        AwakeningPath(
            "despertar_defensivo",
            "Instinto de Sobrevivência",
            "Suas experiências defensivas podem despertar uma habilidade especial.",
            PowerType.DEFENSE,
            setOf("defesa", "defensive")
        ),
        AwakeningPath(
            "despertar_explorador",
            "Percepção Desperta",
            "Suas descobertas podem revelar capacidades desconhecidas.",
            PowerType.UNKNOWN,
            setOf("exploracao", "exploração", "exploration")
        ),
        AwakeningPath(
            "despertar_agilidade",
            "Instinto Relâmpago",
            "Sua movimentação e agilidade podem despertar uma capacidade especial.",
            PowerType.AGILITY,
            setOf("agilidade", "agility")
        ),
        AwakeningPath(
            "despertar_invocacao",
            "Vínculo de Invocação",
            "Sua ligação com criaturas e entidades pode despertar um poder.",
            PowerType.SUMMONING,
            setOf("invocacao", "invocação")
        ),
        AwakeningPath(
            "despertar_elemental",
            "Afinidade Elemental",
            "Sua interação com forças elementais pode despertar uma habilidade.",
            PowerType.ELEMENTAL,
            setOf("elemental", "elemento")
        ),
        AwakeningPath(
            "despertar_espacial",
            "Percepção Espacial",
            "Suas experiências dimensionais podem despertar um poder espacial.",
            PowerType.SPATIAL,
            setOf("espacial", "dimensional", "espaco", "espaço")
        ),
        AwakeningPath(
            "despertar_gravitacional",
            "Domínio Gravitacional",
            "Sua interação com a gravidade pode despertar uma habilidade especial.",
            PowerType.GRAVITY,
            setOf("gravidade", "gravitacional")
        ),
        AwakeningPath(
            "despertar_hibrido",
            "Essência Híbrida",
            "A combinação de diferentes forças pode despertar um poder híbrido.",
            PowerType.HYBRID,
            setOf("hibrido", "híbrido", "combinacao", "combinação")
        )
    )

    
fun observe(
    profile: CharacterPowerProfile,
    action: String,
    category: String,
    intensity: Int,
    difficulty: Int = 1,
    origin: PowerOrigin? = null,
    successful: Boolean = true,
    tags: List<String> = emptyList()
): CharacterPowerProfile {

    val observation = PowerObservation(
        action = action,
        category = category,
        intensity = intensity.coerceIn(1, 100),
        difficulty = difficulty.coerceIn(1, 10),
        origin = origin,
        successful = successful,
        tags = tags
    )

    return profile.copy(
        observations = profile.observations + observation
    )
}

    fun evaluate(
        profile: CharacterPowerProfile
    ): List<PowerDesire> {

        if (profile.observations.isEmpty()) {
            return emptyList()
        }

        val results = mutableListOf<PowerDesire>()

        for (path in awakeningPaths) {

            val evidence = profile.observations.filter { observation ->

                val category = observation.category
                    .trim()
                    .lowercase()

                val tags = observation.tags.map {
                    it.trim().lowercase()
                }

                category in path.categories ||
                    tags.any { it in path.categories }
            }

            if (evidence.isEmpty()) continue

            val progress = calculateProgress(evidence)

            // É necessário demonstrar experiências relevantes.
            if (progress < 20) continue

            val alreadyDesired = profile.desires.any {
                it.id == path.id
            }

            val alreadyAwakened = profile.powers.any {
                it.id == path.id
            }

            if (alreadyDesired || alreadyAwakened) continue

            results.add(
                PowerDesire(
                    id = path.id,
                    name = path.name,
                    description = path.description,
                    desiredType = path.type,
                    progress = progress.coerceIn(0, 100)
                )
            )
        }

        return results
    }

    private fun calculateProgress(
        observations: List<PowerObservation>
    ): Int {

        // Limita a contribuição de ações repetidas
        // para evitar progresso infinito por repetição.
        val groupedActions = observations.groupBy {
            it.action.trim().lowercase()
        }

        var total = 0.0

        for (group in groupedActions.values) {

            val strongestExperiences = group
                .sortedByDescending {
                    calculateExperienceValue(it)
                }
                .take(3)

            total += strongestExperiences.sumOf {
                calculateExperienceValue(it)
            }
        }

        // Valoriza a variedade de experiências.
        val diversityBonus =
            ((groupedActions.size.coerceAtMost(5) - 1)
                .coerceAtLeast(0) * 3)

        return (total + diversityBonus)
            .toInt()
            .coerceIn(0, 100)
    }

    private fun calculateExperienceValue(
        observation: PowerObservation
    ): Double {

        val intensity =
            observation.intensity.coerceIn(1, 100) / 10.0

        val difficulty =
            observation.difficulty.coerceIn(1, 10)

        val difficultyMultiplier =
            1.0 + ((difficulty - 1) * 0.12)

        val originBonus = when (observation.origin) {
            PowerOrigin.TRAINING -> 0
            PowerOrigin.QUEST -> 8
            PowerOrigin.BOSS_DEFEAT -> 18
            PowerOrigin.EXPLORATION -> 8
            PowerOrigin.SURVIVAL -> 12
            PowerOrigin.DISCOVERY -> 12
            PowerOrigin.COMBINATION -> 15
            PowerOrigin.WORLD_EVENT -> 15
            PowerOrigin.SPECIAL_EVENT -> 20
            null -> 0
        }

        val successMultiplier =
            if (observation.successful) 1.0 else 0.4

        return (
            (intensity * difficultyMultiplier + originBonus) *
                successMultiplier
            ).coerceAtLeast(0.0)
    }
}
