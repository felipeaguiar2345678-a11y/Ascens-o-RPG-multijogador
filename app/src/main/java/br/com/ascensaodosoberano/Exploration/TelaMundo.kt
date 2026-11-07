package br.com.ascensaodosoberano.exploration

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import br.com.ascensaodosoberano.companions.Companion
import br.com.ascensaodosoberano.companions.ImagemCompanheiro
import br.com.ascensaodosoberano.multiplayer.PresenceRepository
import br.com.ascensaodosoberano.multiplayer.JogadorOnline
import kotlinx.coroutines.delay
import kotlin.math.abs
import kotlin.math.sqrt

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
    aoPercorrer: (Float) -> Unit = {}
) {
    var direcao by remember { mutableStateOf(MovementDirection()) }
    val estadoAtualizado by rememberUpdatedState(estado)
    val direcaoAtualizada by rememberUpdatedState(direcao)
    val atualizarEstado by rememberUpdatedState(aoAtualizarEstado)
    val percorrerAtualizado by rememberUpdatedState(aoPercorrer)
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
                aoFalhar = {}
            )
        } else null
        onDispose {
            listener?.remove()
            jogadoresNaArea = emptyList()
        }
    }

    LaunchedEffect(uidJogador, nomeJogador, nivelJogador, vidaJogador, vidaMaximaJogador,
        ataqueJogador, defesaJogador, manaJogador, manaMaximaJogador, agilidadeJogador,
        poderMagicoJogador, worldPointId) {
        val uid = uidJogador
        if (!uid.isNullOrBlank()) {
            while (true) {
                runCatching {
                    val pos = estadoAtualizado.posicaoNoMapa
                    presenceRepository.publicar(
                        uid = uid, nome = nomeJogador, nivel = nivelJogador,
                        worldPointId = worldPointId, x = pos.x, y = pos.y,
                        vida = vidaJogador, vidaMaxima = vidaMaximaJogador,
                        ataque = ataqueJogador, defesa = defesaJogador,
                        mana = manaJogador, manaMaxima = manaMaximaJogador,
                        agilidade = agilidadeJogador, poderMagico = poderMagicoJogador
                    )
                }
                delay(3_000L)
            }
        }
    }

    var posicaoCompanheiro by remember(companheiro?.id) {
        mutableStateOf(estado.posicaoNoMapa.copy(
            x = (estado.posicaoNoMapa.x - 0.035f).coerceAtLeast(0f)
        ))
    }

    LaunchedEffect(companheiro?.id) {
        var anterior = 0L
        while (true) {
            withFrameNanos { agora ->
                if (anterior != 0L && estadoAtualizado.modo != ModoCenaMundo.COMBATE) {
                    val dt = ((agora - anterior) / 1_000_000_000f).coerceAtMost(0.05f)
                    val dir = direcaoAtualizada
                    val movendo = dir.x != 0f || dir.y != 0f
                    val posicaoAnterior = estadoAtualizado.posicaoNoMapa
                    val nova = if (movendo) WorldMapSystem.move(
                        posicaoAnterior, dir, dt
                    ) else posicaoAnterior
                    if (movendo) {
                        val dx = nova.x - posicaoAnterior.x
                        val dy = nova.y - posicaoAnterior.y
                        val distancia = sqrt(dx * dx + dy * dy)
                        if (distancia > 0f) percorrerAtualizado(distancia)
                    }
                    if (companheiro != null) {
                        posicaoCompanheiro = CompanionFollowSystem.follow(
                            nova, posicaoCompanheiro, dt
                        )
                    }
                    if (movendo) atualizarEstado(estadoAtualizado.copy(posicaoNoMapa = nova))
                }
                anterior = agora
            }
        }
    }

    BoxWithConstraints(modifier = modifier.fillMaxSize()) {
        val sceneWidth = maxWidth
        val sceneHeight = maxHeight

        Canvas(Modifier.fillMaxSize()) {
            val tile = 92.dp.toPx()
            val cameraX = -(estado.posicaoNoMapa.x - 0.5f) * tile * 15f
            val cameraY = -(estado.posicaoNoMapa.y - 0.5f) * tile * 18f
            val forest = worldPointId.contains("floresta") ||
                worldPointId == "clareira_inicial" || worldPointId == "eldarion" ||
                worldPointId == "vila_verdejante"

            val ground = if (forest) Color(0xFF527C42) else Color(0xFF8B7848)
            drawRect(ground)

            // Camadas de terreno: manchas orgânicas quebram o aspecto quadriculado.
            for (i in -5..14) {
                for (j in -6..18) {
                    val x = i * tile + cameraX
                    val y = j * tile + cameraY
                    val seed = abs(i * 73 + j * 139)
                    if (seed % 4 == 0) {
                        drawOval(
                            color = Color(0xFF6D914D).copy(alpha = 0.48f),
                            topLeft = Offset(x + tile * .12f, y + tile * .18f),
                            size = Size(tile * .78f, tile * .52f)
                        )
                    }
                    if (seed % 7 == 0) {
                        drawCircle(
                            Color(0xFFB1A56A).copy(alpha = .30f),
                            radius = tile * .055f,
                            center = Offset(x + tile * .68f, y + tile * .72f)
                        )
                    }
                }
            }

            // Trilha de terra sinuosa que atravessa a clareira.
            val path = Path().apply {
                moveTo(-tile, size.height * .74f + cameraY * .12f)
                cubicTo(size.width * .20f, size.height * .63f,
                    size.width * .28f, size.height * .84f,
                    size.width * .49f, size.height * .61f)
                cubicTo(size.width * .68f, size.height * .40f,
                    size.width * .79f, size.height * .63f,
                    size.width + tile, size.height * .42f)
            }
            drawPath(path, Color(0xFFB69A63), style = Stroke(tile * .24f))
            drawPath(path, Color(0xFF8B6A43), style = Stroke(tile * .035f))

            // Pequeno riacho ao fundo, com margens de pedra.
            val stream = Path().apply {
                moveTo(size.width * .82f + cameraX * .08f, -tile)
                cubicTo(size.width * .72f, size.height * .22f,
                    size.width * .94f, size.height * .35f,
                    size.width * .80f, size.height * .53f)
                cubicTo(size.width * .70f, size.height * .70f,
                    size.width * .90f, size.height * .82f,
                    size.width * .84f, size.height + tile)
            }
            drawPath(stream, Color(0xFF574F37), style = Stroke(tile * .30f))
            drawPath(stream, Color(0xFF438DA0), style = Stroke(tile * .22f))
            drawPath(stream, Color(0xFF9BD5D1).copy(alpha = .65f), style = Stroke(tile * .025f))

            // Árvores em camadas, com tronco, copa e pixels de luz.
            for (i in -4..12) {
                for (j in -5..16) {
                    val seed = abs(i * 97 + j * 53)
                    val sx = i * tile * 1.12f + cameraX * .72f + (seed % 31)
                    val sy = j * tile * 1.08f + cameraY * .72f + (seed % 23)
                    val screenX = sx % (size.width + tile) - tile * .5f
                    val screenY = sy % (size.height + tile) - tile * .5f
                    val center = Offset(screenX, screenY)
                    val distanceFromPlayer = sqrt(
                        (screenX - size.width / 2f) * (screenX - size.width / 2f) +
                        (screenY - size.height / 2f) * (screenY - size.height / 2f)
                    )
                    if (distanceFromPlayer > tile * 1.05f && seed % 5 != 0) {
                        drawRect(Color(0xFF59432D),
                            Offset(center.x - tile * .055f, center.y + tile * .02f),
                            Size(tile * .11f, tile * .25f))
                        drawCircle(Color(0xFF234A32), tile * .30f,
                            Offset(center.x, center.y - tile * .10f))
                        drawCircle(Color(0xFF32633B), tile * .235f,
                            Offset(center.x - tile * .11f, center.y - tile * .20f))
                        drawRect(Color(0xFF6D9950),
                            Offset(center.x - tile * .16f, center.y - tile * .28f),
                            Size(tile * .12f, tile * .055f))
                        drawRect(Color(0xFF183D2B),
                            Offset(center.x + tile * .07f, center.y - tile * .04f),
                            Size(tile * .09f, tile * .07f))
                    }
                }
            }

            // Pedras, arbustos e flores espalhados pelo chão.
            for (i in 0..22) {
                val x = (i * 173f + cameraX * .31f + 41f) % size.width
                val y = (i * 127f + cameraY * .27f + 19f) % size.height
                drawOval(Color(0xFF53604A), Offset(x, y), Size(17.dp.toPx(), 9.dp.toPx()))
                if (i % 3 == 0) {
                    drawCircle(Color(0xFFE8D58B), 2.2.dp.toPx(), Offset(x + 8.dp.toPx(), y - 3.dp.toPx()))
                    drawCircle(Color(0xFFD8A6D9), 1.8.dp.toPx(), Offset(x + 13.dp.toPx(), y + 1.dp.toPx()))
                }
            }

            // Iluminação noturna e partículas.
            val night = (1f - daylightFactor.coerceIn(0f, 1f)) * .40f
            if (night > 0f) {
                drawRect(Color(0xFF09172B).copy(alpha = night))
                for (i in 0 until 28) {
                    val x = (i * 137f + 53f) % size.width
                    val y = (i * 83f + 29f) % size.height
                    drawCircle(Color(0xFFD8E9FF).copy(alpha = .65f), 1.4.dp.toPx(), Offset(x, y))
                }
            }

            // Sprite provisório em pixel art do aventureiro: capa, armadura e espada.
            val px = 5.dp.toPx()
            val cx = size.width / 2f
            val cy = size.height / 2f
            drawOval(Color(0xFF1B2C25).copy(alpha = .55f),
                Offset(cx - px * 4f, cy + px * 6f), Size(px * 9f, px * 2.2f))
            drawRect(Color(0xFF7C2632), Offset(cx - px * 3f, cy - px * 1f), Size(px * 6f, px * 7f))
            drawRect(Color(0xFFB33D45), Offset(cx - px * 2f, cy + px * 1f), Size(px * 4f, px * 5f))
            drawRect(Color(0xFF26384A), Offset(cx - px * 2f, cy - px * 5f), Size(px * 4f, px * 6f))
            drawRect(Color(0xFF9AA7B5), Offset(cx - px * 2f, cy - px * 4f), Size(px * 4f, px * 2f))
            drawRect(Color(0xFFE3B98B), Offset(cx - px * 1.5f, cy - px * 9f), Size(px * 3f, px * 4f))
            drawRect(Color(0xFF25232A), Offset(cx - px * 2f, cy - px * 10f), Size(px * 4f, px * 2f))
            drawRect(Color(0xFF25232A), Offset(cx - px * 2f, cy + px * 6f), Size(px * 1.5f, px * 3f))
            drawRect(Color(0xFF25232A), Offset(cx + px * .5f, cy + px * 6f), Size(px * 1.5f, px * 3f))
            drawRect(Color(0xFFD8E2EA), Offset(cx + px * 3f, cy - px * 4f), Size(px * 1.3f, px * 9f))
            drawRect(Color(0xFF8C673B), Offset(cx + px * 2.6f, cy + px * 3f), Size(px * 2f, px * 1.5f))
            drawRect(Color(0xFFFFD98B), Offset(cx - px * 1.5f, cy - px * 3f), Size(px * .8f, px * .8f))
        }

        jogadoresNaArea.forEach { outro ->
            val dx = sceneWidth * (outro.x - estado.posicaoNoMapa.x) * 13f
            val dy = sceneHeight * (outro.y - estado.posicaoNoMapa.y) * 18f
            if (abs(dx.value) < sceneWidth.value && abs(dy.value) < sceneHeight.value) {
                Column(
                    modifier = Modifier.align(Alignment.Center).offset(dx, dy)
                        .widthIn(max = 112.dp)
                        .background(Color(0xCC17251B), RoundedCornerShape(8.dp))
                        .padding(horizontal = 6.dp, vertical = 4.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    Text("●", color = Color(0xFF79D7FF), fontSize = 22.sp)
                    Text("${outro.nome} · Nv. ${outro.nivel}", color = Color.White,
                        fontSize = 10.sp, textAlign = TextAlign.Center, maxLines = 2)
                    androidx.compose.material3.TextButton(
                        onClick = { selecionarJogadorAtualizado(outro) },
                        contentPadding = PaddingValues(horizontal = 5.dp, vertical = 0.dp)
                    ) { Text("Interagir", fontSize = 9.sp) }
                }
            }
        }

        if (companheiro != null && companheiro.imagemSpriteCaminho.isNotBlank()) {
            ImagemCompanheiro(
                caminho = companheiro.imagemSpriteCaminho,
                modifier = Modifier.align(Alignment.Center)
                    .offset(
                        x = 64.dp * (posicaoCompanheiro.x - estado.posicaoNoMapa.x) * 13f,
                        y = 64.dp * (posicaoCompanheiro.y - estado.posicaoNoMapa.y) * 18f
                    ).size(48.dp)
            )
        }

        if (estado.modo != ModoCenaMundo.COMBATE) {
            ControleVirtual(
                onDirectionChange = { direcao = it },
                modifier = Modifier
                    .align(Alignment.BottomStart)
                    .padding(start = 18.dp, bottom = 14.dp)
            )
        }

        if (estado.modo == ModoCenaMundo.COMBATE) {
            Box(
                modifier = Modifier.align(Alignment.BottomCenter)
                    .fillMaxWidth().height(360.dp)
            ) { conteudoCombate?.invoke(Modifier.fillMaxSize()) }
        }
    }
}
