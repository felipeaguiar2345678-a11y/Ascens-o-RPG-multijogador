package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.world.AtaqueCriatura
import org.junit.Assert.assertEquals
import org.junit.Test

class SkillDamageCalculatorTest {
    private val hero = Combatant(
        name = "Aventureiro",
        maxHp = 100,
        hp = 100,
        attack = 20,
        defense = 10,
        magicPower = 40
    )

    @Test
    fun habilidadeFisicaUsaAtaqueFisico() {
        val skill = AtaqueCriatura(
            nome = "Corte",
            tipoDano = "FISICO",
            danoBase = 10,
            multiplicador = 0.5f
        )

        assertEquals(20, SkillDamageCalculator.estimatedDamage(hero, skill))
    }

    @Test
    fun habilidadeMagicaUsaPoderMagico() {
        val skill = AtaqueCriatura(
            nome = "Impacto Arcano",
            tipoDano = "MAGICO",
            danoBase = 10,
            multiplicador = 0.5f
        )

        assertEquals(30, SkillDamageCalculator.estimatedDamage(hero, skill))
    }

    @Test
    fun habilidadeSemDanoCalculadoMantemDanoMinimoUm() {
        val skill = AtaqueCriatura(
            nome = "Toque",
            tipoDano = "FISICO",
            danoBase = 0,
            multiplicador = 0f
        )

        assertEquals(1, SkillDamageCalculator.estimatedDamage(hero, skill))
    }
}
