
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
import androidx.compose.ui.platform.LocalContext

import coil.compose.AsyncImage
import androidx.compose.ui.layout.ContentScale
import br.com.ascensaodosoberano.world.CriaturaGerada
import br.com.ascensaodosoberano.world.RepositorioCriaturas
import br.com.ascensaodosoberano.world.TelaMapaMundi
import br.com.ascensaodosoberano.world.WorldTravelPlan
import br.com.ascensaodosoberano.world.WorldMapData
import br.com.ascensaodosoberano.world.WorldRegion
import br.com.ascensaodosoberano.world.WorldSceneCatalog
import br.com.ascensaodosoberano.world.WorldPointType
import br.com.ascensaodosoberano.world.WorldApi
import br.com.ascensaodosoberano.world.CreatureGlobalStats
import br.com.ascensaodosoberano.world.WorldClockApi
import br.com.ascensaodosoberano.world.WorldCycleSystem

import br.com.ascensaodosoberano.exploration.TelaMundo
import br.com.ascensaodosoberano.exploration.ExplorationSystem
import br.com.ascensaodosoberano.exploration.StoryMasterApi
import br.com.ascensaodosoberano.exploration.StoryScene
import br.com.ascensaodosoberano.exploration.StoryCampaignStore
import br.com.ascensaodosoberano.exploration.StoryCampaignMemory
import br.com.ascensaodosoberano.exploration.ExplorationEncounter
import br.com.ascensaodosoberano.exploration.EstadoCenaMundo
import br.com.ascensaodosoberano.exploration.ModoCenaMundo
import br.com.ascensaodosoberano.exploration.TransicaoMundo
import br.com.ascensaodosoberano.exploration.MovementDirection
import br.com.ascensaodosoberano.exploration.WorldPosition
import br.com.ascensaodosoberano.multiplayer.AllyRepository
import br.com.ascensaodosoberano.multiplayer.AllyGroup
import br.com.ascensaodosoberano.multiplayer.AllyStoryRepository
import br.com.ascensaodosoberano.multiplayer.AllyStorySnapshot
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
import br.com.ascensaodosoberano.companions.CurandeiroPanel
import br.com.ascensaodosoberano.companions.OvoCompanheiroPixelArt
import br.com.ascensaodosoberano.companions.MaterialPixelArt
import br.com.ascensaodosoberano.companions.EquipamentoPixelArt
import br.com.ascensaodosoberano.companions.ImagemCompanheiro

import br.com.ascensaodosoberano.character.CharacterProfile
import br.com.ascensaodosoberano.character.CharacterCreationScreen
import br.com.ascensaodosoberano.character.CharacterProfileRepository
import br.com.ascensaodosoberano.character.CharacterLocalStore
import br.com.ascensaodosoberano.character.ProgressionSystem

import br.com.ascensaodosoberano.combat.CombatState
import br.com.ascensaodosoberano.combat.CombatPhase
import br.com.ascensaodosoberano.combat.CombatFactory
import br.com.ascensaodosoberano.combat.CombatSystem
import br.com.ascensaodosoberano.combat.CharacterCombatFactory
import br.com.ascensaodosoberano.combat.TelaCombate
import br.com.ascensaodosoberano.combat.MonsterLootSystem
import br.com.ascensaodosoberano.combat.RewardDistributionSystem
import br.com.ascensaodosoberano.combat.CombatParticipants
import br.com.ascensaodosoberano.combat.PlayerContribution

import com.google.firebase.FirebaseApp
import com.google.firebase.auth.FirebaseAuth
import com.google.firebase.firestore.FirebaseFirestore

import kotlinx.coroutines.launch
import kotlinx.coroutines.delay
import kotlinx.coroutines.tasks.await
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.math.sqrt

class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)

        runCatching {
            FirebaseApp.initializeApp(this)
        }

        setContent {
            MaterialTheme(
                colorScheme = androidx.compose.material3.darkColorScheme(
                    primary = androidx.compose.ui.graphics.Color(0xFFE8BD72),
                    onPrimary = androidx.compose.ui.graphics.Color(0xFF21170A),
                    secondary = androidx.compose.ui.graphics.Color(0xFF9B82C8),
                    background = androidx.compose.ui.graphics.Color(0xFF101722),
                    onBackground = androidx.compose.ui.graphics.Color(0xFFE7ECF4),
                    surface = androidx.compose.ui.graphics.Color(0xFF1B2534),
                    onSurface = androidx.compose.ui.graphics.Color(0xFFE7ECF4),
                    surfaceVariant = androidx.compose.ui.graphics.Color(0xFF293548),
                    onSurfaceVariant = androidx.compose.ui.graphics.Color(0xFFC3CDDA),
                    primaryContainer = androidx.compose.ui.graphics.Color(0xFF4C3A27),
                    onPrimaryContainer = androidx.compose.ui.graphics.Color(0xFFFFE8C1),
                    secondaryContainer = androidx.compose.ui.graphics.Color(0xFF342C48),
                    onSecondaryContainer = androidx.compose.ui.graphics.Color(0xFFE8DCFF)
                )
            ) {
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
fun GameApp(abrirMultiplayerInicial: Boolean = false, modoOffline: Boolean = false) {

    val scope = rememberCoroutineScope()
    val contextoLocal = LocalContext.current
    val armazenamentoLocal = remember(contextoLocal) { CharacterLocalStore(contextoLocal) }
    val armazenamentoHistoria = remember(contextoLocal) { StoryCampaignStore(contextoLocal) }
    var modoOfflineAtivo by remember { mutableStateOf(modoOffline) }

    // Impede que gravações diferentes sobrescrevam umas às outras.
    val saveMutex = remember {
        Mutex()
    }

    var page by remember {
        mutableStateOf(2)
    }
    var painelMundo by remember { mutableStateOf(if (abrirMultiplayerInicial) "MULTIPLAYER" else null) }

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
    var indiceTrechoRota by remember { mutableIntStateOf(0) }
    var progressoTrechoRota by remember { mutableFloatStateOf(0f) }

    var message by remember {
        mutableStateOf("Bem-vindo ao Ascensão do Soberano!")
    }

    var verificandoEncontro by remember { mutableStateOf(false) }
    var encounter by remember { mutableStateOf<ExplorationEncounter?>(null) }

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
    var codigoEntradaMundo by remember { mutableStateOf("") }

    val allyRepository = remember { AllyRepository() }
    val allyStoryRepository = remember { AllyStoryRepository() }
    var allyStorySnapshot by remember { mutableStateOf<AllyStorySnapshot?>(null) }
    var historiaIA by remember { mutableStateOf<StoryScene?>(null) }
    var memoriaCampanha by remember { mutableStateOf(StoryCampaignMemory()) }
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
    var estatisticasGlobaisBestiario by remember {
        mutableStateOf<Map<String, CreatureGlobalStats>>(emptyMap())
    }
    var tokenEncontroAtual by remember { mutableStateOf("") }
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
            if (modoOfflineAtivo) {
                characterProfile = armazenamentoLocal.load()
                contaVisitante = false
                message = if (characterProfile == null) {
                    "Crie seu personagem. O progresso será salvo neste aparelho."
                } else {
                    "Modo offline: personagem carregado do aparelho."
                }
            } else {
                val auth = FirebaseAuth.getInstance()
                if (auth.currentUser == null) auth.signInAnonymously().await()
                val uid = auth.currentUser?.uid
                    ?: throw IllegalStateException("Não foi possível identificar a conta.")
                val repository = CharacterProfileRepository()
                // Nunca associe automaticamente um perfil local sem proprietário
                // a uma nova sessão anônima ou a outra conta.
                val registroLocal = armazenamentoLocal.loadRecord(uid)
                val perfilRemoto = repository.getForCurrentUser()

                if (registroLocal != null &&
                    registroLocal.pendingCloudSync &&
                    registroLocal.ownerUid == uid &&
                    perfilRemoto == null
                ) {
                    repository.save(registroLocal.profile)
                    armazenamentoLocal.markCloudSynced(registroLocal.profile.id, uid)
                    characterProfile = registroLocal.profile
                    message = "Progresso offline sincronizado com sua conta."
                } else if (perfilRemoto != null) {
                    characterProfile = perfilRemoto
                    if (registroLocal == null ||
                        (!registroLocal.pendingCloudSync && registroLocal.ownerUid == uid)
                    ) {
                        armazenamentoLocal.save(perfilRemoto, uid, false)
                    } else if (registroLocal.ownerUid == null && registroLocal.pendingCloudSync) {
                        message = "Sua conta já possui personagem. O progresso offline foi preservado neste aparelho e não foi sobrescrito."
                    }
                } else if (registroLocal != null && registroLocal.ownerUid == uid) {
                    repository.save(registroLocal.profile)
                    armazenamentoLocal.markCloudSynced(registroLocal.profile.id, uid)
                    characterProfile = registroLocal.profile
                }
                contaVisitante = auth.currentUser?.isAnonymous == true
            }
        } catch (e: Exception) {
            // Em falha de rede, só é seguro recuperar o cache pertencente ao UID
            // autenticado. O cache legado/desvinculado permanece preservado,
            // mas não pode pular a criação de personagem de outra conta.
            if (!modoOfflineAtivo) {
                val uid = FirebaseAuth.getInstance().currentUser?.uid
                characterProfile = uid?.let {
                    armazenamentoLocal.loadRecord(it)?.profile
                }
            }
            if (characterProfile != null) modoOfflineAtivo = true
            message = if (characterProfile != null) {
                "Não foi possível sincronizar agora. O personagem local foi carregado: ${e.localizedMessage}"
            } else {
                "Erro ao carregar personagem: ${e.localizedMessage}"
            }
        } finally {
            loadingCharacter = false
        }
    }

    LaunchedEffect(page, painelMundo) {
        if (!modoOfflineAtivo && (page == 3 || painelMundo == "BESTIARIO")) {
            carregandoBestiario = true

            try {
                val uid = FirebaseAuth.getInstance()
                    .currentUser?.uid

                if (uid != null) {
                    val criaturasDescobertas = RepositorioCriaturas.buscarBestiario(uid)
                    bestiario = criaturasDescobertas
                    estatisticasGlobaisBestiario =
                        WorldApi.buscarEstatisticasGlobaisEmLote(
                            criaturasDescobertas.map { it.id }
                        )
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
                    if (modoOfflineAtivo) {
                        throw IllegalStateException(
                            "Conecte-se à internet para a IA analisar seu conceito e criar suas habilidades iniciais."
                        )
                    }

                    val auth = FirebaseAuth.getInstance()
                    val user = auth.currentUser
                        ?: auth.signInAnonymously().await().user
                        ?: throw IllegalStateException("Não foi possível autenticar o jogador.")
                    val uid = user.uid

                    // A IA interpreta o conceito completo e devolve classe/afinidades
                    // analisadas e quatro habilidades iniciais exclusivas.
                    val perfilComHabilidades =
                        CharacterSkillGenerationApi.generate(createdProfile)

                    // Primeiro preserva o resultado localmente; depois tenta sincronizar.
                    saveMutex.withLock {
                        armazenamentoLocal.save(perfilComHabilidades, uid, true)
                    }
                    characterProfile = perfilComHabilidades
                    creationError = ""

                    var sincronizado = false
                    try {
                        saveMutex.withLock {
                            CharacterProfileRepository().save(perfilComHabilidades)
                            armazenamentoLocal.markCloudSynced(perfilComHabilidades.id, uid)
                        }
                        sincronizado = true
                        message = "Personagem criado com quatro habilidades exclusivas e salvo na nuvem!"
                    } catch (syncError: Exception) {
                        modoOfflineAtivo = true
                        message = "Personagem e habilidades salvos neste aparelho. A sincronização será tentada quando a conexão voltar."
                    }

                    // A arte é uma etapa separada: uma falha visual não apaga
                    // nem desfaz as habilidades já geradas e salvas.
                    if (sincronizado) {
                        gerandoImagemPersonagem = true
                        erroImagemPersonagem = ""
                        try {
                            val perfilComImagem = saveMutex.withLock {
                                br.com.ascensaodosoberano.character.CharacterVisualGenerationRunner()
                                    .generate(perfilComHabilidades)
                            }
                            characterProfile = perfilComImagem
                            armazenamentoLocal.save(perfilComImagem, uid, true)
                            armazenamentoLocal.markCloudSynced(perfilComImagem.id, uid)
                            message = "Personagem criado, habilidades geradas e imagem visual concluída!"
                        } catch (visualError: Exception) {
                            erroImagemPersonagem = visualError.localizedMessage
                                ?: "Não foi possível gerar a imagem agora."
                            message = "Personagem e habilidades salvos. A imagem poderá ser tentada novamente."
                        } finally {
                            gerandoImagemPersonagem = false
                        }
                    }
                }
            )
        }

        return
    }

    val profile = characterProfile!!
    val uidAtual = FirebaseAuth.getInstance().currentUser?.uid

    LaunchedEffect(profile.id) {
        memoriaCampanha = armazenamentoHistoria.load(profile.id)
        val salvo = memoriaCampanha
        if (salvo.previousScene.isNotBlank()) {
            historiaIA = StoryScene(
                chapterTitle = salvo.chapterTitle,
                sceneTitle = "Último acontecimento",
                narrativeText = salvo.previousScene,
                choices = emptyList(),
                eventType = "NARRATIVE",
                questTitle = "",
                questObjective = "",
                questLocationHint = "",
                encounterHint = "NONE",
                memorySummary = salvo.memorySummary
            )
        }
    }

    fun solicitarCenaHistoria(acao: String) {
        if (modoOfflineAtivo) {
            message = "O Mestre de História precisa de internet. Seu último capítulo continua salvo neste aparelho."
            return
        }
        if (verificandoEncontro) return
        val uid = uidAtual
        val grupo = allyGroup
        if (grupo != null && grupo.members.size > 1 && uid != grupo.leaderUid) {
            message = "A aventura compartilhada é conduzida pelo líder. Registre sua escolha para o grupo."
            return
        }
        verificandoEncontro = true
        scope.launch {
            try {
                val pointId = profile.currentWorldPointId.ifBlank { "clareira_inicial" }
                val region = ExplorationSystem.regionForWorldPoint(pointId)
                val local = WorldMapData.findPoint(pointId)?.name ?: "Terras desconhecidas"
                val party = grupo?.memberNames?.values?.toList().orEmpty().filter { it != profile.name }
                val cena = StoryMasterApi.advance(
                    characterName = profile.name,
                    level = profile.level,
                    location = local,
                    region = region?.name ?: "Região selvagem",
                    action = acao.ifBlank { "Continue a campanha a partir do último acontecimento, com uma nova cena jogável." },
                    memorySummary = memoriaCampanha.memorySummary,
                    previousScene = allyStorySnapshot?.narrativeText ?: memoriaCampanha.previousScene,
                    party = party,
                    campaignId = allyGroupId ?: profile.id
                )
                historiaIA = cena
                if (region != null && cena.encounterHint != "NONE") {
                    val encontroDaHistoria = ExplorationSystem.explore(
                        region = region,
                        forcarEncontro = cena.encounterHint != "BOSS",
                        permitirGeracaoRemota = true,
                        forcarChefe = cena.encounterHint == "BOSS"
                    )
                    encounter = encontroDaHistoria
                    if (encontroDaHistoria.criatura != null) {
                        message = encontroDaHistoria.message
                    }
                }
                armazenamentoHistoria.save(profile.id, cena, cena.narrativeText)
                memoriaCampanha = StoryCampaignMemory(
                    chapterTitle = cena.chapterTitle,
                    memorySummary = cena.memorySummary,
                    previousScene = cena.narrativeText,
                    revision = memoriaCampanha.revision + 1L
                )
                if (grupo != null && uid == grupo.leaderUid) {
                    allyStoryRepository.publicarAcontecimento(
                        groupId = grupo.id,
                        leaderUid = uid,
                        chapterTitle = cena.chapterTitle + " — " + cena.sceneTitle,
                        narrativeText = cena.narrativeText,
                        eventType = cena.eventType,
                        choices = cena.choices
                    )
                }
                message = when (cena.encounterHint) {
                    "BOSS" -> "A história revelou uma ameaça de chefe. Investigue a pista da missão antes de avançar."
                    "ELITE" -> "A história aponta para uma ameaça poderosa nesta região."
                    "COMMON" -> "Há sinais de uma criatura nas proximidades. Você pode explorar a região."
                    else -> "A campanha avançou. Suas decisões serão consideradas nas próximas cenas."
                }
            } catch (erro: Exception) {
                message = erro.localizedMessage ?: "Não foi possível avançar a história."
            } finally {
                verificandoEncontro = false
            }
        }
    }

    LaunchedEffect(uidAtual) {
        allyGroupId = if (!modoOfflineAtivo) uidAtual?.let { uid ->
            runCatching { allyRepository.obterGrupoId(uid) }.getOrNull()
        } else null
    }

    LaunchedEffect(uidAtual, profile.currentWorldPointId, modoOfflineAtivo) {
        if (uidAtual != null && !modoOfflineAtivo) {
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

    LaunchedEffect(uidAtual, modoOfflineAtivo) {
        if (uidAtual != null && !modoOfflineAtivo) {
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

    LaunchedEffect(showWorldMap, uidAtual, modoOfflineAtivo) {
        if (showWorldMap && uidAtual != null && !modoOfflineAtivo) {
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
                .onFailure { erro ->
                    val detalhe = erro.localizedMessage
                        ?.replace("\n", " ")
                        ?.take(120)
                        ?.takeIf { it.isNotBlank() }
                    worldSyncMessage = if (detalhe == null) {
                        "Não foi possível sincronizar o mundo. Verifique a conexão e tente novamente."
                    } else {
                        "Falha ao sincronizar o mundo: $detalhe"
                    }
                }
        }
    }

    DisposableEffect(uidAtual, modoOfflineAtivo) {
        val listener = if (!modoOfflineAtivo) uidAtual?.let { uid ->
            allyRepository.observarConvites(uid) { allyInvites = it }
        } else null
        onDispose { listener?.remove() }
    }

    DisposableEffect(uidAtual, modoOfflineAtivo) {
        val listener = if (!modoOfflineAtivo) uidAtual?.let { uid ->
            tradeRepository.observarMinhasTrocas(uid) { minhasTrocas = it }
        } else null
        onDispose { listener?.remove() }
    }

    DisposableEffect(allyGroupId, modoOfflineAtivo) {
        allyBattleSnapshot = null
        allyBattleId = null
        val groupListener = if (!modoOfflineAtivo) allyGroupId?.let { id ->
            allyRepository.observarGrupo(id) { group ->
                allyGroup = group
                if (group == null || uidAtual !in group.members) {
                    allyGroupId = null
                    allyGroup = null
                    allyMemberPresences = emptyList()
                }
            }
        } else null
        onDispose {
            groupListener?.remove()
        }
    }

    DisposableEffect(allyGroupId, modoOfflineAtivo) {
        allyStorySnapshot = null
        val listener = if (!modoOfflineAtivo) allyGroupId?.let { id ->
            allyStoryRepository.observarHistoria(id) { allyStorySnapshot = it }
        } else null
        onDispose { listener?.remove() }
    }

    DisposableEffect(allyGroup?.members, modoOfflineAtivo) {
        val listener = if (!modoOfflineAtivo) allyGroup?.members?.let { members ->
            br.com.ascensaodosoberano.multiplayer.PresenceRepository()
                .observarPresencasDosJogadores(members) { allyMemberPresences = it }
        } else null
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
        erro: String,
        allyBattleIdParaReivindicar: String? = null,
        onSuccess: (() -> Unit)? = null,
        onFailure: (() -> Unit)? = null
    ) {
        val profileAnterior = characterProfile ?: profile
        val perfilComStatus = updatedProfile.copy(
            currentHp = hero.hp,
            currentMana = hero.mana
        )
        if (allyBattleIdParaReivindicar == null) characterProfile = perfilComStatus

        scope.launch {
            try {
                saveMutex.withLock {
                    val repository = CharacterProfileRepository()
                    if (allyBattleIdParaReivindicar != null) {
                        val uid = uidAtual
                            ?: throw IllegalStateException("Usuário não autenticado.")
                        val confirmado = repository.saveAndClaimAllyBattleReward(
                            profile = perfilComStatus,
                            battleId = allyBattleIdParaReivindicar,
                            uid = uid
                        )
                        check(confirmado) { "Esta recompensa já foi retirada nesta conta." }
                        armazenamentoLocal.save(perfilComStatus, uid, false)
                    } else if (modoOfflineAtivo) {
                        armazenamentoLocal.save(perfilComStatus, uidAtual ?: armazenamentoLocal.loadRecord()?.ownerUid, true)
                    } else {
                        // Primeiro grava no aparelho; se a rede cair, o progresso fica pendente.
                        armazenamentoLocal.save(perfilComStatus, uidAtual ?: armazenamentoLocal.loadRecord()?.ownerUid, true)
                        repository.save(perfilComStatus)
                        uidAtual?.let { armazenamentoLocal.markCloudSynced(perfilComStatus.id, it) }
                    }
                }
                characterProfile = perfilComStatus
                onSuccess?.invoke()
            } catch (e: Exception) {
                if (allyBattleIdParaReivindicar != null) {
                    val perfilRestaurado = runCatching {
                        CharacterProfileRepository().getForCurrentUser()
                    }.getOrNull() ?: profileAnterior
                    characterProfile = perfilRestaurado
                    playerInventory = perfilRestaurado.inventory
                    hero = CharacterCombatFactory.createHero(perfilRestaurado)
                    powerProfile = perfilRestaurado.powerProfile
                    onFailure?.invoke()
                    message = "${erro}: ${e.localizedMessage}"
                } else if (modoOfflineAtivo) {
                    message = "Não foi possível salvar offline: ${e.localizedMessage}"
                } else {
                    // Não descarta progresso: a cópia local permanece pendente para sincronização.
                    characterProfile = perfilComStatus
                    message = "Progresso guardado no aparelho; aguardando sincronização: ${e.localizedMessage}"
                }
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

    fun alternarEquipamento(equipment: br.com.ascensaodosoberano.companions.Equipment) {
        val currentProfile = characterProfile ?: profile
        val currentLoadout = currentProfile.equipmentLoadout
        val updatedLoadout: br.com.ascensaodosoberano.companions.EquipmentLoadout
        if (currentLoadout.contains(equipment.id)) {
            updatedLoadout = br.com.ascensaodosoberano.character.EquipmentSystem.retirar(
                currentLoadout,
                equipment.id
            )
            message = "${equipment.name} retirado."
        } else {
            val result = br.com.ascensaodosoberano.character.EquipmentSystem.equipar(
                loadout = currentLoadout,
                equipment = equipment,
                characterClass = currentProfile.characterClass,
                characterLevel = currentProfile.level,
                inventoryEquipment = playerInventory.equipment
            )
            if (!result.success) {
                message = result.message
                return
            }
            updatedLoadout = result.loadout
            message = result.message
        }

        val updatedProfile = currentProfile.copy(
            inventory = playerInventory,
            equipmentLoadout = updatedLoadout
        )
        salvarPerfil(updatedProfile, "Erro ao salvar equipamento")
        val heroUpdated = CharacterCombatFactory.createHero(updatedProfile)
        hero = heroUpdated.copy(
            hp = hero.hp.coerceAtMost(heroUpdated.maxHp),
            mana = hero.mana.coerceAtMost(heroUpdated.maxMana)
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
    var ultimaPersistenciaPosicaoMs by remember { mutableStateOf(0L) }

    LaunchedEffect(characterProfile?.id) {
        val perfilCarregado = characterProfile ?: return@LaunchedEffect
        estadoMundo = estadoMundo.copy(
            posicaoNoMapa = WorldPosition(perfilCarregado.worldX, perfilCarregado.worldY)
        )
    }

    LaunchedEffect(characterProfile?.currentWorldPointId) {
        val pontoAtual = characterProfile?.currentWorldPointId
            ?.takeIf { it.isNotBlank() } ?: "clareira_inicial"
        selectedRegion = ExplorationSystem.regionForWorldPoint(pontoAtual) ?: selectedRegion
    }

    var direcaoMovimento by remember {
        mutableStateOf(MovementDirection())
    }

    var distanciaDesdeEncontro by remember { mutableStateOf(0f) }
    var ultimoTesteEncontroMs by remember { mutableStateOf(System.currentTimeMillis()) }

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

    // Se o dono do turno ficar offline, os aliados conectados tentam
    // recuperar a batalha após o prazo; a regra do Firestore valida o tempo no servidor.
    LaunchedEffect(
        allyBattleSnapshot?.id,
        allyBattleSnapshot?.revision,
        allyBattleSnapshot?.status,
        allyBattleSnapshot?.state?.phase,
        uidAtual
    ) {
        val snapshot = allyBattleSnapshot
        val uid = uidAtual
        if (snapshot != null &&
            snapshot.status == "ACTIVE" &&
            !uid.isNullOrBlank() &&
            snapshot.members.any { it.uid == uid }
        ) {
            delay(65_000L)
            // Se a conexão cair no primeiro pedido, tenta novamente até a batalha mudar.
            while (
                allyBattleSnapshot?.id == snapshot.id &&
                allyBattleSnapshot?.revision == snapshot.revision &&
                allyBattleSnapshot?.status == "ACTIVE"
            ) {
                val recuperado = runCatching {
                    allyBattleRepository.recuperarTurnoInativo(snapshot.id, uid)
                }.getOrDefault(false)
                if (recuperado) break
                delay(15_000L)
            }
        }
    }

    var combateFinalizado by remember(profile.id) {
        mutableStateOf(false)
    }

    LaunchedEffect(allyBattleSnapshot?.creatureId) {
        val creatureId = allyBattleSnapshot?.creatureId
        criaturaBatalhaCompartilhada = if (!creatureId.isNullOrBlank()) {
            runCatching { RepositorioCriaturas.buscarCriaturaComImagem(creatureId) }.getOrNull()
        } else null
    }

    fun registrarAvistamentoCriatura(criatura: CriaturaGerada) {
        if (modoOfflineAtivo) return
        val uid = uidAtual ?: return
        scope.launch {
            if (bestiario.none { it.id == criatura.id }) {
                runCatching {
                    RepositorioCriaturas.registrarDescoberta(uid, criatura)
                }.onSuccess {
                    if (bestiario.none { it.id == criatura.id }) {
                        bestiario = bestiario + criatura
                    }
                }
            }
            // Mesmo uma criatura já conhecida precisa emitir um novo token de encontro.
            runCatching {
                WorldApi.registrarEncontroGlobal(
                    criatura.id,
                    characterProfile?.name ?: profile.name,
                    gerarTokenSolo = allyGroup?.members?.size?.let { it <= 1 } ?: true
                )
            }.onSuccess { estatisticas ->
                tokenEncontroAtual = estatisticas.encounterToken
                estatisticasGlobaisBestiario =
                    estatisticasGlobaisBestiario + (criatura.id to estatisticas)
            }
        }
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

    fun finalizarCombate(state: CombatState, battleIdParaRecompensa: String? = null) {

        if (combateFinalizado) return

        combateFinalizado = true

        fun encerrarTelaCombate() {
            combat = null
            estadoMundo = TransicaoMundo.finalizarCombate(estadoMundo)
            encounter = null
            allyBattleSnapshot = null
            allyBattleId = null
            message = pendingLevelMessage
        }

        if (state.phase == CombatPhase.VICTORY) {

            val currentProfile =
                characterProfile ?: profile

            val criaturaDerrotada =
                encounter?.criatura ?: criaturaBatalhaCompartilhada

            val batalhaCompartilhada = allyBattleSnapshot?.takeIf { it.status == "FINISHED" }
            if (batalhaCompartilhada == null && allyBattleId == null && tokenEncontroAtual.isNotBlank()) {
                val token = tokenEncontroAtual
                tokenEncontroAtual = ""
                scope.launch {
                    runCatching { WorldApi.registrarDerrotaSolo(token, (state.enemy.maxHp - state.enemy.hp).coerceAtLeast(0)) }
                        .onSuccess {
                            val criaturaId = criaturaDerrotada?.id
                            if (!criaturaId.isNullOrBlank()) {
                                runCatching { WorldApi.buscarEstatisticasGlobais(criaturaId) }
                                    .onSuccess { estatisticas ->
                                        estatisticasGlobaisBestiario =
                                            estatisticasGlobaisBestiario + (criaturaId to estatisticas)
                                    }
                            }
                        }
                        .onFailure {
                            message = "Vitória concluída. O registro global individual será sincronizado quando possível."
                        }
                }
            }
            val meuCombatente = batalhaCompartilhada?.members?.firstOrNull { it.uid == uidAtual }
            val participaDaBatalha = batalhaCompartilhada == null || meuCombatente != null
            val heroiLocalFinal = meuCombatente?.hero ?: state.hero
            val xpRecebido = if (batalhaCompartilhada != null) {
                val contribuicoes = batalhaCompartilhada.members.map { membro ->
                    PlayerContribution(
                        playerId = membro.uid,
                        playerName = membro.name,
                        damageDealt = membro.damageDealt
                    )
                }
                RewardDistributionSystem.distribute(
                    participants = CombatParticipants(contribuicoes),
                    totalXp = state.xpGained
                ).firstOrNull { it.playerId == uidAtual }?.xp ?: 0
            } else {
                state.xpGained.coerceAtLeast(0)
            }

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
                        playerXp = xpRecebido
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
                    xpRecebido
                )

            val progressedProfile =
                progression.profile.copy(
                    inventory = inventarioAtualizado
                )

            salvarPerfil(
                progressedProfile,
                "Erro ao salvar progresso",
                allyBattleIdParaReivindicar = battleIdParaRecompensa,
                onSuccess = {
                    if (battleIdParaRecompensa != null) {
                        if (!batalhaCompartilhada?.creatureId.isNullOrBlank()) {
                            scope.launch {
                                runCatching {
                                    WorldApi.registrarDerrotaGlobal(battleIdParaRecompensa)
                                }.onSuccess {
                                    runCatching {
                                        WorldApi.buscarEstatisticasGlobais(batalhaCompartilhada!!.creatureId)
                                    }.onSuccess { estatisticas ->
                                        estatisticasGlobaisBestiario =
                                            estatisticasGlobaisBestiario + (batalhaCompartilhada!!.creatureId to estatisticas)
                                    }
                                }.onFailure {
                                    message = "Recompensas salvas. O registro global será sincronizado quando o servidor estiver disponível."
                                }
                            }
                        }
                        encerrarTelaCombate()
                    }
                },
                onFailure = {
                    // Permite tentar encerrar/retirar a recompensa novamente após falha de rede.
                    combateFinalizado = false
                }
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
                    "XP recebido: $xpRecebido"
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
            val grupoDerrotado = allyBattleSnapshot?.takeIf { it.status == "FINISHED" }
                ?.let { batalha -> batalha.members.isNotEmpty() && batalha.members.all { !it.hero.isAlive } }
                ?: false
            val batalhaCooperativa = allyBattleId != null || allyBattleSnapshot != null
            // Em grupo, a queda de um integrante não aplica penalidade nem encerra
            // a batalha enquanto ainda houver companheiros vivos.
            val sofreuDerrota = ProgressionSystem.shouldApplyDefeatPenalty(
                cooperativeBattle = batalhaCooperativa,
                allPartyMembersDefeated = grupoDerrotado,
                soloPlayerDefeated = state.phase == CombatPhase.DEFEAT
            )
            pendingLevelMessage = ""

            if (sofreuDerrota) {
                val perfilAtual = characterProfile ?: profile
                val penalidade = ProgressionSystem.applyDefeatPenalty(
                    perfilAtual.copy(inventory = playerInventory)
                )
                val perfilRenascido = penalidade.profile
                playerInventory = perfilRenascido.inventory
                if (battleIdParaRecompensa == null) characterProfile = perfilRenascido
                hero = CharacterCombatFactory.createHero(perfilRenascido)
                estadoMundo = estadoMundo.copy(
                    posicaoNoMapa = WorldPosition(perfilRenascido.worldX, perfilRenascido.worldY)
                )
                pendingLevelMessage = buildString {
                    append("Você foi derrotado e renasceu em ${perfilRenascido.currentWorldPointId}. ")
                    append("Perdeu 50% do XP acumulado e 20% do ouro.")
                    if (penalidade.levelsLost > 0) append(" Níveis perdidos: ${penalidade.levelsLost}.")
                }
                salvarPerfil(
                    perfilRenascido,
                    "Erro ao salvar o renascimento",
                    allyBattleIdParaReivindicar = battleIdParaRecompensa,
                    onSuccess = { encerrarTelaCombate() },
                    onFailure = { combateFinalizado = false }
                )
                return
            }

            hero = heroiLocal
            pendingLevelMessage = if (state.phase == CombatPhase.ENEMY_ESCAPED) {
                "O inimigo fugiu. Você não recebeu recompensas nem sofreu penalidade."
            } else ""

            if (battleIdParaRecompensa != null) {
                // Fuga ou encerramento sem derrota não concede saque, mas registra a conclusão.
                salvarPerfil(
                    characterProfile ?: profile,
                    "Erro ao registrar o resultado da batalha",
                    allyBattleIdParaReivindicar = battleIdParaRecompensa,
                    onSuccess = { encerrarTelaCombate() },
                    onFailure = { combateFinalizado = false }
                )
                return
            }
        }

        // Em batalhas Ally, a tela só fecha depois que o Firestore confirma
        // a gravação do perfil e a retirada/baixa da recompensa.
        if (battleIdParaRecompensa == null) {
            encerrarTelaCombate()
        }
    }

    Scaffold(
        containerColor = androidx.compose.ui.graphics.Color(0xFF101722),
        topBar = {},
        bottomBar = {}

    ) { padding ->

        Column(
            modifier = if (combat != null) {
                Modifier.fillMaxSize()
            } else if (page == 2) {
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
                                    val estatisticasGlobais = estatisticasGlobaisBestiario[criatura.id]

                                    Row(
                                        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(10.dp)
                                    ) {
                                        if (criatura.imagemIconeCaminho.startsWith("https://") ||
                                            criatura.imagemIconeCaminho.startsWith("http://")) {
                                            AsyncImage(
                                                model = criatura.imagemIconeCaminho,
                                                contentDescription = "Imagem de ${criatura.nome}",
                                                modifier = Modifier.size(76.dp),
                                                contentScale = ContentScale.Fit
                                            )
                                        } else {
                                            br.com.ascensaodosoberano.combat.CriaturaPixelArt(
                                                nome = criatura.nome,
                                                rank = criatura.rank,
                                                chefe = criatura.chefe,
                                                modifier = Modifier.size(76.dp)
                                            )
                                        }
                                        Column {
                                            if (estatisticasGlobais != null) {
                                                Text("Derrotas globais: ${estatisticasGlobais.totalDefeats}", style = MaterialTheme.typography.bodySmall)
                                                Text("Primeiro descobridor: ${estatisticasGlobais.firstDiscovererName.ifBlank { "Ainda não registrado" }}", style = MaterialTheme.typography.bodySmall)
                                                if (estatisticasGlobais.firstDiscoveryAt > 0L) {
                                                    Text("Descoberta em: ${java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale("pt", "BR")).format(java.util.Date(estatisticasGlobais.firstDiscoveryAt))}", style = MaterialTheme.typography.bodySmall)
                                                }
                                            } else {
                                                Text("Estatísticas globais indisponíveis", style = MaterialTheme.typography.bodySmall)
                                            }
                                            Text(criatura.nome, style = MaterialTheme.typography.titleMedium)
                                            Text("Rank: ${criatura.rank} • Nível: ${criatura.nivel}")
                                            if (criatura.chefe) Text("CHEFE", color = MaterialTheme.colorScheme.error)
                                        }
                                    }

                                    if (estatisticasGlobais != null) {
                                        Text("Jogadores que encontraram: ${estatisticasGlobais.totalPlayersEncountered}")
                                        if (estatisticasGlobais.firstDefeaterName.isNotBlank()) {
                                            Text("Primeiro a derrotar: ${estatisticasGlobais.firstDefeaterName}")
                                        }
                                        if (estatisticasGlobais.firstDefeatAt > 0L) {
                                            Text("Primeira derrota: ${java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale("pt", "BR")).format(java.util.Date(estatisticasGlobais.firstDefeatAt))}")
                                        }
                                        if (estatisticasGlobais.highestDamageName.isNotBlank()) {
                                            Text("Maior dano: ${estatisticasGlobais.highestDamageName} (${estatisticasGlobais.highestDamage})")
                                        }
                                        if (estatisticasGlobais.mostDefeatsName.isNotBlank()) {
                                            Text("Mais derrotas: ${estatisticasGlobais.mostDefeatsName} (${estatisticasGlobais.mostDefeatsCount})")
                                        }
                                    }
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
                            appearance = profile.appearance,
                            equippedEquipment = br.com.ascensaodosoberano.character.EquipmentSystem.equipmentForVisuals(
                                (characterProfile ?: profile).equipmentLoadout,
                                playerInventory.equipment
                            ),
                            equipmentLoadout = (characterProfile ?: profile).equipmentLoadout
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
                        br.com.ascensaodosoberano.character.PainelStatusPersonagem(
                            profile = profile,
                            hero = hero,
                            gold = playerInventory.gold,
                            xpProgress = xpProgress,
                            nextLevelXp = nextLevelXp,
                            onAllocateAttribute = { attribute -> allocateAttribute(attribute) }
                        )
                    }

                    // ITENS E MATERIAIS
                    item {
                        Text("ITENS E MATERIAIS", style = MaterialTheme.typography.titleMedium)
                    }
                    if (playerInventory.items.isEmpty()) {
                        item { Text("Sua bolsa ainda está vazia.") }
                    } else {
                        items(items = playerInventory.items, key = { it.id }) { item ->
                            Card(Modifier.fillMaxWidth()) {
                                Row(
                                    modifier = Modifier.padding(10.dp),
                                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                                ) {
                                    MaterialPixelArt(
                                        tipo = item.name,
                                        rank = item.materialRank,
                                        modifier = Modifier.size(54.dp)
                                    )
                                    Column {
                                        Text(item.name, style = MaterialTheme.typography.titleSmall)
                                        Text("Quantidade: ${item.quantity} · Rank: ${item.materialRank}", style = MaterialTheme.typography.bodySmall)
                                        if (item.materialOrigin.isNotBlank()) Text("Origem: ${item.materialOrigin}", style = MaterialTheme.typography.bodySmall)
                                    }
                                }
                            }
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

                                    Row(
                                        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                                    ) {
                                        if (ovo.imagemIconeCaminho.isNotBlank()) {
                                            ImagemCompanheiro(
                                                caminho = ovo.imagemIconeCaminho,
                                                modifier = Modifier.size(76.dp),
                                                especie = ovo.species,
                                                rank = ovo.rank
                                            )
                                        } else {
                                            OvoCompanheiroPixelArt(
                                                rank = ovo.rank,
                                                mutacao = ovo.mutationRarity,
                                                modifier = Modifier.size(76.dp)
                                            )
                                        }
                                        Column(verticalArrangement = Arrangement.spacedBy(3.dp)) {
                                            Text(ovo.species, style = MaterialTheme.typography.titleMedium)
                                            Text("Ovo de companheiro · Rank ${ovo.rank}")
                                        }
                                    }

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

                    // EQUIPAMENTOS
                    item {
                        Text("EQUIPAMENTOS", style = MaterialTheme.typography.titleMedium)
                    }
                    if (playerInventory.equipment.isEmpty()) {
                        item { Text("Você ainda não possui equipamentos.") }
                    } else {
                        items(items = playerInventory.equipment, key = { it.id }) { equipamento ->
                            Card(Modifier.fillMaxWidth()) {
                                Row(
                                    modifier = Modifier.padding(10.dp),
                                    verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                                    horizontalArrangement = Arrangement.spacedBy(10.dp)
                                ) {
                                    EquipamentoPixelArt(
                                        tipo = equipamento.type,
                                        raridade = equipamento.rarity.name,
                                        modifier = Modifier.size(64.dp)
                                    )
                                    Column {
                                        Text(equipamento.name, style = MaterialTheme.typography.titleSmall)
                                        val tipoEquipamentoPt = when (equipamento.type) {
                                            br.com.ascensaodosoberano.companions.EquipmentType.WEAPON -> "Arma"
                                            br.com.ascensaodosoberano.companions.EquipmentType.ARMOR -> "Armadura"
                                            br.com.ascensaodosoberano.companions.EquipmentType.HELMET -> "Elmo"
                                            br.com.ascensaodosoberano.companions.EquipmentType.BOOTS -> "Botas"
                                            br.com.ascensaodosoberano.companions.EquipmentType.GLOVES -> "Luvas"
                                            br.com.ascensaodosoberano.companions.EquipmentType.RING -> "Anel"
                                            br.com.ascensaodosoberano.companions.EquipmentType.NECKLACE -> "Colar"
                                            br.com.ascensaodosoberano.companions.EquipmentType.SHIELD -> "Escudo"
                                        }
                                        val raridadeEquipamentoPt =
                                            br.com.ascensaodosoberano.companions.RarityVisuals.label(equipamento.rarity.name)
                                        Text("$tipoEquipamentoPt · Rank ${equipamento.rank} · $raridadeEquipamentoPt", style = MaterialTheme.typography.bodySmall)
                                        Text(equipamento.description, style = MaterialTheme.typography.bodySmall)
                                        val estaEquipado = (characterProfile ?: profile)
                                            .equipmentLoadout.contains(equipamento.id)
                                        Text(
                                            if (estaEquipado) "Vestido" else "No inventário",
                                            color = if (estaEquipado) MaterialTheme.colorScheme.tertiary else MaterialTheme.colorScheme.onSurfaceVariant,
                                            style = MaterialTheme.typography.labelSmall
                                        )
                                        Button(
                                            onClick = { alternarEquipamento(equipamento) },
                                            modifier = Modifier.padding(top = 4.dp)
                                        ) {
                                            Text(if (estaEquipado) "Retirar" else "Equipar")
                                        }
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

                                    Row(
                                        verticalAlignment = androidx.compose.ui.Alignment.CenterVertically,
                                        horizontalArrangement = Arrangement.spacedBy(12.dp)
                                    ) {
                                        if (companion.imagemSpriteCaminho.isNotBlank()) {
                                            ImagemCompanheiro(
                                                caminho = companion.imagemSpriteCaminho,
                                                modifier = Modifier.size(88.dp),
                                                especie = companion.species,
                                                rank = companion.rank,
                                                mutacao = companion.mutationId,
                                                estagio = companion.stage
                                            )
                                        } else {
                                            br.com.ascensaodosoberano.companions.CompanionPixelArt(
                                                especie = companion.species,
                                                rank = companion.rank,
                                                modifier = Modifier.size(88.dp),
                                                mutacao = companion.mutationId,
                                                estagio = companion.stage
                                            )
                                        }
                                        Column {
                                            Text("${companion.name} — Rank ${companion.rank}", style = MaterialTheme.typography.titleMedium)
                                            Text("Nível ${companion.level} · ${companion.stage}")
                                        }
                                    }

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
                        worldPointId = characterProfile?.currentWorldPointId?.takeIf { it.isNotBlank() } ?: "clareira_inicial",
                        imagemPersonagemUrl = characterProfile?.appearance?.generatedImageUrl.orEmpty(),
                        skinId = characterProfile?.appearance?.skinId ?: "pele_02",
                        hairId = characterProfile?.appearance?.hairId ?: "cabelo_01",
                        hairColorId = characterProfile?.appearance?.hairColorId ?: "castanho",
                        eyeId = characterProfile?.appearance?.eyeId ?: "olhos_01",
                        outfitId = characterProfile?.appearance?.outfitId ?: "roupa_inicial_01",
                        equipamentosVestidos = br.com.ascensaodosoberano.character.EquipmentSystem.equipmentForVisuals(
                            (characterProfile ?: profile).equipmentLoadout,
                            playerInventory.equipment
                        ),
                        espacosEquipamento = (characterProfile ?: profile).equipmentLoadout,
                        daylightFactor = worldDaylightFactor,
                        aoSelecionarJogador = { selectedPlayerForAlly = it },
                        conteudoCombate = { areaCombate ->

                            combat?.let { state ->
                                val membroLocalDaBatalha = allyBattleSnapshot
                                    ?.members
                                    ?.firstOrNull { it.uid == uidAtual }
                                val estadoVisual = if (
                                    allyBattleId != null &&
                                    allyBattleSnapshot?.status == "ACTIVE" &&
                                    allyBattleSnapshot?.activePlayerUid != uidAtual &&
                                    membroLocalDaBatalha != null
                                ) {
                                    state.copy(
                                        hero = membroLocalDaBatalha.hero,
                                        especialCarga = membroLocalDaBatalha.specialCharge,
                                        especialUsado = membroLocalDaBatalha.specialUsed,
                                        recargasJogador = membroLocalDaBatalha.skillCooldowns,
                                        turnosAtordoadoJogador = membroLocalDaBatalha.playerStun,
                                        carregandoHabilidadeJogador = membroLocalDaBatalha.chargingSkill,
                                        turnosRestantesCarregamentoJogador = membroLocalDaBatalha.chargeTurns,
                                        quebraAtaqueCarregadoJogador = membroLocalDaBatalha.chargeBreak,
                                        quebraAtaqueCarregadoMaximaJogador = membroLocalDaBatalha.chargeBreakMax,
                                        playerDefending = false,
                                        defenseReduction = 0,
                                        playerVulnerable = false,
                                        pendingEffectsOnHero = emptyList()
                                    )
                                } else {
                                    state
                                }

                                TelaCombate(
                                    state = estadoVisual,

                                    companion = InventorySystem.obterCompanheiroAtivo(
                                        playerInventory
                                    ),

                                    imagemHeroiUrl = characterProfile?.appearance?.generatedImageUrl.orEmpty(),
                                    skinId = characterProfile?.appearance?.skinId ?: "pele_02",
                                    hairId = characterProfile?.appearance?.hairId ?: "cabelo_01",
                                    hairColorId = characterProfile?.appearance?.hairColorId ?: "castanho",
                                    outfitId = characterProfile?.appearance?.outfitId ?: "roupa_inicial_01",
                        equipamentosVestidos = br.com.ascensaodosoberano.character.EquipmentSystem.equipmentForVisuals(
                            (characterProfile ?: profile).equipmentLoadout,
                            playerInventory.equipment
                        ),
                        espacosEquipamento = (characterProfile ?: profile).equipmentLoadout,
                                    eyeId = characterProfile?.appearance?.eyeId ?: "olhos_01",
                                    modifier = areaCombate,
                                    integradoAoMapa = false,
                                    podeAgir = allyBattleId == null || allyBattleSnapshot?.activePlayerUid == uidAtual,
                                    nomeJogadorDoTurno = allyBattleSnapshot?.members?.firstOrNull { it.uid == allyBattleSnapshot?.activePlayerUid }?.name.orEmpty(),
                                    nomesGrupo = allyBattleSnapshot?.members?.map { "${it.name} (${it.role})" }.orEmpty(),
                                    membrosCombate = allyBattleSnapshot?.members?.map { membro ->
                                        br.com.ascensaodosoberano.combat.CombatAllyVisual(
                                            uid = membro.uid,
                                            name = membro.name,
                                            hp = membro.hero.hp,
                                            maxHp = membro.hero.maxHp,
                                            mana = membro.hero.mana,
                                            maxMana = membro.hero.maxMana,
                                            imageUrl = membro.imageUrl,
                                            isActive = membro.uid == allyBattleSnapshot?.activePlayerUid
                                        )
                                    }.orEmpty(),
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
                                                if (criaturaBatalhaCompartilhada == null && snapshot.creatureId.isNotBlank()) {
                                                    criaturaBatalhaCompartilhada = runCatching {
                                                        RepositorioCriaturas.buscarCriaturaComImagem(snapshot.creatureId)
                                                    }.getOrNull()
                                                }
                                                finalizarCombate(state, battleId)
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
                page == 1 && modoOfflineAtivo -> Column(
                    modifier = Modifier.fillMaxWidth().weight(1f).padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(10.dp)
                ) {
                    Text("MODO OFFLINE", style = MaterialTheme.typography.titleLarge)
                    Text("Você está jogando sozinho. O personagem, os atributos e o inventário são salvos neste aparelho. Para entrar no multiplayer, volte ao menu e escolha o modo conectado.")
                }

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
                        "Crie ou entre em um mundo compartilhado de até 3 jogadores usando um código de entrada. Cada jogador mantém seu próprio personagem e progresso."
                    )

                    if (allyGroup == null) {
                        Card(modifier = Modifier.fillMaxWidth()) {
                            Column(Modifier.padding(12.dp), verticalArrangement = Arrangement.spacedBy(8.dp)) {
                                Text("MUNDO MULTIPLAYER", style = MaterialTheme.typography.titleMedium)
                                Text("Crie um mundo e compartilhe o código com até dois amigos. Todos entram com seus próprios personagens, equipamentos e atributos.")
                                Button(
                                    enabled = uidAtual != null,
                                    onClick = {
                                        scope.launch {
                                            runCatching {
                                                allyRepository.criarMundo(uidAtual ?: error("Sessão inválida."), profile.name)
                                            }.onSuccess { codigo ->
                                                allyGroupId = uidAtual
                                                message = "Mundo criado! Código de entrada: $codigo"
                                            }.onFailure { message = "Não foi possível criar o mundo: ${it.localizedMessage}" }
                                        }
                                    },
                                    modifier = Modifier.fillMaxWidth()
                                ) { Text("CRIAR MUNDO MULTIPLAYER") }
                                OutlinedTextField(
                                    value = codigoEntradaMundo,
                                    onValueChange = { codigoEntradaMundo = it.filter(Char::isDigit).take(6) },
                                    label = { Text("Código do mundo (6 números)") },
                                    modifier = Modifier.fillMaxWidth(),
                                    singleLine = true
                                )
                                OutlinedButton(
                                    enabled = codigoEntradaMundo.length == 6 && uidAtual != null,
                                    onClick = {
                                        scope.launch {
                                            runCatching {
                                                allyRepository.entrarPorCodigo(
                                                    uidAtual ?: error("Sessão inválida."),
                                                    profile.name,
                                                    codigoEntradaMundo
                                                )
                                            }.onSuccess { groupId ->
                                                allyGroupId = groupId
                                                codigoEntradaMundo = ""
                                                message = "Você entrou no mundo multiplayer! Seu personagem e seus equipamentos foram mantidos."
                                            }.onFailure { message = "Não foi possível entrar: ${it.localizedMessage}" }
                                        }
                                    },
                                    modifier = Modifier.fillMaxWidth()
                                ) { Text("ENTRAR NO MUNDO") }
                            }
                        }
                    }

                    allyGroup?.let { group ->
                        Card(modifier = Modifier.fillMaxWidth()) {
                            Column(
                                modifier = Modifier.padding(12.dp),
                                verticalArrangement = Arrangement.spacedBy(6.dp)
                            ) {
                                Text("MUNDO MULTIPLAYER (${group.members.size}/3)", style = MaterialTheme.typography.titleMedium)
                                if (group.inviteCode.isNotBlank()) Text("CÓDIGO DE ENTRADA: ${group.inviteCode}", color = MaterialTheme.colorScheme.primary, style = MaterialTheme.typography.titleMedium)
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
                            regiaoDisponivel = WorldRegion.FLORESTA_ARCANA,

                            aoSelecionarDestino = { plan ->
                                // Selecionar um destino apenas marca a rota.
                                // A localização persistente só muda após deslocamento real no mundo.
                                pendingTravelPlan = plan
                                indiceTrechoRota = 0
                                progressoTrechoRota = 0f
                                message = "Rota marcada para ${plan.destination.name}. Siga o caminho andando na direção indicada; não há teletransporte."
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
                            aoAtualizarEstado = { novoEstado ->
                                estadoMundo = novoEstado
                                val perfilAtual = characterProfile
                                val agora = System.currentTimeMillis()
                                if (perfilAtual != null &&
                                    agora - ultimaPersistenciaPosicaoMs >= 15_000L
                                ) {
                                    ultimaPersistenciaPosicaoMs = agora
                                    val perfilComPosicao = perfilAtual.copy(
                                        worldX = novoEstado.posicaoNoMapa.x,
                                        worldY = novoEstado.posicaoNoMapa.y
                                    )
                                    characterProfile = perfilComPosicao
                                    scope.launch {
                                        runCatching {
                                            if (modoOfflineAtivo) {
                                                armazenamentoLocal.save(perfilComPosicao, uidAtual ?: armazenamentoLocal.loadRecord()?.ownerUid, true)
                                            } else {
                                                CharacterProfileRepository().saveWorldPosition(
                                                    perfilComPosicao.id,
                                                    novoEstado.posicaoNoMapa.x,
                                                    novoEstado.posicaoNoMapa.y,
                                                    perfilComPosicao.currentWorldPointId,
                                                    perfilComPosicao.respawnPointId
                                                )
                                            }
                                        }.onFailure {
                                            message = "Não foi possível salvar sua posição: ${it.localizedMessage}"
                                        }
                                    }
                                }
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
                            worldPointId = characterProfile?.currentWorldPointId?.takeIf { it.isNotBlank() } ?: "clareira_inicial",
                            cameraZoomDestino = pendingTravelPlan?.destination?.let {
                                WorldSceneCatalog.profileFor(it.id).cameraZoom
                            },
                            progressoAproximacao = pendingTravelPlan?.let { plano ->
                                val distanciaConcluida = plano.route.take(indiceTrechoRota)
                                    .sumOf { it.distance.toDouble() }.toFloat() + progressoTrechoRota
                                if (plano.totalDistance > 0f) {
                                    (distanciaConcluida / plano.totalDistance).coerceIn(0f, 1f)
                                } else 0f
                            } ?: 0f,
                            xpAtual = characterProfile?.xp ?: profile.xp,
                            mensagem = message,
                            historiaCompartilhada = allyStorySnapshot,
                            historiaIA = historiaIA,
                            aoContinuarHistoria = { solicitarCenaHistoria("Continue a história principal.") },
                            aoEnviarAcaoLivre = { acao -> solicitarCenaHistoria(acao) },
                            aoEscolherNaHistoria = { escolha ->
                                if (allyGroup == null || allyGroup?.members?.size == 1) {
                                    solicitarCenaHistoria(escolha)
                                } else {
                                val uid = uidAtual
                                val groupId = allyGroupId
                                val story = allyStorySnapshot
                                if (uid != null && groupId != null && story != null) {
                                    scope.launch {
                                        runCatching {
                                            allyStoryRepository.registrarEscolha(
                                                groupId = groupId,
                                                uid = uid,
                                                playerName = characterProfile?.name ?: "Aventureiro",
                                                choice = escolha,
                                                storyRevision = story.revision
                                            )
                                        }.onSuccess { message = "Escolha registrada para a aventura do grupo." }
                                            .onFailure { message = it.localizedMessage ?: "Não foi possível registrar sua escolha." }
                                    }
                                }
                                }
                            },
                            aoVoltar = {},
                            aoAbrirPainel = { painelMundo = it },
                            mercadorDisponivel = merchantAvailable && br.com.ascensaodosoberano.companions.BlacksmithSystem.city(
                                characterProfile?.currentWorldPointId?.takeIf { it.isNotBlank() } ?: "clareira_inicial"
                            ).availableHere,
                            ferreiroDisponivel = br.com.ascensaodosoberano.companions.BlacksmithSystem.city(
                                characterProfile?.currentWorldPointId?.takeIf { it.isNotBlank() } ?: "clareira_inicial"
                            ).availableHere,
                            curandeiroDisponivel = br.com.ascensaodosoberano.companions.BlacksmithSystem.isCity(
                                characterProfile?.currentWorldPointId?.takeIf { it.isNotBlank() } ?: "clareira_inicial"
                            ),
                            criaturaEncontrada = encounter?.criatura,
                            buscandoCriaturas = verificandoEncontro,
                            aoEnfrentarCriatura = {
                                encounter?.criatura?.let {
                                    registrarAvistamentoCriatura(it)
                                    iniciarCombateComCriatura(it)
                                }
                            },
                            aoIgnorarCriatura = {
                                encounter = null
                                message = "Você decidiu continuar explorando."
                            },
                            aoSelecionarCriaturaNoMundo = { criatura ->
                                if (combat == null && !verificandoEncontro) {
                                    encounter = ExplorationEncounter(
                                        region = ExplorationSystem.regionForWorldPoint(
                                            characterProfile?.currentWorldPointId?.takeIf { it.isNotBlank() }
                                                ?: "clareira_inicial"
                                        ) ?: ExplorationSystem.regions.first(),
                                        enemyId = criatura.id,
                                        isBoss = criatura.chefe,
                                        message = "Você se aproximou de ${criatura.nome}.",
                                        criatura = criatura
                                    )
                                    registrarAvistamentoCriatura(criatura)
                                    iniciarCombateComCriatura(criatura)
                                }
                            },
                            aoExplorar = {
                                val pointId = characterProfile?.currentWorldPointId?.takeIf { it.isNotBlank() } ?: "clareira_inicial"
                                val region = ExplorationSystem.regionForWorldPoint(pointId)
                                if (region == null) {
                                    message = "Esta área é segura. Vá para uma região selvagem para encontrar criaturas."
                                } else if (!verificandoEncontro && combat == null) {
                                    verificandoEncontro = true
                                    scope.launch {
                                        try {
                                            val resultado = ExplorationSystem.explore(
                                                region,
                                                forcarEncontro = true,
                                                permitirGeracaoRemota = !modoOfflineAtivo
                                            )
                                            encounter = resultado
                                            if (resultado.criatura != null) {
                                                registrarAvistamentoCriatura(resultado.criatura)
                                                message = resultado.message
                                                val group = allyGroup
                                                val uid = uidAtual
                                                if (group != null && group.members.size > 1 && uid == group.leaderUid) {
                                                    runCatching {
                                                        allyStoryRepository.publicarAcontecimento(
                                                            groupId = group.id,
                                                            leaderUid = uid,
                                                            chapterTitle = resultado.criatura?.let { "Um encontro: ${it.nome}" } ?: "A jornada continua",
                                                            narrativeText = resultado.message,
                                                            imageUrl = resultado.criatura?.imagemDetalhadaCaminho.orEmpty(),
                                                            eventType = if (resultado.criatura?.chefe == true) "BOSS_ENCOUNTER" else if (resultado.criatura != null) "CREATURE_ENCOUNTER" else "NARRATIVE",
                                                            choices = listOf("Investigar os arredores", "Seguir com cautela")
                                                        )
                                                    }.onFailure { message = "Acontecimento local, mas não sincronizado: ${it.localizedMessage}" }
                                                }
                                            } else {
                                                message = resultado.message
                                                val group = allyGroup
                                                val uid = uidAtual
                                                if (group != null && group.members.size > 1 && uid == group.leaderUid) {
                                                    runCatching {
                                                        allyStoryRepository.publicarAcontecimento(
                                                            groupId = group.id,
                                                            leaderUid = uid,
                                                            chapterTitle = "A jornada continua",
                                                            narrativeText = resultado.message,
                                                            eventType = "NARRATIVE",
                                                            choices = listOf("Investigar os arredores", "Seguir com cautela")
                                                        )
                                                    }.onFailure { message = "Acontecimento local, mas não sincronizado: ${it.localizedMessage}" }
                                                }
                                            }
                                        } catch (erro: Exception) {
                                            message = "Falha ao procurar criaturas: ${erro.localizedMessage ?: "verifique sua conexão"}"
                                        } finally {
                                            verificandoEncontro = false
                                        }
                                    }
                                }
                            },
                        imagemPersonagemUrl = characterProfile?.appearance?.generatedImageUrl.orEmpty(),
                        skinId = characterProfile?.appearance?.skinId ?: "pele_02",
                        hairId = characterProfile?.appearance?.hairId ?: "cabelo_01",
                        hairColorId = characterProfile?.appearance?.hairColorId ?: "castanho",
                        eyeId = characterProfile?.appearance?.eyeId ?: "olhos_01",
                        outfitId = characterProfile?.appearance?.outfitId ?: "roupa_inicial_01",
                        equipamentosVestidos = br.com.ascensaodosoberano.character.EquipmentSystem.equipmentForVisuals(
                            (characterProfile ?: profile).equipmentLoadout,
                            playerInventory.equipment
                        ),
                        espacosEquipamento = (characterProfile ?: profile).equipmentLoadout,
                            aoSelecionarJogador = { selectedPlayerForAlly = it },
                            aoPercorrer = { distancia, direcaoX, direcaoY ->
                                val plano = pendingTravelPlan
                                if (plano != null && page == 2 && !showWorldMap && combat == null) {
                                    val indice = indiceTrechoRota
                                    val trecho = plano.route.getOrNull(indice)
                                    if (trecho != null) {
                                        var pontoAnteriorId = plano.origin.id
                                        for (i in 0 until indice) {
                                            val anterior = plano.route[i]
                                            pontoAnteriorId = if (anterior.fromId == pontoAnteriorId) {
                                                anterior.toId
                                            } else {
                                                anterior.fromId
                                            }
                                        }
                                        val proximoPontoId = if (trecho.fromId == pontoAnteriorId) {
                                            trecho.toId
                                        } else {
                                            trecho.fromId
                                        }
                                        val pontoAnterior = WorldMapData.findPoint(pontoAnteriorId)
                                        val proximoPonto = WorldMapData.findPoint(proximoPontoId)
                                        if (pontoAnterior != null && proximoPonto != null) {
                                            val rotaX = proximoPonto.x - pontoAnterior.x
                                            val rotaY = proximoPonto.y - pontoAnterior.y
                                            val tamanhoRota = sqrt(rotaX * rotaX + rotaY * rotaY)
                                            val tamanhoDirecao = sqrt(direcaoX * direcaoX + direcaoY * direcaoY)
                                            if (tamanhoRota > 0.0001f && tamanhoDirecao > 0.0001f) {
                                                val alinhamento = (
                                                    (direcaoX / tamanhoDirecao) * (rotaX / tamanhoRota) +
                                                        (direcaoY / tamanhoDirecao) * (rotaY / tamanhoRota)
                                                    ).coerceIn(-1f, 1f)
                                                if (alinhamento >= 0.55f) {
                                                    progressoTrechoRota +=
                                                        distancia * alinhamento * trecho.distance / tamanhoRota
                                                    if (progressoTrechoRota >= trecho.distance) {
                                                        indiceTrechoRota += 1
                                                        progressoTrechoRota = 0f
                                                        if (indiceTrechoRota >= plano.route.size) {
                                                            val destino = plano.destination
                                                            val perfilAtual = characterProfile
                                                            if (perfilAtual != null) {
                                                                val destinoSeguro = destino.type in listOf(
                                                                    WorldPointType.CAPITAL,
                                                                    WorldPointType.CITY,
                                                                    WorldPointType.VILLAGE
                                                                )
                                                                val perfilAtualizado = perfilAtual.copy(
                                                                    currentWorldPointId = destino.id,
                                                                    respawnPointId = if (destinoSeguro) {
                                                                        destino.id
                                                                    } else {
                                                                        perfilAtual.respawnPointId
                                                                    },
                                                                    worldX = estadoMundo.posicaoNoMapa.x,
                                                                    worldY = estadoMundo.posicaoNoMapa.y
                                                                )
                                                                characterProfile = perfilAtualizado
                                                                pendingTravelPlan = null
                                                                indiceTrechoRota = 0
                                                                message = "Você chegou a ${destino.name}. A nova área está carregando."
                                                                scope.launch {
                                                                    runCatching {
                                                                        saveMutex.withLock {
                                                                            if (modoOfflineAtivo) {
                                                                                armazenamentoLocal.save(perfilAtualizado, uidAtual ?: armazenamentoLocal.loadRecord()?.ownerUid, true)
                                                                            } else {
                                                                                CharacterProfileRepository().saveWorldPosition(
                                                                                    perfilAtualizado.id,
                                                                                    perfilAtualizado.worldX,
                                                                                    perfilAtualizado.worldY,
                                                                                    perfilAtualizado.currentWorldPointId,
                                                                                    perfilAtualizado.respawnPointId
                                                                                )
                                                                            }
                                                                        }
                                                                    }.onFailure {
                                                                        message = "Você chegou a ${destino.name}, mas a localização ainda não foi sincronizada."
                                                                    }
                                                                }
                                                            }
                                                        } else {
                                                            message = "Trecho concluído. Continue seguindo a próxima parte da rota."
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                }

                                val pointId = characterProfile?.currentWorldPointId?.takeIf { it.isNotBlank() } ?: "clareira_inicial"
                                val regiao = ExplorationSystem.regionForWorldPoint(pointId)
                                if (regiao != null && page == 2 && !showWorldMap &&
                                    combat == null && !verificandoEncontro
                                ) {
                                    distanciaDesdeEncontro += distancia
                                    // Encontros mais responsivos: caminhada curta e intervalo de 12 s.
                                    val agora = System.currentTimeMillis()
                                    if (distanciaDesdeEncontro >= 0.0035f &&
                                        agora - ultimoTesteEncontroMs >= 5_000L
                                    ) {
                                        distanciaDesdeEncontro = 0f
                                        ultimoTesteEncontroMs = agora
                                        verificandoEncontro = true
                                        scope.launch {
                                            try {
                                                val resultado = ExplorationSystem.explore(
                                                    regiao,
                                                    permitirGeracaoRemota = !modoOfflineAtivo
                                                )
                                                encounter = resultado
                                                if (resultado.criatura != null) {
                                                    registrarAvistamentoCriatura(resultado.criatura)
                                                    message = resultado.message
                                                    } else if (resultado.worldEvent?.type != null &&
                                                    resultado.worldEvent.type != br.com.ascensaodosoberano.world.WorldEventType.NOTHING
                                                ) {
                                                    message = resultado.message
                                                }
                                            } catch (erro: Exception) {
                                                message = "Não foi possível explorar esta área: ${erro.localizedMessage ?: "erro desconhecido"}"
                                            } finally {
                                                verificandoEncontro = false
                                            }
                                        }
                                    }
                                }
                            }
                        )

                        pendingTravelPlan?.let { plano ->
                            val trechoAtual = plano.route.getOrNull(indiceTrechoRota)
                            val percentual = if (trechoAtual != null && trechoAtual.distance > 0f) {
                                (progressoTrechoRota / trechoAtual.distance * 100f)
                                    .toInt().coerceIn(0, 100)
                            } else 0
                            Surface(
                                modifier = Modifier
                                    .align(androidx.compose.ui.Alignment.TopCenter)
                                    .padding(12.dp),
                                color = androidx.compose.ui.graphics.Color(0xE61B2534),
                                shape = androidx.compose.foundation.shape.RoundedCornerShape(12.dp)
                            ) {
                                Text(
                                    text = "Rota: ${plano.destination.name} · Trecho ${(indiceTrechoRota + 1).coerceAtMost(plano.route.size)}/${plano.route.size} · ${percentual}%",
                                    modifier = Modifier.padding(horizontal = 14.dp, vertical = 9.dp),
                                    color = androidx.compose.ui.graphics.Color.White,
                                    style = MaterialTheme.typography.labelMedium
                                )
                            }
                        }

                    }
                }

                else -> {
                    Text("Selecione uma tela.")
                }
            }
        }


        painelMundo?.let { painel ->
            androidx.compose.ui.window.Dialog(onDismissRequest = { painelMundo = null }) {
                Surface(
                    modifier = Modifier.fillMaxWidth().heightIn(max = 680.dp),
                    shape = androidx.compose.foundation.shape.RoundedCornerShape(18.dp),
                    color = androidx.compose.ui.graphics.Color(0xFF172131)
                ) {
                    Column(
                        modifier = Modifier.verticalScroll(rememberScrollState()).padding(16.dp),
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) {
                            Text(
                                when (painel) {
                                    "STATUS" -> "STATUS DO PERSONAGEM"
                                    "INVENTARIO" -> "INVENTÁRIO"
                                    "BESTIARIO" -> "BESTIÁRIO"
                                    "MULTIPLAYER" -> "MULTIPLAYER"
                                    "FERREIRO" -> "FERREIRO"
                                    "MERCADO" -> "MERCADO"
                                    "CURANDEIRO" -> "CURANDEIRO"
                                    "HABITANTES" -> "HABITANTES DA REGIÃO"
                                    else -> "MENU"
                                },
                                color = androidx.compose.ui.graphics.Color(0xFFFFD58E),
                                style = MaterialTheme.typography.titleMedium
                            )
                            TextButton(onClick = { painelMundo = null }) { Text("FECHAR") }
                        }
                        when (painel) {
                            "STATUS" -> br.com.ascensaodosoberano.character.PainelStatusPersonagem(
                                profile = characterProfile ?: profile,
                                hero = hero,
                                gold = playerInventory.gold,
                                xpProgress = xpProgress,
                                nextLevelXp = nextLevelXp,
                                onAllocateAttribute = { attribute -> allocateAttribute(attribute) }
                            )
                            "HABITANTES" -> br.com.ascensaodosoberano.world.PainelHabitantes(
                                settlementId = when ((characterProfile ?: profile).currentWorldPointId) {
                                    "aurelia", "malachar", "cidade_do_sol", "arkanis",
                                    "vila_esperanca", "mina_dourada", "vila_verdejante",
                                    "eldarion", "torre_natureza" -> (characterProfile ?: profile).currentWorldPointId
                                    "torre_sabedoria" -> "torre_da_sabedoria"
                                    else -> "vila_verdejante"
                                },
                                onMessage = { message = it }
                            )
                            "INVENTARIO" -> {
                                Text("OURO: ${playerInventory.gold}", color = androidx.compose.ui.graphics.Color(0xFFFFD58E))
                                Text("ITENS E MATERIAIS")
                                if (playerInventory.items.isEmpty()) Text("Sua bolsa está vazia.")
                                playerInventory.items.forEach { item ->
                                    Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                        MaterialPixelArt(tipo = item.name, rank = item.materialRank, modifier = Modifier.size(42.dp))
                                        Column {
                                            Text(item.name)
                                            Text("Quantidade: ${item.quantity} · Rank ${item.materialRank}", style = MaterialTheme.typography.bodySmall)
                                        }
                                    }
                                }
                                Text("EQUIPAMENTOS")
                                if (playerInventory.equipment.isEmpty()) Text("Nenhum equipamento encontrado.")
                                playerInventory.equipment.forEach { equipamento ->
                                    Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                        EquipamentoPixelArt(tipo = equipamento.type, raridade = equipamento.rarity.name, modifier = Modifier.size(46.dp))
                                        Column(Modifier.weight(1f)) {
                                            Text(equipamento.name)
                                            Text("Rank ${equipamento.rank}", style = MaterialTheme.typography.bodySmall)
                                        }
                                        TextButton(onClick = { alternarEquipamento(equipamento) }) {
                                            Text(if ((characterProfile ?: profile).equipmentLoadout.contains(equipamento.id)) "Retirar" else "Equipar")
                                        }
                                    }
                                }
                                Text("OVOS DE COMPANHEIRO")
                                if (playerInventory.eggs.isEmpty()) Text("Você ainda não possui ovos.")
                                playerInventory.eggs.forEach { ovo ->
                                    Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                        OvoCompanheiroPixelArt(rank = ovo.rank, mutacao = ovo.mutationRarity, modifier = Modifier.size(42.dp))
                                        Column(Modifier.weight(1f)) {
                                            Text(ovo.species)
                                            Text("Rank ${ovo.rank} · ${ovo.mutationName}", style = MaterialTheme.typography.bodySmall)
                                        }
                                        TextButton(
                                            enabled = eclodindoOvoId == null,
                                            onClick = {
                                                scope.launch {
                                                    eclodindoOvoId = ovo.id
                                                    runCatching { CompanionHatchingSystem.hatchEgg(playerInventory, ovo.id) }
                                                        .onSuccess { resultado ->
                                                            if (resultado.success) atualizarInventario(resultado.inventory)
                                                            message = resultado.message
                                                        }
                                                        .onFailure { message = "Falha ao eclodir: ${it.localizedMessage}" }
                                                    eclodindoOvoId = null
                                                }
                                            }
                                        ) { Text("Eclodir") }
                                    }
                                }
                                Text("COMPANHEIROS")
                                if (playerInventory.companions.isEmpty()) Text("Você ainda não possui companheiros.")
                                playerInventory.companions.forEach { companheiro ->
                                    Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                        br.com.ascensaodosoberano.companions.CompanionPixelArt(
                                            especie = companheiro.species, rank = companheiro.rank, modifier = Modifier.size(48.dp),
                                            mutacao = companheiro.mutationId, estagio = companheiro.stage
                                        )
                                        Column(Modifier.weight(1f)) {
                                            Text(companheiro.name)
                                            Text("Nível ${companheiro.level} · ${if (companheiro.isActive) "Ativo" else "Inativo"}", style = MaterialTheme.typography.bodySmall)
                                        }
                                        TextButton(onClick = {
                                            atualizarInventario(InventorySystem.ativarCompanheiro(playerInventory, companheiro.id))
                                        }) { Text("Ativar") }
                                    }
                                }
                            }
                            "BESTIARIO" -> {
                                Text("Criaturas que você já descobriu.")
                                if (carregandoBestiario) CircularProgressIndicator()
                                else if (bestiario.isEmpty()) Text("Você ainda não descobriu nenhuma criatura.")
                                bestiario.forEach { criatura ->
                                    Card(Modifier.fillMaxWidth()) {
                                        Row(Modifier.padding(10.dp), verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                            if (criatura.imagemIconeCaminho.startsWith("https://") ||
                                                criatura.imagemIconeCaminho.startsWith("http://")) {
                                                AsyncImage(
                                                    model = criatura.imagemIconeCaminho,
                                                    contentDescription = "Imagem de ${criatura.nome}",
                                                    modifier = Modifier.size(64.dp),
                                                    contentScale = ContentScale.Fit
                                                )
                                            } else {
                                                br.com.ascensaodosoberano.combat.CriaturaPixelArt(
                                                    nome = criatura.nome, rank = criatura.rank,
                                                    chefe = criatura.chefe, modifier = Modifier.size(64.dp)
                                                )
                                            }
                                            Column {
                                                val estatisticasGlobais = estatisticasGlobaisBestiario[criatura.id]
                                                if (estatisticasGlobais != null) {
                                                    Text("Derrotas globais: ${estatisticasGlobais.totalDefeats}", style = MaterialTheme.typography.bodySmall)
                                                    Text("Primeiro descobridor: ${estatisticasGlobais.firstDiscovererName.ifBlank { "Ainda não registrado" }}", style = MaterialTheme.typography.bodySmall)
                                                    Text("Jogadores que encontraram: ${estatisticasGlobais.totalPlayersEncountered}", style = MaterialTheme.typography.bodySmall)
                                                    if (estatisticasGlobais.firstDiscoveryAt > 0L) {
                                                        Text("Descoberta em: ${java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale("pt", "BR")).format(java.util.Date(estatisticasGlobais.firstDiscoveryAt))}", style = MaterialTheme.typography.bodySmall)
                                                    }
                                                    if (estatisticasGlobais.firstDefeaterName.isNotBlank()) {
                                                        Text("Primeiro a derrotar: ${estatisticasGlobais.firstDefeaterName}", style = MaterialTheme.typography.bodySmall)
                                                    }
                                                    if (estatisticasGlobais.firstDefeatAt > 0L) {
                                                        Text("Primeira derrota: ${java.text.SimpleDateFormat("dd/MM/yyyy HH:mm", java.util.Locale("pt", "BR")).format(java.util.Date(estatisticasGlobais.firstDefeatAt))}", style = MaterialTheme.typography.bodySmall)
                                                    }
                                                    if (estatisticasGlobais.highestDamageName.isNotBlank()) {
                                                        Text("Maior dano: ${estatisticasGlobais.highestDamageName} (${estatisticasGlobais.highestDamage})", style = MaterialTheme.typography.bodySmall)
                                                    }
                                                    if (estatisticasGlobais.mostDefeatsName.isNotBlank()) {
                                                        Text("Mais derrotas: ${estatisticasGlobais.mostDefeatsName} (${estatisticasGlobais.mostDefeatsCount})", style = MaterialTheme.typography.bodySmall)
                                                    }
                                                } else {
                                                    Text("Estatísticas globais indisponíveis", style = MaterialTheme.typography.bodySmall)
                                                }
                                                Text(criatura.nome, style = MaterialTheme.typography.titleSmall)
                                                Text("Rank ${criatura.rank} · Nível ${criatura.nivel}")
                                                Text("Raridade: ${criatura.raridade} · ${criatura.bioma}", style = MaterialTheme.typography.bodySmall)
                                            }
                                        }
                                    }
                                }
                            }
                            "MULTIPLAYER" -> if (modoOfflineAtivo) {
                                Text("O multiplayer precisa de conexão. Seu personagem e todos os seus itens continuam salvos no modo offline.")
                            } else {
                                allyGroup?.let { grupo ->
                                    Text("MUNDO MULTIPLAYER (${grupo.members.size}/3)", style = MaterialTheme.typography.titleSmall)
                                    grupo.members.forEach { membro ->
                                        Text(grupo.memberNames[membro] ?: "Aventureiro")
                                    }
                                }
                                GuildaPanel(uid = uidAtual.orEmpty(), nomeJogador = profile.name) { message = it }
                                MultiplayerExpandidoPanel(
                                    uid = uidAtual.orEmpty(),
                                    aoAtualizarPersonagem = {
                                        scope.launch {
                                            runCatching { CharacterProfileRepository().getForCurrentUser() }
                                                .onSuccess { characterProfile = it }
                                                .onFailure { message = "Não foi possível atualizar: ${it.localizedMessage}" }
                                        }
                                    }
                                ) { message = it }
                                allyInvites.forEach { convite ->
                                    Card(Modifier.fillMaxWidth()) {
                                        Column(Modifier.padding(10.dp)) {
                                            Text("${convite.senderName} convidou você para Ally.")
                                            Row {
                                                TextButton(onClick = {
                                                    scope.launch {
                                                        runCatching {
                                                            allyRepository.aceitarConvite(convite.id, uidAtual ?: error("Sessão inválida."), profile.name)
                                                            allyGroupId = allyRepository.obterGrupoId(uidAtual!!)
                                                        }.onSuccess { message = "Você entrou no grupo Ally!" }
                                                            .onFailure { message = "Não foi possível aceitar: ${it.localizedMessage}" }
                                                    }
                                                }) { Text("Aceitar") }
                                                TextButton(onClick = {
                                                    scope.launch {
                                                        runCatching { allyRepository.recusarConvite(convite.id, uidAtual ?: error("Sessão inválida.")) }
                                                            .onSuccess { message = "Convite recusado." }
                                                            .onFailure { message = "Não foi possível recusar: ${it.localizedMessage}" }
                                                    }
                                                }) { Text("Recusar") }
                                            }
                                        }
                                    }
                                }
                            }
                            "MERCADO" -> {
                                val pontoAtual = characterProfile?.currentWorldPointId ?: profile.currentWorldPointId
                                br.com.ascensaodosoberano.companions.MerchantPanel(
                                    pointId = pontoAtual,
                                    inventory = playerInventory,
                                    merchantOpen = merchantAvailable,
                                    onInventoryChanged = { atualizarInventario(it) },
                                    onMessage = { message = it },
                                    rolagemInterna = false
                                )
                            }
                            "FERREIRO" -> {
                                val pontoAtual = characterProfile?.currentWorldPointId ?: profile.currentWorldPointId
                                if (br.com.ascensaodosoberano.companions.BlacksmithSystem.city(pontoAtual).availableHere) {
                                    BlacksmithPanel(
                                        pointId = pontoAtual,
                                        inventory = playerInventory,
                                        onInventoryChanged = { atualizarInventario(it) },
                                        onMessage = { message = it },
                                        rolagemInterna = false
                                    )
                                } else Text("O ferreiro só pode ser visitado dentro de uma cidade.")
                            }
                            "CURANDEIRO" -> {
                                val pontoAtual = characterProfile?.currentWorldPointId ?: profile.currentWorldPointId
                                if (br.com.ascensaodosoberano.companions.BlacksmithSystem.isCity(pontoAtual)) {
                                val companheiroAtivo = InventorySystem.obterCompanheiroAtivo(playerInventory)
                                CurandeiroPanel(
                                    vidaAtual = hero.hp,
                                    vidaMaxima = hero.maxHp,
                                    manaAtual = hero.mana,
                                    manaMaxima = hero.maxMana,
                                    companheiro = companheiroAtivo,
                                    onCurar = {
                                        hero = hero.copy(hp = hero.maxHp, mana = hero.maxMana)
                                        if (companheiroAtivo != null) {
                                            val inventarioCurado = playerInventory.copy(
                                                companions = playerInventory.companions.map { companheiro ->
                                                    if (companheiro.id == companheiroAtivo.id) companheiro.copy(hp = companheiro.maxHp)
                                                    else companheiro
                                                }
                                            )
                                            atualizarInventario(inventarioCurado)
                                        }
                                        message = if (companheiroAtivo != null) {
                                            "O curandeiro restaurou toda a sua vida e mana e curou ${companheiroAtivo.name} completamente!"
                                        } else {
                                            "O curandeiro restaurou toda a sua vida e mana!"
                                        }
                                        painelMundo = null
                                    }
                                )
                                } else {
                                    Text("O curandeiro só atende dentro de cidades.")
                                }
                            }
                        }
                    }
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
                                MaterialPixelArt(tipo = item.name, rank = item.materialRank, modifier = Modifier.size(34.dp))
                                Text("${item.name} (x${item.quantity})")
                            }
                        }
                        Text("Ovos")
                        playerInventory.eggs.forEach { egg ->
                            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                Checkbox(checked = egg.id in ovosSelecionadosTroca, onCheckedChange = { checked -> ovosSelecionadosTroca = if (checked) ovosSelecionadosTroca + egg.id else ovosSelecionadosTroca - egg.id })
                                OvoCompanheiroPixelArt(rank = egg.rank, mutacao = egg.mutationRarity, modifier = Modifier.size(34.dp))
                                Text("${egg.species} · Rank ${egg.rank} · ${egg.mutationName}")
                            }
                        }
                        Text("Equipamentos")
                        playerInventory.equipment.forEach { equipment ->
                            Row(verticalAlignment = androidx.compose.ui.Alignment.CenterVertically) {
                                Checkbox(checked = equipment.id in equipamentosSelecionadosTroca, onCheckedChange = { checked -> equipamentosSelecionadosTroca = if (checked) equipamentosSelecionadosTroca + equipment.id else equipamentosSelecionadosTroca - equipment.id })
                                EquipamentoPixelArt(tipo = equipment.type, raridade = equipment.rarity.name, modifier = Modifier.size(34.dp))
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
