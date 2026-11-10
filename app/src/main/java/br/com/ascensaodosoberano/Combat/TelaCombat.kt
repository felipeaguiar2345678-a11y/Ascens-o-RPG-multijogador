
package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.companions.ImagemCompanheiro
import br.com.ascensaodosoberano.companions.CompanionPixelArt
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.tween
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.draw.drawBehind
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
    skinId: String = "pele_02",
    hairId: String = "cabelo_01",
    hairColorId: String = "castanho",
    outfitId: String = "roupa_inicial_01",
    eyeId: String = "olhos_01",
    equipamentosVestidos: List<br.com.ascensaodosoberano.companions.Equipment> = emptyList(),
    espacosEquipamento: br.com.ascensaodosoberano.companions.EquipmentLoadout = br.com.ascensaodosoberano.companions.EquipmentLoadout(),
    modifier: Modifier = Modifier,
    integradoAoMapa: Boolean = false,
    podeAgir: Boolean = true,
    nomeJogadorDoTurno: String = "",
    nomesGrupo: List<String> = emptyList(),
    membrosCombate: List<CombatAllyVisual> = emptyList(),
    contribuicoesDano: List<PlayerContribution> = emptyList(),
    onSkill: (String) -> Unit = {},
    onSpecial: () -> Unit = {},
    onContinueCharge: () -> Unit = {},
    onReleaseCharged: () -> Unit = {}
) {
    val fundo = Color(0xFF101522)
    val painel = Color(0xFF202B40)
    val borda = Color(0xFFB69A58)

    var mostrarEfeitoVisual by remember { mutableStateOf(false) }
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
            .padding(10.dp)
    ) {

        // TÍTULO DA BATALHA
        Text(
            text = if (integradoAoMapa) "⚔ COMBATE ⚔" else "BATALHA",
            color = Color(0xFFFFD76A),
            fontSize = if (integradoAoMapa) 16.sp else 25.sp,
            fontWeight = FontWeight.Black,
            modifier = Modifier.align(Alignment.CenterHorizontally)
        )

        if (nomesGrupo.isNotEmpty()) {
            Text(
                text = "Aliados: ${nomesGrupo.joinToString(" • ")}",
                color = Color(0xFF9CC7FF),
                fontSize = 10.sp,
                modifier = Modifier.align(Alignment.CenterHorizontally)
            )
        }

        // ÁREA DOS COMBATENTES
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .then(
                    if (integradoAoMapa) {
                        Modifier.height(170.dp)
                    } else {
                        Modifier.weight(1f)
                    }
                )
                .border(3.dp, borda, RoundedCornerShape(14.dp))
                .background(
                    Brush.verticalGradient(
                        listOf(Color(0xFF292344), Color(0xFF5B4778), Color(0xFF263B45), Color(0xFF111A2A))
                    )
                )
                .drawBehind {
                    val w = size.width
                    val h = size.height
                    // Horizonte fantástico em camadas: ruínas, montanhas e chão de arena.
                    drawCircle(Color(0x44E7B9FF), w * .105f, Offset(w * .76f, h * .25f))
                    drawCircle(Color(0x22F5D8FF), w * .145f, Offset(w * .76f, h * .25f))
                    for (i in 0..8) {
                        val x = w * (i / 8f)
                        val altura = h * (.13f + ((i * 17) % 23) / 100f)
                        drawRect(Color(0xFF25243D), Offset(x, h * .66f - altura), Size(w * .055f, altura))
                        drawRect(Color(0xFF39304F), Offset(x + w * .012f, h * .66f - altura - h * .025f), Size(w * .03f, h * .025f))
                        drawRect(Color(0xFF171F31), Offset(x + w * .018f, h * .66f - altura + h * .04f), Size(w * .012f, h * .035f))
                    }
                    // Silhuetas de árvores e rochas nas laterais da arena.
                    for (i in 0..5) {
                        val x = w * (i / 5f)
                        val altura = h * (.12f + (i % 3) * .035f)
                        drawRect(Color(0xFF172D35), Offset(x, h * .69f - altura), Size(w * .012f, altura))
                        drawCircle(Color(0xFF203C42), w * .035f, Offset(x + w * .006f, h * .69f - altura))
                    }
                    drawRect(
                        Brush.verticalGradient(listOf(Color(0xFF40534A), Color(0xFF172B35))),
                        Offset(0f, h * .68f),
                        Size(w, h * .32f)
                    )
                    drawLine(Color(0x887EC1A0), Offset(0f, h * .70f), Offset(w, h * .70f), h * .008f)
                    for (i in 0..22) {
                        val x = w * ((i * 37 % 97) / 97f)
                        val y = h * (.12f + (i * 19 % 52) / 100f)
                        drawCircle(Color(0x88E6C8FF), (w * .0018f).coerceAtLeast(1.2f), Offset(x, y))
                    }
                }
                .padding(8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {

            // FORMAÇÃO DO GRUPO
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.Center
            ) {
                if (membrosCombate.isNotEmpty()) {
                    Text("EQUIPE", color = Color.Cyan, fontWeight = FontWeight.Bold, fontSize = 10.sp)
                    membrosCombate.take(4).forEach { membro ->
                        Row(
                            modifier = Modifier.fillMaxWidth().padding(vertical = 0.dp)
                                .then(
                                    if (membro.isActive) Modifier
                                        .border(1.dp, Color(0xFFFFD76A), RoundedCornerShape(5.dp))
                                    else Modifier
                                )
                                .padding(horizontal = 2.dp, vertical = 1.dp),
                            verticalAlignment = Alignment.CenterVertically,
                            horizontalArrangement = Arrangement.spacedBy(3.dp)
                        ) {
                            if (membro.imageUrl.startsWith("https://") || membro.imageUrl.startsWith("http://")) {
                                AsyncImage(
                                    model = membro.imageUrl,
                                    contentDescription = "Personagem de ${membro.name}",
                                    modifier = Modifier.size(27.dp),
                                    contentScale = ContentScale.Fit
                                )
                            } else {
                                HeroPixelArt(modifier = Modifier.size(27.dp))
                            }
                            Column(modifier = Modifier.weight(1f), verticalArrangement = Arrangement.spacedBy(0.dp)) {
                                Text(
                                    text = membro.name + if (membro.isActive) " • TURNO" else "",
                                    color = if (membro.isActive) Color(0xFFFFD76A) else Color.White,
                                    fontSize = 8.sp,
                                    fontWeight = FontWeight.Bold,
                                    maxLines = 1
                                )
                                Text(
                                    "HP ${membro.hp.coerceAtLeast(0)}/${membro.maxHp.coerceAtLeast(1)}",
                                    color = Color(0xFFFF9999), fontSize = 7.sp, maxLines = 1
                                )
                                LinearProgressIndicator(
                                    progress = { membro.hp.coerceAtLeast(0).toFloat() / membro.maxHp.coerceAtLeast(1) },
                                    modifier = Modifier.fillMaxWidth().height(3.dp),
                                    color = if (membro.hp > 0) Color(0xFFE65B62) else Color.Gray
                                )
                                Text(
                                    "MP ${membro.mana.coerceAtLeast(0)}/${membro.maxMana.coerceAtLeast(0)}",
                                    color = Color(0xFF70BFFF), fontSize = 7.sp, maxLines = 1
                                )
                            }
                        }
                    }
                } else {
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
                    if ((imagemHeroiUrl.startsWith("https://") || imagemHeroiUrl.startsWith("http://")) && equipamentosVestidos.isEmpty()) {
                        AsyncImage(
                            model = imagemHeroiUrl,
                            contentDescription = "Imagem do herói",
                            modifier = Modifier.size(112.dp).offset(y = flutuarCombatentes.dp),
                            contentScale = ContentScale.Fit
                        )
                    } else {
                        br.com.ascensaodosoberano.character.PersonagemPixelArt(
                            appearance = br.com.ascensaodosoberano.character.CharacterAppearance(
                                skinId = skinId,
                                hairId = hairId,
                                hairColorId = hairColorId,
                                outfitId = outfitId,
                                eyeId = eyeId
                            ),
                            modifier = Modifier.size(112.dp).offset(y = flutuarCombatentes.dp),
                            equippedEquipment = equipamentosVestidos,
                            equipmentLoadout = espacosEquipamento
                        )
                    }

                    if (companion != null) {
                        if (companion.imagemSpriteCaminho.isNotBlank()) {
                            ImagemCompanheiro(
                                caminho = companion.imagemSpriteCaminho,
                                modifier = Modifier.size(84.dp).offset(y = (-flutuarCombatentes).dp),
                                especie = companion.species,
                                rank = companion.rank,
                                mutacao = companion.mutationId,
                                estagio = companion.stage
                            )
                        } else {
                            CompanionPixelArt(
                                especie = companion.species,
                                rank = companion.rank,
                                modifier = Modifier.size(84.dp).offset(y = (-flutuarCombatentes).dp)
                            )
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
                    progress = {
                        state.hero.hp.toFloat() /
                            state.hero.maxHp.coerceAtLeast(1)
                    },
                    modifier = Modifier.fillMaxWidth()
                )

                Text(
                    "Mana: ${state.hero.mana}/${state.hero.maxMana}",
                    color = Color(0xFF70BFFF)
                )

                LinearProgressIndicator(
                    progress = {
                        state.hero.mana.toFloat() /
                            state.hero.maxMana.coerceAtLeast(1)
                    },
                    modifier = Modifier.fillMaxWidth(),
                    color = Color(0xFF388DFF)
                )
                }
            }

            Text(
                "VS",
                color = Color(0xFFFFD76A),
                fontWeight = FontWeight.Black,
                fontSize = 20.sp,
                modifier = Modifier.padding(horizontal = 8.dp)
            )

            // INIMIGO
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text(
                    if (state.enemy.isBoss) "CHEFE" else "INIMIGO",
                    color = if (state.enemy.isBoss) Color(0xFFFFB85C) else Color(0xFFFF667B),
                    fontWeight = FontWeight.Black,
                    fontSize = 15.sp
                )

                Box(
                    modifier = Modifier.size(164.dp),
                    contentAlignment = Alignment.Center
                ) {
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
                            drawCircle(
                                corAura.copy(alpha = .12f),
                                radius = size.minDimension * .43f * pulsoChefe,
                                center = centro
                            )
                            drawCircle(
                                corAura.copy(alpha = .48f),
                                radius = size.minDimension * .34f * pulsoChefe,
                                center = centro,
                                style = Stroke(width = 1.8.dp.toPx())
                            )
                            for (i in 0..5) {
                                val angulo = i * 1.0472f
                                val px = centro.x + kotlin.math.cos(angulo) * size.minDimension * .39f
                                val py = centro.y + kotlin.math.sin(angulo) * size.minDimension * .39f
                                drawCircle(
                                    corAura.copy(alpha = .55f),
                                    radius = 1.8.dp.toPx(),
                                    center = Offset(px, py)
                                )
                            }
                        }
                    }
                    if (state.enemy.spriteUrl.startsWith("https://") || state.enemy.spriteUrl.startsWith("http://")) {
                        AsyncImage(
                            model = state.enemy.spriteUrl,
                            contentDescription = "Imagem de ${state.enemy.name}",
                            modifier = Modifier.size(148.dp).offset(y = (-flutuarCombatentes).dp),
                            contentScale = ContentScale.Fit
                        )
                    } else {
                        CriaturaPixelArt(
                            nome = state.enemy.name,
                            rank = state.enemy.rank,
                            chefe = state.enemy.isBoss,
                            modifier = Modifier.size(148.dp).offset(y = (-flutuarCombatentes).dp)
                        )
                    }
                }

                Text(
                    state.enemy.name,
                    color = Color.White,
                    fontWeight = FontWeight.Bold
                )

                Text(
                    "Vida: ${state.enemy.hp}/${state.enemy.maxHp}",
                    color = Color(0xFFFF7777)
                )

                LinearProgressIndicator(
                    progress = {
                        state.enemy.hp.toFloat() /
                            state.enemy.maxHp.coerceAtLeast(1)
                    },
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
                    "Rank: ${state.enemy.rank}",
                    color = Color(0xFFFFD76A)
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
                .height(if (integradoAoMapa) 65.dp else 105.dp),
            colors = CardDefaults.cardColors(
                containerColor = if (integradoAoMapa) {
                    Color(0xBB202B40)
                } else {
                    painel
                }
            )
        ) {
            LazyColumn(
                modifier = Modifier.padding(8.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                items(state.log.takeLast(8)) { linha ->
                    Text(
                        linha,
                        color = Color.White,
                        fontSize = 12.sp
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

        // AÇÕES DE COMBATE
        if (state.phase == CombatPhase.PLAYER_TURN && !podeAgir) {
            Text(
                text = if (nomeJogadorDoTurno.isNotBlank()) "Aguardando o turno de $nomeJogadorDoTurno" else "Aguardando outro integrante do grupo...",
                color = Color(0xFF9CC7FF),
                modifier = Modifier.align(Alignment.CenterHorizontally)
            )
        }

        if (state.phase == CombatPhase.PLAYER_TURN && podeAgir) {
            Text("Especial: ${state.especialCarga}%${if (state.especialUsado) " • já utilizado" else ""}", color = Color(0xFFD6B5FF), fontSize = 11.sp)
            LinearProgressIndicator(progress = { state.especialCarga / 100f }, modifier = Modifier.fillMaxWidth(), color = Color(0xFFB36BFF))
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(6.dp)
            ) {
                Button(
                    onClick = onAttack,
                    modifier = Modifier.weight(1f),
                    contentPadding = PaddingValues(
                        horizontal = 8.dp,
                        vertical = if (integradoAoMapa) 8.dp else 12.dp
                    ),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (integradoAoMapa) {
                            Color(0xDD805522)
                        } else {
                            MaterialTheme.colorScheme.primary
                        }
                    )
                ) {
                    Text("LUTAR")
                }

                Button(
                    onClick = onDefend,
                    modifier = Modifier.weight(1f),
                    contentPadding = PaddingValues(
                        horizontal = 8.dp,
                        vertical = if (integradoAoMapa) 8.dp else 12.dp
                    ),
                    colors = ButtonDefaults.buttonColors(
                        containerColor = if (integradoAoMapa) {
                            Color(0xDD345C80)
                        } else {
                            MaterialTheme.colorScheme.primary
                        }
                    )
                ) {
                    Text("DEFENDER")
                }
            }

            if (state.carregandoHabilidadeJogador != null) {
                Button(
                    onClick = if (state.turnosRestantesCarregamentoJogador > 0) onContinueCharge else onReleaseCharged,
                    modifier = Modifier.fillMaxWidth()
                ) { Text(if (state.turnosRestantesCarregamentoJogador > 0) "CONTINUAR CARREGANDO" else "LIBERAR ATAQUE") }
            } else if (state.hero.attacks.isNotEmpty()) {
                Row(
                    modifier = Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
                    horizontalArrangement = Arrangement.spacedBy(4.dp)
                ) {
                    state.hero.attacks.forEach { skill ->
                        val cooldown = state.recargasJogador[skill.id] ?: 0
                        Button(
                            onClick = { onSkill(skill.id) },
                            enabled = cooldown <= 0 && state.hero.mana >= skill.custoMana && state.turnosAtordoadoJogador == 0,
                            contentPadding = PaddingValues(horizontal = 8.dp, vertical = 5.dp)
                        ) {
                            Text(
                                "${skill.nome}" +
                                    (if (cooldown > 0) " ($cooldown)" else "") +
                                    (if (skill.turnosCarregamento > 0) " ⏳" else ""),
                                fontSize = 10.sp
                            )
                        }
                    }
                }
            }
            Button(
                onClick = onSpecial,
                enabled = state.especialCarga >= 100 && !state.especialUsado && state.turnosAtordoadoJogador == 0,
                modifier = Modifier.fillMaxWidth(),
                colors = ButtonDefaults.buttonColors(containerColor = Color(0xFF633A91))
            ) { Text(if (state.especialUsado) "ESPECIAL UTILIZADO" else "RESSONÂNCIA SUPREMA") }

            if (onCombo != null || onRevive != null) {
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    if (onCombo != null) Button(onClick = onCombo, modifier = Modifier.weight(1f)) { Text("COMBO ALLY") }
                    if (onRevive != null) Button(onClick = onRevive, modifier = Modifier.weight(1f)) { Text("REANIMAR ALIADO") }
                }
            }

            // MENU INFERIOR
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(5.dp)
            ) {
                listOf(
                    "HABILIDADES",
                    "INVENTÁRIO",
                    "FUGIR"
                ).forEach { nome ->
                    OutlinedButton(
                        onClick = {},
                        enabled = false,
                        modifier = Modifier.weight(1f),
                        contentPadding = PaddingValues(
                            horizontal = 3.dp,
                            vertical = if (integradoAoMapa) 7.dp else 12.dp
                        ),
                        colors = ButtonDefaults.outlinedButtonColors(
                            contentColor = Color(0xFFFFD76A)
                        )
                    ) {
                        Text(
                            nome,
                            fontSize = if (integradoAoMapa) 8.sp else 9.sp
                        )
                    }
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
                Text("AGUARDAR AÇÃO DO INIMIGO")
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
