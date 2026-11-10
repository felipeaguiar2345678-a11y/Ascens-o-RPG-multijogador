package br.com.ascensaodosoberano.exploration

import br.com.ascensaodosoberano.world.CriaturaGerada
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Test

class NarrativeCreatureMatcherTest {
    @Test
    fun escolheCriaturaQueCombinaComPistaNarrativa() {
        val rato = CriaturaGerada(
            id = "rato_gigante",
            nome = "Rato Gigante",
            descricao = "Um roedor enorme que ataca viajantes.",
            bioma = "esgotos",
            habitat = "tuneis subterraneos"
        )
        val lobo = CriaturaGerada(
            id = "lobo",
            nome = "Lobo Cinzento",
            descricao = "Predador das florestas.",
            bioma = "floresta",
            habitat = "bosques"
        )

        assertEquals(
            rato,
            NarrativeCreatureMatcher.selectBest(
                listOf(lobo, rato),
                "rastros de um rato gigante nos túneis"
            )
        )
    }

    @Test
    fun pistaVaziaNaoForcaUmaCriatura() {
        assertNull(
            NarrativeCreatureMatcher.selectBest(
                listOf(CriaturaGerada(id = "lobo", nome = "Lobo")),
                ""
            )
        )
    }

    @Test
    fun pistaSemCorrespondenciaNaoEscolheCriaturaAleatoria() {
        assertNull(
            NarrativeCreatureMatcher.selectBest(
                listOf(CriaturaGerada(id = "lobo", nome = "Lobo Cinzento")),
                "uma serpente de cristal"
            )
        )
    }

    @Test
    fun ignoraAcentosEMaiusculas() {
        val criatura = CriaturaGerada(
            id = "serpente",
            nome = "Serpente Ígnea",
            descricao = "Habita cavernas vulcânicas."
        )
        assertEquals(
            criatura,
            NarrativeCreatureMatcher.selectBest(
                listOf(criatura),
                "SERPENTE IGNEA"
            )
        )
    }
}
