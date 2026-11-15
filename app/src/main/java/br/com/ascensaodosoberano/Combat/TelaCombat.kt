
package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.companions.ImagemCompanheiro
import br.com.ascensaodosoberano.companions.CompanionPixelArt
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.core.Animatable
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.tween
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.foundation.background
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.border
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.ui.window.Dialog
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.getValue
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.layout.ContentScale
import coil.compose.AsyncImage
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import br.com.ascensaodosoberano.companions.Companion
import kotlinx.coroutines.delay

data class CombatAllyVisual(
    val uid: String,
    val name: String,
    val hp: Int,
    val maxHp: Int,
    val mana: Int,
    val maxMana: Int,
    val imageUrl: String = "",
    val isActive: Boolean = false
)

@Composable
private fun HeroPixelArt(
    modifier: Modifier = Modifier,
    skinId: String = "pele_02",
    hairId: String = "cabelo_01",
    hairColorId: String = "castanho",
    outfitId: String = "roupa_inicial_01",
    eyeId: String = "olhos_01"
) {
    // Arte reserva em VISTA DE COSTAS: nunca mostrar rosto no campo de batalha.
    Canvas(modifier) {
        val p = size.minDimension / 18f
        val x = size.width / 2f
        val y = size.height / 2f
        val hair = when (hairColorId) {
            "preto" -> Color(0xFF202020)
            "loiro" -> Color(0xFFE5C16B)
            "branco" -> Color(0xFFE8E8E8)
            "vermelho" -> Color(0xFFB83A32)
            "azul" -> Color(0xFF3768C5)
            "roxo" -> Color(0xFF8546B5)
            else -> Color(0xFF70452D)
        }
        val outfit = when (outfitId) {
            "roupa_inicial_02" -> Color(0xFF355B7A)
            "roupa_inicial_03" -> Color(0xFF65458F)
            "roupa_inicial_04" -> Color(0xFF34343F)
            "roupa_inicial_05" -> Color(0xFF8A653A)
            else -> Color(0xFF9E3542)
        }
        val shadow = when (outfitId) {
            "roupa_inicial_02" -> Color(0xFF20394F)
            "roupa_inicial_03" -> Color(0xFF3E2C61)
            "roupa_inicial_04" -> Color(0xFF20212B)
            "roupa_inicial_05" -> Color(0xFF594329)
            else -> Color(0xFF641F2B)
        }
        drawOval(Color(0x990B1119), Offset(x - p * 5f, y + p * 7f), Size(p * 10f, p * 2f))
        // Pernas e botas vistas por trás.
        drawRect(shadow, Offset(x - p * 3.2f, y + p * 5f), Size(p * 2.1f, p * 4f))
        drawRect(shadow, Offset(x + p * 1.1f, y + p * 5f), Size(p * 2.1f, p * 4f))
        drawRect(Color(0xFF29232A), Offset(x - p * 3.5f, y + p * 8f), Size(p * 2.5f, p * 1.5f))
        drawRect(Color(0xFF29232A), Offset(x + p * 1f, y + p * 8f), Size(p * 2.5f, p * 1.5f))
        // Tronco, ombros, mangas e capa/roupa sem detalhes frontais.
        drawRect(shadow, Offset(x - p * 4.5f, y - p * 2f), Size(p * 9f, p * 8f))
        drawRect(outfit, Offset(x - p * 3.6f, y - p * 1.5f), Size(p * 7.2f, p * 6.5f))
        drawRect(shadow, Offset(x - p * 5f, y - p * 1.5f), Size(p * 1.6f, p * 5f))
        drawRect(shadow, Offset(x + p * 3.4f, y - p * 1.5f), Size(p * 1.6f, p * 5f))
        // Cabeça por trás: cabelo cobre completamente o rosto.
        drawRect(Color(0xFFB87950), Offset(x - p * 2.3f, y - p * 7.5f), Size(p * 4.6f, p * 5f))
        drawRect(hair, Offset(x - p * 3f, y - p * 9f), Size(p * 6f, p * 3f))
        drawRect(hair, Offset(x - p * 3f, y - p * 7f), Size(p * 1.3f, p * 4f))
        drawRect(hair, Offset(x + p * 1.7f, y - p * 7f), Size(p * 1.3f, p * 4f))
        if (hairId == "cabelo_02" || hairId == "cabelo_04") {
            drawRect(hair, Offset(x - p * 3.4f, y - p * 5.5f), Size(p * 1.4f, p * 2.5f))
            drawRect(hair, Offset(x + p * 2f, y - p * 5.5f), Size(p * 1.4f, p * 2.5f))
        } else if (hairId == "cabelo_05") {
            drawRect(hair, Offset(x - p, y - p * 11f), Size(p * 2f, p * 2f))
        }
        // Arma carregada ao lado do corpo, vista por trás.
        drawRect(Color(0xFFBFCBD5), Offset(x + p * 5f, y - p * 7f), Size(p * 1.1f, p * 13f))
        drawRect(Color(0xFFE6BD64), Offset(x + p * 3.5f, y + p * 2f), Size(p * 4f, p))
    }
}
@Composable
fun TelaCombate(
    state: CombatState,
    onAttack: () -> Unit,
    onDefend: () -> Unit,
    onEnemyTurn: () -> Unit,
    onCombo: (() -> Unit)? = null,
    onRevive: (() -> Unit)? = null,
    onEndCombat: () -> Unit,
    companion: Companion? = null,
    imagemHeroiUrl: String = "",
    imagemHeroiEmQuatroAngulos: Boolean = false,
    skinId: String = "pele_02",
    hairId: String = "cabelo_01",
    hairColorId: String = "castanho",
    outfitId: String = "roupa_inicial_01",
    eyeId: String = "olhos_01",
    equipamentosVestidos: List<br.com.ascensaodosoberano.companions.Equipment> = emptyList(),
    espacosEquipamento: br.com.ascensaodosoberano.companions.EquipmentLoadout = br.com.ascensaodosoberano.companions.EquipmentLoadout(),
    modifier: Modifier = Modifier,
    integradoAoMapa: Boolean = false,
    cenarioCombate: String = "floresta sombria",
    podeAgir: Boolean = true,
    automaticoTurnoInimigo: Boolean = false,
    nomeJogadorDoTurno: String = "",
    nomesGrupo: List<String> = emptyList(),
    membrosCombate: List<CombatAllyVisual> = emptyList(),
    contribuicoesDano: List<PlayerContribution> = emptyList(),
    onSkill: (String) -> Unit = {},
    onSpecial: () -> Unit = {},
    onContinueCharge: () -> Unit = {},
    onReleaseCharged: () -> Unit = {},
    resumoInventario: List<String> = emptyList(),
    onFlee: (() -> Unit)? = null
) {
    val fundo = Color(0xFF101522)
    val painel = Color(0xFF202B40)
    val borda = Color(0xFFB69A58)
    val biomaNormalizado = cenarioCombate.lowercase()
    val arenaNeve = listOf("nevada", "gélida", "gelida", "gelo", "montanha").any { it in biomaNormalizado }
    val arenaDeserto = listOf("deserto", "duna", "areia").any { it in biomaNormalizado }
    val arenaMar = listOf("mar", "costa", "ilha", "oceano").any { it in biomaNormalizado }
    val arenaRuinas = listOf("ruína", "ruina", "antiga", "masmorra").any { it in biomaNormalizado }
    val arenaCentral = listOf("região central", "terras selvagens centrais", "central_wilds").any { it in biomaNormalizado }
    val arenaImperio = listOf("império", "imperio", "fronteiras imperiais", "campos imperiais").any { it in biomaNormalizado }
    val arenaSombras = listOf("terras das sombras", "vale do abismo", "terras mortas", "nhar-zul", "sombras").any { it in biomaNormalizado }
    val arenaFloresta = listOf("floresta arcana", "floresta das sombras", "floresta sombria", "dark_forest").any { it in biomaNormalizado }
    val coresArena = when {
        arenaNeve -> listOf(Color(0xFF253E59), Color(0xFF668DAA), Color(0xFFB9D6E7), Color(0xFF1A2A40))
        arenaDeserto -> listOf(Color(0xFF60402C), Color(0xFFB8793F), Color(0xFFD9AD68), Color(0xFF39271F))
        arenaMar -> listOf(Color(0xFF102F48), Color(0xFF176A83), Color(0xFF36A6A5), Color(0xFF102B3B))
        arenaRuinas -> listOf(Color(0xFF292344), Color(0xFF5B4778), Color(0xFF777080), Color(0xFF111A2A))
        arenaCentral -> listOf(Color(0xFF293B68), Color(0xFF526C9C), Color(0xFFB2A6C9), Color(0xFF24243E))
        arenaImperio -> listOf(Color(0xFF563B2C), Color(0xFF96704A), Color(0xFFD0AD78), Color(0xFF302B35))
        arenaSombras -> listOf(Color(0xFF130F2A), Color(0xFF38234F), Color(0xFF71365F), Color(0xFF100D1B))
        else -> listOf(Color(0xFF142D2C), Color(0xFF315B4A), Color(0xFF557B55), Color(0xFF111A2A))
    }
    val corTerreno = when {
        arenaNeve -> Color(0xFFD6E7ED)
        arenaDeserto -> Color(0xFFC18B4F)
        arenaMar -> Color(0xFF1A6676)
        arenaRuinas -> Color(0xFF62566A)
        arenaCentral -> Color(0xFF69647A)
        arenaImperio -> Color(0xFF9A7952)
        arenaSombras -> Color(0xFF30243D)
        else -> Color(0xFF40534A)
    }
    val corSilhueta = when {
        arenaNeve -> Color(0xFF526F87)
        arenaDeserto -> Color(0xFF81502F)
        arenaMar -> Color(0xFF123E50)
        arenaRuinas -> Color(0xFF25243D)
        arenaCentral -> Color(0xFF30385C)
        arenaImperio -> Color(0xFF59432F)
        arenaSombras -> Color(0xFF160F2A)
        else -> Color(0xFF172D35)
    }

    // Chefes crescem visualmente conforme o rank; inimigos comuns não mudam.
    val rankChefeNormalizado = state.enemy.rank.trim().uppercase()
        .replace(" ", "").replace("-", "")
    val escalaChefe = if (!state.enemy.isBoss) 1f else when (rankChefeNormalizado) {
        "E" -> 1.10f
        "D" -> 1.16f
        "C" -> 1.23f
        "B" -> 1.31f
        "A" -> 1.40f
        "S" -> 1.52f
        "SS" -> 1.68f
        "SSS" -> 1.88f
        "WORLD", "MUNDO", "W" -> 2.25f
        else -> 1.10f
    }
    // Aumenta a escala dos combatentes para que ocupem a arena, não pareçam ícones.
    val tamanhoBaseCaixaInimigo = if (integradoAoMapa) 250.dp else 220.dp
    val tamanhoBaseArteInimigo = if (integradoAoMapa) 220.dp else 190.dp
    val tamanhoCaixaInimigo = (tamanhoBaseCaixaInimigo * escalaChefe).coerceAtMost(380.dp)
    val tamanhoArteInimigo = (tamanhoBaseArteInimigo * escalaChefe).coerceAtMost(320.dp)

    var mostrarEfeitoVisual by remember { mutableStateOf(false) }
    // A destruição acumula durante a batalha e só é zerada quando ela termina.
    var nivelDestruicaoArena by remember { mutableStateOf(0) }
    var ultimoImpactoDevastadorProcessado by remember { mutableStateOf(state.impactosDevastadoresArena) }
    LaunchedEffect(state.impactosDevastadoresArena) {
        val novosImpactos = (state.impactosDevastadoresArena - ultimoImpactoDevastadorProcessado).coerceAtLeast(0)
        if (novosImpactos > 0) {
            nivelDestruicaoArena = (nivelDestruicaoArena + novosImpactos).coerceAtMost(5)
        }
        ultimoImpactoDevastadorProcessado = state.impactosDevastadoresArena
    }
    // Não limpar a arena ao entrar em VITÓRIA/DERROTA/FUGA:
    // a versão destruída permanece visível na tela de resultado até ela ser fechada.
    // Ao sair de TelaCombate, o remember é descartado e a próxima batalha começa intacta.
    var arteInimigoFalhou by remember(state.enemy.spriteUrl) { mutableStateOf(false) }
    var arteHeroiFalhou by remember(imagemHeroiUrl) { mutableStateOf(false) }
    var mostrarInventarioCombate by remember { mutableStateOf(false) }
    var mostrarHabilidadesCombate by remember { mutableStateOf(false) }
    var impactoHeroi by remember { mutableStateOf(false) }
    var impactoInimigo by remember { mutableStateOf(false) }
    var vidaHeroiAnterior by remember { mutableStateOf(state.hero.hp) }
    var vidaInimigoAnterior by remember { mutableStateOf(state.enemy.hp) }
    val movimentoAtaqueHeroi = remember { Animatable(0f) }
    val movimentoAtaqueInimigo = remember { Animatable(0f) }
    val saltoAtaqueHeroi = remember { Animatable(0f) }
    val saltoAtaqueInimigo = remember { Animatable(0f) }
    LaunchedEffect(state.log.size, state.efeitoVisualAtual) {
        val linha = state.log.lastOrNull().orEmpty()
        val habilidade = (state.hero.attacks + state.enemy.attacks).firstOrNull {
            it.nome.isNotBlank() && linha.contains(it.nome, ignoreCase = true)
        }
        val coreografia = CombatMotionLibrary.interpretar(habilidade, state.efeitoVisualAtual, linha)
        val atacanteInimigo = linha.contains(state.enemy.name, ignoreCase = true) &&
            !linha.contains(state.hero.name, ignoreCase = true)
        val atacanteHeroi = linha.contains(state.hero.name, ignoreCase = true)
        val acaoDeAtaque = listOf(" usou ", " causou ", " atacou ", " golpeou ", " concluiu o carregamento ").any { linha.contains(it, ignoreCase = true) }
        if ((atacanteHeroi || atacanteInimigo) && acaoDeAtaque) {
            val distancia = when (coreografia.movimento) {
                MovimentoCombate.TELEPORTE -> 62f
                MovimentoCombate.DASH, MovimentoCombate.INVESTIDA -> 42f
                MovimentoCombate.GIRO, MovimentoCombate.COMBO -> 28f
                else -> 22f
            }
            val altura = if (coreografia.movimento in setOf(
                    MovimentoCombate.SALTO, MovimentoCombate.VOAR,
                    MovimentoCombate.QUEDA, MovimentoCombate.MARTELO_CELESTE
                )) 28f else 0f
            val x = if (atacanteInimigo) movimentoAtaqueInimigo else movimentoAtaqueHeroi
            val y = if (atacanteInimigo) saltoAtaqueInimigo else saltoAtaqueHeroi
            x.snapTo(0f)
            y.snapTo(0f)
            x.animateTo(if (atacanteInimigo) -distancia else distancia, tween(150))
            y.animateTo(-altura, tween(150))
            x.animateTo(0f, tween(210))
            y.animateTo(0f, tween(210))
        }
    }
    val deslocamentoHeroi by animateFloatAsState(
        targetValue = if (impactoHeroi) 12f else 0f,
        animationSpec = tween(130),
        label = "impacto_heroi"
    )
    val deslocamentoInimigo by animateFloatAsState(
        targetValue = if (impactoInimigo) -12f else 0f,
        animationSpec = tween(130),
        label = "impacto_inimigo"
    )
    val vidaHeroiAnimada by animateFloatAsState(
        targetValue = (state.hero.hp.toFloat() / state.hero.maxHp.coerceAtLeast(1)).coerceIn(0f, 1f),
        animationSpec = tween(420),
        label = "vida_heroi"
    )
    val manaHeroiAnimada by animateFloatAsState(
        targetValue = (state.hero.mana.toFloat() / state.hero.maxMana.coerceAtLeast(1)).coerceIn(0f, 1f),
        animationSpec = tween(420),
        label = "mana_heroi"
    )
    val vidaInimigoAnimada by animateFloatAsState(
        targetValue = (state.enemy.hp.toFloat() / state.enemy.maxHp.coerceAtLeast(1)).coerceIn(0f, 1f),
        animationSpec = tween(420),
        label = "vida_inimigo"
    )
    LaunchedEffect(state.hero.hp) {
        if (state.hero.hp < vidaHeroiAnterior) {
            impactoHeroi = true
            delay(170)
            impactoHeroi = false
        }
        vidaHeroiAnterior = state.hero.hp
    }
    LaunchedEffect(state.enemy.hp) {
        if (state.enemy.hp < vidaInimigoAnterior) {
            impactoInimigo = true
            delay(170)
            impactoInimigo = false
        }
        vidaInimigoAnterior = state.enemy.hp
    }
    val transicaoChefe = rememberInfiniteTransition(label = "aura_inimigo")
    val pulsoChefe by transicaoChefe.animateFloat(
        initialValue = .88f,
        targetValue = 1.08f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1_050),
            repeatMode = RepeatMode.Reverse
        ),
        label = "pulso_aura_chefe"
    )
    val flutuarCombatentes by transicaoChefe.animateFloat(
        initialValue = -3f,
        targetValue = 3f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 1_300),
            repeatMode = RepeatMode.Reverse
        ),
        label = "movimento_idle_combatentes"
    )

    LaunchedEffect(state.efeitoVisualAtual, state.log.size) {
        mostrarEfeitoVisual = state.efeitoVisualAtual.isNotBlank()
        if (mostrarEfeitoVisual) {
            delay(900)
            mostrarEfeitoVisual = false
        }
    }

    // No combate solo, o inimigo responde automaticamente após a ação do jogador,
    // mantendo o ritmo clássico de batalha por turnos. Batalhas cooperativas
    // continuam aguardando a sincronização do servidor.
    LaunchedEffect(state.phase, state.turn, automaticoTurnoInimigo, podeAgir) {
        if (automaticoTurnoInimigo && podeAgir && state.phase == CombatPhase.ENEMY_TURN) {
            delay(450)
            onEnemyTurn()
        }
    }

    // Atordoamento consome automaticamente a ação do jogador, sem exigir clique.
    LaunchedEffect(state.phase, state.turn, state.turnosAtordoadoJogador, podeAgir) {
        if (state.phase == CombatPhase.PLAYER_TURN && podeAgir && state.turnosAtordoadoJogador > 0) {
            delay(450)
            onAttack()
        }
    }

    if (mostrarHabilidadesCombate) {
        Dialog(onDismissRequest = { mostrarHabilidadesCombate = false }) {
            Surface(
                color = Color(0xFF17182B),
                shape = RoundedCornerShape(18.dp),
                border = androidx.compose.foundation.BorderStroke(2.dp, Color(0xFFB98AFF))
            ) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(9.dp)
                ) {
                    Text("HABILIDADES DESPERTADAS", color = Color(0xFFD8B6FF), fontWeight = FontWeight.Black, fontSize = 18.sp)
                    Text("Escolha um poder disponível. Recarga e mana são verificadas antes do uso.", color = Color(0xFFD8D5E5), fontSize = 12.sp)
                    if (state.hero.attacks.isEmpty()) {
                        Text("Você ainda não despertou habilidades. Continue sua aventura para descobrir novos poderes.", color = Color.White)
                    } else {
                        LazyColumn(
                            modifier = Modifier.heightIn(max = 340.dp),
                            verticalArrangement = Arrangement.spacedBy(7.dp)
                        ) {
                            items(state.hero.attacks) { skill ->
                                val cooldown = state.recargasJogador[skill.id] ?: 0
                                val disponivel = state.phase == CombatPhase.PLAYER_TURN &&
                                    cooldown <= 0 &&
                                    state.hero.mana >= skill.custoMana &&
                                    state.turnosAtordoadoJogador == 0 &&
                                    state.carregandoHabilidadeJogador == null
                                OutlinedButton(
                                    onClick = {
                                        onSkill(skill.id)
                                        mostrarHabilidadesCombate = false
                                    },
                                    enabled = disponivel,
                                    modifier = Modifier.fillMaxWidth(),
                                    border = androidx.compose.foundation.BorderStroke(1.dp, Color(0xFF8D70B9))
                                ) {
                                    Column(Modifier.fillMaxWidth()) {
                                        Text(skill.nome, color = Color.White, fontWeight = FontWeight.Bold)
                                        Text(
                                            "Mana: ${skill.custoMana} · Recarga: ${if (cooldown > 0) cooldown else skill.turnosRecarga} turno(s)",
                                            color = Color(0xFFC8B8E8),
                                            fontSize = 10.sp
                                        )
                                    }
                                }
                            }
                        }
                    }
                    if (state.especialCarga >= 100 && !state.especialUsado && state.phase == CombatPhase.PLAYER_TURN) {
                        Button(
                            onClick = {
                                onSpecial()
                                mostrarHabilidadesCombate = false
                            },
                            modifier = Modifier.fillMaxWidth(),
                            colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF633A91))
                        ) { Text("✦ RESSONÂNCIA SUPREMA · ESPECIAL", fontWeight = FontWeight.Black) }
                    }
                    if (state.phase == CombatPhase.PLAYER_TURN) {
                        OutlinedButton(
                            onClick = {
                                onDefend()
                                mostrarHabilidadesCombate = false
                            },
                            modifier = Modifier.fillMaxWidth()
                        ) { Text("DEFENDER") }
                    }
                    TextButton(onClick = { mostrarHabilidadesCombate = false }, modifier = Modifier.align(Alignment.End)) {
                        Text("VOLTAR À BATALHA", color = Color(0xFFD8B6FF), fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }

    if (mostrarInventarioCombate) {
        Dialog(onDismissRequest = { mostrarInventarioCombate = false }) {
            Surface(
                color = Color(0xFF17182B),
                shape = RoundedCornerShape(18.dp),
                border = androidx.compose.foundation.BorderStroke(2.dp, Color(0xFFD8B66D))
            ) {
                Column(
                    modifier = Modifier.fillMaxWidth().padding(16.dp),
                    verticalArrangement = Arrangement.spacedBy(9.dp)
                ) {
                    Text("INVENTÁRIO DE BATALHA", color = Color(0xFFFFD76A), fontWeight = FontWeight.Black, fontSize = 18.sp)
                    Text("Seus itens permanecem seguros durante o combate.", color = Color(0xFFD8D5E5), fontSize = 12.sp)
                    if (resumoInventario.isEmpty()) {
                        Text("Seu inventário está vazio.", color = Color.White)
                    } else {
                        LazyColumn(
                            modifier = Modifier.heightIn(max = 300.dp),
                            verticalArrangement = Arrangement.spacedBy(6.dp)
                        ) {
                            items(resumoInventario) { item ->
                                Text("◆ $item", color = Color.White, fontSize = 13.sp)
                            }
                        }
                    }
                    TextButton(onClick = { mostrarInventarioCombate = false }, modifier = Modifier.align(Alignment.End)) {
                        Text("VOLTAR À BATALHA", color = Color(0xFFFFD76A), fontWeight = FontWeight.Bold)
                    }
                }
            }
        }
    }

    BoxWithConstraints(
        modifier = modifier
            .fillMaxSize()
            .background(Color(0xFF090D18))
    ) {
        val layoutPaisagem = maxWidth > maxHeight
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(if (integradoAoMapa) 3.dp else 7.dp),
            verticalArrangement = Arrangement.spacedBy(5.dp)
        ) {
        // CENA PRINCIPAL: a arena ocupa o fundo inteiro; HUD e combatentes ficam em camadas.
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .background(
                    Brush.verticalGradient(
                        listOf(coresArena[0], coresArena[1], coresArena[2], coresArena[3])
                    ),
                    RoundedCornerShape(14.dp)
                )
                .border(2.dp, Color(0xFFD4B46E), RoundedCornerShape(14.dp))
                .drawBehind {
                    val w = size.width
                    val h = size.height
                    val horizonte = h * .48f

                    // Céu profundo, lua e luz ambiente.
                    drawCircle(
                        Brush.radialGradient(
                            listOf(Color(0x66E8C7FF), Color(0x229A75C8), Color.Transparent),
                            center = Offset(w * .76f, h * .27f),
                            radius = w * .25f
                        ),
                        radius = w * .25f,
                        center = Offset(w * .76f, h * .27f)
                    )
                    drawCircle(Color(0xFFE8D9FF), w * .052f, Offset(w * .76f, h * .27f))
                    drawCircle(Color(0xFFB5A8D2), w * .046f, Offset(w * .76f, h * .27f))
                    for (i in 0..34) {
                        val x = w * ((i * 37 % 97) / 97f)
                        val y = h * (.08f + (i * 19 % 48) / 100f)
                        drawCircle(Color(0x99F4DFFF), (w * .0015f).coerceAtLeast(1f), Offset(x, y))
                    }

                    // Silhuetas distantes específicas do bioma.
                    if (arenaNeve) {
                        for (i in 0..7) {
                            val x = w * (i / 7f)
                            val peak = h * (.20f + (i % 3) * .045f)
                            drawLine(corSilhueta, Offset(x - w * .10f, horizonte), Offset(x, horizonte - peak), w * .12f)
                            drawLine(Color(0xFFDAEAF3), Offset(x, horizonte - peak), Offset(x + w * .10f, horizonte), w * .025f)
                        }
                    } else if (arenaDeserto) {
                        for (i in 0..5) {
                            val x = w * (i / 5f)
                            drawOval(Color(0x887E4F30), Offset(x - w * .12f, h * .48f), Size(w * .34f, h * .20f))
                            drawOval(Color(0x99D6A45F), Offset(x - w * .08f, h * .50f), Size(w * .28f, h * .15f))
                        }
                    } else if (arenaMar) {
                        for (i in 0..7) {
                            val x = w * (i / 7f)
                            drawLine(Color(0x9978D6D4), Offset(x, h * .48f), Offset(x + w * .12f, h * .48f), 2.dp.toPx())
                        }
                    } else if (arenaFloresta || arenaSombras) {
                        for (i in 0..8) {
                            val x = w * (i / 8f)
                            val altura = h * (.22f + (i % 3) * .075f)
                            drawRect(corSilhueta, Offset(x, horizonte - altura), Size(w * .018f, altura))
                            drawCircle(
                                if (arenaSombras) Color(0xFF21132F) else Color(0xFF21483B),
                                w * .055f,
                                Offset(x + w * .01f, horizonte - altura)
                            )
                            if (arenaSombras) {
                                drawLine(Color(0xFF160F27), Offset(x, horizonte), Offset(x + w * .035f, horizonte - altura * 1.25f), w * .025f)
                            }
                        }
                    } else {
                        // Torres e muralhas da região central/imperial.
                        for (i in 0..7) {
                            val x = w * (i / 7f)
                            val altura = h * (.18f + (i % 3) * .045f)
                            drawRect(corSilhueta, Offset(x, horizonte - altura), Size(w * .075f, altura))
                            drawRect(Color(0xFF9B806B), Offset(x - w * .008f, horizonte - altura - h * .025f), Size(w * .09f, h * .025f))
                            drawRect(Color(0xFFFFC879), Offset(x + w * .025f, horizonte - altura + h * .06f), Size(w * .012f, h * .035f))
                        }
                    }

                    // Piso em perspectiva: linhas convergem para o ponto de fuga.
                    drawRect(
                        Brush.verticalGradient(listOf(corTerreno.copy(alpha = .82f), coresArena.last())),
                        Offset(0f, horizonte),
                        Size(w, h - horizonte)
                    )
                    drawLine(Color(0x88E2C99A), Offset(0f, horizonte), Offset(w, horizonte), 2.dp.toPx())
                    for (i in 0..8) {
                        val x = w * (i / 8f)
                        drawLine(Color(0x3379A9B7), Offset(w * .5f, horizonte), Offset(x, h), 1.dp.toPx())
                    }
                    for (i in 1..4) {
                        val y = horizonte + (h - horizonte) * (i / 4f) * (i / 4f)
                        drawLine(Color(0x226F9AA7), Offset(0f, y), Offset(w, y), 1.dp.toPx())
                    }

                    // Sombras de contato dos dois combatentes.
                    // Plataforma distante do inimigo: menor e mais alta no quadro.
                    drawOval(Color(0x99050810), Offset(w * .70f, h * .555f), Size(w * .20f, h * .060f))
                    drawOval(Color(0x668FCF9B), Offset(w * .695f, h * .535f), Size(w * .21f, h * .055f))
                    // Plataforma próxima do herói: maior, reforçando a câmera sobre o ombro.
                    drawOval(Color(0xCC050810), Offset(w * .015f, h * .855f), Size(w * .47f, h * .125f))
                    drawOval(Color(0x557ABF9A), Offset(w * .005f, h * .825f), Size(w * .49f, h * .115f))

                    // Destruição cumulativa: rachaduras, crateras e destroços permanecem até o fim.
                    if (nivelDestruicaoArena > 0) {
                        val intensidade = nivelDestruicaoArena / 5f
                        drawRect(Color(0x66040710).copy(alpha = .25f + intensidade * .45f), Offset.Zero, Size(w, h))
                        val fissura = Color(0xFF090A12)
                        for (i in 0 until nivelDestruicaoArena) {
                            val x = w * (.16f + (i * 17 % 67) / 100f)
                            val y = h * (.77f + (i * 7 % 14) / 100f)
                            drawOval(Color(0xBB080910), Offset(x, y), Size(w * (.10f + i * .018f), h * .045f))
                            drawLine(fissura, Offset(x, y), Offset(x + w * .055f, y + h * .09f), 2.dp.toPx() + i)
                            drawLine(fissura, Offset(x + w * .055f, y + h * .09f), Offset(x + w * .09f, y + h * .045f), 1.5.dp.toPx() + i)
                        }
                        for (i in 0 until nivelDestruicaoArena * 5) {
                            val x = w * (.04f + (i * 29 % 91) / 100f)
                            val y = h * (.72f + (i * 13 % 24) / 100f)
                            drawRect(corSilhueta, Offset(x, y), Size(w * .018f, h * .025f))
                        }
                    }
                }
                .then(CombatAnimationEngine.modifier(state))
                .then(CombatMotionLibrary.modifier(state))
        ) {
            CombatSceneVisual(
                biome = cenarioCombate,
                destructionLevel = nivelDestruicaoArena,
                modifier = Modifier.fillMaxSize()
            )
            // Painéis de status com retratos, como na referência de combate.
            Row(
                modifier = Modifier.fillMaxWidth().align(Alignment.TopCenter).padding(7.dp),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                Row(
                    modifier = Modifier.weight(1f)
                        .background(Brush.verticalGradient(listOf(Color(0xEE171A31), Color(0xDD292044))), RoundedCornerShape(9.dp))
                        .border(1.5.dp, Color(0xFFC58DFF), RoundedCornerShape(9.dp))
                        .padding(horizontal = 7.dp, vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(7.dp)
                ) {
                    Box(
                        Modifier.size(width = 52.dp, height = 60.dp)
                            .background(Color(0x553B285B), RoundedCornerShape(5.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        if (imagemHeroiUrl.startsWith("https://") || imagemHeroiUrl.startsWith("http://")) {
                            if (imagemHeroiEmQuatroAngulos) {
                                br.com.ascensaodosoberano.character.ImagemAnguloPersonagem(
                                    imageUrl = imagemHeroiUrl,
                                    angulo = br.com.ascensaodosoberano.character.AnguloPersonagem.FRENTE,
                                    modifier = Modifier.fillMaxSize()
                                )
                            } else {
                                AsyncImage(model = imagemHeroiUrl, contentDescription = "Retrato do herói", modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Fit)
                            }
                        } else {
                            HeroPixelArt(Modifier.fillMaxSize(), skinId, hairId, hairColorId, outfitId, eyeId)
                        }
                    }
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                            Text(state.hero.name, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Black, maxLines = 1)
                            Text("Nv. ${state.hero.level}", color = Color(0xFFFFD889), fontSize = 10.sp, fontWeight = FontWeight.Bold)
                        }
                        Text("❤ ${state.hero.hp}/${state.hero.maxHp}", color = Color(0xFFFFA2A2), fontSize = 9.sp)
                        LinearProgressIndicator(progress = { vidaHeroiAnimada }, modifier = Modifier.fillMaxWidth().height(5.dp), color = Color(0xFFE84A55), trackColor = Color(0xFF512A3A))
                        Text("✦ ${state.hero.mana}/${state.hero.maxMana}", color = Color(0xFF9EDBFF), fontSize = 9.sp)
                        LinearProgressIndicator(progress = { manaHeroiAnimada }, modifier = Modifier.fillMaxWidth().height(4.dp), color = Color(0xFF368DFF), trackColor = Color(0xFF263B61))
                    }
                }
                Row(
                    modifier = Modifier.weight(1f)
                        .background(Brush.verticalGradient(listOf(Color(0xEE28172C), Color(0xDD40223C))), RoundedCornerShape(9.dp))
                        .border(1.5.dp, Color(0xFFFF91A7), RoundedCornerShape(9.dp))
                        .padding(horizontal = 7.dp, vertical = 5.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(7.dp)
                ) {
                    Column(Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(2.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                            Text(state.enemy.name, color = Color.White, fontSize = 12.sp, fontWeight = FontWeight.Black, maxLines = 1)
                            Text("Nv. ${state.enemy.level}", color = Color(0xFFFFD889), fontSize = 10.sp, fontWeight = FontWeight.Bold)
                        }
                        Text("❤ ${state.enemy.hp}/${state.enemy.maxHp}", color = Color(0xFFFFA2A2), fontSize = 9.sp)
                        LinearProgressIndicator(progress = { vidaInimigoAnimada }, modifier = Modifier.fillMaxWidth().height(5.dp), color = Color(0xFFE84A55), trackColor = Color(0xFF512A3A))
                        Text("Mana ${state.enemy.mana}/${state.enemy.maxMana}", color = Color(0xFF9EDBFF), fontSize = 9.sp)
                        LinearProgressIndicator(
                            progress = { (state.enemy.mana.toFloat() / state.enemy.maxMana.coerceAtLeast(1)).coerceIn(0f, 1f) },
                            modifier = Modifier.fillMaxWidth().height(4.dp), color = Color(0xFF368DFF), trackColor = Color(0xFF263B61)
                        )
                    }
                    Box(
                        Modifier.size(width = 52.dp, height = 60.dp)
                            .background(Color(0x553B1E32), RoundedCornerShape(5.dp)),
                        contentAlignment = Alignment.Center
                    ) {
                        if (state.enemy.spriteUrl.startsWith("https://") || state.enemy.spriteUrl.startsWith("http://")) {
                            AsyncImage(model = state.enemy.spriteUrl, contentDescription = "Retrato de ${state.enemy.name}", modifier = Modifier.fillMaxSize(), contentScale = ContentScale.Fit)
                        } else {
                            CriaturaPixelArt(state.enemy.name, state.enemy.rank, state.enemy.isBoss, Modifier.fillMaxSize())
                        }
                    }
                }
            }

            // Personagem do jogador em primeiro plano, à esquerda.
            Box(
                modifier = Modifier
                    .align(Alignment.BottomStart)
                     .fillMaxWidth(.43f)
                    .fillMaxHeight(.92f)
                    .offset(x = (-5).dp, y = deslocamentoHeroi.dp + 2.dp)
                    .graphicsLayer { translationX = movimentoAtaqueHeroi.value.dp.toPx(); translationY = -saltoAtaqueHeroi.value.dp.toPx() },
                contentAlignment = Alignment.BottomCenter
            ) {
                br.com.ascensaodosoberano.character.PersonagemVisualCombate(
                    appearance = br.com.ascensaodosoberano.character.CharacterAppearance(
                        skinId = skinId,
                        hairId = hairId,
                        hairColorId = hairColorId,
                        outfitId = outfitId,
                        eyeId = eyeId
                    ),
                    imageUrl = imagemHeroiUrl,
                    visualVersion = if (imagemHeroiEmQuatroAngulos) 2 else 1,
                    equippedEquipment = equipamentosVestidos,
                    equipmentLoadout = espacosEquipamento,
                    modifier = Modifier.fillMaxSize(),
                    usarFallback = arteHeroiFalhou,
                    fallback = {
                        HeroPixelArt(
                            modifier = Modifier.fillMaxSize(),
                            skinId = skinId,
                            hairId = hairId,
                            hairColorId = hairColorId,
                            outfitId = outfitId,
                            eyeId = eyeId
                        )
                    },
                    onError = { arteHeroiFalhou = true }
                )
                if (companion != null) {
                    Box(Modifier.align(Alignment.BottomEnd).size(58.dp), contentAlignment = Alignment.Center) {
                        if (companion.imagemSpriteCaminho.startsWith("https://") || companion.imagemSpriteCaminho.startsWith("http://")) {
                            ImagemCompanheiro(
                                caminho = companion.imagemSpriteCaminho,
                                modifier = Modifier.fillMaxSize(),
                                especie = companion.species,
                                rank = companion.rank,
                                mutacao = companion.mutationId,
                                estagio = companion.stage
                            )
                        } else {
                            CompanionPixelArt(
                                especie = companion.species,
                                rank = companion.rank,
                                modifier = Modifier.fillMaxSize(),
                                mutacao = companion.mutationId,
                                estagio = companion.stage
                            )
                        }
                    }
                }
            }

            // Criatura distante no plano superior direito; menor que o herói para criar profundidade.
            Box(
                modifier = Modifier
                     .align(Alignment.TopEnd)
                    .fillMaxWidth(.34f)
                    .fillMaxHeight(.60f)
                    .clipToBounds()
                    .offset(x = (-18).dp, y = 42.dp + deslocamentoInimigo.dp)
                    .graphicsLayer {
                        translationX = movimentoAtaqueInimigo.value.dp.toPx()
                        translationY = -saltoAtaqueInimigo.value.dp.toPx()
                    },
                contentAlignment = Alignment.BottomCenter
            ) {
                val possuiImagemInimigo = state.enemy.spriteUrl.startsWith("https://") || state.enemy.spriteUrl.startsWith("http://")
                if (!possuiImagemInimigo || arteInimigoFalhou) {
                    CriaturaPixelArt(
                        nome = state.enemy.name,
                        rank = state.enemy.rank,
                        chefe = state.enemy.isBoss,
                        modifier = Modifier.fillMaxSize().graphicsLayer { scaleX = -1f; scaleY = escalaChefe }
                    )
                }
                if (possuiImagemInimigo && !arteInimigoFalhou) {
                    AsyncImage(
                        model = state.enemy.spriteUrl,
                        contentDescription = "Imagem oficial de ${state.enemy.name}",
                        modifier = Modifier.fillMaxSize().graphicsLayer { scaleX = -1f; scaleY = escalaChefe },
                        contentScale = ContentScale.Fit,
                        onError = { arteInimigoFalhou = true },
                        onSuccess = { arteInimigoFalhou = false }
                    )
                }
                Canvas(Modifier.fillMaxSize()) {
                    if (state.enemy.isBoss || state.enemy.rank.uppercase() in setOf("S", "SS", "SSS")) {
                        val aura = if (state.enemy.isBoss) Color(0xFFFFC66D) else Color(0xFFB98AFF)
                        drawCircle(aura.copy(alpha = .12f), size.minDimension * .43f * pulsoChefe, Offset(size.width / 2f, size.height * .56f))
                        drawCircle(aura.copy(alpha = .48f), size.minDimension * .34f * pulsoChefe, Offset(size.width / 2f, size.height * .56f), style = Stroke(width = 2.dp.toPx()))
                    }
                }
            }

            if (state.enemy.isBoss) {
                Text(
                    "CHEFE · RANK ${state.enemy.rank}",
                    color = Color(0xFFFFD58E),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Black,
                    modifier = Modifier.align(Alignment.BottomEnd).padding(end = 10.dp, bottom = 4.dp)
                        .background(Color(0xBB160F22), RoundedCornerShape(30.dp))
                        .border(1.dp, Color(0xFFFFC66D), RoundedCornerShape(30.dp))
                        .padding(horizontal = 8.dp, vertical = 3.dp)
                )
            }
            Text(
                cenarioCombate.replaceFirstChar { it.uppercase() },
                color = Color(0xFFE7E1F0),
                fontSize = 9.sp,
                fontWeight = FontWeight.Bold,
                modifier = Modifier.align(Alignment.BottomCenter).padding(bottom = 5.dp)
                    .background(Color(0x99090D18), RoundedCornerShape(30.dp))
                    .padding(horizontal = 9.dp, vertical = 3.dp)
            )

            if (layoutPaisagem) {
                Card(
                    modifier = Modifier.align(Alignment.BottomStart).fillMaxWidth(.48f)
                        .padding(start = 8.dp, bottom = 8.dp).heightIn(min = 66.dp, max = 92.dp),
                    colors = CardDefaults.cardColors(containerColor = Color(0xF0181028)),
                    border = androidx.compose.foundation.BorderStroke(2.dp, Color(0xFFB98AFF)),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Column(
                        modifier = Modifier.fillMaxSize().padding(horizontal = 10.dp, vertical = 7.dp),
                        verticalArrangement = Arrangement.Center
                    ) {
                        Text(
                            when (state.phase) {
                                CombatPhase.PLAYER_TURN -> "O que ${state.hero.name} irá fazer?"
                                CombatPhase.ENEMY_TURN -> "O inimigo está preparando sua ação..."
                                CombatPhase.VICTORY -> "Vitória! ${state.enemy.name} foi derrotado."
                                CombatPhase.DEFEAT -> "Derrota. ${state.hero.name} foi vencido."
                                CombatPhase.ENEMY_ESCAPED -> "${state.enemy.name} fugiu da batalha."
                            },
                            color = Color.White, fontSize = 14.sp, fontWeight = FontWeight.Bold, maxLines = 3
                        )
                        Text(state.log.lastOrNull().orEmpty(), color = Color(0xFFE1D6F0), fontSize = 9.sp, maxLines = 2)
                    }
                }
                Column(
                    modifier = Modifier.align(Alignment.BottomEnd).fillMaxWidth(.45f)
                        .padding(end = 8.dp, bottom = 8.dp),
                    verticalArrangement = Arrangement.spacedBy(5.dp)
                ) {
                    if (state.phase == CombatPhase.PLAYER_TURN && podeAgir && state.turnosAtordoadoJogador == 0) {
                        if (state.carregandoHabilidadeJogador != null) {
                            Button(
                                onClick = if (state.turnosRestantesCarregamentoJogador > 0) onContinueCharge else onReleaseCharged,
                                modifier = Modifier.fillMaxWidth().height(43.dp),
                                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF7134B5)),
                                shape = RoundedCornerShape(8.dp)
                            ) {
                                Text(if (state.turnosRestantesCarregamentoJogador > 0) "CONTINUAR CARGA" else "LIBERAR PODER", fontWeight = FontWeight.Black)
                            }
                        } else {
                            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                                Button(
                                    onClick = onAttack, modifier = Modifier.weight(1f).height(45.dp),
                                    shape = RoundedCornerShape(8.dp),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFB32635)),
                                    contentPadding = PaddingValues(horizontal = 2.dp)
                                ) { Text("⚔ ATAQUE", fontWeight = FontWeight.Black, fontSize = 11.sp) }
                                Button(
                                    onClick = { mostrarHabilidadesCombate = true },
                                    modifier = Modifier.weight(1f).height(45.dp), shape = RoundedCornerShape(8.dp),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF6332A0)),
                                    contentPadding = PaddingValues(horizontal = 2.dp)
                                ) { Text("✦ HABILIDADES", fontWeight = FontWeight.Black, fontSize = 10.sp) }
                            }
                            Row(horizontalArrangement = Arrangement.spacedBy(5.dp)) {
                                Button(
                                    onClick = onDefend, modifier = Modifier.weight(1f).height(45.dp),
                                    shape = RoundedCornerShape(8.dp),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2456A5)),
                                    contentPadding = PaddingValues(horizontal = 2.dp)
                                ) { Text("🛡 DEFESA", fontWeight = FontWeight.Black, fontSize = 11.sp) }
                                Button(
                                    onClick = { onFlee?.invoke() }, enabled = onFlee != null,
                                    modifier = Modifier.weight(1f).height(45.dp), shape = RoundedCornerShape(8.dp),
                                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF268344)),
                                    contentPadding = PaddingValues(horizontal = 2.dp)
                                ) { Text("🏃 FUGIR", fontWeight = FontWeight.Black, fontSize = 11.sp) }
                            }
                        }
                    } else if (state.phase == CombatPhase.VICTORY || state.phase == CombatPhase.DEFEAT || state.phase == CombatPhase.ENEMY_ESCAPED) {
                        Button(onClick = onEndCombat, modifier = Modifier.fillMaxWidth().height(48.dp)) {
                            Text("ENCERRAR COMBATE · ${state.xpGained} XP", fontWeight = FontWeight.Black)
                        }
                    } else {
                        Text(
                            if (nomeJogadorDoTurno.isNotBlank()) "Aguardando: $nomeJogadorDoTurno" else "Aguardando próximo turno...",
                            color = Color.White,
                            modifier = Modifier.fillMaxWidth().background(Color(0xCC17182B), RoundedCornerShape(8.dp)).padding(10.dp)
                        )
                    }
                }
            }
        }

        if (!layoutPaisagem) {
        // Turno e mensagem ficam abaixo da arena no modo retrato.
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(
                when (state.phase) {
                    CombatPhase.PLAYER_TURN -> "SEU TURNO"
                    CombatPhase.ENEMY_TURN -> "TURNO DO INIMIGO"
                    CombatPhase.VICTORY -> "VITÓRIA!"
                    CombatPhase.DEFEAT -> "DERROTA!"
                    CombatPhase.ENEMY_ESCAPED -> "O INIMIGO FUGIU"
                },
                color = Color(0xFFFFD76A),
                fontWeight = FontWeight.Black,
                fontSize = 12.sp
            )
            if (nomesGrupo.isNotEmpty()) {
                Text("Grupo: ${nomesGrupo.joinToString(" • ")}", color = Color(0xFF9CC7FF), fontSize = 9.sp, maxLines = 1)
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth().heightIn(min = 34.dp, max = 43.dp),
            colors = CardDefaults.cardColors(containerColor = Color(0xEE17182B)),
            border = androidx.compose.foundation.BorderStroke(1.dp, Color(0x99B69A58)),
            shape = RoundedCornerShape(9.dp)
        ) {
            Box(Modifier.fillMaxWidth().padding(horizontal = 9.dp, vertical = 5.dp), contentAlignment = Alignment.CenterStart) {
                Text(state.log.lastOrNull() ?: "A batalha começou.", color = Color.White, fontSize = 10.sp, maxLines = 2)
            }
        }

        // Barras independentes de carregamento e de quebra; quebrar causa atordoamento.
        if (state.carregandoHabilidadeJogador != null || state.carregandoHabilidadeInimigo != null || state.turnosAtordoadoJogador > 0 || state.turnosAtordoadoInimigo > 0) {
            Column(
                modifier = Modifier.fillMaxWidth().background(Color(0xFF171426), RoundedCornerShape(8.dp)).padding(horizontal = 8.dp, vertical = 4.dp),
                verticalArrangement = Arrangement.spacedBy(3.dp)
            ) {
                if (state.carregandoHabilidadeJogador != null) {
                    val total = state.carregandoHabilidadeJogador.turnosCarregamento.coerceAtLeast(1)
                    val feito = (total - state.turnosRestantesCarregamentoJogador).coerceIn(0, total)
                    Text("HERÓI · ${state.carregandoHabilidadeJogador.nome} · CARGA ${feito}/${total}", color = Color(0xFFFFD98B), fontSize = 9.sp, fontWeight = FontWeight.Bold)
                    LinearProgressIndicator(progress = { feito.toFloat() / total }, modifier = Modifier.fillMaxWidth().height(4.dp), color = Color(0xFFFFC45C), trackColor = Color(0xFF4A3829))
                    Text("QUEBRA ${state.quebraAtaqueCarregadoJogador}/${state.quebraAtaqueCarregadoMaximaJogador.coerceAtLeast(1)}", color = Color(0xFFFF9A9A), fontSize = 8.sp)
                    LinearProgressIndicator(progress = { state.quebraAtaqueCarregadoJogador.toFloat() / state.quebraAtaqueCarregadoMaximaJogador.coerceAtLeast(1) }, modifier = Modifier.fillMaxWidth().height(5.dp), color = Color(0xFFB66BFF), trackColor = Color(0xFF3A244E))
                }
                if (state.carregandoHabilidadeInimigo != null) {
                    val total = state.carregandoHabilidadeInimigo.turnosCarregamento.coerceAtLeast(1)
                    val feito = (total - state.turnosRestantesCarregamentoInimigo).coerceIn(0, total)
                    Text("INIMIGO · ${state.carregandoHabilidadeInimigo.nome} · CARGA ${feito}/${total}", color = Color(0xFFFFB0A0), fontSize = 9.sp, fontWeight = FontWeight.Bold)
                    LinearProgressIndicator(progress = { feito.toFloat() / total }, modifier = Modifier.fillMaxWidth().height(4.dp), color = Color(0xFFFF8A64), trackColor = Color(0xFF4A2929))
                    Text("QUEBRA ${state.quebraAtaqueCarregadoInimigo}/${state.quebraAtaqueCarregadoMaximaInimigo.coerceAtLeast(1)}", color = Color(0xFFFF9A9A), fontSize = 8.sp)
                    LinearProgressIndicator(progress = { state.quebraAtaqueCarregadoInimigo.toFloat() / state.quebraAtaqueCarregadoMaximaInimigo.coerceAtLeast(1) }, modifier = Modifier.fillMaxWidth().height(5.dp), color = Color(0xFFB66BFF), trackColor = Color(0xFF3A244E))
                }
                if (state.turnosAtordoadoJogador > 0) {
                    Text("💫 HERÓI ATORDOADO · ${state.turnosAtordoadoJogador} turno(s) sem agir", color = Color(0xFFFF7777), fontSize = 9.sp, fontWeight = FontWeight.Black)
                }
                if (state.turnosAtordoadoInimigo > 0) {
                    Text("💫 INIMIGO ATORDOADO · ${state.turnosAtordoadoInimigo} turno(s) sem agir", color = Color(0xFFFF7777), fontSize = 9.sp, fontWeight = FontWeight.Black)
                }
            }
        }

        if (state.phase == CombatPhase.PLAYER_TURN && podeAgir && state.turnosAtordoadoJogador == 0) {
            if (state.carregandoHabilidadeJogador != null) {
                Button(
                    onClick = if (state.turnosRestantesCarregamentoJogador > 0) onContinueCharge else onReleaseCharged,
                    modifier = Modifier.fillMaxWidth().height(42.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF8B4CC4)),
                    shape = RoundedCornerShape(10.dp)
                ) {
                    Text(if (state.turnosRestantesCarregamentoJogador > 0) "CONTINUAR CARREGANDO" else "LIBERAR ATAQUE DEVASTADOR", fontWeight = FontWeight.Black)
                }
            } else {
                Row(horizontalArrangement = Arrangement.spacedBy(7.dp), modifier = Modifier.fillMaxWidth()) {
                    Button(
                        onClick = onAttack,
                        modifier = Modifier.weight(1f).height(43.dp),
                        shape = RoundedCornerShape(8.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFFB32635)),
                        contentPadding = PaddingValues(horizontal = 3.dp, vertical = 5.dp)
                    ) { Text("⚔ ATAQUE", fontWeight = FontWeight.Black, fontSize = 12.sp) }
                    Button(
                        onClick = { mostrarHabilidadesCombate = true },
                        modifier = Modifier.weight(1f).height(43.dp),
                        shape = RoundedCornerShape(8.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF6332A0)),
                        contentPadding = PaddingValues(horizontal = 3.dp, vertical = 5.dp)
                    ) { Text("✦ HABILIDADES", fontWeight = FontWeight.Black, fontSize = 11.sp) }
                }
                Row(horizontalArrangement = Arrangement.spacedBy(7.dp), modifier = Modifier.fillMaxWidth()) {
                    Button(
                        onClick = onDefend,
                        modifier = Modifier.weight(1f).height(43.dp),
                        shape = RoundedCornerShape(8.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF2456A5)),
                        contentPadding = PaddingValues(horizontal = 3.dp, vertical = 5.dp)
                    ) { Text("🛡 DEFESA", fontWeight = FontWeight.Black, fontSize = 12.sp) }
                    Button(
                        onClick = { onFlee?.invoke() },
                        enabled = onFlee != null,
                        modifier = Modifier.weight(1f).height(43.dp),
                        shape = RoundedCornerShape(8.dp),
                        colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF268344)),
                        contentPadding = PaddingValues(horizontal = 3.dp, vertical = 5.dp)
                    ) { Text("🏃 FUGIR", fontWeight = FontWeight.Black, fontSize = 12.sp) }
                }
                TextButton(onClick = { mostrarInventarioCombate = true }, modifier = Modifier.align(Alignment.End), contentPadding = PaddingValues(0.dp)) {
                    Text("🎒 Inventário", color = Color(0xFFFFD995), fontSize = 10.sp)
                }
            }
        }

        if (state.phase == CombatPhase.ENEMY_TURN && !podeAgir) {
            Text(
                if (nomeJogadorDoTurno.isNotBlank()) "Aguardando ação do inimigo no turno de $nomeJogadorDoTurno" else "Aguardando ação do inimigo...",
                color = Color(0xFF9CC7FF),
                fontSize = 10.sp
            )
        }
        if (state.phase == CombatPhase.ENEMY_TURN && podeAgir) {
            if (automaticoTurnoInimigo) {
                Text("O inimigo está preparando sua ação...", color = Color(0xFFFFD58E), fontSize = 10.sp)
            } else {
                Button(onClick = onEnemyTurn, modifier = Modifier.fillMaxWidth().height(40.dp)) {
                    Text("AGUARDAR AÇÃO DO INIMIGO", fontWeight = FontWeight.Black)
                }
            }
        }

        if (state.phase == CombatPhase.VICTORY || state.phase == CombatPhase.DEFEAT || state.phase == CombatPhase.ENEMY_ESCAPED) {
            Row(verticalAlignment = Alignment.CenterVertically, horizontalArrangement = Arrangement.SpaceBetween, modifier = Modifier.fillMaxWidth()) {
                Text("XP recebido: ${state.xpGained}", color = Color(0xFFFFD76A), fontWeight = FontWeight.Bold)
                Button(onClick = onEndCombat) { Text("ENCERRAR COMBATE") }
            }
        }
        }
    }
    }
}
