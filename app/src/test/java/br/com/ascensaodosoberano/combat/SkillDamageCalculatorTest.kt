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
    fun habilidadeEscalaComNivelDoPersonagem() {
        val heroiNivel42 = hero.copy(level = 42)
        val habilidadeFraca = AtaqueCriatura(
            nome = "Golpe de energia",
            tipoDano = "MAGICO",
            danoBase = 8,
            multiplicador = 0f
        )
        assertEquals(90, SkillDamageCalculator.estimatedDamage(heroiNivel42, habilidadeFraca))
    }

    @Test
    fun habilidadeDevastadoraTemMultiplicadorSuperior() {
        val habilidade = AtaqueCriatura(
            nome = "Ruptura",
            tipoDano = "FISICO",
            danoBase = 10,
            multiplicador = 0f,
            categoria = "DEVASTADOR"
        )
        assertEquals(18, SkillDamageCalculator.estimatedDamage(hero, habilidade))
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
