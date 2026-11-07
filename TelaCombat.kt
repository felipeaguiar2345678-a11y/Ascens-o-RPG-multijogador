
package br.com.ascensaodosoberano.combat

import br.com.ascensaodosoberano.companions.ImagemCompanheiro
import androidx.compose.foundation.background
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import br.com.ascensaodosoberano.companions.Companion

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
    modifier: Modifier = Modifier,
    integradoAoMapa: Boolean = false,
    podeAgir: Boolean = true,
    nomeJogadorDoTurno: String = "",
    nomesGrupo: List<String> = emptyList()
) {
    val fundo = Color(0xFF101522)
    val painel = Color(0xFF202B40)
    val borda = Color(0xFFB69A58)

    var finalizacaoEnviada by remember {
        mutableStateOf(false)
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
                        Color(0xCC202B40)
                    } else {
                        painel
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
                    Text(
                        "⚔",
                        fontSize = 64.sp,
                        color = Color.White
                    )

                    if (
                        companion != null &&
                        companion.imagemSpriteCaminho.isNotBlank()
                    ) {
                        ImagemCompanheiro(
                            caminho = companion.imagemSpriteCaminho,
                            modifier = Modifier.size(64.dp)
                        )
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

                Text(
                    "👹",
                    fontSize = 64.sp
                )

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

        // AÇÕES DE COMBATE
        if (state.phase == CombatPhase.PLAYER_TURN && !podeAgir) {
            Text(
                text = if (nomeJogadorDoTurno.isNotBlank()) "Aguardando o turno de $nomeJogadorDoTurno" else "Aguardando outro integrante do grupo...",
                color = Color(0xFF9CC7FF),
                modifier = Modifier.align(Alignment.CenterHorizontally)
            )
        }

        if (state.phase == CombatPhase.PLAYER_TURN && podeAgir) {
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
