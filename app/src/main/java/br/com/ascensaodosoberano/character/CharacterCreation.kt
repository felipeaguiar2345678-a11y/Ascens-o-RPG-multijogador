
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

object CharacterCreation {

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
            description = proposal.description,
            affinities = proposal.affinities
        )
    }
}
