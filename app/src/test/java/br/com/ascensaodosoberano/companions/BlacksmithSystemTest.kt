package br.com.ascensaodosoberano.companions

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertTrue
import org.junit.Test

class BlacksmithSystemTest {

    private fun material(
        id: String,
        name: String,
        quantity: Int,
        rank: String = "COMUM",
        traits: List<String> = listOf("PREDADOR")
    ) = InventoryItem(
        id = id,
        name = name,
        description = "Material de teste",
        type = "MATERIAL",
        quantity = quantity,
        materialRank = rank,
        materialOrigin = "Floresta Arcana",
        materialTraits = traits,
        sourceCreatureId = "criatura_teste"
    )

    @Test
    fun mesmaCombinacaoDeMateriaisNaoGeraReceitasDuplicadas() {
        val inventory = PlayerInventory(
            items = listOf(
                material("presa", "Presa", 2),
                material("couro", "Couro", 2, traits = listOf("NATUREZA"))
            ),
            gold = 100_000L
        )

        val options = BlacksmithSystem.suggestions(inventory, "aurelia", "espada")

        assertEquals(1, options.size)
        assertEquals(EquipmentType.WEAPON, options.single().equipment.type)
    }

    @Test
    fun fabricarConsomeMateriaisEOuroEAdicionaEquipamento() {
        val inventory = PlayerInventory(
            items = listOf(
                material("presa", "Presa", 3),
                material("couro", "Couro", 1, traits = listOf("NATUREZA"))
            ),
            gold = 100_000L
        )
        val option = BlacksmithSystem.suggestions(inventory, "aurelia", "espada").single()

        val result = BlacksmithSystem.craft(inventory, option)

        assertNotNull(result)
        assertEquals(inventory.gold - option.goldCost, result!!.gold)
        assertEquals(1, result.items.first { it.id == "presa" }.quantity)
        assertTrue(result.items.none { it.id == "couro" })
        assertEquals(1, result.equipment.size)
        assertEquals(option.equipment.id, result.equipment.single().id)
    }

    @Test
    fun fabricarFalhaSemOuroSuficienteSemAlterarInventarioOriginal() {
        val inventory = PlayerInventory(
            items = listOf(
                material("presa", "Presa", 2),
                material("couro", "Couro", 1, traits = listOf("NATUREZA"))
            ),
            gold = 0L
        )
        val option = BlacksmithSystem.suggestions(inventory.copy(gold = 100_000L), "aurelia", "espada").single()

        val result = BlacksmithSystem.craft(inventory, option)

        assertNull(result)
        assertEquals(0L, inventory.gold)
        assertEquals(2, inventory.items.first { it.id == "presa" }.quantity)
        assertTrue(inventory.equipment.isEmpty())
    }

    @Test
    fun fabricarFalhaQuandoFaltaMaterial() {
        val inventory = PlayerInventory(
            items = listOf(material("presa", "Presa", 1)),
            gold = 100_000L
        )
        val option = BlacksmithSystem.suggestions(
            inventory.copy(items = listOf(material("presa", "Presa", 2))),
            "aurelia",
            "espada"
        ).single()

        assertNull(BlacksmithSystem.craft(inventory, option))
    }

    @Test
    fun materiaisDeRankWorldNaoPodemSerForjados() {
        val inventory = PlayerInventory(
            items = listOf(material("fragmento", "Fragmento Mundial", 5, rank = "WORLD")),
            gold = 1_000_000L
        )

        assertTrue(BlacksmithSystem.suggestions(inventory, "aurelia", "espada").isEmpty())
    }

    @Test
    fun naoPermiteFabricacaoForaDePovoadoComFerreiro() {
        val inventory = PlayerInventory(
            items = listOf(material("presa", "Presa", 3)),
            gold = 100_000L
        )

        assertFalse(BlacksmithSystem.city("clareira_inicial").availableHere)
        assertTrue(BlacksmithSystem.suggestions(inventory, "clareira_inicial", "espada").isEmpty())
    }
}
