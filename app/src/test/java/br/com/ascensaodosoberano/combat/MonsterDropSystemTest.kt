package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.world.CriaturaGerada
import br.com.ascensaodosoberano.world.DropCriatura
import br.com.ascensaodosoberano.companions.BlacksmithSystem
import br.com.ascensaodosoberano.companions.MerchantSystem
import br.com.ascensaodosoberano.companions.PlayerInventory
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Test

class MonsterDropSystemTest {

    @Test
    fun materialObtidoEmCombatePodeSerVendidoEUsadoNaForja() {
        val creature = CriaturaGerada(
            id = "lobo_arcano_teste",
            nome = "Lobo Arcano",
            descricao = "Predador da floresta",
            bioma = "Floresta Arcana",
            drops = listOf(
                DropCriatura(
                    itemId = "presa_lobo",
                    nome = "Presa Arcana",
                    descricao = "Uma presa resistente",
                    tipo = "MATERIAL",
                    raridade = "COMUM",
                    garantido = true,
                    quantidadeMinima = 2,
                    quantidadeMaxima = 2
                )
            )
        )

        val material = MonsterDropSystem.roll(creature).materials.single()

        assertEquals("MATERIAL", material.type)
        assertTrue(MerchantSystem.sellPrice(material) > 0L)
        val inventory = PlayerInventory(items = listOf(material), gold = 100_000L)
        assertTrue(BlacksmithSystem.suggestions(inventory, "aurelia", "espada").isNotEmpty())
    }
}
