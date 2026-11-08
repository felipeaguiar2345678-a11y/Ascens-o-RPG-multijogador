package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.character.CharacterProfile
import br.com.ascensaodosoberano.character.CharacterSystem
import org.junit.Assert.assertEquals
import org.junit.Test

class CharacterCombatFactoryPersistenceTest {

    @Test
    fun restoresSavedHealthAndMana() {
        val profile = CharacterProfile(
            name = "Aventureiro",
            level = 1,
            xp = 0,
            characterClass = CharacterSystem.predefinedClasses.first(),
            currentHp = 37,
            currentMana = 12
        )

        val hero = CharacterCombatFactory.createHero(profile)

        assertEquals(37, hero.hp)
        assertEquals(12, hero.mana)
    }

    @Test
    fun clampsSavedHealthAndManaToNewMaximums() {
        val profile = CharacterProfile(
            name = "Aventureiro",
            level = 1,
            xp = 0,
            characterClass = CharacterSystem.predefinedClasses.first(),
            currentHp = 999999,
            currentMana = 999999
        )

        val hero = CharacterCombatFactory.createHero(profile)

        assertEquals(hero.maxHp, hero.hp)
        assertEquals(hero.maxMana, hero.mana)
    }
}
