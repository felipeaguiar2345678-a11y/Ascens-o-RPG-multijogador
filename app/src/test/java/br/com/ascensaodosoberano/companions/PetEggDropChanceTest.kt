package br.com.ascensaodosoberano.companions

import org.junit.Assert.assertEquals
import org.junit.Assert.assertNotEquals
import org.junit.Assert.assertNotNull
import org.junit.Test

class PetEggDropChanceTest {

    @Test
    fun chancesDeOvoAumentamComORankDaCriatura() {
        assertEquals(1, PetEggSystem.getDropChance("E"))
        assertEquals(2, PetEggSystem.getDropChance("D"))
        assertEquals(3, PetEggSystem.getDropChance("C"))
        assertEquals(4, PetEggSystem.getDropChance("B"))
        assertEquals(5, PetEggSystem.getDropChance("A"))
        assertEquals(7, PetEggSystem.getDropChance("S"))
        assertEquals(9, PetEggSystem.getDropChance("SS"))
        assertEquals(12, PetEggSystem.getDropChance("SSS"))
        assertEquals(15, PetEggSystem.getDropChance("WORLD"))
    }

    @Test
    fun consultaDeRankIgnoraMaiusculasEMinusculas() {
        assertEquals(1, PetEggSystem.getDropChance("e"))
        assertEquals(12, PetEggSystem.getDropChance("sss"))
    }

    @Test
    fun ovosDaMesmaCriaturaRecebemIdsDiferentes() {
        val primeiro = PetEggSystem.rollEggDrop(
            monsterId = "lobo_arcano",
            species = "Lobo Arcano",
            rank = "E",
            imageKey = "lobo",
            chanceMultiplier = 100f
        )
        val segundo = PetEggSystem.rollEggDrop(
            monsterId = "lobo_arcano",
            species = "Lobo Arcano",
            rank = "E",
            imageKey = "lobo",
            chanceMultiplier = 100f
        )

        assertNotNull(primeiro)
        assertNotNull(segundo)
        assertNotEquals(primeiro!!.id, segundo!!.id)
    }

    @Test
    fun rankDesconhecidoUsaChanceMinima() {
        assertEquals(1, PetEggSystem.getDropChance("DESCONHECIDO"))
    }
}
