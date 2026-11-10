package br.com.ascensaodosoberano.world

import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class CreatureApiValidationTest {
    @Test
    fun aceitaRankRaridadeEBiomaOriginaisCriadosPelaIa() {
        val creature = CriaturaGerada(
            id = "colosso_mare_viva",
            nome = "Colosso das Marés Vivas",
            rank = "TRANSCENDENTE",
            nivel = 900,
            vidaMaxima = 900000,
            ecosystemId = "eternal_sea",
            bioma = "Oceano de Cristal das Fendas Abissais",
            raridade = "SINGULARIDADE",
            chefe = true,
            ataques = listOf(AtaqueCriatura(id = "onda_causal", nome = "Onda Causal"))
        )

        validateCreatureForEncounter(creature, "eternal_sea", expectedBoss = true)
        assertTrue(creature.rank == "TRANSCENDENTE")
        assertTrue(creature.raridade == "SINGULARIDADE")
    }

    @Test
    fun rejeitaCriaturaDeOutroEcossistema() {
        val creature = CriaturaGerada(
            ecosystemId = "shadowlands",
            bioma = "Terras sombrias",
            ataques = listOf(AtaqueCriatura(nome = "Golpe"))
        )
        assertThrows(IllegalArgumentException::class.java) {
            validateCreatureForEncounter(creature, "eternal_sea", expectedBoss = false)
        }
    }

    @Test
    fun rejeitaTipoDeEncontroIncorreto() {
        val creature = CriaturaGerada(
            ecosystemId = "eternal_sea",
            bioma = "Mar Eterno",
            chefe = false,
            ataques = listOf(AtaqueCriatura(nome = "Golpe"))
        )
        assertThrows(IllegalArgumentException::class.java) {
            validateCreatureForEncounter(creature, "eternal_sea", expectedBoss = true)
        }
    }

    @Test
    fun rejeitaCriaturaSemAtaqueUtilizavel() {
        val creature = CriaturaGerada(
            ecosystemId = "eternal_sea",
            bioma = "Mar Eterno",
            ataques = emptyList()
        )
        assertThrows(IllegalArgumentException::class.java) {
            validateCreatureForEncounter(creature, "eternal_sea", expectedBoss = false)
        }
    }
}
