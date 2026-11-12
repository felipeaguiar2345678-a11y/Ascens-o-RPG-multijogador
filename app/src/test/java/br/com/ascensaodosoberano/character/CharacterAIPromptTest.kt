package br.com.ascensaodosoberano.character

import org.junit.Assert.assertTrue
import org.junit.Test

class CharacterAIPromptTest {

    @Test
    fun promptIncludesCustomClassConceptAndIdentity() {
        val customClass = CharacterClass(
            id = "custom_mago_do_tempo",
            name = "Mago do Tempo",
            description = "Manipula passado, futuro, ampulhetas e anéis temporais.",
            affinities = mapOf(
                SkillDomain.MAGIC to Affinity.HIGH,
                SkillDomain.PHYSICAL to Affinity.LOW
            ),
            isCustom = true
        )

        val prompt = CharacterAIPrompt.generate(
            characterName = "Arius",
            appearance = CharacterAppearance(),
            characterClass = customClass
        )

        assertTrue(prompt.contains("Mago do Tempo"))
        assertTrue(prompt.contains("ampulhetas e anéis temporais"))
        assertTrue(prompt.contains("Highly detailed"))
        assertTrue(prompt.contains("FOUR-VIEW CHARACTER TURNAROUND"))
        assertTrue(prompt.contains("exact front view"))
        assertTrue(prompt.contains("exact left-side profile"))
        assertTrue(prompt.contains("exact rear view"))
        assertTrue(prompt.contains("exact right-side profile"))
        assertTrue(prompt.contains("exact 2-by-2 grid"))
        assertTrue(prompt.contains("Custom classes"))
    }

    @Test
    fun promptPreservesNecromancerConceptWithoutForcingUnrelatedEquipment() {
        val necromancer = CharacterClass(
            id = "custom_necromante",
            name = "Necromante",
            description = "Conduz almas espectrais e invoca ecos dos mortos.",
            affinities = mapOf(SkillDomain.MAGIC to Affinity.HIGH),
            isCustom = true
        )

        val prompt = CharacterAIPrompt.generate(
            characterName = "Nox",
            appearance = CharacterAppearance(),
            characterClass = necromancer
        )

        assertTrue(prompt.contains("Necromante"))
        assertTrue(prompt.contains("almas espectrais"))
        assertTrue(prompt.contains("Never force a sword, staff"))
    }
}
