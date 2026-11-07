
package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.companions.ImagemCompanheiro
import br.com.ascensaodosoberano.companions.CompanionPixelArt
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
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

@Composable
private fun HeroPixelArt(modifier: Modifier = Modifier) {
    Canvas(modifier) {
        val p = size.minDimension / 18f
        val x = size.width / 2f
        val y = size.height / 2f
        drawOval(Color(0x990B1119), Offset(x - p * 5f, y + p * 6f), Size(p * 10f, p * 2f))
        drawRect(Color(0xFF572331), Offset(x - p * 4f, y - p, ), Size(p * 8f, p * 8f))
        drawRect(Color(0xFF9D3542), Offset(x - p * 3f, y + p, ), Size(p * 6f, p * 5f))
        drawRect(Color(0xFF25384D), Offset(x - p * 3f, y - p * 4f), Size(p * 6f, p * 6f))
        drawRect(Color(0xFFB7C5CE), Offset(x - p * 2f, y - p * 3f), Size(p * 4f, p * 3f))
        drawRect(Color(0xFFE6BD91), Offset(x - p * 2f, y - p * 8f), Size(p * 4f, p * 4f))
        drawRect(Color(0xFF30231F), Offset(x - p * 2.5f, y - p * 9f), Size(p * 5f, p * 2f))
        drawRect(Color(0xFF25384D), Offset(x - p * 2f, y + p * 6f), Size(p * 1.5f, p * 3f))
        drawRect(Color(0xFF25384D), Offset(x + p * .5f, y + p * 6f), Size(p * 1.5f, p * 3f))
        drawRect(Color(0xFF151B25), Offset(x - p * 2.5f, y + p * 8f), Size(p * 2f, p * 1.5f))
        drawRect(Color(0xFF151B25), Offset(x + p * .5f, y + p * 8f), Size(p * 2f, p * 1.5f))
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
    modifier: Modifier = Modifier,
    integradoAoMapa: Boolean = false,
    podeAgir: Boolean = true,
    nomeJogadorDoTurno: String = "",
    nomesGrupo: List<String> = emptyList(),
    onSkill: (String) -> Unit = {},
    onSpecial: () -> Unit = {},
    onContinueCharge: () -> Unit = {},
    onReleaseCharged: () -> Unit = {}
) {
    val fundo = Color(0xFF101522)
    val painel = Color(0xFF202B40)
    val borda = Color(0xFFB69A58)

    var finalizacaoEnviada by remember {
        mutableStateOf(false)
    }
    var mostrarEfeitoVisual by remember { mutableStateOf(false) }

    LaunchedEffect(state.efeitoVisualAtual, state.log.size) {
        mostrarEfeitoVisual = state.efeitoVisualAtual.isNotBlank()
        if (mostrarEfeitoVisual) {
            delay(900)
            mostrarEfeitoVisual = false
        }
    }

    LaunchedEffect(state.phase) {
        if (state.phase == CombatPhase.PLAYER_TURN) {
            finalizacaoEnviada = false
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
            fontSize = if (integradoAoMapa) 16.sp else 22.sp,
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
                .border(2.dp, borda, RoundedCornerShape(8.dp))
                .background(
                    if (integradoAoMapa) {
                        Brush.verticalGradient(
                            listOf(Color(0xDD53665A), Color(0xDD293B3C), Color(0xEE182331))
                        )
                    } else {
                        Brush.verticalGradient(listOf(painel, fundo))
                    }
                )
                .padding(8.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {

            // JOGADOR
            Column(
                modifier = Modifier.weight(1f),
                horizontalAlignment = Alignment.CenterHorizontally
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
                    if (imagemHeroiUrl.startsWith("https://") || imagemHeroiUrl.startsWith("http://")) {
                        AsyncImage(
                            model = imagemHeroiUrl,
                            contentDescription = "Imagem do herói",
                            modifier = Modifier.size(64.dp),
                            contentScale = ContentScale.Fit
                        )
                    } else {
                        HeroPixelArt(Modifier.size(64.dp))
                    }

                    if (companion != null) {
                        if (companion.imagemSpriteCaminho.isNotBlank()) {
                            ImagemCompanheiro(
                                caminho = companion.imagemSpriteCaminho,
                                modifier = Modifier.size(64.dp)
                            )
                        } else {
                            CompanionPixelArt(
                                especie = companion.species,
                                rank = companion.rank,
                                modifier = Modifier.size(64.dp)
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
                    "INIMIGO",
                    color = Color.Red,
                    fontWeight = FontWeight.Bold
                )

                if (state.enemy.spriteUrl.startsWith("https://") || state.enemy.spriteUrl.startsWith("http://")) {
                    AsyncImage(
                        model = state.enemy.spriteUrl,
                        contentDescription = "Imagem de ${state.enemy.name}",
                        modifier = Modifier.size(82.dp),
                        contentScale = ContentScale.Fit
                    )
                } else {
                    Text(
                        "👹",
                        fontSize = 64.sp
                    )
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
                onClick = {
                    if (!finalizacaoEnviada) {
                        finalizacaoEnviada = true
                        onEndCombat()
                    }
                },
                enabled = !finalizacaoEnviada,
                modifier = Modifier.fillMaxWidth()
            ) {
                Text(
                    if (finalizacaoEnviada) {
                        "ENCERRANDO..."
                    } else {
                        "ENCERRAR COMBATE"
                    }
                )
            }
        }
    }
}
