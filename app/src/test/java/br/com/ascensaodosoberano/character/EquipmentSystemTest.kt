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
    fun rascunhoVisualNaoPodeSobrescreverPersonagemExistente() {
        assertFalse(CharacterDocumentOwnershipPolicy.mayCreateVisualDraft(
            exists = true, storedOwnerUid = "uid-a",
            authenticatedUid = "uid-a", isVisualDraft = false
        ))
        assertFalse(CharacterDocumentOwnershipPolicy.mayCreateVisualDraft(
            exists = true, storedOwnerUid = "uid-b",
            authenticatedUid = "uid-a", isVisualDraft = true
        ))
        assertTrue(CharacterDocumentOwnershipPolicy.mayCreateVisualDraft(
            exists = false, storedOwnerUid = null,
            authenticatedUid = "uid-a", isVisualDraft = false
        ))
        assertTrue(CharacterDocumentOwnershipPolicy.mayCreateVisualDraft(
            exists = true, storedOwnerUid = "uid-a",
            authenticatedUid = "uid-a", isVisualDraft = true
        ))
    }

    @Test
    fun somenteDonoPodeRemoverRascunhoVisual() {
        assertTrue(CharacterDocumentOwnershipPolicy.mayDeleteVisualDraft(
            exists = true, storedOwnerUid = "uid-a",
            authenticatedUid = "uid-a", isVisualDraft = true
        ))
        assertFalse(CharacterDocumentOwnershipPolicy.mayDeleteVisualDraft(
            exists = true, storedOwnerUid = "uid-b",
            authenticatedUid = "uid-a", isVisualDraft = true
        ))
        assertFalse(CharacterDocumentOwnershipPolicy.mayDeleteVisualDraft(
            exists = true, storedOwnerUid = "uid-a",
            authenticatedUid = "uid-a", isVisualDraft = false
        ))
    }

    @Test
    fun geracaoVisualSoAplicaQuandoAparenciaOriginalContinuaIgual() {
        val original = CharacterAppearance(
            skinId = "pele_dragao", faceId = "rosto_2", hairId = "cabelo_azul",
            hairColorId = "azul", eyeId = "olho_dourado", outfitId = "tunica",
            descricaoCorpo = "escamas"
        )
        val armazenada = mapOf(
            "skinId" to "pele_dragao", "faceId" to "rosto_2", "hairId" to "cabelo_azul",
            "hairColorId" to "azul", "eyeId" to "olho_dourado", "outfitId" to "tunica",
            "descricaoCorpo" to "escamas"
        )
        assertTrue(CharacterVisualPersistencePolicy.matchesAppearance(original, armazenada))
        assertFalse(CharacterVisualPersistencePolicy.matchesAppearance(
            original, armazenada + ("hairId" to "cabelo_vermelho")
        ))
    }

    @Test
    fun geracaoVisualNaoSubstituiOutraImagemDaMesmaVersao() {
        val appearance = CharacterAppearance(skinId = "pele_01")
        val stored = mapOf(
            "skinId" to "pele_01", "faceId" to "rosto_01", "hairId" to "cabelo_01",
            "hairColorId" to "castanho", "eyeId" to "olhos_01",
            "outfitId" to "roupa_inicial_01", "descricaoCorpo" to "",
            "generatedImageUrl" to "https://cdn.example/atual.png",
            "generationId" to "geracao-atual", "visualVersion" to 3
        )
        val nova = CharacterAIGeneration(
            characterId = "personagem", generationId = "geracao-atrasada",
            status = GenerationStatus.COMPLETED, imagePath = "nova.png",
            imageUrl = "https://cdn.example/nova.png", visualVersion = 3
        )
        assertFalse(CharacterVisualPersistencePolicy.canApplyVisual(appearance, stored, nova))
    }

    @Test
    fun geracaoVisualPodeAtualizarArteLegadaIncompativel() {
        val appearance = CharacterAppearance()
        val stored = mapOf(
            "skinId" to "pele_01", "faceId" to "rosto_01", "hairId" to "cabelo_01",
            "hairColorId" to "castanho", "eyeId" to "olhos_01",
            "outfitId" to "roupa_inicial_01", "descricaoCorpo" to "",
            "generatedImageUrl" to "https://cdn.example/antiga.png",
            "generationId" to "legada", "visualVersion" to 1
        )
        val nova = CharacterAIGeneration(
            characterId = "personagem", generationId = "geracao-v3",
            status = GenerationStatus.COMPLETED, imagePath = "nova.png",
            imageUrl = "https://cdn.example/nova.png", visualVersion = 3
        )
        assertTrue(CharacterVisualPersistencePolicy.canApplyVisual(appearance, stored, nova))
    }

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
    fun recompensaNaoRestauraEquipamentoAntigoRemovidoNoServidor() {
        val inventarioRemoto = mapOf("equipment" to listOf(mapOf("id" to "escudo-atual", "name" to "Escudo")))
        val inventarioLocalAntigo = mapOf("equipment" to listOf(
            mapOf("id" to "escudo-atual", "name" to "Escudo"),
            mapOf("id" to "espada-transferida", "name" to "Espada antiga"),
            mapOf("id" to "nova-recompensa", "name" to "Lança")
        ))
        val resultado = BattleRewardEquipmentPolicy.mesclarEquipamentosDaRecompensa(
            inventarioRemoto, inventarioLocalAntigo, listOf("nova-recompensa")
        ) as Map<*, *>
        val ids = (resultado["equipment"] as List<*>).map { (it as Map<*, *>) ["id"] }
        assertEquals(listOf("escudo-atual", "nova-recompensa"), ids)
    }

    @Test
    fun inventarioRemotoAusenteAceitaSomenteEquipamentoExplicitamenteConcedido() {
        val local = mapOf("equipment" to listOf(
            mapOf("id" to "equipamento-antigo"), mapOf("id" to "drop-confirmado")
        ))
        val resultado = BattleRewardEquipmentPolicy.mesclarEquipamentosDaRecompensa(
            null, local, listOf("drop-confirmado")
        ) as Map<*, *>
        val ids = (resultado["equipment"] as List<*>).map { (it as Map<*, *>) ["id"] }
        assertEquals(listOf("drop-confirmado"), ids)
    }

    @Test
    fun recompensaIgnoraIdsDeEquipamentoDuplicadosOuNaoAutorizados() {
        val remoto = mapOf("equipment" to emptyList<Any>())
        val local = mapOf("equipment" to listOf(
            mapOf("id" to "drop-1"), mapOf("id" to "drop-1"), mapOf("id" to "antigo")
        ))
        val resultado = BattleRewardEquipmentPolicy.mesclarEquipamentosDaRecompensa(
            remoto, local, listOf("drop-1", "antigo")
        ) as Map<*, *>
        assertEquals(emptyList<Any>(), resultado["equipment"])
    }

    @Test
    fun loadoutPersistidoNaoMantemEquipamentoAusenteOuRepetido() {
        val loadout = mapOf("weaponId" to "espada", "shieldId" to "espada", "ringId" to "anel-removido")
        val inventory = mapOf("equipment" to listOf(mapOf("id" to "espada")))
        val seguro = BattleRewardEquipmentPolicy.normalizarLoadoutPersistido(loadout, inventory)
        assertEquals("espada", seguro["weaponId"])
        assertEquals(null, seguro["shieldId"])
        assertEquals(null, seguro["ringId"])
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
