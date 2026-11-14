package br.com.ascensaodosoberano.exploration

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import br.com.ascensaodosoberano.companions.Companion
import br.com.ascensaodosoberano.multiplayer.JogadorOnline
import br.com.ascensaodosoberano.world.CriaturaGerada
import br.com.ascensaodosoberano.world.WorldMapData
import br.com.ascensaodosoberano.multiplayer.AllyStorySnapshot

@Composable
fun TelaMundo(
    estado: EstadoCenaMundo,
    aoAtualizarEstado: (EstadoCenaMundo) -> Unit,
    companheiro: Companion? = null,
    modifier: Modifier = Modifier,
    conteudoCombate: (@Composable (Modifier) -> Unit)? = null,
    uidJogador: String? = null,
    nomeJogador: String = "Aventureiro",
    nivelJogador: Int = 1,
    vidaJogador: Int = 0,
    vidaMaximaJogador: Int = 0,
    ataqueJogador: Int = 0,
    defesaJogador: Int = 0,
    manaJogador: Int = 0,
    manaMaximaJogador: Int = 0,
    agilidadeJogador: Int = 0,
    poderMagicoJogador: Int = 0,
    worldPointId: String = "clareira_inicial",
    daylightFactor: Float = 1f,
    aoSelecionarJogador: (JogadorOnline) -> Unit = {},
    aoPercorrer: (Float, Float, Float) -> Unit = { _, _, _ -> },
    imagemPersonagemUrl: String = "",
    skinId: String = "pele_02",
    hairId: String = "cabelo_01",
    hairColorId: String = "castanho",
    eyeId: String = "olhos_01",
    outfitId: String = "roupa_inicial_01",
    equipamentosVestidos: List<br.com.ascensaodosoberano.companions.Equipment> = emptyList(),
    espacosEquipamento: br.com.ascensaodosoberano.companions.EquipmentLoadout = br.com.ascensaodosoberano.companions.EquipmentLoadout(),
    xpAtual: Int = 0,
    aoVoltar: () -> Unit = {},
    aoExplorar: () -> Unit = {},
    aoAbrirPainel: (String) -> Unit = {},
    ferreiroDisponivel: Boolean = false,
    mercadorDisponivel: Boolean = false,
    curandeiroDisponivel: Boolean = false,
    criaturaEncontrada: CriaturaGerada? = null,
    buscandoCriaturas: Boolean = false,
    aoEnfrentarCriatura: () -> Unit = {},
    aoIgnorarCriatura: () -> Unit = {},
    aoSelecionarCriaturaNoMundo: (CriaturaGerada) -> Unit = {},
    cameraZoomDestino: Float? = null,
    progressoAproximacao: Float = 0f,
    mensagem: String = "",
    historiaCompartilhada: AllyStorySnapshot? = null,
    aoEscolherNaHistoria: (String) -> Unit = {},
    tituloAventura: String = "",
    narrativaAventura: String = "",
    erroAventura: String = "",
    resultadoDadoAventura: String = "",
    escolhasAventura: List<String> = emptyList(),
    rankJogador: String = "E",
    chefesPromocaoDerrotados: List<String> = emptyList(),
    aoAceitarMissao: (GuildMission) -> Unit = {},
    acaoLivre: String = "",
    aoAlterarAcaoLivre: (String) -> Unit = {},
    aoEscolherNaAventura: (String) -> Unit = {},
    aoEnviarAcaoLivre: () -> Unit = {},
    missaoAtiva: GuildMission? = null,
    aoAbandonarMissao: () -> Unit = {},
    aceitandoMissao: Boolean = false,
    erroAceitarMissao: String = ""
) {
    if (estado.modo == ModoCenaMundo.COMBATE && conteudoCombate != null) {
        Box(modifier = modifier.fillMaxSize()) {
            conteudoCombate(Modifier.fillMaxSize())
        }
        return
    }

    TelaAventuraNarrativa(
        nomeJogador = nomeJogador,
        nivelJogador = nivelJogador,
        local = NarrativeLocationCatalog.displayName(worldPointId),
        imagemPersonagemUrl = imagemPersonagemUrl,
        criaturaEncontrada = criaturaEncontrada,
        buscandoCriaturas = buscandoCriaturas,
        mensagem = mensagem,
        aoExplorar = aoExplorar,
        aoEnfrentarCriatura = aoEnfrentarCriatura,
        aoIgnorarCriatura = aoIgnorarCriatura,
        aoAbrirPainel = aoAbrirPainel,
        historiaCompartilhada = historiaCompartilhada,
        aoEscolherNaHistoria = aoEscolherNaHistoria,
        tituloAventura = tituloAventura,
        narrativaAventura = narrativaAventura,
        erroAventura = erroAventura,
        resultadoDadoAventura = resultadoDadoAventura,
        escolhasAventura = escolhasAventura,
        rankJogador = rankJogador,
        chefesPromocaoDerrotados = chefesPromocaoDerrotados,
        aoAceitarMissao = aoAceitarMissao,
        acaoLivre = acaoLivre,
        aoAlterarAcaoLivre = aoAlterarAcaoLivre,
        aoEscolherNaAventura = aoEscolherNaAventura,
        aoEnviarAcaoLivre = aoEnviarAcaoLivre,
        missaoAtiva = missaoAtiva,
        aoAbandonarMissao = aoAbandonarMissao,
        aceitandoMissao = aceitandoMissao,
        erroAceitarMissao = erroAceitarMissao,
        modifier = modifier
    )
}
