
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
    Canvas(modifier) {
        val p = size.minDimension / 18f
        val x = size.width / 2f
        val y = size.height / 2f
        val skin = when (skinId) {
            "pele_01" -> Color(0xFFFFDFC4)
            "pele_02" -> Color(0xFFEBC09A)
            "pele_03" -> Color(0xFFB87950)
            "pele_04" -> Color(0xFF75452F)
            "pele_05" -> Color(0xFF432719)
            else -> Color(0xFFEBC09A)
        }
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
        val eye = if (eyeId == "olhos_03" || eyeId == "olhos_04") Color(0xFF7BE5F2) else Color(0xFF332A26)
        drawOval(Color(0x990B1119), Offset(x - p * 5f, y + p * 6f), Size(p * 10f, p * 2f))
        drawRect(shadow, Offset(x - p * 4f, y - p), Size(p * 8f, p * 8f))
        drawRect(outfit, Offset(x - p * 3f, y + p), Size(p * 6f, p * 5f))
        drawRect(shadow, Offset(x - p * 3f, y - p * 4f), Size(p * 6f, p * 6f))
        drawRect(Color(0xFFB7C5CE), Offset(x - p * 2f, y - p * 3f), Size(p * 4f, p * 3f))
        drawRect(skin, Offset(x - p * 2f, y - p * 8f), Size(p * 4f, p * 4f))
        if (hairId != "cabelo_06") {
            drawRect(hair, Offset(x - p * 2.5f, y - p * 9f), Size(p * 5f, p * 2f))
            if (hairId == "cabelo_02" || hairId == "cabelo_04") {
                drawRect(hair, Offset(x - p * 2.5f, y - p * 7.5f), Size(p, p * 3f))
                drawRect(hair, Offset(x + p * 1.5f, y - p * 7.5f), Size(p, p * 3f))
            } else if (hairId == "cabelo_05") {
                drawRect(hair, Offset(x - p, y - p * 11f), Size(p * 2f, p * 2f))
            }
        }
        drawRect(eye, Offset(x - p, y - p * 6f), Size(p * .6f, p * .6f))
        drawRect(eye, Offset(x + p * .4f, y - p * 6f), Size(p * .6f, p * .6f))
        drawRect(shadow, Offset(x - p * 2f, y + p * 6f), Size(p * 1.5f, p * 3f))
        drawRect(shadow, Offset(x + p * .5f, y + p * 6f), Size(p * 1.5f, p * 3f))
        drawRect(shadow, Offset(x - p * 2.5f, y + p * 8f), Size(p * 2f, p * 1.5f))
        drawRect(shadow, Offset(x + p * .5f, y + p * 8f), Size(p * 2f, p * 1.5f))
        drawRect(Color(0xFFDCE7EF), Offset(x + p * 4f, y - p * 6f), Size(p, p * 12f))
        drawRect(Color(0xFFE6BD64), Offset(x + p * 2.5f, y + p * 2f), Size(p * 4f, p))
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
    val coresArena = when {
        arenaNeve -> listOf(Color(0xFF253E59), Color(0xFF668DAA), Color(0xFFB9D6E7), Color(0xFF1A2A40))
        arenaDeserto -> listOf(Color(0xFF60402C), Color(0xFFB8793F), Color(0xFFD9AD68), Color(0xFF39271F))
        arenaMar -> listOf(Color(0xFF102F48), Color(0xFF176A83), Color(0xFF36A6A5), Color(0xFF102B3B))
        arenaRuinas -> listOf(Color(0xFF292344), Color(0xFF5B4778), Color(0xFF777080), Color(0xFF111A2A))
        else -> listOf(Color(0xFF142D2C), Color(0xFF315B4A), Color(0xFF557B55), Color(0xFF111A2A))
    }
    val corTerreno = when {
        arenaNeve -> Color(0xFFD6E7ED)
        arenaDeserto -> Color(0xFFC18B4F)
        arenaMar -> Color(0xFF1A6676)
        arenaRuinas -> Color(0xFF62566A)
        else -> Color(0xFF40534A)
    }
    val corSilhueta = when {
        arenaNeve -> Color(0xFF526F87)
        arenaDeserto -> Color(0xFF81502F)
        arenaMar -> Color(0xFF123E50)
        arenaRuinas -> Color(0xFF25243D)
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
    val tamanhoBaseCaixaInimigo = if (integradoAoMapa) 190.dp else 168.dp
    val tamanhoBaseArteInimigo = if (integradoAoMapa) 168.dp else 130.dp
    val tamanhoCaixaInimigo = (tamanhoBaseCaixaInimigo * escalaChefe).coerceAtMost(380.dp)
    val tamanhoArteInimigo = (tamanhoBaseArteInimigo * escalaChefe).coerceAtMost(320.dp)

    var mostrarEfeitoVisual by remember { mutableStateOf(false) }
    var arteInimigoFalhou by remember(state.enemy.spriteUrl) { mutableStateOf(false) }
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

    Column(
        modifier = modifier
            .fillMaxSize()
            .then(
                if (integradoAoMapa) {
                    Modifier
                } else {
                    Modifier.background(fundo)
                }
            )
            .padding(if (integradoAoMapa) 0.dp else 10.dp)
    ) {

        if (!integradoAoMapa) {
            // Cabeçalho compacto fora do modo de combate imersivo.
            Text(
                text = cenarioCombate.replaceFirstChar { it.uppercase() },
                color = Color(0xFFD5DCE8),
                fontSize = 10.sp,
                fontWeight = FontWeight.SemiBold,
                modifier = Modifier.align(Alignment.CenterHorizontally)
            )
            Box(
                modifier = Modifier
                    .align(Alignment.CenterHorizontally)
                    .background(
                        Brush.horizontalGradient(
                            listOf(Color(0xFF211A35), Color(0xFF49365F), Color(0xFF211A35))
                        ),
                        RoundedCornerShape(50)
                    )
                    .border(1.dp, Color(0xFFD8B66D), RoundedCornerShape(50))
                    .padding(horizontal = 24.dp, vertical = 5.dp)
            ) {
                Text("✦ BATALHA ✦", color = Color(0xFFFFD76A), fontSize = 23.sp, fontWeight = FontWeight.Black)
            }
            if (nomesGrupo.isNotEmpty()) {
                Text(
                    text = "Aliados: ${nomesGrupo.joinToString(" • ")}",
                    color = Color(0xFF9CC7FF),
                    fontSize = 10.sp,
                    modifier = Modifier.align(Alignment.CenterHorizontally)
                )
            }
        }

        // ÁREA DOS COMBATENTES
        Box(
            modifier = Modifier
                .fillMaxWidth()
                .weight(if (integradoAoMapa) 1.35f else 1f)
                .then(if (integradoAoMapa) Modifier else Modifier.border(3.dp, borda, RoundedCornerShape(14.dp)))
                .background(Brush.verticalGradient(coresArena))
                .drawBehind {
                    val w = size.width
                    val h = size.height
                    // Arena em perspectiva: primeiro plano mais largo e fundo comprimido.
                    drawOval(
                        Brush.verticalGradient(listOf(Color(0x665B7890), Color(0x00202A3A))),
                        Offset(w * .03f, h * .69f),
                        Size(w * .94f, h * .43f)
                    )
                    // Plataformas separadas para a formação do herói e do adversário.
                    drawOval(Color(0x663D5B52), Offset(w * .04f, h * .75f), Size(w * .43f, h * .18f))
                    drawOval(Color(0x664B435E), Offset(w * .56f, h * .48f), Size(w * .39f, h * .15f))
                    // Linhas do piso convergem para o horizonte e reforçam a distância.
                    for (i in 0..6) {
                        val x = w * (i / 6f)
                        drawLine(Color(0x226FC6B0), Offset(w * .50f, h * .69f), Offset(x, h), 1.1.dp.toPx())
                    }
                    for (i in 0..3) {
                        val y = h * (.75f + i * .065f)
                        drawLine(Color(0x226FC6B0), Offset(w * .04f, y), Offset(w * .96f, y), 1.dp.toPx())
                    }
                    // Silhueta e horizonte mudam de acordo com o bioma real do encontro.
                    drawCircle(Color(0x44E7B9FF), w * .105f, Offset(w * .76f, h * .25f))
                    drawCircle(Color(0x22F5D8FF), w * .145f, Offset(w * .76f, h * .25f))
                    when {
                        arenaNeve -> {
                            for (i in 0..6) {
                                val x = w * (i / 6f)
                                val pico = h * (.20f + (i % 3) * .045f)
                                drawLine(corSilhueta, Offset(x - w * .08f, h * .67f), Offset(x, h * .67f - pico), w * .11f)
                                drawLine(Color(0xFFDBEEF5), Offset(x, h * .67f - pico), Offset(x + w * .08f, h * .67f), w * .035f)
                            }
                        }
                        arenaDeserto -> {
                            for (i in 0..4) {
                                val x = w * (i / 4f)
                                drawOval(Color(0x668F5B32), Offset(x - w * .10f, h * (.48f + (i % 2) * .06f)), Size(w * .38f, h * .25f))
                                drawOval(Color(0x66E4B96E), Offset(x - w * .06f, h * (.51f + (i % 2) * .06f)), Size(w * .30f, h * .16f))
                            }
                        }
                        arenaMar -> {
                            for (i in 0..7) {
                                val x = w * (i / 7f)
                                val y = h * (.43f + (i % 3) * .045f)
                                drawLine(Color(0x8877D6D2), Offset(x, y), Offset(x + w * .13f, y), 2.dp.toPx())
                            }
                        }
                        else -> {
                            for (i in 0..8) {
                                val x = w * (i / 8f)
                                val altura = h * (.13f + ((i * 17) % 23) / 100f)
                                drawRect(corSilhueta, Offset(x, h * .66f - altura), Size(w * .055f, altura))
                                drawRect(Color(0xFF39304F), Offset(x + w * .012f, h * .66f - altura - h * .025f), Size(w * .03f, h * .025f))
                                drawRect(Color(0xFF171F31), Offset(x + w * .018f, h * .66f - altura + h * .04f), Size(w * .012f, h * .035f))
                            }
                        }
                    }
                    if (!arenaNeve && !arenaDeserto && !arenaMar && !arenaRuinas) {
                        // Árvores da floresta; não aparecem nas arenas de areia, gelo ou mar.
                        for (i in 0..5) {
                            val x = w * (i / 5f)
                            val altura = h * (.12f + (i % 3) * .035f)
                            drawRect(corSilhueta, Offset(x, h * .69f - altura), Size(w * .012f, altura))
                            drawCircle(Color(0xFF203C42), w * .035f, Offset(x + w * .006f, h * .69f - altura))
                        }
                    }
                    drawRect(
                        Brush.verticalGradient(listOf(corTerreno, coresArena.last())),
                        Offset(0f, h * .68f),
                        Size(w, h * .32f)
                    )
                    drawLine(corTerreno.copy(alpha = .72f), Offset(0f, h * .70f), Offset(w, h * .70f), h * .008f)
                    for (i in 0..22) {
                        val x = w * ((i * 37 % 97) / 97f)
                        val y = h * (.12f + (i * 19 % 52) / 100f)
                        drawCircle(Color(0x88E6C8FF), (w * .0018f).coerceAtLeast(1.2f), Offset(x, y))
                    }
                }
                .then(CombatAnimationEngine.modifier(state))
                .then(CombatMotionLibrary.modifier(state))
                .padding(8.dp)
        ) {

            // FORMAÇÃO DO GRUPO
            Column(
                modifier = Modifier.fillMaxWidth(.49f)
                    .align(Alignment.CenterStart)
                    .offset(x = 8.dp, y = 14.dp)
                    .padding(2.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                Text(
                    "HERÓI",
                    color = Color.Cyan,
                    fontWeight = FontWeight.Bold
                )

                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically
                    ) {
                        Box(
                            modifier = Modifier.size(if (companion != null) 154.dp else 190.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            val urlHeroiValida = imagemHeroiUrl.startsWith("https://") || imagemHeroiUrl.startsWith("http://")
                            var arteHeroiFalhou by remember(imagemHeroiUrl) { mutableStateOf(false) }

                            if (urlHeroiValida && !arteHeroiFalhou) {
                                // A arte gerada é a identidade principal do herói.
                                // Não desenhar o boneco genérico por baixo dela.
                                if (imagemHeroiEmQuatroAngulos) {
                                    br.com.ascensaodosoberano.character.ImagemAnguloPersonagem(
                                        imageUrl = imagemHeroiUrl,
                                        angulo = br.com.ascensaodosoberano.character.AnguloPersonagem.COSTAS,
                                        modifier = Modifier.fillMaxSize(),
                                        onError = { arteHeroiFalhou = true }
                                    )
                                } else {
                                    AsyncImage(
                                        model = imagemHeroiUrl,
                                        contentDescription = "Imagem gerada do herói",
                                        modifier = Modifier.fillMaxSize(),
                                        contentScale = ContentScale.Fit,
                                        onError = { arteHeroiFalhou = true }
                                    )
                                }
                            } else {
                                // Reserva personalizada se ainda não houver arte válida.
                                br.com.ascensaodosoberano.character.PersonagemPixelArt(
                                    appearance = br.com.ascensaodosoberano.character.CharacterAppearance(
                                        skinId = skinId,
                                        hairId = hairId,
                                        hairColorId = hairColorId,
                                        outfitId = outfitId,
                                        eyeId = eyeId
                                    ),
                                    modifier = Modifier.fillMaxSize(),
                                    equippedEquipment = equipamentosVestidos,
                                    equipmentLoadout = espacosEquipamento
                                )
                            }
                        }
                        if (companion != null) {
                            Box(Modifier.size(58.dp), contentAlignment = Alignment.Center) {
                                CompanionPixelArt(
                                    especie = companion.species,
                                    rank = companion.rank,
                                    modifier = Modifier.fillMaxSize()
                                )
                                if (companion.imagemSpriteCaminho.startsWith("https://") || companion.imagemSpriteCaminho.startsWith("http://")) {
                                    ImagemCompanheiro(
                                        caminho = companion.imagemSpriteCaminho,
                                        modifier = Modifier.fillMaxSize(),
                                        especie = companion.species,
                                        rank = companion.rank,
                                        mutacao = companion.mutationId,
                                        estagio = companion.stage
                                    )
                                }
                            }
                        }
                    }

                Text(
                    state.hero.name,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )

                if (companion != null) {
                    Text(
                        companion.name,
                        color = Color(0xFF70BFFF),
                        fontSize = 12.sp,
                        fontWeight = FontWeight.Bold
                    )
                }

                Text(
                    "Vida: ${state.hero.hp}/${state.hero.maxHp}",
                    color = Color(0xFFFF7777)
                )

                LinearProgressIndicator(
                    progress = { vidaHeroiAnimada },
                    modifier = Modifier.fillMaxWidth()
                )

                Text(
                    "Mana: ${state.hero.mana}/${state.hero.maxMana}",
                    color = Color(0xFF70BFFF)
                )

                LinearProgressIndicator(
                    progress = { manaHeroiAnimada },
                    modifier = Modifier.fillMaxWidth(),
                    color = Color(0xFF388DFF)
                )
            }

            // INIMIGO
            Column(
                modifier = Modifier.fillMaxWidth(.47f)
                    .align(Alignment.CenterEnd)
                    .offset(x = (-8).dp, y = (-16).dp)
                    .padding(2.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    if (state.enemy.isBoss) "CHEFE" else "INIMIGO",
                    color = if (state.enemy.isBoss) Color(0xFFFFB85C) else Color(0xFFFF667B),
                    fontWeight = FontWeight.Black,
                    fontSize = 15.sp
                )

                    Box(
                        modifier = Modifier.size(tamanhoCaixaInimigo).offset(y = if (integradoAoMapa) (-28).dp else 0.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        // A arte oficial é a camada principal. A ilustração genérica
                        // só aparece se não houver URL cadastrada para esta criatura.
                        if (state.enemy.spriteUrl.isBlank() || arteInimigoFalhou) {
                            CriaturaPixelArt(
                                nome = state.enemy.name,
                                rank = state.enemy.rank,
                                chefe = state.enemy.isBoss,
                                modifier = Modifier.size(tamanhoArteInimigo).graphicsLayer { scaleX = -1f }
                            )
                        }
                        Canvas(Modifier.fillMaxSize()) {
                            val centro = Offset(size.width / 2f, size.height * .56f)
                            drawOval(
                                Color(0x99060A12),
                                Offset(size.width * .18f, size.height * .79f),
                                Size(size.width * .64f, size.height * .13f)
                            )
                            val raro = state.enemy.rank.uppercase() in setOf("S", "SS", "SSS")
                            if (state.enemy.isBoss || raro) {
                                val corAura = if (state.enemy.isBoss) Color(0xFFFFC66D) else Color(0xFFB98AFF)
                                drawCircle(corAura.copy(alpha = .12f), size.minDimension * .43f * pulsoChefe, centro)
                                drawCircle(corAura.copy(alpha = .48f), size.minDimension * .34f * pulsoChefe, centro, style = Stroke(width = 1.8.dp.toPx()))
                            }
                        }
                        if (state.enemy.spriteUrl.startsWith("https://") || state.enemy.spriteUrl.startsWith("http://")) {
                            AsyncImage(
                                model = state.enemy.spriteUrl,
                                contentDescription = "Imagem oficial de ${state.enemy.name}",
                                modifier = Modifier.size(tamanhoArteInimigo).graphicsLayer { scaleX = -1f }
                                    .offset(x = deslocamentoInimigo.dp + movimentoAtaqueInimigo.value.dp, y = (-flutuarCombatentes).dp - saltoAtaqueInimigo.value.dp),
                                contentScale = ContentScale.Fit,
                                onError = { arteInimigoFalhou = true },
                                onSuccess = { arteInimigoFalhou = false }
                            )
                        }
                    }

                Text(
                    state.enemy.name,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )
                Text(
                    "Rank ${state.enemy.rank} · ${state.enemy.rarity.ifBlank { "Raridade não definida" }} · Nível ${state.enemy.level}",
                    color = Color(0xFFFFD58E),
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Bold,
                    maxLines = 1
                )
                if (state.enemy.description.isNotBlank()) {
                    Text(
                        state.enemy.description.take(150),
                        color = Color(0xFFD7DCE8),
                        fontSize = 9.sp,
                        maxLines = 2
                    )
                }
                Text(
                    "Habitat: ${state.enemy.habitat.ifBlank { state.enemy.biome.ifBlank { "Não catalogado" } }} · Perigo ${state.enemy.danger}",
                    color = Color(0xFFB9C9DD),
                    fontSize = 9.sp,
                    maxLines = 1
                )

                Text(
                    "Vida: ${state.enemy.hp}/${state.enemy.maxHp}",
                    color = Color(0xFFFF7777)
                )

                LinearProgressIndicator(
                    progress = { vidaInimigoAnimada },
                    modifier = Modifier.fillMaxWidth(),
                    color = Color.Red
                )

                if (contribuicoesDano.isNotEmpty()) {
                    Column(
                        modifier = Modifier.fillMaxWidth().padding(top = 4.dp),
                        verticalArrangement = Arrangement.spacedBy(2.dp)
                    ) {
                        Text(
                            "DANO DO GRUPO",
                            color = Color(0xFFFFD76A),
                            fontSize = 8.sp,
                            fontWeight = FontWeight.Bold
                        )
                        Text(
                            "Mínimo para itens, ovos e equipamentos: 10%",
                            color = Color(0xFFD6DCE8),
                            fontSize = 7.sp
                        )
                        contribuicoesDano.sortedByDescending { it.damageDealt }.forEach { jogador ->
                            val percentual = CombatContributionSystem.damagePercentage(
                                jogador.damageDealt,
                                state.enemy.maxHp
                            )
                            Text(
                                "${jogador.playerName}: ${String.format(java.util.Locale("pt", "BR"), "%.1f", percentual)}%",
                                color = if (percentual >= 10.0) Color(0xFF8FE3A0) else Color(0xFFFFB0A0),
                                fontSize = 8.sp,
                                maxLines = 1
                            )
                            LinearProgressIndicator(
                                progress = { (percentual / 100.0).toFloat() },
                                modifier = Modifier.fillMaxWidth().height(2.dp),
                                color = if (percentual >= 10.0) Color(0xFF55C878) else Color(0xFFE58B70)
                            )
                        }
                    }
                }

                Text(
                    "RANK ${state.enemy.rank}  •  NÍVEL ${state.enemy.level}",
                    color = Color(0xFFFFD76A),
                    fontWeight = FontWeight.Black,
                    fontSize = 11.sp,
                    modifier = Modifier
                        .background(Color(0xAA171426), RoundedCornerShape(50))
                        .border(1.dp, Color(0x77D8B66D), RoundedCornerShape(50))
                        .padding(horizontal = 9.dp, vertical = 3.dp)
                )
            }
        }

        AnimatedVisibility(
            visible = mostrarEfeitoVisual && state.efeitoVisualAtual.isNotBlank(),
            enter = fadeIn() + scaleIn(),
            exit = fadeOut() + scaleOut()
        ) {
            val visual = when (state.efeitoVisualAtual.uppercase()) {
                "FOGO" -> "🔥 EXPLOSÃO DE FOGO"
                "GELO" -> "❄️ IMPACTO CONGELANTE"
                "RAIO", "ELETRICO", "ELÉTRICO" -> "⚡ DESCARGA ELÉTRICA"
                "SOMBRIO", "SOMBRA" -> "🌑 ENERGIA SOMBRIA"
                "CARREGANDO" -> "✨ ENERGIA EM CONCENTRAÇÃO"
                "INTERRUPCAO" -> "💥 CARREGAMENTO INTERROMPIDO"
                "RESSONANCIA" -> "🌟 RESSONÂNCIA SUPREMA"
                "FALHA" -> "💨 HABILIDADE FALHOU"
                else -> "✦ ${state.efeitoVisualAtual}"
            }
            Text(
                visual,
                color = when (state.efeitoVisualAtual.uppercase()) {
                    "FOGO" -> Color(0xFFFF8A45)
                    "GELO" -> Color(0xFF82DFFF)
                    "SOMBRIO", "SOMBRA" -> Color(0xFFC39BFF)
                    "INTERRUPCAO" -> Color(0xFFFF7777)
                    "RESSONANCIA" -> Color(0xFFFFD76A)
                    else -> Color(0xFFB8D9FF)
                },
                fontWeight = FontWeight.Bold,
                modifier = Modifier.align(Alignment.CenterHorizontally)
            )
        }

        // FASE DA BATALHA
        Text(
            text = when (state.phase) {
                CombatPhase.PLAYER_TURN -> "SEU TURNO"
                CombatPhase.ENEMY_TURN -> "TURNO DO INIMIGO"
                CombatPhase.VICTORY -> "VITÓRIA!"
                CombatPhase.DEFEAT -> "DERROTA!"
                CombatPhase.ENEMY_ESCAPED -> "O INIMIGO FUGIU"
            },
            color = Color(0xFFFFD76A),
            fontWeight = FontWeight.Bold,
            modifier = Modifier.align(Alignment.CenterHorizontally)
        )

        // HISTÓRICO
        Card(
            modifier = Modifier
                .fillMaxWidth()
                .height(48.dp),
            colors = CardDefaults.cardColors(
                containerColor = Color(0xEE17182B)
            ),
            border = androidx.compose.foundation.BorderStroke(1.dp, Color(0x99B69A58)),
            shape = RoundedCornerShape(12.dp)
        ) {
            LazyColumn(
                modifier = Modifier.padding(8.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                item {
                    Text(
                        state.log.lastOrNull() ?: "A batalha começou.",
                        color = Color.White,
                        fontSize = 11.sp,
                        maxLines = 2
                    )
                }
            }
        }

        if (state.turnosAtordoadoJogador > 0) {
            Text("💫 VOCÊ ESTÁ ATORDOADO • ${state.turnosAtordoadoJogador} turno(s)", color = Color(0xFFFF7777), fontWeight = FontWeight.Bold)
        }
        if (state.carregandoHabilidadeInimigo != null) {
            Text("⚠ ${state.enemy.name} está carregando ${state.carregandoHabilidadeInimigo.nome}", color = Color(0xFFFFA45B), fontWeight = FontWeight.Bold)
            LinearProgressIndicator(
                progress = { state.quebraAtaqueCarregadoInimigo.toFloat() / state.quebraAtaqueCarregadoMaximaInimigo.coerceAtLeast(1) },
                modifier = Modifier.fillMaxWidth(), color = Color(0xFFB36BFF)
            )
        }
        if (state.carregandoHabilidadeJogador != null) {
            Text("Carregando ${state.carregandoHabilidadeJogador.nome} • ${state.turnosRestantesCarregamentoJogador} turno(s)", color = Color(0xFFFFD76A), fontWeight = FontWeight.Bold)
            LinearProgressIndicator(
                progress = { state.quebraAtaqueCarregadoJogador.toFloat() / state.quebraAtaqueCarregadoMaximaJogador.coerceAtLeast(1) },
                modifier = Modifier.fillMaxWidth(), color = Color(0xFFB36BFF)
            )
        }

        // MENU CLÁSSICO DE BATALHA: quatro comandos fixos, como na referência.
        if (state.phase == CombatPhase.PLAYER_TURN && podeAgir) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(7.dp)
            ) {
                Button(
                    onClick = onAttack,
                    modifier = Modifier.weight(1f),
                    contentPadding = PaddingValues(horizontal = 4.dp, vertical = 12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF315B9B))
                ) { Text("⚔ LUTAR", fontWeight = FontWeight.Black, fontSize = 11.sp) }

                Button(
                    onClick = { mostrarHabilidadesCombate = true },
                    modifier = Modifier.weight(1f),
                    contentPadding = PaddingValues(horizontal = 4.dp, vertical = 12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF593A83))
                ) { Text("✦ HABILIDADES", fontWeight = FontWeight.Black, fontSize = 10.sp) }

                Button(
                    onClick = { mostrarInventarioCombate = true },
                    modifier = Modifier.weight(1f),
                    contentPadding = PaddingValues(horizontal = 4.dp, vertical = 12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF805522))
                ) { Text("🎒 INVENTÁRIO", fontWeight = FontWeight.Black, fontSize = 10.sp) }

                Button(
                    onClick = { onFlee?.invoke() },
                    enabled = onFlee != null,
                    modifier = Modifier.weight(1f),
                    contentPadding = PaddingValues(horizontal = 4.dp, vertical = 12.dp),
                    colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF75404A))
                ) { Text("🏃 FUGIR", fontWeight = FontWeight.Black, fontSize = 10.sp) }
            }
            if (state.carregandoHabilidadeJogador != null) {
                Button(
                    onClick = if (state.turnosRestantesCarregamentoJogador > 0) onContinueCharge else onReleaseCharged,
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text(if (state.turnosRestantesCarregamentoJogador > 0) "CONTINUAR CARREGANDO" else "LIBERAR ATAQUE")
                }
            }
        }

        if (state.phase == CombatPhase.ENEMY_TURN && !podeAgir) {
            Text(
                text = if (nomeJogadorDoTurno.isNotBlank()) "Aguardando a ação do inimigo no turno de $nomeJogadorDoTurno" else "Aguardando a ação do inimigo...",
                color = Color(0xFF9CC7FF),
                modifier = Modifier.align(Alignment.CenterHorizontally)
            )
        }

        if (state.phase == CombatPhase.ENEMY_TURN && podeAgir) {
            Button(
                onClick = onEnemyTurn,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("AGUARDAR AÇÃO DO INIMIGO", fontWeight = FontWeight.Black)
            }
        }

        // ENCERRAMENTO DO COMBATE
        if (
            state.phase == CombatPhase.VICTORY ||
            state.phase == CombatPhase.DEFEAT ||
            state.phase == CombatPhase.ENEMY_ESCAPED
        ) {
            Text(
                "XP recebido: ${state.xpGained}",
                color = Color(0xFFFFD76A),
                modifier = Modifier.align(Alignment.CenterHorizontally)
            )

            Button(
                onClick = onEndCombat,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text("ENCERRAR COMBATE")
            }
        }
    }
}
