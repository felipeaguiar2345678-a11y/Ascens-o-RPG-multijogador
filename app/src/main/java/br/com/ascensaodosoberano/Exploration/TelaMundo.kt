package br.com.ascensaodosoberano.exploration

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import coil.compose.AsyncImage
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import br.com.ascensaodosoberano.companions.Companion
import br.com.ascensaodosoberano.companions.CompanionPixelArt
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
    aoPercorrer: (Float) -> Unit = {},
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
    ferreiroDisponivel: Boolean = false
) {
    var direcao by remember { mutableStateOf(MovementDirection()) }
    var mostrarCinematicaCombate by remember { mutableStateOf(false) }
    LaunchedEffect(estado.modo) {
        if (estado.modo == ModoCenaMundo.COMBATE) {
            mostrarCinematicaCombate = true
            delay(1_250L)
            mostrarCinematicaCombate = false
        } else {
            mostrarCinematicaCombate = false
        }
    }
    var quadroCaminhada by remember { mutableIntStateOf(0) }
    LaunchedEffect(direcao.x, direcao.y, estado.modo) {
        if (direcao.x != 0f || direcao.y != 0f) {
            while (true) {
                delay(150L)
                quadroCaminhada = (quadroCaminhada + 1) % 4
            }
        } else {
            quadroCaminhada = 0
        }
    }
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
        val pointId = worldPointId.ifBlank { "clareira_inicial" }

        Canvas(Modifier.fillMaxSize()) {
            val tile = 92.dp.toPx()
            val cameraX = -(estado.posicaoNoMapa.x - 0.5f) * tile * 15f
            val cameraY = -(estado.posicaoNoMapa.y - 0.5f) * tile * 18f
            val forest = pointId.contains("floresta") ||
                pointId == "clareira_inicial" || pointId == "eldarion" ||
                pointId == "vila_verdejante" || pointId == "dark_forest"
            val snow = pointId.contains("gelo") || pointId.contains("neve") ||
                pointId.contains("montanha") || pointId.contains("frost")
            val desert = pointId.contains("deserto") || pointId.contains("areia") ||
                pointId.contains("desert")
            val ruins = pointId.contains("ruin") || pointId.contains("ruinas")
            val abyss = pointId.contains("abismo") || pointId.contains("abyss")
            val deadLands = pointId.contains("mortas") || pointId.contains("dead") || pointId.contains("nhar")
            val darkBiome = pointId.contains("sombras") || abyss || deadLands

            val ground = when {
                snow -> Color(0xFFB9CED0)
                desert -> Color(0xFFB99A5E)
                ruins -> Color(0xFF77796E)
                abyss -> Color(0xFF343044)
                deadLands -> Color(0xFF4A493C)
                darkBiome -> Color(0xFF344638)
                forest -> Color(0xFF527C42)
                else -> Color(0xFF8B7848)
            }
            val patchColor = when {
                snow -> Color(0xFFE5F0E9)
                desert -> Color(0xFFD9B875)
                ruins -> Color(0xFF99998B)
                abyss -> Color(0xFF66527E)
                deadLands -> Color(0xFF68634D)
                darkBiome -> Color(0xFF53694A)
                forest -> Color(0xFF6D914D)
                else -> Color(0xFFA99A62)
            }
            drawRect(ground)

            // Camadas de terreno: manchas orgânicas quebram o aspecto quadriculado.
            for (i in -5..14) {
                for (j in -6..18) {
                    val x = i * tile + cameraX
                    val y = j * tile + cameraY
                    val seed = abs(i * 73 + j * 139)
                    if (seed % 4 == 0) {
                        drawOval(
                            color = patchColor.copy(alpha = 0.48f),
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
            drawPath(path, if (snow) Color(0xFFE5D9B8) else if (desert) Color(0xFFD9BD82) else Color(0xFFB69A63), style = Stroke(tile * .24f))
            drawPath(path, if (snow) Color(0xFFB8AA8E) else Color(0xFF8B6A43), style = Stroke(tile * .035f))

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
            if (!desert && !deadLands && !abyss) {
                drawPath(stream, Color(0xFF574F37), style = Stroke(tile * .30f))
                drawPath(stream, if (snow) Color(0xFF80B8C9) else Color(0xFF438DA0), style = Stroke(tile * .22f))
                drawPath(stream, Color(0xFFBDE9E8).copy(alpha = .72f), style = Stroke(tile * .025f))
                // Ponte de madeira atravessando o riacho na rota principal.
                val bridgeY = size.height * .54f
                drawRoundRect(Color(0xFF503A2B), Offset(size.width * .745f, bridgeY - 9.dp.toPx()), Size(size.width * .15f, 19.dp.toPx()), androidx.compose.ui.geometry.CornerRadius(3.dp.toPx()))
                for (plank in 0..5) {
                    val px = size.width * .75f + plank * size.width * .024f
                    drawLine(Color(0xFFC49A61), Offset(px, bridgeY - 7.dp.toPx()), Offset(px, bridgeY + 7.dp.toPx()), 2.dp.toPx())
                }
                drawLine(Color(0xFFE0BD7F), Offset(size.width * .75f, bridgeY - 8.dp.toPx()), Offset(size.width * .89f, bridgeY - 8.dp.toPx()), 2.dp.toPx())
                drawLine(Color(0xFFE0BD7F), Offset(size.width * .75f, bridgeY + 8.dp.toPx()), Offset(size.width * .89f, bridgeY + 8.dp.toPx()), 2.dp.toPx())
            }

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
                    if (forest && distanceFromPlayer > tile * 1.05f && seed % 5 != 0) {
                        drawRect(Color(0xFF59432D),
                            Offset(center.x - tile * .055f, center.y + tile * .02f),
                            Size(tile * .11f, tile * .25f))
                        drawCircle(if (darkBiome) Color(0xFF182F2B) else if (snow) Color(0xFF537A72) else Color(0xFF234A32), tile * .30f,
                            Offset(center.x, center.y - tile * .10f))
                        drawCircle(if (darkBiome) Color(0xFF294638) else if (snow) Color(0xFF7DA59A) else Color(0xFF32633B), tile * .235f,
                            Offset(center.x - tile * .11f, center.y - tile * .20f))
                        drawRect(if (snow) Color(0xFFB8D4C3) else Color(0xFF6D9950),
                            Offset(center.x - tile * .16f, center.y - tile * .28f),
                            Size(tile * .12f, tile * .055f))
                        drawRect(Color(0xFF183D2B),
                            Offset(center.x + tile * .07f, center.y - tile * .04f),
                            Size(tile * .09f, tile * .07f))
                    }
                }
            }

            // Pequeno acampamento de madeira na clareira inicial.
            if (forest && !darkBiome) {
                val hutX = size.width * .16f + cameraX * .08f
                val hutY = size.height * .23f + cameraY * .08f
                drawRect(Color(0xFF65452F), Offset(hutX, hutY + 20.dp.toPx()), Size(58.dp.toPx(), 34.dp.toPx()))
                drawRect(Color(0xFF9B7047), Offset(hutX - 5.dp.toPx(), hutY + 14.dp.toPx()), Size(68.dp.toPx(), 8.dp.toPx()))
                val roof = Path().apply {
                    moveTo(hutX - 8.dp.toPx(), hutY + 15.dp.toPx())
                    lineTo(hutX + 29.dp.toPx(), hutY - 10.dp.toPx())
                    lineTo(hutX + 66.dp.toPx(), hutY + 15.dp.toPx())
                    close()
                }
                drawPath(roof, Color(0xFF49352D))
                drawRect(Color(0xFF30251F), Offset(hutX + 23.dp.toPx(), hutY + 31.dp.toPx()), Size(13.dp.toPx(), 23.dp.toPx()))
                drawCircle(Color(0xFFFFB34F).copy(alpha = .8f), 8.dp.toPx(), Offset(hutX + 82.dp.toPx(), hutY + 48.dp.toPx()))
                drawCircle(Color(0xFFFFE08A).copy(alpha = .85f), 4.dp.toPx(), Offset(hutX + 82.dp.toPx(), hutY + 48.dp.toPx()))
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

            // Ruínas antigas: colunas partidas, blocos caídos e inscrições gastas.
            if (ruins) {
                for (i in 0..10) {
                    val x = (i * 181f + cameraX * .38f + 29f).mod(size.width + 60f) - 30f
                    val y = (i * 113f + cameraY * .34f + 43f).mod(size.height + 60f) - 30f
                    if (i % 3 == 0) {
                        drawRect(Color(0xFF4B4D49), Offset(x, y), Size(18.dp.toPx(), 38.dp.toPx()))
                        drawRect(Color(0xFFA9A99A), Offset(x - 4.dp.toPx(), y - 3.dp.toPx()), Size(26.dp.toPx(), 7.dp.toPx()))
                        drawRect(Color(0xFF62645D), Offset(x + 4.dp.toPx(), y + 10.dp.toPx()), Size(3.dp.toPx(), 15.dp.toPx()))
                    } else {
                        drawRect(Color(0xFF66685F), Offset(x, y), Size(25.dp.toPx(), 12.dp.toPx()))
                        drawRect(Color(0xFF9B9A8C), Offset(x + 4.dp.toPx(), y - 3.dp.toPx()), Size(12.dp.toPx(), 4.dp.toPx()))
                    }
                }
            }

            // Vale do Abismo: fissuras violetas e cristais de energia no solo.
            if (abyss) {
                for (i in 0..8) {
                    val x = (i * 157f + cameraX * .25f + 17f).mod(size.width)
                    val y = (i * 97f + cameraY * .22f + 31f).mod(size.height)
                    drawLine(Color(0xFF9C69C8).copy(alpha = .75f), Offset(x, y), Offset(x + 13.dp.toPx(), y + 21.dp.toPx()), 2.dp.toPx())
                    drawLine(Color(0xFFD8A8FF).copy(alpha = .6f), Offset(x + 5.dp.toPx(), y + 7.dp.toPx()), Offset(x + 16.dp.toPx(), y + 2.dp.toPx()), 1.dp.toPx())
                    drawCircle(Color(0xFFB68AE8).copy(alpha = .45f), 3.dp.toPx(), Offset(x + 15.dp.toPx(), y + 19.dp.toPx()))
                }
            }

            // Terras Mortas: árvores secas sem copa, com galhos retorcidos.
            if (deadLands) {
                for (i in 0..9) {
                    val x = (i * 211f + cameraX * .44f + 23f).mod(size.width)
                    val y = (i * 139f + cameraY * .41f + 37f).mod(size.height)
                    drawRect(Color(0xFF514333), Offset(x, y), Size(5.dp.toPx(), 42.dp.toPx()))
                    drawLine(Color(0xFF514333), Offset(x + 2.dp.toPx(), y + 12.dp.toPx()), Offset(x - 13.dp.toPx(), y - 1.dp.toPx()), 3.dp.toPx())
                    drawLine(Color(0xFF514333), Offset(x + 3.dp.toPx(), y + 20.dp.toPx()), Offset(x + 16.dp.toPx(), y + 5.dp.toPx()), 3.dp.toPx())
                    drawLine(Color(0xFF514333), Offset(x + 2.dp.toPx(), y + 28.dp.toPx()), Offset(x - 10.dp.toPx(), y + 18.dp.toPx()), 2.dp.toPx())
                }
            }

            // Detalhes de cenário: raízes, troncos caídos, pedras em camadas e tufos de capim.
            for (i in 0..17) {
                val seed = i * 211
                val x = (seed * 1.37f + cameraX * .43f + 23f).mod(size.width + 80f) - 40f
                val y = (seed * .83f + cameraY * .39f + 47f).mod(size.height + 80f) - 40f
                if (i % 4 == 0) {
                    drawRoundRect(Color(0xFF5A432D), Offset(x, y), Size(34.dp.toPx(), 8.dp.toPx()), androidx.compose.ui.geometry.CornerRadius(4.dp.toPx()))
                    drawCircle(Color(0xFF9A7547), 4.dp.toPx(), Offset(x + 5.dp.toPx(), y + 4.dp.toPx()))
                    drawLine(Color(0xFFB58B56), Offset(x + 13.dp.toPx(), y + 2.dp.toPx()), Offset(x + 27.dp.toPx(), y + 2.dp.toPx()), 1.5.dp.toPx())
                } else if (i % 3 == 0) {
                    drawOval(Color(0xFF58645A), Offset(x, y), Size(19.dp.toPx(), 11.dp.toPx()))
                    drawOval(Color(0xFF89958A), Offset(x + 3.dp.toPx(), y + 1.dp.toPx()), Size(9.dp.toPx(), 4.dp.toPx()))
                } else {
                    val blade = if (snow) Color(0xFF668E8C) else if (desert) Color(0xFF827344) else Color(0xFF345D35)
                    drawLine(blade, Offset(x, y + 8.dp.toPx()), Offset(x - 3.dp.toPx(), y), 1.5.dp.toPx())
                    drawLine(blade, Offset(x + 2.dp.toPx(), y + 8.dp.toPx()), Offset(x + 5.dp.toPx(), y - 2.dp.toPx()), 1.5.dp.toPx())
                    drawLine(blade, Offset(x + 4.dp.toPx(), y + 8.dp.toPx()), Offset(x + 9.dp.toPx(), y + 2.dp.toPx()), 1.2.dp.toPx())
                }
            }

            // Pequenos cogumelos luminosos na sombra das árvores.
            if (forest || darkBiome) {
                for (i in 0..7) {
                    val x = (i * 193f + cameraX * .57f + 37f).mod(size.width)
                    val y = (i * 109f + cameraY * .48f + 61f).mod(size.height)
                    drawRect(Color(0xFFE7D6B5), Offset(x, y), Size(3.dp.toPx(), 7.dp.toPx()))
                    drawOval(if (darkBiome) Color(0xFFB96D8B) else Color(0xFFD98A59), Offset(x - 3.dp.toPx(), y - 3.dp.toPx()), Size(9.dp.toPx(), 5.dp.toPx()))
                    drawCircle(Color(0xFFFFE6B8).copy(alpha = .75f), 1.2.dp.toPx(), Offset(x, y - 1.dp.toPx()))
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

            
        }


        // Barra superior fixa: retorno ao mapa e status do personagem.
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopCenter)
                .padding(horizontal = 12.dp, vertical = 10.dp),
            horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top
        ) {
            if (estado.modo != ModoCenaMundo.COMBATE) {
                androidx.compose.material3.Button(
                    onClick = aoVoltar,
                    contentPadding = PaddingValues(horizontal = 14.dp, vertical = 8.dp)
                ) {
                    Text("← Mapa", fontSize = 13.sp)
                }
            }

            Column(
                modifier = Modifier
                    .widthIn(min = 176.dp, max = 210.dp)
                    .background(Color(0xE817202B), RoundedCornerShape(12.dp))
                    .padding(horizontal = 11.dp, vertical = 8.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp)
            ) {
                Text("$nomeJogador · Nv. $nivelJogador", color = Color.White, fontSize = 12.sp)
                Text("VIDA  $vidaJogador / $vidaMaximaJogador", color = Color(0xFFFF8585), fontSize = 11.sp)
                Box(Modifier.fillMaxWidth().height(6.dp).background(Color(0xFF51383D), RoundedCornerShape(5.dp))) {
                    Box(Modifier.fillMaxWidth(if (vidaMaximaJogador > 0) (vidaJogador.toFloat() / vidaMaximaJogador).coerceIn(0f, 1f) else 0f).height(6.dp).background(Color(0xFFE34E5B), RoundedCornerShape(5.dp)))
                }
                if (estado.modo != ModoCenaMundo.COMBATE) {
                    Row(Modifier.fillMaxWidth(), horizontalArrangement = androidx.compose.foundation.layout.Arrangement.spacedBy(4.dp)) {
                        listOf("BOLSA" to "INVENTARIO", "STATUS" to "STATUS", "BESTIÁRIO" to "BESTIARIO", "MULTI" to "MULTIPLAYER").forEach { (label, key) ->
                            Box(
                                Modifier.weight(1f).background(Color(0xFF35465B), RoundedCornerShape(6.dp))
                                    .clickable { aoAbrirPainel(key) }.padding(horizontal = 3.dp, vertical = 6.dp),
                                contentAlignment = Alignment.Center
                            ) {
                                Text(label, color = Color(0xFFFFE2AE), fontSize = 8.sp, textAlign = TextAlign.Center, maxLines = 1)
                            }
                        }
                    }
                }
                Text("MANA  $manaJogador / $manaMaximaJogador", color = Color(0xFF8EDBFF), fontSize = 11.sp)
                Box(Modifier.fillMaxWidth().height(5.dp).background(Color(0xFF293F50), RoundedCornerShape(5.dp))) {
                    Box(Modifier.fillMaxWidth(if (manaMaximaJogador > 0) (manaJogador.toFloat() / manaMaximaJogador).coerceIn(0f, 1f) else 0f).height(5.dp).background(Color(0xFF36A9E8), RoundedCornerShape(5.dp)))
                }
                val xpNecessario = (nivelJogador * 100).coerceAtLeast(100)
                Text("XP  $xpAtual / $xpNecessario", color = Color(0xFFFFD879), fontSize = 11.sp)
                Box(Modifier.fillMaxWidth().height(5.dp).background(Color(0xFF51482F), RoundedCornerShape(5.dp))) {
                    Box(Modifier.fillMaxWidth((xpAtual.toFloat() / xpNecessario).coerceIn(0f, 1f)).height(5.dp).background(Color(0xFFE9B94F), RoundedCornerShape(5.dp)))
                }
                if (estado.modo != ModoCenaMundo.COMBATE && ferreiroDisponivel) {
                    Box(
                        Modifier.fillMaxWidth().background(Color(0xFF59452D), RoundedCornerShape(6.dp))
                            .clickable { aoAbrirPainel("FERREIRO") }.padding(vertical = 6.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text("⚒ FERREIRO DA CIDADE", color = Color(0xFFFFE2AE), fontSize = 10.sp)
                    }
                }
            }
        }

        if ((imagemPersonagemUrl.startsWith("https://") || imagemPersonagemUrl.startsWith("http://")) && equipamentosVestidos.isEmpty()) {
            AsyncImage(
                model = imagemPersonagemUrl,
                contentDescription = "Personagem do jogador",
                modifier = Modifier.align(Alignment.Center).size(104.dp),
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
                modifier = Modifier.align(Alignment.Center)
                    .offset(y = if (direcao.x != 0f || direcao.y != 0f) {
                        if (quadroCaminhada % 2 == 0) (-2).dp else 0.dp
                    } else 0.dp)
                    .size(104.dp),
                equippedEquipment = equipamentosVestidos,
                equipmentLoadout = espacosEquipamento
            )
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

        if (companheiro != null) {
            val companionModifier = Modifier.align(Alignment.Center)
                .offset(
                    x = 64.dp * (posicaoCompanheiro.x - estado.posicaoNoMapa.x) * 13f,
                    y = 64.dp * (posicaoCompanheiro.y - estado.posicaoNoMapa.y) * 18f
                ).size(48.dp)
            if (companheiro.imagemSpriteCaminho.isNotBlank()) {
                ImagemCompanheiro(
                    caminho = companheiro.imagemSpriteCaminho,
                    modifier = companionModifier,
                    especie = companheiro.species,
                    rank = companheiro.rank,
                    mutacao = companheiro.mutationId,
                    estagio = companheiro.stage
                )
            } else {
                CompanionPixelArt(especie = companheiro.species, rank = companheiro.rank, modifier = companionModifier)
            }
        }

        if (estado.modo != ModoCenaMundo.COMBATE) {
            androidx.compose.material3.Button(
                onClick = aoExplorar,
                modifier = Modifier.align(Alignment.BottomEnd).padding(end = 16.dp, bottom = 22.dp),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 11.dp)
            ) {
                Text("Explorar", fontSize = 14.sp)
            }
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

        AnimatedVisibility(
            visible = mostrarCinematicaCombate,
            modifier = Modifier.fillMaxSize(),
            enter = fadeIn(tween(180)) + scaleIn(initialScale = 1.08f, animationSpec = tween(420)),
            exit = fadeOut(tween(420))
        ) {
            Box(
                modifier = Modifier.fillMaxSize()
                    .background(Color(0xD90A101A)),
                contentAlignment = Alignment.Center
            ) {
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    Text(
                        "⚔  ENCONTRO!  ⚔",
                        color = Color(0xFFFFD879),
                        fontSize = 30.sp,
                        textAlign = TextAlign.Center
                    )
                    Spacer(Modifier.height(8.dp))
                    Text(
                        "Uma criatura surgiu no caminho...",
                        color = Color.White,
                        fontSize = 15.sp,
                        textAlign = TextAlign.Center
                    )
                }
            }
        }
    }
}
