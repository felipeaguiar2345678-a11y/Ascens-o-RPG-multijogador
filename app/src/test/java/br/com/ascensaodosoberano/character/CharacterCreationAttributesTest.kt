package br.com.ascensaodosoberano.character

import org.junit.Assert.assertEquals
import org.junit.Test

class CharacterCreationAttributesTest {

    @Test
    fun magoInvocadorComecaComInteligenciaPrincipalEEspiritoSecundario() {
        val proposal = CharacterCreation.createCustomProposal("Mago Invocador")!!
        val characterClass = CharacterCreation.approveProposal(proposal, "Mago Invocador")

        val attributes = CharacterCreation.initialAttributes(
            characterClass = characterClass,
            concept = proposal.concept
        )

        assertEquals(10, attributes.intelligence)
        assertEquals(8, attributes.spirit)
        assertEquals(5, attributes.strength)
        assertEquals(5, attributes.agility)
        assertEquals(5, attributes.vitality)
    }

    @Test
    fun classeMagoPuroMantemApenasInteligenciaComoAtributoPrincipal() {
        val mage = CharacterSystem.getClassById("mage")!!

        val attributes = CharacterCreation.initialAttributes(mage)

        assertEquals(10, attributes.intelligence)
        assertEquals(5, attributes.spirit)
        assertEquals(5, attributes.strength)
        assertEquals(5, attributes.agility)
        assertEquals(5, attributes.vitality)
    }

    @Test
    fun classeInvocadorUsaEspíritoComoPrincipalEMagiaComoSecundario() {
        val summoner = CharacterSystem.getClassById("summoner")!!

        val attributes = CharacterCreation.initialAttributes(summoner)

        assertEquals(10, attributes.spirit)
        assertEquals(8, attributes.intelligence)
        assertEquals(5, attributes.strength)
        assertEquals(5, attributes.agility)
        assertEquals(5, attributes.vitality)
    }
}
