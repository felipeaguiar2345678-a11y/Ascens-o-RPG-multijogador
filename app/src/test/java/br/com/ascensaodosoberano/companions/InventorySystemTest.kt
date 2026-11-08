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

    private fun egg(id: String = "ovo_1") = PetEgg(
        id = id,
        species = "Lobo",
        monsterId = "lobo_arcano",
        rank = "E",
        imageKey = "lobo",
        hatchChance = 100
    )

    private fun equipment(id: String = "espada_1") = Equipment(
        id = id,
        name = "Espada de teste",
        description = "Equipamento de teste",
        type = EquipmentType.WEAPON,
        rarity = EquipmentRarity.COMMON,
        rank = "E"
    )

    private fun companion(id: String = "lobo_1", active: Boolean = false) = Companion(
        id = id,
        name = "Lobo",
        species = "Lobo Arcano",
        rank = "E",
        maxHp = 100,
        hp = 100,
        attack = 10,
        defense = 5,
        agility = 8,
        magicPower = 0,
        imageKey = "lobo",
        isActive = active
    )

    @Test fun naoDuplicaOvoComMesmoId() {
        val original = egg()
        val inventory = PlayerInventory(eggs = listOf(original))
        assertEquals(inventory, InventorySystem.addEgg(inventory, original))
    }

    @Test fun removerOvoRejeitaIdDuplicado() {
        val original = egg()
        val inventory = PlayerInventory(eggs = listOf(original, original.copy(quantity = 2)))
        assertEquals(inventory, InventorySystem.removeEgg(inventory, original.id))
    }

    @Test fun chocarOvoRejeitaIdDuplicado() {
        val original = egg()
        val inventory = PlayerInventory(eggs = listOf(original, original.copy(quantity = 2)))
        assertEquals(inventory, InventorySystem.hatchEgg(inventory, original.id, companion()))
    }

    @Test fun naoAdicionaOvoComIdVazio() {
        val inventory = PlayerInventory()
        assertEquals(inventory, InventorySystem.addEgg(inventory, egg(" ")))
    }

    @Test fun naoDuplicaEquipamentoComMesmoId() {
        val original = equipment()
        val inventory = PlayerInventory(equipment = listOf(original))
        assertEquals(inventory, InventorySystem.addEquipment(inventory, original.copy(name = "Falso")))
    }

    @Test fun naoAdicionaEquipamentoComIdVazio() {
        val inventory = PlayerInventory()
        assertEquals(inventory, InventorySystem.addEquipment(inventory, equipment("")))
    }

    @Test fun adicionarCompanheiroAtivoDesativaAnterior() {
        val anterior = companion("lobo_1", active = true)
        val novo = companion("urso_1", active = true)
        val inventory = PlayerInventory(companions = listOf(anterior))

        val result = InventorySystem.addCompanion(inventory, novo)

        assertFalse(result.companions.first { it.id == "lobo_1" }.isActive)
        assertTrue(result.companions.first { it.id == "urso_1" }.isActive)
        assertEquals(1, result.companions.count { it.isActive })
    }

    @Test fun ativarCompanheiroRejeitaIdDuplicado() {
        val original = companion()
        val inventory = PlayerInventory(companions = listOf(original, original.copy(name = "Duplicado")))
        assertEquals(inventory, InventorySystem.ativarCompanheiro(inventory, original.id))
    }

    @Test fun companheiroAtivoSoEhRetornadoQuandoExisteUmUnico() {
        val inventory = PlayerInventory(
            companions = listOf(
                companion("lobo_1", active = true),
                companion("urso_1", active = true)
            )
        )
        assertNull(InventorySystem.obterCompanheiroAtivo(inventory))
    }

    @Test fun naoDuplicaCompanheiroComMesmoId() {
        val original = companion()
        val inventory = PlayerInventory(companions = listOf(original))
        assertEquals(inventory, InventorySystem.addCompanion(inventory, original.copy(name = "Falso")))
    }

    @Test fun naoAdicionaCompanheiroComIdVazio() {
        val inventory = PlayerInventory()
        assertEquals(inventory, InventorySystem.addCompanion(inventory, companion("")))
    }

    @Test fun rejeitaIdVazio() {
        val inventory = PlayerInventory()
        assertEquals(inventory, InventorySystem.addItem(inventory, item(id = " ")))
    }
}
