
package br.com.ascensaodosoberano.character

enum class CreationMode {
    PREDEFINED,
    CUSTOM
}

data class ClassProposal(
    val name: String,
    val description: String,
    val concept: String,
    val affinities: Map<SkillDomain, Affinity>,
    val requiresReview: Boolean = true
)

enum class PrimaryAttribute {
    STRENGTH, INTELLIGENCE, AGILITY, VITALITY, SPIRIT
}

object CharacterCreation {

    /**
     * A identidade da classe define a distribuição inicial, sem bloquear
     * o desenvolvimento futuro em outros atributos.
     */
    fun primaryAttribute(characterClass: CharacterClass): PrimaryAttribute {
        val affinities = characterClass.affinities
        val strongest = SkillDomain.values().filter {
            affinities[it] == Affinity.HIGH
        }
        val domain = when {
            characterClass.id == "summoner" -> SkillDomain.SUMMONING
            characterClass.id == "mage" -> SkillDomain.MAGIC
            characterClass.id == "warrior" -> SkillDomain.PHYSICAL
            characterClass.id == "assassin" || characterClass.id == "archer" -> SkillDomain.AGILITY
            characterClass.id == "guardian" -> SkillDomain.DEFENSE
            SkillDomain.SUMMONING in strongest &&
                ("invoc" in characterClass.description.lowercase() ||
                 "invoc" in characterClass.name.lowercase()) -> SkillDomain.SUMMONING
            else -> strongest.maxByOrNull { domain ->
                when (domain) {
                    SkillDomain.PHYSICAL -> 5
                    SkillDomain.MAGIC -> 4
                    SkillDomain.AGILITY -> 3
                    SkillDomain.DEFENSE -> 2
                    SkillDomain.SUMMONING -> 1
                }
            } ?: SkillDomain.MAGIC
        }
        return when (domain) {
            SkillDomain.PHYSICAL -> PrimaryAttribute.STRENGTH
            SkillDomain.MAGIC -> PrimaryAttribute.INTELLIGENCE
            SkillDomain.AGILITY -> PrimaryAttribute.AGILITY
            SkillDomain.DEFENSE -> PrimaryAttribute.VITALITY
            SkillDomain.SUMMONING -> PrimaryAttribute.SPIRIT
        }
    }

    fun initialAttributes(
        characterClass: CharacterClass,
        concept: String = ""
    ): CharacterAttributes {
        val identityText = (characterClass.name + " " + characterClass.description + " " + concept)
            .lowercase()
        val primary = when {
            listOf("mago", "magia", "arcano", "feiticeir", "realidade", "energia").any { it in identityText } ->
                PrimaryAttribute.INTELLIGENCE
            listOf("guerreiro", "força", "forca", "berserker").any { it in identityText } ->
                PrimaryAttribute.STRENGTH
            listOf("assassino", "arqueiro", "velocidade", "agilidade").any { it in identityText } ->
                PrimaryAttribute.AGILITY
            listOf("guardião", "guardiao", "defesa", "protetor").any { it in identityText } ->
                PrimaryAttribute.VITALITY
            listOf("invocador", "invocação", "invocacao", "espírito", "espirito").any { it in identityText } ->
                PrimaryAttribute.SPIRIT
            else -> primaryAttribute(characterClass)
        }
        return when (primary) {
            PrimaryAttribute.STRENGTH -> CharacterAttributes(strength = 10)
            PrimaryAttribute.INTELLIGENCE -> CharacterAttributes(intelligence = 10)
            PrimaryAttribute.AGILITY -> CharacterAttributes(agility = 10)
            PrimaryAttribute.VITALITY -> CharacterAttributes(vitality = 10)
            PrimaryAttribute.SPIRIT -> CharacterAttributes(spirit = 10)
        }
    }

    fun choosePredefinedClass(id: String): ClassProposal? {
        val selected = CharacterSystem.getClassById(id)
            ?: return null

        return ClassProposal(
            name = selected.name,
            description = selected.description,
            concept = selected.description,
            affinities = selected.affinities,
            requiresReview = false
        )
    }

    fun createCustomProposal(
        concept: String
    ): ClassProposal? {

        if (concept.isBlank()) return null

        val text = concept.lowercase()

        val affinities = mutableMapOf(
            SkillDomain.PHYSICAL to Affinity.MEDIUM,
            SkillDomain.MAGIC to Affinity.MEDIUM,
            SkillDomain.AGILITY to Affinity.MEDIUM,
            SkillDomain.DEFENSE to Affinity.MEDIUM,
            SkillDomain.SUMMONING to Affinity.MEDIUM
        )

        if ("força" in text || "guerreiro" in text) {
            affinities[SkillDomain.PHYSICAL] = Affinity.HIGH
        }

        if ("magia" in text || "mago" in text || "energia" in text) {
            affinities[SkillDomain.MAGIC] = Affinity.HIGH
        }

        if ("velocidade" in text || "assassino" in text) {
            affinities[SkillDomain.AGILITY] = Affinity.HIGH
        }

        if ("defesa" in text || "proteção" in text) {
            affinities[SkillDomain.DEFENSE] = Affinity.HIGH
        }

        if ("invocação" in text || "invocar" in text) {
            affinities[SkillDomain.SUMMONING] = Affinity.HIGH
        }

        return ClassProposal(
            name = "Classe Personalizada",
            description = "Classe criada a partir da ideia do jogador.",
            concept = concept,
            affinities = affinities,
            requiresReview = true
        )
    }

    fun approveProposal(
        proposal: ClassProposal,
        finalName: String
    ): CharacterClass {

        return CharacterSystem.createCustomClass(
            name = finalName,
            description = proposal.concept.trim().ifBlank { proposal.description },
            affinities = proposal.affinities
        )
    }
}
