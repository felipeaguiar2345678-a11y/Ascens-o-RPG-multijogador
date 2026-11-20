
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

    private fun attributeForDomain(domain: SkillDomain): PrimaryAttribute =
        when (domain) {
            SkillDomain.PHYSICAL -> PrimaryAttribute.STRENGTH
            SkillDomain.MAGIC -> PrimaryAttribute.INTELLIGENCE
            SkillDomain.AGILITY -> PrimaryAttribute.AGILITY
            SkillDomain.DEFENSE -> PrimaryAttribute.VITALITY
            SkillDomain.SUMMONING -> PrimaryAttribute.SPIRIT
        }

    private fun attributesMentioned(text: String): List<PrimaryAttribute> {
        val matches = mutableListOf<PrimaryAttribute>()
        fun addIfFound(attribute: PrimaryAttribute, words: List<String>) {
            if (words.any { it in text } && attribute !in matches) {
                matches += attribute
            }
        }

        addIfFound(PrimaryAttribute.INTELLIGENCE,
            listOf("mago", "magia", "arcano", "feiticeir", "realidade", "energia", "mental"))
        addIfFound(PrimaryAttribute.STRENGTH,
            listOf("guerreiro", "força", "forca", "berserker", "lutador", "brutal"))
        addIfFound(PrimaryAttribute.AGILITY,
            listOf("assassino", "arqueiro", "velocidade", "agilidade", "destreza"))
        addIfFound(PrimaryAttribute.VITALITY,
            listOf("guardião", "guardiao", "defesa", "protetor", "resistência", "resistencia"))
        addIfFound(PrimaryAttribute.SPIRIT,
            listOf("invocador", "invocação", "invocacao", "invocar", "espírito", "espirito", "alma"))

        return matches
    }

    /**
     * A identidade define um atributo principal (10) e, quando a classe
     * realmente combina duas especialidades, um secundário (8).
     * Os demais começam em 5 e continuam livres para evolução.
     */
    fun initialAttributes(
        characterClass: CharacterClass,
        concept: String = ""
    ): CharacterAttributes {
        val identityText = (characterClass.name + " " + characterClass.description + " " + concept)
            .lowercase()
        val mentioned = attributesMentioned(identityText)
        val primary = mentioned.firstOrNull() ?: primaryAttribute(characterClass)

        val affinityAttributes = SkillDomain.values()
            .filter { characterClass.affinities[it] == Affinity.HIGH }
            .map(::attributeForDomain)
            .distinct()

        val secondary = mentioned.firstOrNull { it != primary }
            ?: affinityAttributes.firstOrNull { it != primary }

        val values = mutableMapOf(
            PrimaryAttribute.STRENGTH to 5,
            PrimaryAttribute.INTELLIGENCE to 5,
            PrimaryAttribute.AGILITY to 5,
            PrimaryAttribute.VITALITY to 5,
            PrimaryAttribute.SPIRIT to 5
        )
        values[primary] = 10
        if (secondary != null) values[secondary] = 8

        return CharacterAttributes(
            strength = values.getValue(PrimaryAttribute.STRENGTH),
            intelligence = values.getValue(PrimaryAttribute.INTELLIGENCE),
            agility = values.getValue(PrimaryAttribute.AGILITY),
            vitality = values.getValue(PrimaryAttribute.VITALITY),
            spirit = values.getValue(PrimaryAttribute.SPIRIT)
        )
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
