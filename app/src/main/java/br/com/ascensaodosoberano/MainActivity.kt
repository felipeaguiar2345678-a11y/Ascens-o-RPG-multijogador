
package br.com.ascensaodosoberano

import androidx.compose.ui.text.input.PasswordVisualTransformation
import android.os.Bundle
import android.os.SystemClock
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.background
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

import br.com.ascensaodosoberano.world.CriaturaGerada
import br.com.ascensaodosoberano.world.RepositorioCriaturas
import br.com.ascensaodosoberano.world.TelaMapaMundi
import br.com.ascensaodosoberano.world.WorldTravelPlan
import br.com.ascensaodosoberano.world.WorldApi
import br.com.ascensaodosoberano.world.WorldClockApi
import br.com.ascensaodosoberano.world.WorldCycleSystem

import br.com.ascensaodosoberano.exploration.TelaMundo
import br.com.ascensaodosoberano.exploration.ExplorationSystem
import br.com.ascensaodosoberano.exploration.ExplorationEncounter
import br.com.ascensaodosoberano.exploration.EstadoCenaMundo
import br.com.ascensaodosoberano.exploration.ModoCenaMundo
import br.com.ascensaodosoberano.exploration.TransicaoMundo
import br.com.ascensaodosoberano.exploration.MovementDirection
import br.com.ascensaodosoberano.multiplayer.AllyRepository
import br.com.ascensaodosoberano.multiplayer.AllyGroup
import br.com.ascensaodosoberano.multiplayer.AllyInvite
import br.com.ascensaodosoberano.multiplayer.JogadorOnline
import br.com.ascensaodosoberano.multiplayer.AllyBattleRepository
import br.com.ascensaodosoberano.multiplayer.AllyBattleSnapshot
import br.com.ascensaodosoberano.multiplayer.TradeRepository
import br.com.ascensaodosoberano.multiplayer.TrocaSnapshot
import br.com.ascensaodosoberano.multiplayer.OfertaTroca
import br.com.ascensaodosoberano.multiplayer.GuildaPanel
import br.com.ascensaodosoberano.multiplayer.MultiplayerExpandidoPanel

import br.com.ascensaodosoberano.powers.PowerAwakeningEngine
import br.com.ascensaodosoberano.powers.PowerOrigin

import br.com.ascensaodosoberano.companions.PlayerInventory
import br.com.ascensaodosoberano.companions.InventorySystem
import br.com.ascensaodosoberano.companions.CompanionHatchingSystem
import br.com.ascensaodosoberano.companions.CompanionProgressionSystem
import br.com.ascensaodosoberano.companions.BlacksmithPanel

import br.com.ascensaodosoberano.character.CharacterProfile
import br.com.ascensaodosoberano.character.CharacterCreationScreen
import br.com.ascensaodosoberano.character.CharacterProfileRepository
import br.com.ascensaodosoberano.character.ProgressionSystem

import br.com.ascensaodosoberano.combat.CombatState
import br.com.ascensaodosoberano.combat.CombatPhase
import br.com.ascensaodosoberano.combat.CombatFactory
import br.com.ascensaodosoberano.combat.CombatSystem
import br.com.ascensaodosoberano.combat.CharacterCombatFactory
import br.com.ascensaodosoberano.combat.TelaCombate
import br.com.ascensaodosoberano.combat.MonsterLootSystem

import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore

import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        runCatching {
            FirebaseApp.initializeApp(this)
        }

        setContent {
            MaterialTheme {
                FluxoInicial()
            }
        }
    }
}

data class Power(
    val name: String,
    val cost: String,
    val detail: String
)

@Composable
fun GameApp() {

    val scope = rememberCoroutineScope()

    // Impede que gravações diferentes sobrescrevam umas às outras.
    val saveMutex = remember {
        Mutex()
    }

    var page by remember {
        mutableStateOf(0)
    }

    var showWorldMap by remember {
        mutableStateOf(false)
    }

    var worldSyncMessage by remember { mutableStateOf("") }
    var isWorldNight by remember { mutableStateOf(false) }
    var worldDaylightFactor by remember { mutableStateOf(1f) }
    var blacksmithAvailable by remember { mutableStateOf(true) }
    var merchantAvailable by remember { mutableStateOf(true) }

    var pendingTravelPlan by remember {
        mutableStateOf<WorldTravelPlan?>(null)
    }

    var message by remember {
        mutableStateOf("Bem-vindo ao Ascensão do Soberano!")
    }

    var characterProfile by remember {
        mutableStateOf<CharacterProfile?>(null)
    }

    var loadingCharacter by remember {
        mutableStateOf(true)
    }

    var creationError by remember {
        mutableStateOf("")
    }

    var gerandoImagemPersonagem by remember {
        mutableStateOf(false)
    }

    var erroImagemPersonagem by remember {
        mutableStateOf("")
    }

    var showIntro by remember {
        mutableStateOf(false)
    }

    var pendingLevelMessage by remember {
        mutableStateOf("")
    }

    var invite by remember {
        mutableStateOf("")
    }

    var code by remember {
        mutableStateOf("")
    }

    val allyRepository = remember { AllyRepository() }
    var allyGroupId by remember { mutableStateOf<String?>(null) }
    var allyGroup by remember { mutableStateOf<AllyGroup?>(null) }
    var allyInvites by remember { mutableStateOf<List<AllyInvite>>(emptyList()) }
    var allyMemberPresences by remember { mutableStateOf<List<JogadorOnline>>(emptyList()) }
    var selectedPlayerForAlly by remember { mutableStateOf<JogadorOnline?>(null) }
    val tradeRepository = remember { TradeRepository() }
    var minhasTrocas by remember { mutableStateOf<List<TrocaSnapshot>>(emptyList()) }
    var trocaParaEditar by remember { mutableStateOf<String?>(null) }
    var mostrarEditorTroca by remember { mutableStateOf(false) }
    var itensSelecionadosTroca by remember { mutableStateOf<Set<String>>(emptySet()) }
    var ovosSelecionadosTroca by remember { mutableStateOf<Set<String>>(emptySet()) }
    var equipamentosSelecionadosTroca by remember { mutableStateOf<Set<String>>(emptySet()) }
    val allyBattleRepository = remember { AllyBattleRepository() }
    var allyBattleSnapshot by remember { mutableStateOf<AllyBattleSnapshot?>(null) }
    var criaturaBatalhaCompartilhada by remember { mutableStateOf<CriaturaGerada?>(null) }
    var allyBattleId by remember { mutableStateOf<String?>(null) }

    var bestiario by remember {
        mutableStateOf<List<CriaturaGerada>>(emptyList())
    }

    var carregandoBestiario by remember {
        mutableStateOf(false)
    }
    var contaVisitante by remember {
    mutableStateOf(
        FirebaseAuth.getInstance().currentUser?.isAnonymous == true
    )
}

var mostrarVinculacao by remember {
    mutableStateOf(false)
}

var emailVinculacao by remember {
    mutableStateOf("")
}

var senhaVinculacao by remember {
    mutableStateOf("")
}

var vinculandoConta by remember {
    mutableStateOf(false)
}

    LaunchedEffect(Unit) {
        try {
            val auth = FirebaseAuth.getInstance()

            if (auth.currentUser == null) {
                auth.signInAnonymously().await()
            }

            characterProfile =
    CharacterProfileRepository().getForCurrentUser()

contaVisitante =
    auth.currentUser?.isAnonymous == true

        } catch (e: Exception) {
            message =
                "Erro ao carregar personagem: ${e.localizedMessage}"
        } finally {
            loadingCharacter = false
        }
    }

    LaunchedEffect(page) {
        if (page == 3) {
            carregandoBestiario = true

            try {
                val uid = FirebaseAuth.getInstance()
                    .currentUser?.uid

                if (uid != null) {
                    bestiario =
                        RepositorioCriaturas.buscarBestiario(uid)
                }

            } catch (e: Exception) {
                message =
                    "Erro ao carregar bestiário: ${e.localizedMessage}"
            } finally {
                carregandoBestiario = false
            }
        }
    }

    if (loadingCharacter) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = androidx.compose.ui.Alignment.Center
        ) {
            CircularProgressIndicator()
        }
        return
    }

    if (characterProfile == null) {

        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {

            if (creationError.isNotBlank()) {
                Text(
                    text = creationError,
                    color = MaterialTheme.colorScheme.error
                )
            }

            CharacterCreationScreen(
                onCharacterCreated = { createdProfile ->

                    scope.launch {
                        try {
                            val auth = FirebaseAuth.getInstance()

                            val user = auth.currentUser
                                ?: auth.signInAnonymously().await().user

                            if (user == null) {
                                error("Não foi possível autenticar o jogador.")
                            }

                            saveMutex.withLock {
                                CharacterProfileRepository().save(
                                    createdProfile
                                )
                            }

                            characterProfile = createdProfile
                            creationError = ""
                            message = "Personagem salvo na nuvem!"

                            // A imagem é gerada uma vez após a criação.
                            // O login normal nunca dispara uma nova cobrança.
                            gerandoImagemPersonagem = true
                            erroImagemPersonagem = ""
                            try {
                                val perfilComImagem = saveMutex.withLock {
                                    br.com.ascensaodosoberano.character.CharacterVisualGenerationRunner()
                                        .generate(createdProfile)
                                }
                                characterProfile = perfilComImagem
                                message = "Personagem criado e imagem visual gerada!"
                            } catch (visualError: Exception) {
                                erroImagemPersonagem = visualError.localizedMessage
                                    ?: "Não foi possível gerar a imagem agora."
                                message = "Personagem salvo. A imagem poderá ser tentada novamente."
                            } finally {
                                gerandoImagemPersonagem = false
                            }

                        } catch (e: Exception) {
                            creationError =
                                "Não foi possível salvar o personagem: ${e.localizedMessage}"
                        }
                    }
                }
            )
        }

        return
    }

    val profile = characterProfile!!
    val uidAtual = FirebaseAuth.getInstance().currentUser?.uid

    LaunchedEffect(uidAtual) {
        allyGroupId = uidAtual?.let { uid ->
            runCatching { allyRepository.obterGrupoId(uid) }.getOrNull()
        }
    }

    LaunchedEffect(uidAtual, profile.currentWorldPointId) {
        if (uidAtual != null) {
            runCatching { WorldApi.getWorldState() }.onSuccess { response ->
                val settlements = response.optJSONObject("state")?.optJSONArray("settlements")
                val currentCity = if (settlements == null) null else (0 until settlements.length())
                    .mapNotNull { settlements.optJSONObject(it) }
                    .firstOrNull { it.optString("id") == profile.currentWorldPointId }
                blacksmithAvailable = currentCity?.optBoolean("blacksmithOpen", true) ?: true
                merchantAvailable = currentCity?.optBoolean("merchantsOpen", true) ?: true
            }
        }
    }

    LaunchedEffect(uidAtual) {
        if (uidAtual != null) {
            var serverAnchor = runCatching { WorldClockApi.getServerEpochMillis() }.getOrDefault(0L)
            var monotonicAnchor = SystemClock.elapsedRealtime()
            var ultimaSincronizacao = monotonicAnchor
            while (true) {
                val monotonicNow = SystemClock.elapsedRealtime()
                if (serverAnchor == 0L || monotonicNow - ultimaSincronizacao >= 60_000L) {
                    runCatching { WorldClockApi.getServerEpochMillis() }
                        .onSuccess {
                            serverAnchor = it
                            monotonicAnchor = SystemClock.elapsedRealtime()
                            ultimaSincronizacao = monotonicAnchor
                        }
                }
                if (serverAnchor > 0L) {
                    val estimatedServerNow = serverAnchor + (SystemClock.elapsedRealtime() - monotonicAnchor)
                    val clock = WorldCycleSystem.calculate(estimatedServerNow)
                    isWorldNight = clock.isNight
                    worldDaylightFactor = clock.daylightFactor
                }
                delay(1000L)
            }
        }
    }

    LaunchedEffect(showWorldMap, uidAtual) {
        if (showWorldMap && uidAtual != null) {
            worldSyncMessage = "Sincronizando o mundo..."
            runCatching { WorldApi.getWorldState() }
                .onSuccess { response ->
                    val serverNow = response.optLong("serverEpochMillis", 0L)
                    if (serverNow > 0L) {
                        val clock = WorldCycleSystem.calculate(serverNow)
                        isWorldNight = clock.isNight
                        worldDaylightFactor = clock.daylightFactor
                        val state = response.optJSONObject("state")
                        val cityArray = state?.optJSONArray("settlements")
                        val cities = cityArray?.length() ?: 0
                        var threatened = 0
                        var conquered = 0
                        if (cityArray != null) {
                            for (index in 0 until cityArray.length()) {
                                val condition = cityArray.optJSONObject(index)?.optString("condition").orEmpty()
                                if (condition == "THREATENED" || condition == "BESIEGED") threatened++
                                if (condition == "CONQUERED") conquered++
                            }
                        }
                        val currentCity = if (cityArray == null) null else (0 until cityArray.length())
                            .mapNotNull { cityArray.optJSONObject(it) }
                            .firstOrNull { it.optString("id") == profile.currentWorldPointId }
                        blacksmithAvailable = currentCity?.optBoolean("blacksmithOpen", true) ?: true
                        merchantAvailable = currentCity?.optBoolean("merchantsOpen", true) ?: true
                        val intervalos = response.optInt("elapsedIntervals", 0)
                        val factions = state?.optJSONArray("factions")?.length() ?: 0
                        val questArray = state?.optJSONArray("quests")
                        val quests = questArray?.length() ?: 0
                        val questTitle = questArray?.optJSONObject(0)?.optString("title").orEmpty()
                        val wars = state?.optJSONArray("wars")?.length() ?: 0
                        val fase = when (clock.phase) {
                            br.com.ascensaodosoberano.world.WorldTimePhase.DAY -> "Dia"
                            br.com.ascensaodosoberano.world.WorldTimePhase.SUNSET -> "Pôr do sol"
                            br.com.ascensaodosoberano.world.WorldTimePhase.NIGHT -> "Noite"
                            br.com.ascensaodosoberano.world.WorldTimePhase.DAWN -> "Amanhecer"
                        }
                        worldSyncMessage = "Mundo sincronizado • $fase • $cities cidades • $threatened ameaçadas • $conquered conquistadas • $factions facções • $wars guerras • $quests missões • $intervalos ciclos simulados" +
                            if (questTitle.isNotBlank()) "\nMissão ativa: $questTitle" else ""
                    } else {
                        worldSyncMessage = "Relógio mundial aguardando sincronização."
                    }
                }
                .onFailure {
                    worldSyncMessage = "Mundo persistente aguardando ativação do servidor."
                }
        }
    }

    DisposableEffect(uidAtual) {
        val listener = uidAtual?.let { uid ->
            allyRepository.observarConvites(uid) { allyInvites = it }
        }
        onDispose { listener?.remove() }
    }

    DisposableEffect(uidAtual) {
        val listener = uidAtual?.let { uid ->
            tradeRepository.observarMinhasTrocas(uid) { minhasTrocas = it }
        }
        onDispose { listener?.remove() }
    }

    DisposableEffect(allyGroupId) {
        allyBattleSnapshot = null
        allyBattleId = null
        val groupListener = allyGroupId?.let { id ->
            allyRepository.observarGrupo(id) { group ->
                allyGroup = group
                if (group == null || uidAtual !in group.members) {
                    allyGroupId = null
                    allyGroup = null
                    allyMemberPresences = emptyList()
                }
            }
        }
        onDispose {
            groupListener?.remove()
        }
    }

    DisposableEffect(allyGroup?.members) {
        val listener = allyGroup?.members?.let { members ->
            br.com.ascensaodosoberano.multiplayer.PresenceRepository()
                .observarPresencasDosJogadores(members) { allyMemberPresences = it }
        }
        onDispose { listener?.remove() }
    }

    LaunchedEffect(profile.id, profile.hasSeenIntro) {
        if (!profile.hasSeenIntro) {
            showIntro = true
        }
    }

    val nextLevelXp =
        ProgressionSystem.xpForNextLevel(profile.level)

    val xpProgress = (
        profile.xp.toFloat() / nextLevelXp.toFloat()
    ).coerceIn(0f, 1f)

    var hero by remember(profile.id) {
        mutableStateOf(
            CharacterCombatFactory.createHero(profile)
        )
    }

    var powerProfile by remember(profile.id) {
        mutableStateOf(profile.powerProfile)
    }

    var playerInventory by remember(profile.id) {
        mutableStateOf(profile.inventory)
    }

    // Controle para impedir duas eclosões simultâneas.
    var eclodindoOvoId by remember(profile.id) {
        mutableStateOf<String?>(null)
    }

    fun salvarPerfil(
        updatedProfile: CharacterProfile,
        erro: String
    ) {
        characterProfile = updatedProfile

        scope.launch {
            try {
                saveMutex.withLock {
                    CharacterProfileRepository().save(updatedProfile)
                }
            } catch (e: Exception) {
                message = "$erro: ${e.localizedMessage}"
            }
        }
    }

    fun atualizarInventario(
        updatedInventory: PlayerInventory
    ) {
        playerInventory = updatedInventory

        val updatedProfile = (
            characterProfile ?: profile
        ).copy(
            inventory = updatedInventory
        )

        salvarPerfil(
            updatedProfile,
            "Erro ao salvar inventário"
        )
    }

    fun allocateAttribute(attribute: String) {

        val currentProfile =
            characterProfile ?: profile

        val updatedProfile =
            ProgressionSystem.spendAttributePoint(
                currentProfile,
                attribute
            )

        if (updatedProfile == currentProfile) {
            return
        }

        val profileWithInventory =
            updatedProfile.copy(
                inventory = playerInventory
            )

        salvarPerfil(
            profileWithInventory,
            "Erro ao salvar atributos"
        )

        val updatedHero =
            CharacterCombatFactory.createHero(
                profileWithInventory
            )

        hero = updatedHero.copy(
            hp = hero.hp.coerceAtMost(updatedHero.maxHp),
            mana = hero.mana.coerceAtMost(updatedHero.maxMana)
        )
    }

    fun observePowerAction(
        action: String,
        category: String,
        intensity: Int,
        difficulty: Int = 1,
        origin: PowerOrigin? = null,
        successful: Boolean = true,
        tags: List<String> = emptyList()
    ) {

        powerProfile = PowerAwakeningEngine.observe(
            profile = powerProfile,
            action = action,
            category = category,
            intensity = intensity,
            difficulty = difficulty,
            origin = origin,
            successful = successful,
            tags = tags
        )

        val newDesires =
            PowerAwakeningEngine.evaluate(powerProfile)

        if (newDesires.isNotEmpty()) {
            powerProfile = powerProfile.copy(
                desires = powerProfile.desires + newDesires
            )
        }

        val updatedProfile = (
            characterProfile ?: profile
        ).copy(
            powerProfile = powerProfile,
            inventory = playerInventory
        )

        salvarPerfil(
            updatedProfile,
            "Erro ao salvar evolução dos poderes"
        )
    }

    var selectedRegion by remember {
        mutableStateOf(ExplorationSystem.regions.first())
    }

    var estadoMundo by remember {
        mutableStateOf(EstadoCenaMundo())
    }

    var direcaoMovimento by remember {
        mutableStateOf(MovementDirection())
    }

    var encounter by remember {
        mutableStateOf<ExplorationEncounter?>(null)
    }

    var combat by remember {
        mutableStateOf<CombatState?>(null)
    }

    DisposableEffect(allyGroup?.activeBattleId) {
        val battleId = allyGroup?.activeBattleId?.takeIf { it.isNotBlank() }
        allyBattleId = battleId
        val listener = battleId?.let { id ->
            allyBattleRepository.observarBatalha(id) { snapshot ->
                allyBattleSnapshot = snapshot
                if (snapshot != null && snapshot.members.any { it.uid == uidAtual }) {
                    snapshot.members.firstOrNull { it.uid == uidAtual }?.let { hero = it.hero }
                    if (snapshot.status == "FINISHED" && uidAtual in snapshot.claimedUids) {
                        combat = null
                        estadoMundo = TransicaoMundo.finalizarCombate(estadoMundo)
                    } else {
                        combat = snapshot.state
                        if (snapshot.status == "ACTIVE" || snapshot.status == "FINISHED") {
                            page = 2
                            estadoMundo = TransicaoMundo.iniciarCombate(estadoMundo)
                        }
                    }
                }
            }
        }
        onDispose { listener?.remove() }
    }

    var combateFinalizado by remember(profile.id) {
        mutableStateOf(false)
    }

    LaunchedEffect(allyBattleSnapshot?.creatureId) {
        val creatureId = allyBattleSnapshot?.creatureId
        criaturaBatalhaCompartilhada = if (!creatureId.isNullOrBlank()) {
            runCatching { RepositorioCriaturas.buscarCriatura(creatureId) }.getOrNull()
        } else null
    }

    fun iniciarCombateComCriatura(criatura: CriaturaGerada) {
        combateFinalizado = false
        if (criatura.atividadeNoturna && !isWorldNight) {
            message = "Essa criatura só aparece durante a noite."
            return
        }
        val estadoInicial = CombatFactory.createCombat(hero, criatura, isNight = isWorldNight)
        val grupo = allyGroup
        val uid = uidAtual
        if (grupo != null && grupo.members.size > 1 && uid != null) {
            scope.launch {
                try {
                    val batalhaExistente = if (grupo.activeBattleId.isNotBlank()) {
                        allyBattleRepository.obterBatalha(grupo.activeBattleId)
                    } else null
                    if (batalhaExistente?.status == "ACTIVE") {
                        allyBattleSnapshot = batalhaExistente
                        allyBattleId = batalhaExistente.id
                        if (batalhaExistente.members.any { it.uid == uid }) {
                            combat = batalhaExistente.state
                            estadoMundo = TransicaoMundo.iniciarCombate(estadoMundo)
                            page = 2
                            message = "Você já está participando desta batalha."
                        } else {
                            allyBattleRepository.entrarNaBatalha(batalhaExistente.id, uid)
                            message = "Solicitação para entrar na batalha enviada."
                        }
                    } else {
                        if (batalhaExistente?.status == "FINISHED" &&
                            !batalhaExistente.claimedUids.containsAll(batalhaExistente.members.map { it.uid })
                        ) {
                            error("Todos os participantes precisam retirar as recompensas antes de iniciar outra batalha.")
                        }
                        val battleId = allyBattleRepository.iniciarBatalha(
                            groupId = grupo.id,
                            starterUid = uid,
                            worldPointId = profile.currentWorldPointId,
                            creatureId = criatura.id,
                            initialState = estadoInicial
                        )
                        allyBattleId = battleId
                        combat = estadoInicial
                        estadoMundo = TransicaoMundo.iniciarCombate(estadoMundo)
                        page = 2
                        message = "Combate cooperativo iniciado!"
                    }
                } catch (e: Exception) {
                    message = "Não foi possível iniciar o combate cooperativo: ${e.localizedMessage}"
                }
            }
        } else {
            allyBattleSnapshot = null
            allyBattleId = null
            combat = estadoInicial
            estadoMundo = TransicaoMundo.iniciarCombate(estadoMundo)
            message = "Combate iniciado!"
        }
    }

    fun finalizarCombate(state: CombatState) {

        if (combateFinalizado) return

        combateFinalizado = true

        if (state.phase == CombatPhase.VICTORY) {

            val currentProfile =
                characterProfile ?: profile

            val criaturaDerrotada =
                encounter?.criatura ?: criaturaBatalhaCompartilhada

            val batalhaCompartilhada = allyBattleSnapshot?.takeIf { it.status == "FINISHED" }
            val meuCombatente = batalhaCompartilhada?.members?.firstOrNull { it.uid == uidAtual }
            val participaDaBatalha = batalhaCompartilhada == null || meuCombatente != null
            val heroiLocalFinal = meuCombatente?.hero ?: state.hero

            // Cada participante recebe uma rolagem individual e independente de saque.
            // Dano causado não aumenta nem reduz as chances de materiais, equipamentos ou ovos.
            val loot = if (participaDaBatalha) {
                criaturaDerrotada?.let { criatura -> MonsterLootSystem.generate(criatura, isNight = isWorldNight) }
            } else null

            var inventarioAtualizado =
                playerInventory

            loot?.items?.forEach { item ->
                inventarioAtualizado =
                    InventorySystem.addItem(
                        inventarioAtualizado,
                        item
                    )
            }

            loot?.equipment?.forEach { equipamento ->
                inventarioAtualizado =
                    InventorySystem.addEquipment(
                        inventarioAtualizado,
                        equipamento
                    )
            }

            loot?.egg?.let { ovo ->
                inventarioAtualizado =
                    InventorySystem.addEgg(
                        inventarioAtualizado,
                        ovo
                    )
            }

            // XP do companheiro ativo: 50% do XP do jogador.
            var mensagemCompanheiro = ""

            val companheiroAtivo =
                InventorySystem.obterCompanheiroAtivo(
                    inventarioAtualizado
                )

            if (companheiroAtivo != null) {

                val resultadoCompanheiro =
                    CompanionProgressionSystem.gainXp(
                        companion = companheiroAtivo,
                        playerXp = state.xpGained
                    )

                val companheiroAtualizado =
                    resultadoCompanheiro.companion

                inventarioAtualizado =
                    inventarioAtualizado.copy(
                        companions = inventarioAtualizado.companions.map {
                            companheiro ->
                            if (companheiro.id == companheiroAtivo.id) {
                                companheiroAtualizado
                            } else {
                                companheiro
                            }
                        }
                    )

                if (resultadoCompanheiro.xpReceived > 0) {
                    mensagemCompanheiro =
                        "\n${companheiroAtualizado.name} recebeu ${resultadoCompanheiro.xpReceived} XP."
                }

                if (resultadoCompanheiro.levelsGained > 0) {
                    mensagemCompanheiro +=
                        "\n${companheiroAtualizado.name} subiu ${resultadoCompanheiro.levelsGained} nível(is)! Nível atual: ${companheiroAtualizado.level}. Estágio: ${companheiroAtualizado.stage}."
                }
            }

            val membrosDaRecompensa = batalhaCompartilhada?.members?.sortedBy { it.uid }.orEmpty()
            val participantesDaRecompensa = membrosDaRecompensa.size.coerceAtLeast(1)
            val ouroTotal = loot?.gold ?: 0L
            val parcelaBase = ouroTotal / participantesDaRecompensa
            val resto = (ouroTotal % participantesDaRecompensa).toInt()
            val indiceDoJogador = membrosDaRecompensa.indexOfFirst { it.uid == uidAtual }
            val bonusDeResto = if (indiceDoJogador in 0 until resto) 1L else 0L
            val ouroRecebido = if (batalhaCompartilhada == null) ouroTotal else parcelaBase + bonusDeResto
            inventarioAtualizado = inventarioAtualizado.copy(
                gold = inventarioAtualizado.gold + ouroRecebido
            )

            playerInventory =
                inventarioAtualizado

            if (ouroRecebido > 0L) {
                message = "Você recebeu $ouroRecebido de ouro. Seus itens foram definidos por uma rolagem individual de sorte."
            }

            // Progressão normal do jogador permanece inalterada.
            val progression =
                ProgressionSystem.gainXp(
                    currentProfile,
                    state.xpGained
                )

            val progressedProfile =
                progression.profile.copy(
                    inventory = inventarioAtualizado
                )

            salvarPerfil(
                progressedProfile,
                "Erro ao salvar progresso"
            )

            if (progression.levelsGained > 0) {

                val upgradedHero =
                    CharacterCombatFactory.createHero(
                        progressedProfile
                    )

                hero = upgradedHero.copy(
                    hp = heroiLocalFinal.hp.coerceAtMost(
                        upgradedHero.maxHp
                    ),
                    mana = heroiLocalFinal.mana.coerceAtMost(
                        upgradedHero.maxMana
                    )
                )

                pendingLevelMessage =
                    "Você subiu ${progression.levelsGained} nível(is)! Novo nível: ${progressedProfile.level}"

            } else {

                hero = heroiLocalFinal

                pendingLevelMessage =
                    "XP recebido: ${state.xpGained}"
            }

            pendingLevelMessage += mensagemCompanheiro
            if (ouroRecebido > 0L) pendingLevelMessage += "\nOuro recebido: $ouroRecebido"

            if (loot != null) {

                val nomesRecompensas =
                    buildList {

                        addAll(
                            loot.items.map { it.name }
                        )

                        addAll(
                            loot.equipment.map { it.name }
                        )

                        if (loot.egg != null) {
                            add("Ovo de companheiro")
                        }
                    }

                if (nomesRecompensas.isNotEmpty()) {
                    pendingLevelMessage +=
                        "\nRecompensas: ${nomesRecompensas.joinToString(", ")}"
                }
            }

        } else {

            val heroiLocal = allyBattleSnapshot?.members?.firstOrNull { it.uid == uidAtual }?.hero ?: state.hero
            hero = heroiLocal
            pendingLevelMessage = ""
        }

        combat = null

        estadoMundo =
            TransicaoMundo.finalizarCombate(
                estadoMundo
            )

        encounter = null
        allyBattleSnapshot = null
        allyBattleId = null

        message = pendingLevelMessage
    }

    Scaffold(
        topBar = {
            if (combat == null) {
                Surface(tonalElevation = 3.dp) {
                    Text(
                        text = "Ascensão do Soberano",
                        style = MaterialTheme.typography.titleLarge,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(horizontal = 16.dp, vertical = 14.dp)
                    )
                }
            }
        },

        bottomBar = {
            if (combat == null) {
                NavigationBar {
                    listOf(
                        "Personagem",
                        "Multiplayer",
                        "Mundo",
                        "Bestiário",
                        "Ferreiro"
                    ).forEachIndexed { index, title ->

                        NavigationBarItem(
                            selected = page == index,
                            onClick = {
                                page = index
                            },
                            icon = {},
                            label = {
                                Text(title)
                            }
                        )
                    }
                }
            }
        }

    ) { padding ->

        Column(
            modifier = if (combat != null) {
                Modifier.fillMaxSize()
            } else {
                Modifier
                    .padding(padding)
                    .fillMaxSize()
                    .padding(16.dp)
            },

            verticalArrangement = if (combat != null) {
                Arrangement.Top
            } else {
                Arrangement.spacedBy(12.dp)
            }

        ) {

            when {

                // BESTIÁRIO
                page == 3 -> LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {

                    item {
                        Text(
                            "BESTIÁRIO",
                            style = MaterialTheme.typography.titleLarge
                        )

                        Text(
                            "Criaturas descobertas durante suas explorações."
                        )
                    }

                    if (carregandoBestiario) {
                        item {
                            CircularProgressIndicator()
                        }

                    } else if (bestiario.isEmpty()) {
                        item {
                            Text(
                                "Você ainda não descobriu nenhuma criatura."
                            )
                        }

                    } else {
                        items(bestiario) { criatura ->

                            Card(
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(
                                    modifier = Modifier.padding(12.dp),
                                    verticalArrangement = Arrangement.spacedBy(4.dp)
                                ) {

                                    Text(
                                        criatura.nome,
                                        style = MaterialTheme.typography.titleMedium
                                    )

                                    Text(
                                        "Rank: ${criatura.rank} • Nível: ${criatura.nivel}"
                                    )

                                    Text("Raridade: ${criatura.raridade}")
                                    Text("Bioma: ${criatura.bioma}")
                                    Text("Habitat: ${criatura.habitat}")
                                    Text(criatura.descricao)

                                    if (criatura.chefe) {
                                        Text("CHEFE")
                                    }

                                    Text(
                                        "Habilidades: ${
                                            criatura.habilidades.joinToString(", ")
                                                .ifBlank { "Nenhuma registrada" }
                                        }"
                                    )
                                }
                            }
                        }
                    }
                }

                // FERREIRO E FABRICAÇÃO DE EQUIPAMENTOS
                page == 4 -> if (blacksmithAvailable) {
                    BlacksmithPanel(
                        pointId = profile.currentWorldPointId,
                        inventory = playerInventory,
                        onInventoryChanged = { updated -> atualizarInventario(updated) },
                        onMessage = { message = it }
                    )
                } else {
                    Column(
                        modifier = Modifier.fillMaxSize().padding(24.dp),
                        verticalArrangement = Arrangement.Center,
                        horizontalAlignment = androidx.compose.ui.Alignment.CenterHorizontally
                    ) {
                        Text("O ferreiro não está disponível.")
                        Text("Esta cidade foi conquistada e os artesãos fugiram. Ajude a libertá-la para reabrir os serviços.")
                    }
                }

                // PERSONAGEM
                page == 0 -> LazyColumn(
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {

                    item {
                        Text(
                            profile.name,
                            style = MaterialTheme.typography.titleLarge
                        )
                    }
                    item {
                        Text("Ouro: ${playerInventory.gold}", style = MaterialTheme.typography.titleMedium)
                    }
                    item {
                        br.com.ascensaodosoberano.character.CharacterAppearancePreview(
                            appearance = profile.appearance
                        )
                    }
                    item {
                        when {
                            gerandoImagemPersonagem -> {
                                Row(
                                    modifier = Modifier.fillMaxWidth(),
                                    horizontalArrangement = Arrangement.spacedBy(10.dp),
                                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically
                                ) {
                                    CircularProgressIndicator(modifier = Modifier.size(22.dp))
                                    Text("Gerando a aparência do personagem...")
                                }
                            }
                            profile.appearance.generatedImageUrl.isBlank() -> {
                                Column(verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                    if (erroImagemPersonagem.isNotBlank()) {
                                        Text(
                                            erroImagemPersonagem,
                                            color = MaterialTheme.colorScheme.error
                                        )
                                    }
                                    Button(
                                        onClick = {
                                            if (gerandoImagemPersonagem) return@Button
                                            scope.launch {
                                                gerandoImagemPersonagem = true
                                                erroImagemPersonagem = ""
                                                try {
                                                    val atualizado = saveMutex.withLock {
                                                        br.com.ascensaodosoberano.character.CharacterVisualGenerationRunner()
                                                            .generate(characterProfile ?: profile)
                                                    }
                                                    characterProfile = atualizado
                                                    message = "Imagem do personagem gerada!"
                                                } catch (visualError: Exception) {
                                                    erroImagemPersonagem = visualError.localizedMessage
                                                        ?: "Não foi possível gerar a imagem."
                                                } finally {
                                                    gerandoImagemPersonagem = false
                                                }
                                            }
                                        },
                                        modifier = Modifier.fillMaxWidth(),
                                        enabled = !gerandoImagemPersonagem
                                    ) {
                                        Text("GERAR IMAGEM DO PERSONAGEM")
                                    }
                                    Text(
                                        "Uma tentativa consome o orçamento reservado para imagens.",
                                        style = MaterialTheme.typography.bodySmall
                                    )
                                }
                            }
                        }
                    }
                    item {
    if (contaVisitante) {
        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(
                containerColor = MaterialTheme.colorScheme.secondaryContainer
            )
        ) {
            Column(
                modifier = Modifier.padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(10.dp)
            ) {

                Text(
                    "CONTA DE VISITANTE",
                    style = MaterialTheme.typography.titleMedium
                )

                Text(
                    "Vincule um e-mail e uma senha para proteger " +
                    "seu personagem e continuar jogando em outros dispositivos."
                )

                if (!mostrarVinculacao) {

                    Button(
                        onClick = {
                            mostrarVinculacao = true
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("VINCULAR CONTA")
                    }

                } else {

                    OutlinedTextField(
                        value = emailVinculacao,
                        onValueChange = {
                            emailVinculacao = it
                        },
                        label = {
                            Text("E-mail")
                        },
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )

                    OutlinedTextField(
                        value = senhaVinculacao,
                        onValueChange = {
                            senhaVinculacao = it
                        },
                        label = {
                            Text("Senha")
                        },
                        visualTransformation = PasswordVisualTransformation(),
                        singleLine = true,
                        modifier = Modifier.fillMaxWidth()
                    )

                    Button(
                        onClick = {
                            if (vinculandoConta) return@Button

                            scope.launch {
                                vinculandoConta = true

                                try {
                                    AutenticacaoJogador.vincularConta(
                                        emailVinculacao.trim(),
                                        senhaVinculacao
                                    )

                                    contaVisitante = false
                                    mostrarVinculacao = false
                                    emailVinculacao = ""
                                    senhaVinculacao = ""

                                    message =
                                        "Conta vinculada com sucesso! " +
                                        "Seu personagem e seu progresso foram preservados."

                                } catch (e: Exception) {

                                    message =
                                        "Não foi possível vincular a conta: " +
                                        (e.localizedMessage
                                            ?: "Verifique o e-mail e tente novamente.")
                                } finally {
                                    vinculandoConta = false
                                }
                            }
                        },
                        enabled = emailVinculacao.isNotBlank() &&
                            senhaVinculacao.length >= 6 &&
                            !vinculandoConta,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text(
                            if (vinculandoConta) {
                                "VINCULANDO..."
                            } else {
                                "CONFIRMAR VINCULAÇÃO"
                            }
                        )
                    }

                    OutlinedButton(
                        onClick = {
                            mostrarVinculacao = false
                            emailVinculacao = ""
                            senhaVinculacao = ""
                        },
                        enabled = !vinculandoConta,
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("CANCELAR")
                    }

                    if (vinculandoConta) {
                        CircularProgressIndicator()
                    }
                }
            }
        }
    }
}

                    item {
                        Text("Nível ${profile.level} • XP ${profile.xp}")
                    }

                    item {
                        LinearProgressIndicator(
                            progress = { xpProgress },
                            modifier = Modifier.fillMaxWidth()
                        )
                    }

                    item {
                        Text(
                            "${(xpProgress * 100).toInt()}% de progresso para o próximo nível"
                        )
                    }

                    item {
                        Text(
                            "Próximo nível: ${nextLevelXp - profile.xp} XP restantes"
                        )
                    }

                    item {
                        Text("Classe: ${profile.characterClass.name}")
                        Text(profile.characterClass.description)
                    }

                    item {
                        Text(
                            "ATRIBUTOS DE COMBATE",
                            style = MaterialTheme.typography.titleMedium
                        )

                        Text("Vida: ${hero.hp}/${hero.maxHp}")
                        Text("Mana: ${hero.mana}/${hero.maxMana}")
                        Text("Ataque: ${hero.attack}")
                        Text("Poder mágico: ${hero.magicPower}")
                        Text("Defesa: ${hero.defense}")
                        Text("Agilidade: ${hero.agility}")
                        Text("Rank: ${hero.rank}")
                    }

                    item {
                        Text(
                            "ATRIBUTOS DO PERSONAGEM",
                            style = MaterialTheme.typography.titleMedium
                        )

                        Text(
                            "Pontos disponíveis: ${profile.attributePoints}"
                        )
                    }

                    item {
                        Text("Força: ${profile.attributes.strength}")

                        Button(
                            onClick = {
                                allocateAttribute("forca")
                            },
                            enabled = profile.attributePoints > 0
                        ) {
                            Text("Aumentar força")
                        }
                    }

                    item {
                        Text("Inteligência: ${profile.attributes.intelligence}")

                        Button(
                            onClick = {
                                allocateAttribute("inteligencia")
                            },
                            enabled = profile.attributePoints > 0
                        ) {
                            Text("Aumentar inteligência")
                        }
                    }

                    item {
                        Text("Agilidade: ${profile.attributes.agility}")

                        Button(
                            onClick = {
                                allocateAttribute("agilidade")
                            },
                            enabled = profile.attributePoints > 0
                        ) {
                            Text("Aumentar agilidade")
                        }
                    }

                    item {
                        Text("Vitalidade: ${profile.attributes.vitality}")

                        Button(
                            onClick = {
                                allocateAttribute("vitalidade")
                            },
                            enabled = profile.attributePoints > 0
                        ) {
                            Text("Aumentar vitalidade")
                        }
                    }

                    item {
                        Text("Espírito: ${profile.attributes.spirit}")

                        Button(
                            onClick = {
                                allocateAttribute("espirito")
                            },
                            enabled = profile.attributePoints > 0
                        ) {
                            Text("Aumentar espírito")
                        }
                    }

                    // OVOS DE COMPANHEIROS
                    item {
                        Text(
                            "OVOS DE COMPANHEIROS",
                            style = MaterialTheme.typography.titleMedium
                        )
                    }

                    if (playerInventory.eggs.isEmpty()) {
                        item {
                            Text("Você ainda não possui ovos.")
                        }
                    } else {
                        items(
                            items = playerInventory.eggs,
                            key = { it.id }
                        ) { ovo ->

                            Card(
                                modifier = Modifier.fillMaxWidth()
                            ) {
                                Column(
                                    modifier = Modifier.padding(12.dp),
                                    verticalArrangement = Arrangement.spacedBy(6.dp)
                                ) {

                                    Text(
                                        ovo.species,
                                        style = MaterialTheme.typography.titleMedium
                                    )

                                    Text("Rank: ${ovo.rank}")
                                    Text("Quantidade: ${ovo.quantity}")
                                    Text("Mutação: ${ovo.mutationName}")
                                    Text("Raridade: ${ovo.mutationRarity}")
                                    Text(ovo.mutationDescription)

                                    Button(
                                        onClick = {
                                            if (eclodindoOvoId != null) {
                                                return@Button
                                            }

                                            scope.launch {
                                                eclodindoOvoId = ovo.id

                                                try {
                                                    val resultado =
                                                        CompanionHatchingSystem.hatchEgg(
                                                            inventory = playerInventory,
                                                            eggId = ovo.id
                                                        )

                                                    if (resultado.success) {
                                                        atualizarInventario(
                                                            resultado.inventory
                                                        )
                                                    }

                                                    message = resultado.message

                                                } catch (e: Exception) {
                                                    message =
                                                        "Erro ao eclodir ovo: ${e.localizedMessage}"
                                                } finally {
                                                    eclodindoOvoId = null
                                                }
                                            }
                                        },
                                        enabled = eclodindoOvoId == null,
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text(
                                            if (eclodindoOvoId == ovo.id) {
                                                "ECLODINDO..."
                                            } else {
                                                "ECLODIR OVO"
                                            }
                                        )
                                    }
                                }
                            }
                        }
                    }

                    // COMPANHEIROS
                    item {
                        Text(
                            "COMPANHEIROS",
                            style = MaterialTheme.typography.titleMedium
                        )
                    }

                    if (playerInventory.companions.isEmpty()) {
                        item {
                            Text("Você ainda não possui companheiros.")
                        }
                    } else {
                        items(
                            items = playerInventory.companions,
                            key = { it.id }
                        ) { companion ->

                            Card {
                                Column(
                                    Modifier.padding(12.dp)
                                ) {

                                    Text(
                                        "${companion.name} — Rank ${companion.rank}"
                                    )

                                    Text("Nível ${companion.level}")
                                    Text("Estágio: ${companion.stage}")
                                    Text("Mutação: ${companion.mutationName}")
                                    Text("Vida: ${companion.hp}/${companion.maxHp}")
                                    Text("Ataque: ${companion.attack}")
                                    Text("Defesa: ${companion.defense}")

                                    if (companion.isActive) {
                                        Text("Companheiro ativo")
                                    }

                                    Row {

                                        Button(
                                            onClick = {

                                                val updated =
                                                    InventorySystem.ativarCompanheiro(
                                                        playerInventory,
                                                        companion.id
                                                    )

                                                atualizarInventario(updated)
                                            }
                                        ) {
                                            Text("Ativar")
                                        }

                                        OutlinedButton(
                                            onClick = {

                                                val updated =
                                                    InventorySystem.retirarCompanheiro(
                                                        playerInventory
                                                    )

                                                atualizarInventario(updated)
                                            },
                                            enabled = companion.isActive
                                        ) {
                                            Text("Retirar")
                                        }
                                    }
                                }
                            }
                        }
                    }
                }

                // COMBATE INTEGRADO AO MUNDO
                estadoMundo.modo == ModoCenaMundo.COMBATE &&
                    combat != null -> {

                    TelaMundo(
                        estado = estadoMundo,
                        aoAtualizarEstado = {
                            estadoMundo = it
                        },
                        companheiro = InventorySystem.obterCompanheiroAtivo(
                            playerInventory
                        ),
                        modifier = Modifier.fillMaxSize(),
                        uidJogador = FirebaseAuth.getInstance().currentUser?.uid,
                        nomeJogador = characterProfile?.name ?: "Aventureiro",
                        nivelJogador = characterProfile?.level ?: 1,
                        vidaJogador = hero.hp,
                        vidaMaximaJogador = hero.maxHp,
                        ataqueJogador = hero.attack,
                        defesaJogador = hero.defense,
                        manaJogador = hero.mana,
                        manaMaximaJogador = hero.maxMana,
                        agilidadeJogador = hero.agility,
                        poderMagicoJogador = hero.magicPower,
                        worldPointId = characterProfile?.currentWorldPointId ?: "clareira_inicial",
                        daylightFactor = worldDaylightFactor,
                        aoSelecionarJogador = { selectedPlayerForAlly = it },
                        conteudoCombate = { areaCombate ->

                            combat?.let { state ->

                                TelaCombate(
                                    state = state,

                                    companion = InventorySystem.obterCompanheiroAtivo(
                                        playerInventory
                                    ),

                                    modifier = areaCombate,
                                    integradoAoMapa = true,
                                    podeAgir = allyBattleId == null || allyBattleSnapshot?.activePlayerUid == uidAtual,
                                    nomeJogadorDoTurno = allyBattleSnapshot?.members?.firstOrNull { it.uid == allyBattleSnapshot?.activePlayerUid }?.name.orEmpty(),
                                    nomesGrupo = allyBattleSnapshot?.members?.map { "${it.name} (${it.role})" }.orEmpty(),
                                    onCombo = if (allyBattleId != null && allyBattleSnapshot?.members?.any { it.uid != uidAtual && it.hero.isAlive } == true) ({
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) scope.launch {
                                            runCatching { allyBattleRepository.executarAcao(battleId, uid, "COMBO") }
                                                .onFailure { message = "Combo não sincronizado: ${it.localizedMessage}" }
                                        }
                                    }) else null,
                                    onRevive = if (allyBattleId != null && allyBattleSnapshot?.members?.any { it.uid != uidAtual && !it.hero.isAlive } == true) ({
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) scope.launch {
                                            runCatching { allyBattleRepository.executarAcao(battleId, uid, "REVIVER") }
                                                .onFailure { message = "Não foi possível reanimar: ${it.localizedMessage}" }
                                        }
                                    }) else null,

                                    onSkill = { skillId ->
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) {
                                            scope.launch {
                                                runCatching { allyBattleRepository.executarAcao(battleId, uid, "HABILIDADE:$skillId") }
                                                    .onFailure { message = "Habilidade não sincronizada: ${it.localizedMessage}" }
                                            }
                                        } else {
                                            combat = CombatSystem.playerUseSkill(state, skillId)
                                        }
                                    },
                                    onSpecial = {
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) {
                                            scope.launch {
                                                runCatching { allyBattleRepository.executarAcao(battleId, uid, "ESPECIAL") }
                                                    .onFailure { message = "Especial não sincronizado: ${it.localizedMessage}" }
                                            }
                                        } else combat = CombatSystem.playerSpecial(state)
                                    },
                                    onContinueCharge = {
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) scope.launch {
                                            runCatching { allyBattleRepository.executarAcao(battleId, uid, "CONTINUAR_CARREGAMENTO") }
                                                .onFailure { message = "Carregamento não sincronizado: ${it.localizedMessage}" }
                                        } else combat = CombatSystem.playerContinueCharge(state)
                                    },
                                    onReleaseCharged = {
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) scope.launch {
                                            runCatching { allyBattleRepository.executarAcao(battleId, uid, "LIBERAR_CARREGAMENTO") }
                                                .onFailure { message = "Ataque carregado não sincronizado: ${it.localizedMessage}" }
                                        } else combat = CombatSystem.playerReleaseChargedSkill(state)
                                    },

                                    onAttack = {
                                        observePowerAction(
                                            action = "Realizou um ataque físico",
                                            category = "fisico",
                                            intensity = 10
                                        )
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) {
                                            scope.launch {
                                                runCatching { allyBattleRepository.executarAcao(battleId, uid, "ATACAR") }
                                                    .onFailure { message = "Ação não sincronizada: ${it.localizedMessage}" }
                                            }
                                        } else {
                                            combat = CombatSystem.playerAttack(state)
                                        }
                                    },

                                    onDefend = {
                                        observePowerAction(
                                            action = "Realizou uma defesa em combate",
                                            category = "defesa",
                                            intensity = 10
                                        )
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) {
                                            scope.launch {
                                                runCatching { allyBattleRepository.executarAcao(battleId, uid, "DEFENDER") }
                                                    .onFailure { message = "Ação não sincronizada: ${it.localizedMessage}" }
                                            }
                                        } else {
                                            val updatedCombat = CombatSystem.playerDefend(state)
                                            combat = updatedCombat
                                            hero = updatedCombat.hero
                                        }
                                    },

                                    onEnemyTurn = {
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (battleId != null && uid != null) {
                                            scope.launch {
                                                runCatching { allyBattleRepository.executarAcao(battleId, uid, "INIMIGO") }
                                                    .onFailure { message = "Turno do inimigo não sincronizado: ${it.localizedMessage}" }
                                            }
                                        } else {
                                            val updated = CombatSystem.enemyAttack(state)
                                            combat = updated
                                            hero = updated.hero
                                        }
                                    },

                                    onEndCombat = {
                                        val snapshot = allyBattleSnapshot
                                        val battleId = allyBattleId
                                        val uid = uidAtual
                                        if (snapshot?.status == "FINISHED" && battleId != null && uid != null) {
                                            scope.launch {
                                                val podeReceber = runCatching {
                                                    allyBattleRepository.reivindicarRecompensa(battleId, uid)
                                                }.getOrElse {
                                                    message = "Não foi possível registrar a recompensa: ${it.localizedMessage}"
                                                    false
                                                }
                                                if (podeReceber) {
                                                    if (criaturaBatalhaCompartilhada == null && snapshot.creatureId.isNotBlank()) {
                                                        criaturaBatalhaCompartilhada = runCatching {
                                                            RepositorioCriaturas.buscarCriatura(snapshot.creatureId)
                                                        }.getOrNull()
                                                    }
                                                    finalizarCombate(state)
                                                } else {
                                                    message = "As recompensas desta batalha já foram recebidas."
                                                    combat = null
                                                    estadoMundo = TransicaoMundo.finalizarCombate(estadoMundo)
                                                }
                                            }
                                        } else {
                                            finalizarCombate(state)
                                        }
                                    }
                                )
                            }
                        }
                    )
                }

                // MULTIPLAYER
                page == 1 -> Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                        .verticalScroll(rememberScrollState()),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {

                    Text(
                        "MULTIPLAYER",
                        style = MaterialTheme.typography.titleLarge
                    )

                    Text(
                        "Ally: forme um grupo cooperativo de até 4 jogadores no mundo aberto. Campanhas continuam separadas."
                    )

                    allyGroup?.let { group ->
                        Card(modifier = Modifier.fillMaxWidth()) {
                            Column(
                                modifier = Modifier.padding(12.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Text("GRUPO ALLY (${group.members.size}/4)", style = MaterialTheme.typography.titleMedium)
                                val batalhaFinalizada = allyBattleSnapshot?.status == "FINISHED"
                                val todosReivindicaram = batalhaFinalizada && allyBattleSnapshot?.claimedUids?.containsAll(
                                    allyBattleSnapshot?.members?.map { it.uid }.orEmpty()
                                ) == true
                                val podeGerenciarGrupo = group.activeBattleId.isBlank() || todosReivindicaram
                                group.members.forEach { memberUid ->
                                    val presence = allyMemberPresences.firstOrNull { it.uid == memberUid }
                                    val memberName = group.memberNames[memberUid] ?: presence?.nome ?: "Aventureiro"
                                    Text(
                                        buildString {
                                            append(if (memberUid == group.leaderUid) "Líder: " else "Integrante: ")
                                            append(memberName)
                                            if (presence != null) {
                                                append(" · Nv. ${presence.nivel}")
                                                if (presence.vidaMaxima > 0) append(" · Vida ${presence.vida}/${presence.vidaMaxima}")
                                            } else {
                                                append(" · Offline")
                                            }
                                        }
                                    )
                                    if (podeGerenciarGrupo && group.leaderUid == uidAtual && memberUid != uidAtual) {
                                        TextButton(onClick = {
                                            scope.launch {
                                                runCatching {
                                                    allyRepository.removerMembro(uidAtual!!, memberUid)
                                                }.onSuccess { message = "$memberName removido do grupo." }
                                                    .onFailure { message = "Não foi possível remover: ${it.localizedMessage}" }
                                            }
                                        }) { Text("Remover") }
                                    }
                                }
                                val jaEstaNaBatalha = allyBattleSnapshot?.members?.any { it.uid == uidAtual } == true
                                if (group.activeBattleId.isNotBlank() && allyBattleSnapshot?.status == "ACTIVE" && !jaEstaNaBatalha) {
                                    Button(onClick = {
                                        scope.launch {
                                            runCatching {
                                                allyBattleRepository.entrarNaBatalha(group.activeBattleId, uidAtual ?: error("Sessão inválida."))
                                            }.onSuccess { message = "Você entrou na batalha compartilhada." }
                                                .onFailure { message = "Não foi possível entrar: ${it.localizedMessage}" }
                                        }
                                    }, modifier = Modifier.fillMaxWidth()) {
                                        Text("ENTRAR NO COMBATE")
                                    }
                                }
                                if (group.activeBattleId.isNotBlank() && allyBattleSnapshot?.status == "ACTIVE" && jaEstaNaBatalha) {
                                    Text("Batalha em andamento · ${allyBattleSnapshot?.state?.enemy?.name ?: "Criatura"}")
                                } else if (batalhaFinalizada) {
                                    val total = allyBattleSnapshot?.members?.size ?: 0
                                    val retiradas = allyBattleSnapshot?.claimedUids?.size ?: 0
                                    Text("Último combate concluído · Recompensas retiradas: $retiradas/$total")
                                }
                                if (podeGerenciarGrupo) TextButton(onClick = {
                                    scope.launch {
                                        runCatching {
                                            allyRepository.sairDoGrupo(group.id, uidAtual ?: error("Sessão inválida."))
                                        }.onSuccess {
                                            allyGroupId = null
                                            allyGroup = null
                                            allyMemberPresences = emptyList()
                                            message = if (group.leaderUid == uidAtual) "Grupo encerrado." else "Você saiu do grupo."
                                        }.onFailure { message = "Não foi possível sair: ${it.localizedMessage}" }
                                    }
                                }) { Text(if (group.leaderUid == uidAtual) "Encerrar grupo" else "Sair do grupo") }
                            }
                        }
                    }

                    GuildaPanel(uid = uidAtual.orEmpty(), nomeJogador = profile.name) { message = it }

                    MultiplayerExpandidoPanel(
                        uid = uidAtual.orEmpty(),
                        aoAtualizarPersonagem = {
                            scope.launch {
                                runCatching { CharacterProfileRepository().getForCurrentUser() }
                                    .onSuccess { characterProfile = it }
                                    .onFailure { message = "Recompensa registrada, mas não foi possível atualizar a ficha: ${it.localizedMessage}" }
                            }
                        }
                    ) { message = it }

                    if (allyInvites.isNotEmpty()) {
                        Text("CONVITES PARA ALLY", style = MaterialTheme.typography.titleMedium)
                        allyInvites.forEach { allyInvite ->
                            Card(modifier = Modifier.fillMaxWidth()) {
                                Column(modifier = Modifier.padding(10.dp)) {
                                    Text("${allyInvite.senderName} convidou você para um grupo.")
                                    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                                        Button(onClick = {
                                            scope.launch {
                                                runCatching {
                                                    allyRepository.aceitarConvite(allyInvite.id, uidAtual ?: error("Sessão inválida."), profile.name)
                                                    allyGroupId = allyRepository.obterGrupoId(uidAtual!!)
                                                }.onSuccess { message = "Você entrou no grupo Ally!" }
                                                    .onFailure { message = "Não foi possível aceitar: ${it.localizedMessage}" }
                                            }
                                        }) { Text("Aceitar") }
                                        TextButton(onClick = {
                                            scope.launch {
                                                runCatching {
                                                    allyRepository.recusarConvite(allyInvite.id, uidAtual ?: error("Sessão inválida."))
                                                }.onSuccess { message = "Convite recusado." }
                                                    .onFailure { message = "Não foi possível recusar: ${it.localizedMessage}" }
                                            }
                                        }) { Text("Recusar") }
                                    }
                                }
                            }
                        }
                    }

                    Text("TROCAS", style = MaterialTheme.typography.titleMedium)
                    Text("Negocie itens, materiais, equipamentos e ovos. XP e companheiros já eclodidos não podem ser trocados.")
                    minhasTrocas.filter { it.status == "PENDENTE" || it.status == "CONCLUIDA" }.forEach { troca ->
                        val uid = uidAtual.orEmpty()
                        val minhaOferta = troca.ofertas[uid] as? Map<*, *> ?: emptyMap<Any, Any>()
                        val outraOferta = troca.ofertas[if (uid == troca.remetenteUid) troca.destinatarioUid else troca.remetenteUid] as? Map<*, *> ?: emptyMap<Any, Any>()
                        Card(modifier = Modifier.fillMaxWidth()) {
                            Column(modifier = Modifier.padding(10.dp), verticalArrangement = Arrangement.spacedBy(6.dp)) {
                                Text(if (uid == troca.remetenteUid) "Troca enviada" else "Troca recebida", style = MaterialTheme.typography.titleSmall)
                                Text("Status: ${if (troca.status == "CONCLUIDA") "Concluída" else "Aguardando confirmações"}")
                                Text("Sua oferta: ${(minhaOferta["itens"] as? List<*>)?.size ?: 0} tipo(s) de item, ${(minhaOferta["ovos"] as? List<*>)?.size ?: 0} ovo(s), ${(minhaOferta["equipamentos"] as? List<*>)?.size ?: 0} equipamento(s)")
                                Text("Oferta do outro jogador: ${(outraOferta["itens"] as? List<*>)?.size ?: 0} tipo(s) de item, ${(outraOferta["ovos"] as? List<*>)?.size ?: 0} ovo(s), ${(outraOferta["equipamentos"] as? List<*>)?.size ?: 0} equipamento(s)")
                                if (troca.status == "PENDENTE") {
                                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                                        TextButton(onClick = {
                                            trocaParaEditar = troca.id
                                            itensSelecionadosTroca = emptySet(); ovosSelecionadosTroca = emptySet(); equipamentosSelecionadosTroca = emptySet()
                                            mostrarEditorTroca = true
                                        }) { Text("Montar minha oferta") }
                                        Button(enabled = uid !in troca.aceitoPor, onClick = { scope.launch { runCatching { tradeRepository.aceitar(troca.id) }.onSuccess { message = "Confirmação registrada. A troca será concluída quando ambos aceitarem." }.onFailure { message = "Não foi possível confirmar: ${it.localizedMessage}" } } }) { Text("Confirmar") }
                                    }
                                    TextButton(onClick = { scope.launch { runCatching { tradeRepository.cancelar(troca.id) }.onSuccess { message = "Troca cancelada." }.onFailure { message = "Não foi possível cancelar: ${it.localizedMessage}" } } }) { Text("Cancelar troca") }
                                }
                            }
                        }
                    }

                    Text("CAMPANHAS", style = MaterialTheme.typography.titleMedium)

                    Button(
                        onClick = {

                            scope.launch {
                                try {
                                    val auth = FirebaseAuth.getInstance()

                                    val user = auth.currentUser
                                        ?: auth.signInAnonymously().await().user

                                    if (user == null) {
                                        error("Autenticação falhou.")
                                    }

                                    val db = FirebaseFirestore.getInstance()

                                    val id = db.collection("campaigns")
                                        .document().id

                                    val inviteCode = (1..6)
                                        .map { ('A'..'Z').random() }
                                        .joinToString("")

                                    // Campanha e convite nascem juntos: não existe campanha
                                    // com código que ainda não tenha um documento de convite.
                                    val batch = db.batch()

                                    val campaignRef = db.collection("campaigns")
                                        .document(id)

                                    val inviteRef = db.collection("campaignInvites")
                                        .document(inviteCode)

                                    batch.set(
                                        campaignRef,
                                        mapOf(
                                            "ownerUid" to user.uid,
                                            "inviteCode" to inviteCode,
                                            "name" to "Campanha de ${profile.name}",
                                            "visibility" to "private",
                                            "members" to listOf(user.uid),
                                            "createdAt" to System.currentTimeMillis()
                                        )
                                    )

                                    batch.set(
                                        inviteRef,
                                        mapOf(
                                            "campaignId" to id,
                                            "inviteCode" to inviteCode,
                                            "ownerUid" to user.uid,
                                            "active" to true,
                                            "createdAt" to System.currentTimeMillis()
                                        )
                                    )

                                    batch.commit().await()

                                    invite = inviteCode
                                    message =
                                        "Campanha criada! Código: $inviteCode"

                                } catch (e: Exception) {
                                    message =
                                        "Erro online: ${e.localizedMessage}"
                                }
                            }
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("CRIAR CAMPANHA")
                    }

                    if (invite.isNotBlank()) {
                        Text("Código de convite: $invite")
                    }

                    OutlinedTextField(
                        value = code,
                        onValueChange = {
                            code = it
                        },
                        label = {
                            Text("Código do amigo")
                        },
                        modifier = Modifier.fillMaxWidth()
                    )

                    Button(
                        onClick = {

                            scope.launch {
                                try {
                                    val auth = FirebaseAuth.getInstance()

                                    val user = auth.currentUser
                                        ?: auth.signInAnonymously().await().user

                                    if (user == null) {
                                        error("Autenticação falhou.")
                                    }

                                    val db = FirebaseFirestore.getInstance()

                                    val inviteCode = code.trim().uppercase()
                                    if (inviteCode.length != 6 || inviteCode.any { !it.isLetterOrDigit() }) {
                                        error("Digite um código válido de 6 caracteres.")
                                    }

                                    // O convite é lido diretamente pelo código. Não fazemos
                                    // consulta/listagem da coleção campaigns, que é bloqueada.
                                    val inviteSnapshot = db.collection("campaignInvites")
                                        .document(inviteCode)
                                        .get()
                                        .await()

                                    if (!inviteSnapshot.exists() ||
                                        inviteSnapshot.getBoolean("active") != true
                                    ) {
                                        error("Código não encontrado ou convite desativado.")
                                    }

                                    val campaignId = inviteSnapshot.getString("campaignId")
                                        ?: error("Convite inválido: campanha não identificada.")

                                    // A prova do convite e a inclusão do membro são gravadas
                                    // em um único lote atômico, validado pelas regras Firestore.
                                    val batch = db.batch()
                                    val campaignRef = db.collection("campaigns")
                                        .document(campaignId)
                                    val joinProofRef = db.collection("campaignInvites")
                                        .document(inviteCode)
                                        .collection("joins")
                                        .document(user.uid)

                                    batch.set(
                                        joinProofRef,
                                        mapOf(
                                            "userUid" to user.uid,
                                            "campaignId" to campaignId,
                                            "inviteCode" to inviteCode,
                                            "joinedAt" to System.currentTimeMillis()
                                        )
                                    )

                                    batch.update(
                                        campaignRef,
                                        "members",
                                        com.google.firebase.firestore.FieldValue
                                            .arrayUnion(user.uid)
                                    )

                                    batch.commit().await()

                                    code = ""
                                    message = "Você entrou na campanha!"

                                } catch (e: Exception) {
                                    message =
                                        "Erro ao entrar: ${e.localizedMessage}"
                                }
                            }
                        },
                        modifier = Modifier.fillMaxWidth()
                    ) {
                        Text("ENTRAR NA CAMPANHA")
                    }
                }

                // MUNDO ABERTO
                page == 2 -> Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .weight(1f)
                ) {

                    if (showWorldMap) {

                        TelaMapaMundi(
                            localAtualId = profile.currentWorldPointId,

                            aoSelecionarDestino = { plan ->

                                pendingTravelPlan = plan
                                message = "Registrando viagem..."

                                scope.launch {
                                    try {
                                        val currentProfile =
                                            characterProfile ?: profile

                                        val updatedProfile =
                                            currentProfile.copy(
                                                currentWorldPointId =
                                                    plan.destination.id,
                                                inventory = playerInventory
                                            )

                                        saveMutex.withLock {
                                            CharacterProfileRepository().save(
                                                updatedProfile
                                            )
                                        }

                                        characterProfile = updatedProfile
                                        pendingTravelPlan = null
                                        showWorldMap = false

                                        message =
                                            "Você chegou a ${plan.destination.name}!"

                                    } catch (e: Exception) {
                                        message =
                                            "Não foi possível salvar a viagem: ${e.localizedMessage}"
                                    }
                                }
                            },

                            aoVoltar = {
                                showWorldMap = false
                            },

                            modifier = Modifier.fillMaxSize()
                        )

                        if (worldDaylightFactor < 1f) {
                            Box(
                                modifier = Modifier
                                    .fillMaxSize()
                                    .background(
                                        androidx.compose.ui.graphics.Color(0xFF07152D)
                                            .copy(alpha = (1f - worldDaylightFactor) * 0.34f)
                                    )
                            )
                        }

                        if (worldSyncMessage.isNotBlank()) {
                            Text(
                                text = worldSyncMessage,
                                modifier = Modifier.align(androidx.compose.ui.Alignment.TopCenter),
                                color = MaterialTheme.colorScheme.tertiary,
                                style = MaterialTheme.typography.labelSmall
                            )
                        }

                    } else {

                        TelaMundo(
                            estado = estadoMundo,
                            aoAtualizarEstado = {
                                estadoMundo = it
                            },
                            companheiro = InventorySystem.obterCompanheiroAtivo(
                                playerInventory
                            ),
                            modifier = Modifier.fillMaxSize(),
                            uidJogador = FirebaseAuth.getInstance().currentUser?.uid,
                            nomeJogador = characterProfile?.name ?: "Aventureiro",
                            nivelJogador = characterProfile?.level ?: 1,
                            vidaJogador = hero.hp,
                            vidaMaximaJogador = hero.maxHp,
                            ataqueJogador = hero.attack,
                            defesaJogador = hero.defense,
                            manaJogador = hero.mana,
                            manaMaximaJogador = hero.maxMana,
                            agilidadeJogador = hero.agility,
                            poderMagicoJogador = hero.magicPower,
                            worldPointId = characterProfile?.currentWorldPointId ?: "clareira_inicial",
                            aoSelecionarJogador = { selectedPlayerForAlly = it }
                        )

                        Card(
                            modifier = Modifier
                                .align(androidx.compose.ui.Alignment.TopCenter)
                                .fillMaxWidth()
                                .padding(8.dp)
                        ) {

                            Column(
                                modifier = Modifier.padding(10.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp)
                            ) {

                                Button(
                                    onClick = {
                                        showWorldMap = true
                                    },
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Text("ABRIR MAPA-MÚNDI")
                                }

                                Text(
                                    "MUNDO ABERTO",
                                    style = MaterialTheme.typography.titleMedium
                                )

                                Text("Região: ${selectedRegion.name}")
                                Text("Escolha uma região:")

                                ExplorationSystem.regions.forEach { region ->

                                    Button(
                                        onClick = {
                                            selectedRegion = region
                                            encounter = null

                                            estadoMundo =
                                                TransicaoMundo.entrarNaExploracao(
                                                    estadoMundo
                                                )
                                        },
                                        modifier = Modifier.fillMaxWidth()
                                    ) {
                                        Text(
                                            "${region.name} — Rank ${region.rank}"
                                        )
                                    }
                                }

                                Button(
                                    onClick = {

                                        estadoMundo =
                                            TransicaoMundo.entrarNaExploracao(
                                                estadoMundo
                                            )

                                        scope.launch {
                                            try {
                                                encounter =
                                                    ExplorationSystem.explore(
                                                        selectedRegion
                                                    )

                                                val criaturaEncontrada =
                                                    encounter?.criatura

                                                val uidJogador =
                                                    FirebaseAuth.getInstance()
                                                        .currentUser?.uid

                                                if (
                                                    criaturaEncontrada != null &&
                                                    uidJogador != null
                                                ) {
                                                    try {
                                                        RepositorioCriaturas.registrarDescoberta(
                                                            uid = uidJogador,
                                                            criatura = criaturaEncontrada
                                                        )

                                                        message =
                                                            "Exploração concluída. Criatura registrada no bestiário!"

                                                    } catch (e: Exception) {
                                                        message =
                                                            "Criatura encontrada, mas não foi possível salvar no bestiário: ${e.localizedMessage}"
                                                    }

                                                } else {
                                                    message =
                                                        "Exploração concluída."
                                                }

                                            } catch (e: Exception) {
                                                message =
                                                    "Erro ao explorar região: ${e.localizedMessage}"
                                            }
                                        }
                                    },
                                    modifier = Modifier.fillMaxWidth()
                                ) {
                                    Text("EXPLORAR REGIÃO")
                                }

                                encounter?.let { result ->

                                    Text(result.message)

                                    Text(
                                        "Evento: ${result.worldEvent?.title ?: "Nenhum"}"
                                    )

                                    Text(
                                        "Criatura: ${result.criatura?.nome ?: "Nenhuma"}"
                                    )

                                    Text(
                                        "Chefe: ${if (result.isBoss) "Sim" else "Não"}"
                                    )

                                    result.criatura?.let { criatura ->

                                        Button(
                                            onClick = {

                                                iniciarCombateComCriatura(criatura)
                                            },
                                            modifier = Modifier.fillMaxWidth()
                                        ) {
                                            Text("ENFRENTAR CRIATURA")
                                        }
                                    }

                                    result.enemyId
                                        ?.takeIf { result.criatura == null }
                                        ?.let { enemyId ->
                                            Button(
                                                onClick = {
                                                    scope.launch {
                                                        try {
                                                            val criatura =
                                                                RepositorioCriaturas.buscarCriatura(enemyId)

                                                            if (criatura == null) {
                                                                message = "A criatura não está mais disponível no bestiário global."
                                                            } else {
                                                                iniciarCombateComCriatura(criatura)
                                                            }
                                                        } catch (e: Exception) {
                                                            message = "Não foi possível carregar a criatura: ${e.localizedMessage}"
                                                        }
                                                    }
                                                },
                                                modifier = Modifier.fillMaxWidth()
                                            ) {
                                                Text("ENFRENTAR CRIATURA")
                                            }
                                        }
                                }
                            }
                        }
                    }
                }

                else -> {
                    Text("Selecione uma tela.")
                }
            }
        }

        selectedPlayerForAlly?.let { jogador ->
            AlertDialog(
                onDismissRequest = { selectedPlayerForAlly = null },
                title = { Text(jogador.nome) },
                text = { Text("Nível ${jogador.nivel}. Deseja convidar este jogador para seu grupo Ally?") },
                confirmButton = {
                    Column {
                        TextButton(onClick = {
                            selectedPlayerForAlly = null
                            scope.launch {
                                runCatching {
                                    allyRepository.enviarConvite(
                                        senderUid = uidAtual ?: error("Sessão inválida."),
                                        senderName = profile.name,
                                        receiverUid = jogador.uid
                                    )
                                }.onSuccess {
                                    allyGroupId = allyRepository.obterGrupoId(uidAtual!!)
                                    message = "Convite enviado para ${jogador.nome}."
                                }.onFailure { message = "Não foi possível convidar: ${it.localizedMessage}" }
                            }
                        }) { Text("Convidar para Ally") }
                        TextButton(onClick = {
                            selectedPlayerForAlly = null
                            scope.launch {
                                runCatching { tradeRepository.criarTroca(jogador.uid) }
                                    .onSuccess { message = "Proposta de troca enviada para ${jogador.nome}. Abra a seção TROCAS para montar sua oferta." }
                                    .onFailure { message = "Não foi possível iniciar a troca: ${it.localizedMessage}" }
                            }
                        }) { Text("Propor troca") }
                    }
                },
                dismissButton = {
                    TextButton(onClick = { selectedPlayerForAlly = null }) { Text("Cancelar") }
                }
            )
        }

        if (mostrarEditorTroca && trocaParaEditar != null) {
            AlertDialog(
                onDismissRequest = { mostrarEditorTroca = false },
                title = { Text("Montar oferta") },
                text = {
                    Column(modifier = Modifier.heightIn(max = 420.dp).verticalScroll(rememberScrollState()), verticalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text("Itens e materiais")
                        playerInventory.items.forEach { item ->
                            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                Checkbox(checked = item.id in itensSelecionadosTroca, onCheckedChange = { checked -> itensSelecionadosTroca = if (checked) itensSelecionadosTroca + item.id else itensSelecionadosTroca - item.id })
                                Text("${item.name} (x${item.quantity})")
                            }
                        }
                        Text("Ovos")
                        playerInventory.eggs.forEach { egg ->
                            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                Checkbox(checked = egg.id in ovosSelecionadosTroca, onCheckedChange = { checked -> ovosSelecionadosTroca = if (checked) ovosSelecionadosTroca + egg.id else ovosSelecionadosTroca - egg.id })
                                Text("${egg.species} · Rank ${egg.rank} · ${egg.mutationName}")
                            }
                        }
                        Text("Equipamentos")
                        playerInventory.equipment.forEach { equipment ->
                            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                Checkbox(checked = equipment.id in equipamentosSelecionadosTroca, onCheckedChange = { checked -> equipamentosSelecionadosTroca = if (checked) equipamentosSelecionadosTroca + equipment.id else equipamentosSelecionadosTroca - equipment.id })
                                Text(equipment.name)
                            }
                        }
                        Text("XP e companheiros eclodidos não aparecem nesta lista e não podem ser negociados.", style = MaterialTheme.typography.bodySmall)
                    }
                },
                confirmButton = {
                    TextButton(onClick = {
                        val tradeId = trocaParaEditar!!
                        val oferta = OfertaTroca(
                            itens = playerInventory.items.filter { it.id in itensSelecionadosTroca }.map { mapOf("id" to it.id, "quantidade" to it.quantity) },
                            ovos = ovosSelecionadosTroca.toList(),
                            equipamentos = equipamentosSelecionadosTroca.toList()
                        )
                        mostrarEditorTroca = false
                        scope.launch {
                            runCatching { tradeRepository.enviarOferta(tradeId, oferta) }
                                .onSuccess { message = "Sua oferta foi enviada. Agora os dois jogadores precisam confirmar." }
                                .onFailure { message = "Não foi possível enviar a oferta: ${it.localizedMessage}" }
                        }
                    }) { Text("Enviar oferta") }
                },
                dismissButton = { TextButton(onClick = { mostrarEditorTroca = false }) { Text("Voltar") } }
            )
        }
    }
}
