package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.world.CriaturaGerada
import br.com.ascensaodosoberano.companions.EquipmentType
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class EquipamentoProceduralGeneratorTest {

    @Test
    fun mesmoSeedProduzMesmoEquipamentoBase() {
        val criatura = CriaturaGerada(
            id = "dragao_negro_teste",
            nome = "Dragão Negro",
            descricao = "Uma criatura dracônica que exala fogo e cobre o corpo com escamas negras.",
            rank = "S",
            nivel = 40,
            ataque = 180,
            defesa = 120,
            perigo = 85,
            bioma = "Vulcão",
            habitat = "Caverna de magma"
        )

        val primeiro = EquipamentoProceduralGenerator.gerar(criatura, 123456L)
        val segundo = EquipamentoProceduralGenerator.gerar(criatura, 123456L)

        assertEquals(primeiro.id, segundo.id)
        assertEquals(primeiro.name, segundo.name)
        assertEquals(primeiro.type, segundo.type)
        assertEquals(primeiro.rarity, segundo.rarity)
        assertEquals(primeiro.attributes, segundo.attributes)
        assertEquals(primeiro.specialEffect, segundo.specialEffect)
    }

    @Test
    fun equipamentoDraconicoPreservaMaterialEOrigemDaCriatura() {
        val criatura = CriaturaGerada(
            id = "dragao_ancestral",
            nome = "Dragão Ancestral",
            descricao = "Dragão de escamas resistentes e sopro de fogo.",
            rank = "SSS",
            nivel = 90,
            perigo = 100,
            bioma = "Montanhas vulcânicas"
        )

        val item = EquipamentoProceduralGenerator.gerar(criatura, 77L)

        assertTrue(item.name.contains("Escamas dracônicas"))
        assertTrue(item.description.contains("Dragão Ancestral"))
        assertEquals(criatura.id, item.sourceMonsterId)
        assertTrue(item.craftingMaterials.any { it.contains("Escamas dracônicas") })
        assertTrue(item.materialTraits.contains("DRACONICO"))
        assertEquals("SSS", item.rank)
    }

    @Test
    fun equipamentoDeCriaturaDeRankMaiorRecebeNivelDePoderMaior() {
        fun gerar(rank: String, nivel: Int) = EquipamentoProceduralGenerator.gerar(
            CriaturaGerada(
                id = "mesma_origem_$rank",
                nome = "Golem de Pedra",
                rank = rank,
                nivel = nivel,
                perigo = 50,
                bioma = "Montanhas"
            ),
            999L
        )

        val comum = gerar("E", 10)
        val elevado = gerar("SSS", 10)

        assertTrue(elevado.attributes.defense + elevado.attributes.physicalDamage >=
            comum.attributes.defense + comum.attributes.physicalDamage)
        assertNotEquals(comum.id, elevado.id)
    }

    @Test
    fun criaturaAquaticaPodeGerarAcessorioOuEquipamentoDeDefesa() {
        val criatura = CriaturaGerada(
            id = "serpente_marinha",
            nome = "Serpente Marinha",
            descricao = "Serpente aquática que domina as correntes oceânicas.",
            bioma = "Oceano",
            habitat = "Abismo marinho"
        )
        val item = EquipamentoProceduralGenerator.gerar(criatura, 2L)

        assertTrue(item.type in setOf(EquipmentType.NECKLACE, EquipmentType.SHIELD, EquipmentType.WEAPON))
        assertTrue(item.name.contains("Pérolas e escamas marinhas"))
    }
}
