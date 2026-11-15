package br.com.ascensaodosoberano.character

import br.com.ascensaodosoberano.companions.Equipment
import br.com.ascensaodosoberano.companions.EquipmentLoadout
import br.com.ascensaodosoberano.companions.EquipmentRarity
import br.com.ascensaodosoberano.companions.EquipmentType
import org.junit.Assert.*
import org.junit.Test

class EquipmentSystemTest {

    private fun classe(id: String, fisico: Affinity = Affinity.HIGH) = CharacterClass(
        id = id,
        name = id,
        description = "",
        affinities = SkillDomain.values().associateWith {
            if (it == SkillDomain.PHYSICAL) fisico else Affinity.MEDIUM
        }
    )

    private fun equipamento(
        id: String,
        type: EquipmentType,
        name: String = id,
        level: Int = 1
    ) = Equipment(
        id = id,
        name = name,
        description = "",
        type = type,
        rarity = EquipmentRarity.COMMON,
        rank = "E",
        levelRequired = level
    )

    @Test
    fun armaDeUmaMaoPermiteEspadaComEscudo() {
        val espada = equipamento("espada", EquipmentType.WEAPON, "Espada curta")
        val escudo = equipamento("escudo", EquipmentType.SHIELD)
        val primeira = EquipmentSystem.equipar(
            EquipmentLoadout(), espada, classe("warrior"), 1
        )
        val segunda = EquipmentSystem.equipar(
            primeira.loadout, escudo, classe("warrior"), 1,
            listOf(espada, escudo)
        )
        assertTrue(primeira.success)
        assertTrue(segunda.success)
        assertEquals("espada", segunda.loadout.weaponId)
        assertEquals("escudo", segunda.loadout.shieldId)
    }

    @Test
    fun armaDeDuasMaosLiberaEspacoDeEscudo() {
        val espada = equipamento("espada_gigante", EquipmentType.WEAPON, "Espadão de duas mãos")
        val escudo = equipamento("escudo", EquipmentType.SHIELD)
        val comEscudo = EquipmentLoadout(weaponId = "espada_curta", shieldId = "escudo")
        val resultado = EquipmentSystem.equipar(
            comEscudo, espada, classe("warrior"), 1, listOf(espada, escudo)
        )
        assertTrue(resultado.success)
        assertEquals("espada_gigante", resultado.loadout.weaponId)
        assertNull(resultado.loadout.shieldId)
    }

    @Test
    fun armaPesadaOcupaEspacoDeEscudo() {
        val arma = equipamento("martelo", EquipmentType.WEAPON, "Martelo pesado")
        val resultado = EquipmentSystem.equipar(
            EquipmentLoadout(weaponId = "espada", shieldId = "escudo"),
            arma, classe("warrior"), 1
        )
        assertTrue(resultado.success)
        assertNull(resultado.loadout.weaponId)
        assertEquals("martelo", resultado.loadout.shieldId)
    }

    @Test
    fun classeMagicaNaoPodeEquiparEscudo() {
        val resultado = EquipmentSystem.equipar(
            EquipmentLoadout(),
            equipamento("escudo", EquipmentType.SHIELD),
            classe("mage", Affinity.LOW),
            1
        )
        assertFalse(resultado.success)
        assertNull(resultado.loadout.shieldId)
    }

    @Test
    fun apenasUmAnelPodeFicarEquipado() {
        val primeiro = equipamento("anel1", EquipmentType.RING)
        val segundo = equipamento("anel2", EquipmentType.RING)
        val resultado = EquipmentSystem.equipar(
            EquipmentLoadout(ringId = primeiro.id),
            segundo, classe("mage"), 1
        )
        assertEquals("anel2", resultado.loadout.ringId)
    }

    @Test
    fun equipamentoInformadoPrecisaPertencerAoInventario() {
        val item = equipamento("espada", EquipmentType.WEAPON)
        val resultado = EquipmentSystem.equipar(
            EquipmentLoadout(),
            item,
            classe("warrior"),
            1,
            inventoryEquipment = emptyList()
        )

        assertFalse(resultado.success)
        assertNull(resultado.loadout.weaponId)
    }

    @Test
    fun inventarioComIdDuplicadoNaoPermiteEquiparItemAmbiguo() {
        val item = equipamento("espada", EquipmentType.WEAPON)
        val resultado = EquipmentSystem.equipar(
            EquipmentLoadout(),
            item,
            classe("warrior"),
            1,
            inventoryEquipment = listOf(item, item.copy(name = "Cópia adulterada"))
        )

        assertFalse(resultado.success)
        assertNull(resultado.loadout.weaponId)
    }

    @Test
    fun equipamentoComIdVazioNaoPodeSerVestido() {
        val item = equipamento(" ", EquipmentType.WEAPON)
        val resultado = EquipmentSystem.equipar(
            EquipmentLoadout(),
            item,
            classe("warrior"),
            1
        )

        assertFalse(resultado.success)
        assertNull(resultado.loadout.weaponId)
    }

    @Test
    fun equipamentoComRequisitoDeNivelInvalidoNaoPodeSerVestido() {
        val item = equipamento("espada", EquipmentType.WEAPON).copy(levelRequired = 0)
        val resultado = EquipmentSystem.equipar(
            EquipmentLoadout(),
            item,
            classe("warrior"),
            10
        )

        assertFalse(resultado.success)
        assertNull(resultado.loadout.weaponId)
    }

    @Test
    fun previewIgnoraEquipamentosComIdDuplicadoNoInventario() {
        val item = equipamento("espada", EquipmentType.WEAPON)
        val loadout = EquipmentLoadout(weaponId = item.id)

        val visuais = EquipmentSystem.equipmentForVisuals(
            loadout,
            listOf(item, item.copy(name = "Duplicado"))
        )

        assertTrue(visuais.isEmpty())
    }

    @Test
    fun loadoutDescartaItemRemovidoDoInventario() {
        val espada = equipamento("espada", EquipmentType.WEAPON)
        val loadout = EquipmentLoadout(weaponId = espada.id, armorId = "armadura_removida")
        val normalizado = EquipmentSystem.normalizarLoadout(loadout, listOf(espada))
        assertEquals("espada", normalizado.weaponId)
        assertNull(normalizado.armorId)
    }

    @Test
    fun loadoutDescartaIdDuplicadoEItemNoSlotIncorreto() {
        val espada = equipamento("espada", EquipmentType.WEAPON)
        val anel = equipamento("anel", EquipmentType.RING)
        val loadout = EquipmentLoadout(weaponId = "anel", ringId = "espada", shieldId = "espada")
        val normalizado = EquipmentSystem.normalizarLoadout(loadout, listOf(espada, anel, espada.copy(name = "Duplicada")))
        assertNull(normalizado.weaponId)
        assertNull(normalizado.ringId)
        assertNull(normalizado.shieldId)
    }

    @Test
    fun loadoutPermiteEscudoOuArmaPesadaNoEspacoSecundario() {
        val escudo = equipamento("escudo", EquipmentType.SHIELD)
        val martelo = equipamento("martelo", EquipmentType.WEAPON, "Martelo pesado")
        val normalizadoEscudo = EquipmentSystem.normalizarLoadout(
            EquipmentLoadout(shieldId = escudo.id), listOf(escudo)
        )
        val normalizadoMartelo = EquipmentSystem.normalizarLoadout(
            EquipmentLoadout(shieldId = martelo.id), listOf(martelo)
        )
        assertEquals("escudo", normalizadoEscudo.shieldId)
        assertEquals("martelo", normalizadoMartelo.shieldId)
    }

    @Test
    fun loadoutNaoRepeteMesmoItemEmDoisEspacos() {
        val espada = equipamento("espada", EquipmentType.WEAPON)
        val loadout = EquipmentLoadout(weaponId = "espada", shieldId = "espada")
        val normalizado = EquipmentSystem.normalizarLoadout(loadout, listOf(espada))
        assertEquals("espada", normalizado.weaponId)
        assertNull(normalizado.shieldId)
    }

    @Test
    fun equipamentoRespeitaNivelMinimo() {
        val resultado = EquipmentSystem.equipar(
            EquipmentLoadout(),
            equipamento("armadura", EquipmentType.ARMOR, level = 10),
            classe("warrior"),
            4
        )
        assertFalse(resultado.success)
        assertTrue(resultado.message.contains("nível 10"))
    }
}
