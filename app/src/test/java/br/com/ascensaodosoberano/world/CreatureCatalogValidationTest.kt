package br.com.ascensaodosoberano.world

import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class CreatureCatalogValidationTest {
    @Test
    fun aceitaRankERaridadeOriginaisSemListaFechada() {
        val creature = CriaturaGerada(
            id = "entidade_do_vazio",
            nome = "Entidade do Vazio",
            rank = "TRANSCENDENTE-ALFA",
            nivel = 900,
            vidaMaxima = 900_000,
            ataque = 70_000,
            defesa = 30_000,
            manaMaxima = 1_800_000,
            agilidade = 40_000,
            poderMagico = 120_000,
            experienciaBase = 500_000,
            perigo = 100,
            ecosystemId = "abyss_valley",
            bioma = "Fenda entre dimensões",
            raridade = "SINGULARIDADE ETERNA",
            ataques = listOf(AtaqueCriatura(id = "rasgo", nome = "Rasgo da Realidade"))
        )

        validarCriaturaParaCatalogoGlobal(creature)

        assertTrue(creature.rank.startsWith("TRANSCENDENTE"))
        assertTrue(creature.raridade.contains("SINGULARIDADE"))
    }

    @Test
    fun rejeitaCriaturaSemAtaquesMesmoQueTenhaNomeERank() {
        val creature = CriaturaGerada(
            id = "criatura_sem_ataque",
            nome = "Criatura sem ataque",
            rank = "INFINITO",
            raridade = "ÚNICA",
            ataques = emptyList()
        )

        assertThrows(IllegalArgumentException::class.java) {
            validarCriaturaParaCatalogoGlobal(creature)
        }
    }

    @Test
    fun rejeitaDadosTecnicosQueImpedemOCombate() {
        val creature = CriaturaGerada(
            id = "criatura_sem_vida",
            nome = "Criatura sem vida",
            vidaMaxima = 0,
            rank = "E",
            raridade = "COMUM",
            ataques = listOf(AtaqueCriatura(nome = "Golpe"))
        )

        assertThrows(IllegalArgumentException::class.java) {
            validarCriaturaParaCatalogoGlobal(creature)
        }
    }
}
