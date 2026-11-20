package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.world.AtaqueCriatura
import br.com.ascensaodosoberano.powers.PowerDamagePolicy
import br.com.ascensaodosoberano.powers.PowerType
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
    fun poderOfensivoGeradoSemDanoRecebeBaseAdequadaAoTipo() {
        assertEquals(10, PowerDamagePolicy.normalizeBaseDamage(PowerType.PHYSICAL, 0))
        assertEquals(9, PowerDamagePolicy.normalizeBaseDamage(PowerType.MAGIC, 0))
        assertEquals(8, PowerDamagePolicy.normalizeBaseDamage(PowerType.AGILITY, 0))
    }

    @Test
    fun poderDefensivoOuDesconhecidoNaoViraAtaqueDeUmDano() {
        assertEquals(false, PowerDamagePolicy.causesDamage(PowerType.DEFENSE))
        assertEquals(false, PowerDamagePolicy.causesDamage(PowerType.UNKNOWN))
        assertEquals(0, PowerDamagePolicy.normalizeBaseDamage(PowerType.DEFENSE, 50))
    }

    @Test
    fun poderOfensivoMantemDanoGeradoQuandoAcimaDoMinimo() {
        assertEquals(24, PowerDamagePolicy.normalizeBaseDamage(PowerType.PHYSICAL, 24))
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
