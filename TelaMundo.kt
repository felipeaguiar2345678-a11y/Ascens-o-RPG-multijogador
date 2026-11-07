
package br.com.ascensaodosoberano.exploration

import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import br.com.ascensaodosoberano.companions.ImagemCompanheiro
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.material3.Text
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.height
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.geometry.Offset
import androidx.compose.runtime.withFrameNanos
import br.com.ascensaodosoberano.companions.Companion
import br.com.ascensaodosoberano.multiplayer.PresenceRepository
import br.com.ascensaodosoberano.multiplayer.JogadorOnline
import androidx.compose.foundation.layout.BoxWithConstraints
import androidx.compose.foundation.layout.widthIn
import androidx.compose.foundation.background
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.ui.text.style.TextAlign
import kotlinx.coroutines.delay

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
    aoSelecionarJogador: (JogadorOnline) -> Unit = {}
){
    var direcao by remember {
        mutableStateOf(MovementDirection())
    }
    val estadoAtualizado by rememberUpdatedState(estado)
    val direcaoAtualizada by rememberUpdatedState(direcao)
    val atualizarEstado by rememberUpdatedState(aoAtualizarEstado)
    val presenceRepository = remember { PresenceRepository() }
    var jogadoresNaArea by remember { mutableStateOf<List<JogadorOnline>>(emptyList()) }
    val selecionarJogadorAtualizado by rememberUpdatedState(aoSelecionarJogador)

    DisposableEffect(uidJogador, worldPointId) {
        val uid = uidJogador
        val listener = if (!uid.isNullOrBlank()) {
            presenceRepository.observarJogadoresNaArea(
                worldPointId = worldPointId,
                uidAtual = uid,
                aoAtualizar = { jogadoresNaArea = it },
                aoFalhar = { }
            )
        } else null
        onDispose {
            listener?.remove()
            jogadoresNaArea = emptyList()
        }
    }

    LaunchedEffect(uidJogador, nomeJogador, nivelJogador, vidaJogador, vidaMaximaJogador, ataqueJogador, defesaJogador, manaJogador, manaMaximaJogador, agilidadeJogador, poderMagicoJogador, worldPointId) {
        val uid = uidJogador
        if (!uid.isNullOrBlank()) {
            while (true) {
                runCatching {
                    val posicao = estadoAtualizado.posicaoNoMapa
                    presenceRepository.publicar(
                        uid = uid,
                        nome = nomeJogador,
                        nivel = nivelJogador,
                        worldPointId = worldPointId,
                        x = posicao.x,
                        y = posicao.y,
                        vida = vidaJogador,
                        vidaMaxima = vidaMaximaJogador,
                        ataque = ataqueJogador,
                        defesa = defesaJogador,
                        mana = manaJogador,
                        manaMaxima = manaMaximaJogador,
                        agilidade = agilidadeJogador,
                        poderMagico = poderMagicoJogador
                    )
                }
                delay(3_000L)
            }
        }
    }

    var posicaoCompanheiro by remember(companheiro?.id) {
    mutableStateOf(
        estado.posicaoNoMapa.copy(
            x = if (estado.posicaoNoMapa.x >= 0.08f) {
                estado.posicaoNoMapa.x - 0.04f
            } else {
                (estado.posicaoNoMapa.x + 0.04f).coerceAtMost(1f)
            },
            y = estado.posicaoNoMapa.y
        )
    )
}
        LaunchedEffect(companheiro?.id) {
    var instanteAnterior = 0L

    while (true) {
        withFrameNanos { instanteAtual ->
            if (instanteAnterior != 0L) {
                val deltaTime =
                    ((instanteAtual - instanteAnterior) / 1_000_000_000f)
                        .coerceAtMost(0.05f)

                val estadoAgora = estadoAtualizado
                val direcaoAgora = direcaoAtualizada

                if (estadoAgora.modo != ModoCenaMundo.COMBATE) {
                    val jogadorMovendo =
                        direcaoAgora.x != 0f || direcaoAgora.y != 0f

                    val novaPosicao = if (jogadorMovendo) {
                        WorldMapSystem.move(
                            estadoAgora.posicaoNoMapa,
                            direcaoAgora,
                            deltaTime
                        )
                    } else {
                        estadoAgora.posicaoNoMapa
                    }

                    if (companheiro != null) {
                        posicaoCompanheiro =
                            CompanionFollowSystem.follow(
                                novaPosicao,
                                posicaoCompanheiro,
                                deltaTime
                            )
                    }

                    if (jogadorMovendo) {
                        atualizarEstado(
                            estadoAgora.copy(
                                posicaoNoMapa = novaPosicao
                            )
                        )
                    }
                }
            }

            instanteAnterior = instanteAtual
        }
    }
}
            BoxWithConstraints(
        modifier = modifier.fillMaxSize()
    ) {
        val larguraCena = maxWidth
        val alturaCena = maxHeight
                Canvas(
            modifier = Modifier.fillMaxSize()
        ) {
            drawRect(
                color = Color(0xFF263D2B)
            )


                        val tamanho = 64.dp.toPx()

            val deslocamentoCameraX =
                -(estado.posicaoNoMapa.x - 0.5f) * tamanho * 13f

            val deslocamentoCameraY =
                -(estado.posicaoNoMapa.y - 0.5f) * tamanho * 21f

            for (x in -12..24) {
                for (y in -12..32) {
                    val cor = if ((x + y) % 2 == 0) {
                        Color(0xFF304C32)
                    } else {
                        Color(0xFF29432E)
                    }

                    drawRect(
                        color = cor,
                        topLeft = Offset(
                            x * tamanho + deslocamentoCameraX,
                            y * tamanho + deslocamentoCameraY
                        ),
                        size = androidx.compose.ui.geometry.Size(
                            tamanho,
                            tamanho
                        )
                    )
                }
            }
            // Clareira inicial
drawCircle(
    color = Color(0xFF789653),
    radius = 180.dp.toPx(),
    center = Offset(
        size.width / 2f,
        size.height / 2f
    )
)

// Área de grama mais clara
drawCircle(
    color = Color(0xFF91A85D),
    radius = 115.dp.toPx(),
    center = Offset(
        size.width / 2f,
        size.height / 2f
    )
)
          // Jogador centralizado na tela
            drawCircle(
                color = Color(0xFFE7D3A0),
                radius = 18.dp.toPx(),
                center = Offset(
                    size.width / 2f,
                    size.height / 2f
                )
            )

            drawCircle(
                color = Color(0xFF5B4128),
                radius = 18.dp.toPx(),
                center = Offset(
                    size.width / 2f,
                    size.height / 2f
                ),
                                style = Stroke(width = 3.dp.toPx())
            )
        }

                jogadoresNaArea.forEach { outroJogador ->
            Column(
                modifier = Modifier
                    .align(Alignment.Center)
                    .offset(
                        x = larguraCena * (outroJogador.x - estado.posicaoNoMapa.x) * 13f,
                        y = alturaCena * (outroJogador.y - estado.posicaoNoMapa.y) * 21f
                    )
                    .widthIn(max = 112.dp)
                    .background(
                        color = Color(0xCC17251B),
                        shape = RoundedCornerShape(8.dp)
                    )
                    .padding(horizontal = 6.dp, vertical = 4.dp),
                horizontalAlignment = Alignment.CenterHorizontally
            ) {
                Text("●", color = Color(0xFF79D7FF), fontSize = 22.sp)
                Text(
                    text = "${outroJogador.nome} · Nv. ${outroJogador.nivel}",
                    color = Color.White,
                    fontSize = 10.sp,
                    textAlign = TextAlign.Center,
                    maxLines = 2
                )
                androidx.compose.material3.TextButton(
                    onClick = { selecionarJogadorAtualizado(outroJogador) },
                    contentPadding = androidx.compose.foundation.layout.PaddingValues(
                        horizontal = 5.dp, vertical = 0.dp
                    )
                ) {
                    Text("Interagir", fontSize = 9.sp)
                }
            }
        }

        if (companheiro != null &&
            companheiro.imagemSpriteCaminho.isNotBlank()
        ) {
            ImagemCompanheiro(
                caminho = companheiro.imagemSpriteCaminho,
                modifier = Modifier
                    .align(Alignment.Center)
                    .offset(
                        x = 64.dp * (posicaoCompanheiro.x - estado.posicaoNoMapa.x) * 13f,
                        y = 64.dp * (posicaoCompanheiro.y - estado.posicaoNoMapa.y) * 21f
                    )
                    .size(48.dp)
            )
        }
        
        Column(
            modifier = Modifier
                .align(Alignment.TopCenter)
                .padding(top = 16.dp),
            horizontalAlignment = Alignment.CenterHorizontally
        ) {
            Text(
                text = when (estado.modo) {
                    ModoCenaMundo.VIAGEM -> "VIAGEM"
                    ModoCenaMundo.EXPLORACAO -> "EXPLORAÇÃO"
                    ModoCenaMundo.COMBATE -> "COMBATE"
                },
                color = Color.White,
                fontSize = 18.sp
            )

            Spacer(modifier = Modifier.height(4.dp))

            Text(
                text = "Mundo em exploração",
                color = Color(0xFFE0C58D),
                fontSize = 12.sp
            )
        }

                if (estado.modo != ModoCenaMundo.COMBATE) {
            ControleVirtual(
                onDirectionChange = { direcao = it },
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .padding(bottom = 24.dp)
            )
        }

        if (estado.modo == ModoCenaMundo.COMBATE) {
            Box(
                modifier = Modifier
                    .align(Alignment.BottomCenter)
                    .fillMaxWidth()
                    .height(360.dp)
            ) {
                conteudoCombate?.invoke(Modifier.fillMaxSize())
            }
        }
    }
}