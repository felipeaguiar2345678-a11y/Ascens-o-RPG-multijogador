package br.com.ascensaodosoberano.companions

import org.junit.Assert.*
import org.junit.Test

class InventorySystemTest {
    private fun item(
        id: String = "fibra",
        quantity: Int = 2,
        name: String = "Fibra",
        rank: String = "E"
    ) = InventoryItem(
        id = id,
        name = name,
        description = "Fibra vegetal resistente",
        type = "MATERIAL",
        quantity = quantity,
        materialRank = rank,
        materialOrigin = "Floresta Arcana",
        materialTraits = listOf("NATUREZA")
    )

    @Test fun adicionaNovoItem() {
        val result = InventorySystem.addItem(PlayerInventory(), item())
        assertEquals(1, result.items.size)
        assertEquals(2, result.items.single().quantity)
    }

    @Test fun acumulaSomenteItensComIdentidadeIgual() {
        val original = item(quantity = 3)
        val result = InventorySystem.addItem(PlayerInventory(items = listOf(original)), item(quantity = 2))
        assertEquals(5, result.items.single().quantity)
    }

    @Test fun rejeitaMesmoIdComNomeDiferente() {
        val original = item()
        val result = InventorySystem.addItem(PlayerInventory(items = listOf(original)), item(name = "Material falso"))
        assertEquals(original, result.items.single())
    }

    @Test fun rejeitaMesmoIdComRankDiferente() {
        val original = item()
        val result = InventorySystem.addItem(PlayerInventory(items = listOf(original)), item(rank = "SSS"))
        assertEquals(original, result.items.single())
    }

    @Test fun rejeitaQuantidadeZeroOuNegativa() {
        val inventory = PlayerInventory()
        assertEquals(inventory, InventorySystem.addItem(inventory, item(quantity = 0)))
        assertEquals(inventory, InventorySystem.addItem(inventory, item(quantity = -1)))
    }

    @Test fun rejeitaEstouroDeQuantidade() {
        val original = item(quantity = Int.MAX_VALUE)
        val result = InventorySystem.addItem(PlayerInventory(items = listOf(original)), item(quantity = 1))
        assertEquals(original, result.items.single())
    }

    @Test fun rejeitaInventarioComIdsDuplicados() {
        val first = item(quantity = 2)
        val second = item(quantity = 4, name = "Outra fibra")
        val inventory = PlayerInventory(items = listOf(first, second))
        assertEquals(inventory, InventorySystem.addItem(inventory, item(quantity = 1)))
    }

    @Test fun rejeitaIdVazio() {
        val inventory = PlayerInventory()
        assertEquals(inventory, InventorySystem.addItem(inventory, item(id = " ")))
    }
}
