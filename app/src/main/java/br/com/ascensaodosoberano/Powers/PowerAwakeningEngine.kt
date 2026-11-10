
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


    fun createStarterFallback(
        className: String,
        type: PowerType,
        originDesireId: String = "despertar_inicial_classe"
    ): AwakenedPower {
        val template = when (type) {
            PowerType.PHYSICAL -> Triple("Impacto de " + className, "Concentra a força do aventureiro em um golpe preciso.", listOf("Golpe físico concentrado"))
            PowerType.MAGIC, PowerType.ELEMENTAL, PowerType.SPATIAL, PowerType.GRAVITY -> Triple("Centelha de " + className, "Libera uma pequena manifestação de energia que responde à vontade do aventureiro.", listOf("Pulso de energia", "Alcance curto"))
            PowerType.AGILITY -> Triple("Passo Instintivo", "Um movimento súbito que combina deslocamento e um ataque rápido.", listOf("Movimento rápido", "Ataque de oportunidade"))
            PowerType.DEFENSE -> Triple("Postura Inabalável", "Concentra a resistência do corpo em uma resposta defensiva.", listOf("Guarda reforçada", "Contra-ataque curto"))
            PowerType.SUMMONING -> Triple("Vínculo Menor", "Manifesta uma pequena extensão da vontade do invocador para atingir um alvo.", listOf("Manifestação auxiliar", "Vínculo instável"))
            PowerType.HYBRID -> Triple("Manifestação Híbrida", "Combina duas inclinações da classe em uma técnica versátil.", listOf("Combinação inicial"))
            PowerType.UNKNOWN -> Triple("Instinto Desperto", "Uma habilidade inicial que responde à natureza ainda desconhecida do aventureiro.", listOf("Manifestação inicial"))
        }
        val damage = when (type) {
            PowerType.PHYSICAL, PowerType.AGILITY -> 8
            PowerType.MAGIC, PowerType.ELEMENTAL, PowerType.SPATIAL, PowerType.GRAVITY -> 7
            PowerType.SUMMONING, PowerType.HYBRID -> 6
            PowerType.DEFENSE, PowerType.UNKNOWN -> 5
        }
        val mana = when (type) {
            PowerType.MAGIC, PowerType.ELEMENTAL, PowerType.SPATIAL, PowerType.GRAVITY, PowerType.SUMMONING, PowerType.HYBRID -> 3
            else -> 0
        }
        return AwakenedPower(
            id = "starter_fallback_" + type.name.lowercase(),
            name = template.first,
            description = template.second,
            type = type,
            origin = PowerOrigin.DISCOVERY,
            status = PowerStatus.AWAKENED,
            level = 1,
            manaCost = mana,
            baseDamage = damage,
            durationTurns = 0,
            cooldown = 1,
            effects = template.third,
            limitations = listOf("É a manifestação inicial; seu potencial verdadeiro será desenvolvido durante a aventura."),
            concept = "Habilidade inicial ligada à classe " + className + ".",
            potential = "Pode evoluir e revelar novas aplicações conforme as experiências do aventureiro.",
            manifestation = template.second,
            awakeningNarrative = "Mesmo antes de dominar seu poder, o aventureiro desperta uma primeira técnica própria.",
            originDesireId = originDesireId
        )
    }
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
        observations = (profile.observations + observation).takeLast(500)
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
                val category = observation.category.trim().lowercase()
                val tags = observation.tags.map { it.trim().lowercase() }
                category in path.categories || tags.any { it in path.categories }
            }
            if (evidence.isEmpty()) continue
            val progress = calculateProgress(evidence)
            if (progress < 20) continue
            if (profile.desires.any { it.id == path.id } || profile.powers.any { it.id == path.id }) continue
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

        // Categorias novas não precisam existir numa lista fechada: viram pistas
        // abertas para a IA inventar uma manifestação inteiramente original.
        val knownCategories = awakeningPaths.flatMap { it.categories }.toSet()
        val freeCategories = profile.observations
            .flatMap { observation -> listOf(observation.category) + observation.tags }
            .map { it.trim().lowercase() }
            .filter { it.isNotBlank() && it !in knownCategories }
            .distinct()
        for (category in freeCategories) {
            val evidence = profile.observations.filter { observation ->
                observation.category.trim().lowercase() == category ||
                    observation.tags.any { it.trim().lowercase() == category }
            }
            val id = "despertar_livre_" + category
                .replace(Regex("[^a-z0-9_]+"), "_").take(48)
            if (calculateProgress(evidence) < 20) continue
            if (profile.desires.any { it.id == id } || profile.powers.any { it.id == id }) continue
            results.add(
                PowerDesire(
                    id = id,
                    name = "Manifestação singular",
                    description = "Suas experiências revelaram uma possibilidade de poder ainda sem classificação.",
                    desiredType = PowerType.UNKNOWN,
                    progress = calculateProgress(evidence).coerceIn(0, 100)
                )
            )
        }
        return results
    }


    fun recordPowerUse(
        profile: CharacterPowerProfile,
        powerId: String,
        characterLevel: Int,
        successful: Boolean = true
    ): CharacterPowerProfile {
        val gain = if (successful) 25 else 8
        return profile.copy(
            powers = profile.powers.map { power ->
                if (power.id != powerId) return@map power
                var level = power.level.coerceAtLeast(1)
                var experience = power.experience + gain
                var damage = power.baseDamage
                var mana = power.manaCost
                var cooldown = power.cooldown
                while (experience >= level * 100) {
                    experience -= level * 100
                    level += 1
                    if (damage > 0) damage += (damage * 0.05).toInt().coerceAtLeast(1)
                    if (mana > 1 && level % 3 == 0) mana -= 1
                    if (cooldown > 0 && level % 4 == 0) cooldown -= 1
                }
                val currentStage = power.evolutionStage.coerceIn(0, power.evolutionStages.size)
                val unlockedStage = power.evolutionStages
                    .mapIndexedNotNull { index, stage ->
                        if (characterLevel >= stage.requiredLevel) index + 1 else null
                    }.lastOrNull() ?: currentStage
                val newStage = unlockedStage.coerceIn(currentStage, power.evolutionStages.size)
                val stageData = power.evolutionStages.getOrNull(newStage - 1)
                power.copy(
                    name = stageData?.name ?: power.name,
                    description = stageData?.description ?: power.description,
                    manifestation = stageData?.description ?: power.manifestation,
                    level = level,
                    experience = experience,
                    baseDamage = damage,
                    manaCost = mana,
                    cooldown = cooldown,
                    evolutionStage = newStage,
                    status = when {
                        newStage >= power.evolutionStages.size && newStage > 0 -> PowerStatus.MASTERED
                        newStage > 0 || level > 1 -> PowerStatus.EVOLVING
                        else -> PowerStatus.AWAKENED
                    }
                )
            }
        )
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
                .coerceAtLeast(0) * 4)

        return (total + diversityBonus)
            .toInt()
            .coerceIn(0, 100)
    }

    private fun calculateExperienceValue(
        observation: PowerObservation
    ): Double {

        val intensity =
            observation.intensity.coerceIn(1, 100) / 1.5

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
