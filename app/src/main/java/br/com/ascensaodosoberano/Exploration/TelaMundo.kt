package br.com.ascensaodosoberano.exploration

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.core.tween
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.RepeatMode
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.draw.clip
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
import br.com.ascensaodosoberano.combat.CriaturaPixelArt
import br.com.ascensaodosoberano.companions.CompanionPixelArt
import br.com.ascensaodosoberano.companions.ImagemCompanheiro
import br.com.ascensaodosoberano.multiplayer.PresenceRepository
import br.com.ascensaodosoberano.multiplayer.JogadorOnline
import br.com.ascensaodosoberano.world.WorldMapData
import br.com.ascensaodosoberano.world.WorldPointType
import br.com.ascensaodosoberano.world.WorldSceneCatalog
import br.com.ascensaodosoberano.world.CriaturaGerada
import br.com.ascensaodosoberano.world.RepositorioCriaturas
import br.com.ascensaodosoberano.world.WorldApi
import org.json.JSONObject
import kotlinx.coroutines.delay
import kotlin.math.abs
import kotlin.math.sqrt

private data class CriaturaPosicionadaNoMundo(
    val criatura: CriaturaGerada,
    val x: Float,
    val y: Float,
    val populacao: Int
)

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
    curandeiroDisponivel: Boolean = false,
    criaturaEncontrada: CriaturaGerada? = null,
    buscandoCriaturas: Boolean = false,
    aoEnfrentarCriatura: () -> Unit = {},
    aoIgnorarCriatura: () -> Unit = {},
    aoSelecionarCriaturaNoMundo: (CriaturaGerada) -> Unit = {}
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
    val transicaoAmbiente = rememberInfiniteTransition(label = "ambiente_mundo")
    val faseAmbiente by transicaoAmbiente.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(
            animation = tween(durationMillis = 8_000),
            repeatMode = RepeatMode.Restart
        ),
        label = "movimento_ambiente"
    )
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
    var criaturasNoCenario by remember { mutableStateOf<List<CriaturaPosicionadaNoMundo>>(emptyList()) }
    val selecionarJogadorAtualizado by rememberUpdatedState(aoSelecionarJogador)

    // As espécies registradas no servidor recebem coordenadas persistentes.
    // Cada cliente consulta o mesmo estado e desenha as mesmas criaturas na área.
    LaunchedEffect(uidJogador, worldPointId) {
        criaturasNoCenario = emptyList()
        if (!uidJogador.isNullOrBlank()) {
            val cacheCriaturas = mutableMapOf<String, CriaturaGerada>()
            while (true) {
                runCatching {
                    val regiao = ExplorationSystem.regionForWorldPoint(worldPointId)
                        ?: return@runCatching emptyList<CriaturaPosicionadaNoMundo>()
                    val populacoes = WorldApi.getCreaturePlacements(regiao.ecosystemId)
                        .optJSONArray("creatures")
                        ?: return@runCatching emptyList<CriaturaPosicionadaNoMundo>()
                    val especies = (0 until populacoes.length()).mapNotNull { index ->
                        populacoes.optJSONObject(index)
                    }.take(12)
                    val posicionadas = mutableListOf<CriaturaPosicionadaNoMundo>()
                    for ((index, especie) in especies.withIndex()) {
                        val id = especie.optString("speciesId")
                        if (id.isBlank()) continue
                        val criatura = cacheCriaturas[id]
                            ?: RepositorioCriaturas.buscarCriaturaComImagem(id)
                                ?.also { cacheCriaturas[id] = it }
                            ?: continue
                        val fallbackX = 0.2f + (index % 4) * 0.18f
                        val fallbackY = 0.2f + (index / 4) * 0.2f
                        posicionadas.add(
                            CriaturaPosicionadaNoMundo(
                                criatura = criatura,
                                x = especie.optDouble("spawnX", fallbackX.toDouble()).toFloat(),
                                y = especie.optDouble("spawnY", fallbackY.toDouble()).toFloat(),
                                populacao = especie.optInt("population", 1)
                            )
                        )
                    }
                    posicionadas
                }.onSuccess { criaturasNoCenario = it }
                delay(15_000L)
            }
        }
    }

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
        poderMagicoJogador, imagemPersonagemUrl, worldPointId) {
        val uid = uidJogador
        if (!uid.isNullOrBlank()) {
            while (true) {
                runCatching {
                    val pos = estadoAtualizado.posicaoNoMapa
                    val posicaoOficial = presenceRepository.publicar(
                        uid = uid, nome = nomeJogador, nivel = nivelJogador,
                        worldPointId = worldPointId, x = pos.x, y = pos.y,
                        vida = vidaJogador, vidaMaxima = vidaMaximaJogador,
                        ataque = ataqueJogador, defesa = defesaJogador,
                        mana = manaJogador, manaMaxima = manaMaximaJogador,
                        agilidade = agilidadeJogador, poderMagico = poderMagicoJogador,
                        imagemPersonagemUrl = imagemPersonagemUrl
                    )
                    // Se o servidor rejeitar um salto de posição, o cliente volta
                    // para a última coordenada oficial em vez de divergir do mundo.
                    if (abs(posicaoOficial.x - pos.x) > 0.001f ||
                        abs(posicaoOficial.y - pos.y) > 0.001f
                    ) {
                        atualizarEstado(
                            estadoAtualizado.copy(
                                posicaoNoMapa = WorldPosition(posicaoOficial.x, posicaoOficial.y)
                            )
                        )
                    }
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
                        if (distancia > 0f) percorrerAtualizado(distancia, dir.x, dir.y)
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
        val pontoAtual = WorldMapData.findPoint(pointId)
        val perfilCena = WorldSceneCatalog.profileFor(pointId)
        val zoomCamera by animateFloatAsState(
            targetValue = perfilCena.cameraZoom,
            animationSpec = tween(durationMillis = 850),
            label = "aproximacao_cena_${pointId}"
        )
        val areaSegura = pontoAtual?.type in listOf(
            WorldPointType.CAPITAL, WorldPointType.CITY, WorldPointType.VILLAGE
        )

        Canvas(Modifier.fillMaxSize()) {
            val tile = 92.dp.toPx() * zoomCamera
            val cameraX = -(estado.posicaoNoMapa.x - 0.5f) * tile * 15f
            val cameraY = -(estado.posicaoNoMapa.y - 0.5f) * tile * 18f
            val pontoMundo = WorldMapData.findPoint(pointId)
            val forest = pointId.contains("floresta") ||
                pointId == "clareira_inicial" || pointId == "eldarion" ||
                pointId == "vila_verdejante" || pointId == "dark_forest" ||
                pontoMundo?.region == br.com.ascensaodosoberano.world.WorldRegion.FLORESTA_ARCANA
            val snow = pointId.contains("gelo") || pointId.contains("neve") ||
                pointId.contains("montanha") || pointId.contains("frost") ||
                pontoMundo?.region == br.com.ascensaodosoberano.world.WorldRegion.MONTANHAS_GELIDAS
            val desert = pointId.contains("deserto") || pointId.contains("areia") ||
                pointId.contains("desert") ||
                pontoMundo?.region == br.com.ascensaodosoberano.world.WorldRegion.DESERTO_ANCESTRAL
            val ruins = pointId.contains("ruin") || pointId.contains("ruinas")
            val abyss = pointId.contains("abismo") || pointId.contains("abyss")
            val deadLands = pointId.contains("mortas") || pointId.contains("dead") || pointId.contains("nhar")
            val darkBiome = pointId.contains("sombras") || abyss || deadLands ||
                pontoMundo?.region == br.com.ascensaodosoberano.world.WorldRegion.SOMBRAS
            val cidade = pontoMundo?.type in listOf(
                WorldPointType.CAPITAL, WorldPointType.CITY, WorldPointType.VILLAGE
            )
            val mar = pontoMundo?.region == br.com.ascensaodosoberano.world.WorldRegion.MAR_ETERNAL

            val ground = when {
                snow -> Color(0xFFB9CED0)
                desert -> Color(0xFFB99A5E)
                pontoMundo?.region == br.com.ascensaodosoberano.world.WorldRegion.MAR_ETERNAL -> Color(0xFFB5A16F)
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
                pontoMundo?.region == br.com.ascensaodosoberano.world.WorldRegion.MAR_ETERNAL -> Color(0xFFD9C795)
                ruins -> Color(0xFF99998B)
                abyss -> Color(0xFF66527E)
                deadLands -> Color(0xFF68634D)
                darkBiome -> Color(0xFF53694A)
                forest -> Color(0xFF6D914D)
                else -> Color(0xFFA99A62)
            }
            drawRect(ground)

            // Identidade visual dos biomas: formas grandes primeiro, detalhes por cima.
            if (snow) {
                // Cordilheira em camadas irregulares, com cristas quebradas e neve acumulada.
                for (i in 0..3) {
                    val x = (i * size.width / 3.2f - size.width * .10f + cameraX * .045f)
                    val y = size.height * (.10f + (i % 2) * .13f)
                    val base = y + tile * 1.30f
                    val pico = Path().apply {
                        moveTo(x - tile * 1.55f, base)
                        lineTo(x - tile * 1.08f, y + tile * .52f)
                        lineTo(x - tile * .76f, y + tile * .34f)
                        lineTo(x - tile * .34f, y - tile * .22f)
                        lineTo(x - tile * .10f, y + tile * .03f)
                        lineTo(x + tile * .28f, y - tile * .66f)
                        lineTo(x + tile * .52f, y - tile * .25f)
                        lineTo(x + tile * .88f, y + tile * .04f)
                        lineTo(x + tile * 1.18f, y + tile * .48f)
                        lineTo(x + tile * 1.52f, base)
                        close()
                    }
                    drawPath(pico, Color(0xFF718E99).copy(alpha = .72f))
                    val neve = Path().apply {
                        moveTo(x - tile * .58f, y + tile * .03f)
                        lineTo(x - tile * .34f, y - tile * .22f)
                        lineTo(x - tile * .10f, y + tile * .03f)
                        lineTo(x + tile * .10f, y - tile * .31f)
                        lineTo(x + tile * .28f, y - tile * .66f)
                        lineTo(x + tile * .52f, y - tile * .25f)
                        lineTo(x + tile * .72f, y + tile * .03f)
                        lineTo(x + tile * .43f, y - tile * .06f)
                        lineTo(x + tile * .25f, y + tile * .18f)
                        lineTo(x + tile * .02f, y + tile * .02f)
                        lineTo(x - tile * .18f, y + tile * .23f)
                        close()
                    }
                    drawPath(neve, Color(0xFFE8F3F1))
                    drawPath(pico, Color(0xFF526D78).copy(alpha = .8f), style = Stroke(1.4.dp.toPx()))
                    drawLine(Color(0xFF9AB4B8), Offset(x - tile*.95f, base - tile*.08f),
                        Offset(x - tile*.25f, base - tile*.30f), 2.dp.toPx())
                }
                for (i in 0..18) {
                    val x = (i * 79f + cameraX * .3f).mod(size.width)
                    val y = (i * 47f + cameraY * .25f).mod(size.height)
                    drawCircle(Color.White.copy(alpha = .72f), 1.5.dp.toPx(), Offset(x, y))
                }
            }

            if (desert) {
                for (i in 0..6) {
                    val y = size.height * (.16f + i * .13f) + cameraY * .04f
                    val duna = Path().apply {
                        moveTo(0f, y + tile * .32f)
                        cubicTo(size.width * .22f, y - tile * .45f,
                            size.width * .52f, y + tile * .55f,
                            size.width, y - tile * .18f)
                        lineTo(size.width, y + tile * .48f)
                        lineTo(0f, y + tile * .72f)
                        close()
                    }
                    drawPath(duna, if (i % 2 == 0) Color(0xFFD8B875).copy(alpha = .42f)
                        else Color(0xFF8E713F).copy(alpha = .20f))
                }
                    // Pedras e cactos dão escala ao deserto.
                for (i in 0..9) {
                    val x = (i * 137f + cameraX * .19f + 20f).mod(size.width)
                    val y = (i * 91f + cameraY * .16f + 35f).mod(size.height)
                    drawOval(Color(0xFF79613E), Offset(x, y), Size(19.dp.toPx(), 8.dp.toPx()))
                    if (i % 3 == 0) {
                        drawRoundRect(Color(0xFF477044), Offset(x + 24.dp.toPx(), y - 17.dp.toPx()),
                            Size(7.dp.toPx(), 30.dp.toPx()), androidx.compose.ui.geometry.CornerRadius(4.dp.toPx()))
                        drawRoundRect(Color(0xFF477044), Offset(x + 14.dp.toPx(), y - 7.dp.toPx()),
                            Size(16.dp.toPx(), 6.dp.toPx()), androidx.compose.ui.geometry.CornerRadius(3.dp.toPx()))
                    }
                }
            }

            if (mar) {
                // Costa, areia clara e água em faixas para identificar a região marítima.
                drawRect(Color(0xFF2E7186).copy(alpha = .24f),
                    Offset(size.width * .72f, 0f), Size(size.width * .28f, size.height))
                for (i in 0..8) {
                    val y = i * size.height / 8f
                    drawLine(Color(0xFF8AD5D5).copy(alpha = .30f),
                        Offset(size.width * .73f, y), Offset(size.width, y - 12.dp.toPx()), 2.dp.toPx())
                }
                drawPath(Path().apply {
                    moveTo(size.width * .67f, 0f)
                    cubicTo(size.width * .78f, size.height * .24f,
                        size.width * .59f, size.height * .56f,
                        size.width * .75f, size.height)
                    lineTo(size.width * .68f, size.height)
                    cubicTo(size.width * .52f, size.height * .56f,
                        size.width * .70f, size.height * .24f,
                        size.width * .60f, 0f)
                    close()
                }, Color(0xFFD6C18B))
            }

            if (darkBiome) {
                for (i in 0..12) {
                    val x = (i * 113f + cameraX * .17f).mod(size.width)
                    val y = (i * 71f + cameraY * .14f).mod(size.height)
                    drawCircle(Color(0xFF9B6DB6).copy(alpha = .09f),
                        18.dp.toPx() + (i % 3) * 7.dp.toPx(), Offset(x, y))
                }
            }

            if (cidade) {
                // Malha urbana: praça central, ruas de pedra e quarteirões.
                val pedra = if (snow) Color(0xFF9CAEB0) else if (desert) Color(0xFF9B8058)
                    else if (darkBiome) Color(0xFF4C4654) else Color(0xFF77766C)
                drawRect(pedra.copy(alpha = .24f))
                val ruaY = size.height * .54f + cameraY * .10f
                val ruaX = size.width * .50f + cameraX * .10f
                drawRect(Color(0xFFB9A27A), Offset(0f, ruaY - 13.dp.toPx()),
                    Size(size.width, 26.dp.toPx()))
                drawRect(Color(0xFFB9A27A), Offset(ruaX - 13.dp.toPx(), 0f),
                    Size(26.dp.toPx(), size.height))
                drawCircle(Color(0xFFC5B28A), 45.dp.toPx(), Offset(ruaX, ruaY))
                drawCircle(Color(0xFF8D9A86), 31.dp.toPx(), Offset(ruaX, ruaY))
                drawCircle(Color(0xFF6C9AA0), 12.dp.toPx(), Offset(ruaX, ruaY))
                // Quatro quarteirões com fachadas, telhados, portas e janelas em pixel art.
                val casas = listOf(
                    Offset(size.width * .14f, size.height * .16f),
                    Offset(size.width * .65f, size.height * .13f),
                    Offset(size.width * .13f, size.height * .70f),
                    Offset(size.width * .67f, size.height * .70f),
                    Offset(size.width * .39f, size.height * .06f),
                    Offset(size.width * .39f, size.height * .82f)
                )
                casas.forEachIndexed { index, p ->
                    val w = if (index < 4) 54.dp.toPx() else 44.dp.toPx()
                    val h = if (index < 4) 39.dp.toPx() else 32.dp.toPx()
                    val parede = when (index % 3) {
                        0 -> Color(0xFFB69A72)
                        1 -> Color(0xFF9B8B78)
                        else -> Color(0xFFC6B48C)
                    }
                    drawRect(Color(0xFF342D2A).copy(alpha = .30f),
                        Offset(p.x + 4.dp.toPx(), p.y + h), Size(w, 7.dp.toPx()))
                    drawRect(parede, p, Size(w, h))
                    drawRect(Color(0xFF6B5845), Offset(p.x, p.y + h - 5.dp.toPx()),
                        Size(w, 5.dp.toPx()))
                    drawLine(Color(0xFFE1C89B), Offset(p.x + 3.dp.toPx(), p.y + 5.dp.toPx()),
                        Offset(p.x + 3.dp.toPx(), p.y + h - 7.dp.toPx()), 1.5.dp.toPx())
                    drawLine(Color(0xFF7D654B), Offset(p.x + w - 3.dp.toPx(), p.y + 5.dp.toPx()),
                        Offset(p.x + w - 3.dp.toPx(), p.y + h - 7.dp.toPx()), 1.5.dp.toPx())
                    val telhado = Path().apply {
                        moveTo(p.x - 5.dp.toPx(), p.y + 3.dp.toPx())
                        lineTo(p.x + w / 2f, p.y - 19.dp.toPx())
                        lineTo(p.x + w + 5.dp.toPx(), p.y + 3.dp.toPx())
                        close()
                    }
                    val telhadoCidade = when {
                        darkBiome -> Color(0xFF493D4B)
                        snow -> Color(0xFF536C78)
                        desert -> Color(0xFFB8793F)
                        mar -> Color(0xFF3E6574)
                        pontoMundo?.region == br.com.ascensaodosoberano.world.WorldRegion.IMPERIO -> Color(0xFF813F38)
                        else -> Color(0xFF754536)
                    }
                    drawPath(telhado, telhadoCidade)
                    drawLine(Color(0xFF302B2A), Offset(p.x - 5.dp.toPx(), p.y + 3.dp.toPx()),
                        Offset(p.x + w + 5.dp.toPx(), p.y + 3.dp.toPx()), 2.dp.toPx())
                    for (fileira in 0..2) {
                        val yy = p.y - 12.dp.toPx() + fileira * 6.dp.toPx()
                        drawLine(Color(0xFFB18A5D).copy(alpha = .62f),
                            Offset(p.x + w*.18f, yy), Offset(p.x + w*.82f, yy), 1.dp.toPx())
                    }
                    if (index % 2 == 0) {
                        drawRect(Color(0xFF655044), Offset(p.x + w*.76f, p.y - 25.dp.toPx()),
                            Size(7.dp.toPx(), 15.dp.toPx()))
                        drawRect(Color(0xFF9B7C61), Offset(p.x + w*.73f, p.y - 27.dp.toPx()),
                            Size(13.dp.toPx(), 3.dp.toPx()))
                    }
                    drawRect(Color(0xFF49352B), Offset(p.x + w * .42f, p.y + h * .48f),
                        Size(w * .18f, h * .52f))
                    drawRect(Color(0xFF59463A), Offset(p.x + w * .105f, p.y + h * .22f),
                        Size(w * .21f, h * .24f))
                    drawRect(Color(0xFFFFD78A), Offset(p.x + w * .13f, p.y + h * .25f),
                        Size(w * .16f, h * .18f))
                    drawLine(Color(0xFF6E5038), Offset(p.x + w*.21f, p.y+h*.22f),
                        Offset(p.x + w*.21f, p.y+h*.46f), 1.dp.toPx())
                    drawLine(Color(0xFF6E5038), Offset(p.x + w*.105f, p.y+h*.34f),
                        Offset(p.x + w*.315f, p.y+h*.34f), 1.dp.toPx())
                    drawRect(Color(0xFF59463A), Offset(p.x + w * .695f, p.y + h * .22f),
                        Size(w * .21f, h * .24f))
                    drawRect(Color(0xFFFFD78A), Offset(p.x + w * .72f, p.y + h * .25f),
                        Size(w * .16f, h * .18f))
                    drawLine(Color(0xFF6E5038), Offset(p.x + w*.80f, p.y+h*.22f),
                        Offset(p.x + w*.80f, p.y+h*.46f), 1.dp.toPx())
                    drawLine(Color(0xFF55493D), Offset(p.x, p.y + h),
                        Offset(p.x + w, p.y + h), 2.dp.toPx())
                }
                // Poste de luz e bandeirolas identificam ruas movimentadas.
                for (i in 0..2) {
                    val x = size.width * (.25f + i * .25f)
                    drawRect(Color(0xFF49382A), Offset(x, ruaY - 31.dp.toPx()),
                        Size(3.dp.toPx(), 19.dp.toPx()))
                    drawCircle(Color(0xFFFFD58A).copy(alpha = .8f), 5.dp.toPx(),
                        Offset(x + 1.5.dp.toPx(), ruaY - 34.dp.toPx()))
                }
            }

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
                    if ((forest || snow) && distanceFromPlayer > tile * 1.05f && seed % 5 != 0) {
                        drawRect(Color(0xFF59432D),
                            Offset(center.x - tile * .055f, center.y + tile * .02f),
                            Size(tile * .11f, tile * .25f))
                        if (snow) {
                            // Pinheiros com três patamares de galhos, neve nas pontas e tronco aparente.
                            for (nivel in 0..2) {
                                val largura = tile * (.34f - nivel * .075f)
                                val topo = center.y - tile * (.42f - nivel * .18f)
                                val copa = Path().apply {
                                    moveTo(center.x, topo - tile*.12f)
                                    lineTo(center.x - largura, topo + tile*.30f)
                                    lineTo(center.x - largura*.52f, topo + tile*.26f)
                                    lineTo(center.x - largura*.72f, topo + tile*.48f)
                                    lineTo(center.x + largura*.72f, topo + tile*.48f)
                                    lineTo(center.x + largura*.52f, topo + tile*.26f)
                                    lineTo(center.x + largura, topo + tile*.30f)
                                    close()
                                }
                                drawPath(copa, if (nivel % 2 == 0) Color(0xFF315E59) else Color(0xFF47766D))
                                drawLine(Color(0xFFDDECE7), Offset(center.x, topo - tile*.10f),
                                    Offset(center.x - largura*.42f, topo + tile*.18f), 2.dp.toPx())
                                drawLine(Color(0xFFDDECE7), Offset(center.x, topo - tile*.10f),
                                    Offset(center.x + largura*.42f, topo + tile*.18f), 2.dp.toPx())
                            }
                        } else {
                            drawCircle(if (darkBiome) Color(0xFF182F2B) else Color(0xFF234A32), tile * .30f,
                                Offset(center.x, center.y - tile * .10f))
                            drawCircle(if (darkBiome) Color(0xFF294638) else Color(0xFF32633B), tile * .235f,
                                Offset(center.x - tile * .11f, center.y - tile * .20f))
                            drawCircle(Color(0xFF6D9950),
                                tile * .12f, Offset(center.x + tile*.13f, center.y - tile*.25f))
                            drawRect(Color(0xFF183D2B),
                                Offset(center.x + tile * .07f, center.y - tile * .04f),
                                Size(tile * .09f, tile * .07f))
                        }
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

            // Estrutura principal de cada ponto de interesse: a aparência acompanha o tipo e a região.
            val estruturaX = size.width * .50f + cameraX * .10f
            val estruturaY = size.height * .43f + cameraY * .10f
            val pedraEstrutura = when (pontoMundo?.region) {
                br.com.ascensaodosoberano.world.WorldRegion.MONTANHAS_GELIDAS -> Color(0xFF829DA5)
                br.com.ascensaodosoberano.world.WorldRegion.IMPERIO -> Color(0xFF9A8062)
                br.com.ascensaodosoberano.world.WorldRegion.SOMBRAS -> Color(0xFF51475D)
                br.com.ascensaodosoberano.world.WorldRegion.DESERTO_ANCESTRAL -> Color(0xFFB38A54)
                br.com.ascensaodosoberano.world.WorldRegion.MAR_ETERNAL -> Color(0xFF557F88)
                else -> Color(0xFF77796E)
            }
            when (pontoMundo?.type) {
                WorldPointType.TOWER -> {
                    // Torre de pedra com base, ameias, telhado e janelas iluminadas.
                    drawRect(Color(0xFF342F32).copy(alpha = .30f),
                        Offset(estruturaX - 27.dp.toPx(), estruturaY + 55.dp.toPx()),
                        Size(58.dp.toPx(), 9.dp.toPx()))
                    drawRect(pedraEstrutura, Offset(estruturaX - 19.dp.toPx(), estruturaY - 5.dp.toPx()),
                        Size(39.dp.toPx(), 61.dp.toPx()))
                    drawRect(pedraEstrutura.copy(red = (pedraEstrutura.red * .82f).coerceIn(0f, 1f)),
                        Offset(estruturaX - 25.dp.toPx(), estruturaY + 45.dp.toPx()),
                        Size(51.dp.toPx(), 11.dp.toPx()))
                    val torreTopo = Path().apply {
                        moveTo(estruturaX - 24.dp.toPx(), estruturaY - 5.dp.toPx())
                        lineTo(estruturaX, estruturaY - 30.dp.toPx())
                        lineTo(estruturaX + 24.dp.toPx(), estruturaY - 5.dp.toPx())
                        close()
                    }
                    drawPath(torreTopo, if (snow) Color(0xFF4D6677) else Color(0xFF51413C))
                    for (janela in -1..1) {
                        drawRect(Color(0xFFFFD78A), Offset(estruturaX - 3.dp.toPx(),
                            estruturaY + (janela * 18).dp.toPx()), Size(6.dp.toPx(), 9.dp.toPx()))
                    }
                    drawRect(Color(0xFF332B2A), Offset(estruturaX - 7.dp.toPx(),
                        estruturaY + 34.dp.toPx()), Size(14.dp.toPx(), 22.dp.toPx()))
                }
                WorldPointType.DUNGEON -> {
                    // Entrada de masmorra escavada na rocha, com arco e brilho interno.
                    drawOval(Color(0xFF302D32), Offset(estruturaX - 43.dp.toPx(),
                        estruturaY + 22.dp.toPx()), Size(86.dp.toPx(), 30.dp.toPx()))
                    drawRoundRect(pedraEstrutura, Offset(estruturaX - 35.dp.toPx(),
                        estruturaY - 9.dp.toPx()), Size(70.dp.toPx(), 42.dp.toPx()),
                        androidx.compose.ui.geometry.CornerRadius(20.dp.toPx()))
                    drawArc(Color(0xFF29252D), 180f, 180f, false,
                        Offset(estruturaX - 23.dp.toPx(), estruturaY - 3.dp.toPx()),
                        Size(46.dp.toPx(), 48.dp.toPx()), style = Stroke(7.dp.toPx()))
                    drawOval(Color(0xFF171923), Offset(estruturaX - 19.dp.toPx(),
                        estruturaY + 2.dp.toPx()), Size(38.dp.toPx(), 35.dp.toPx()))
                    drawCircle(if (abyss || darkBiome) Color(0xFFB77BE0) else Color(0xFFFFC66D),
                        4.dp.toPx(), Offset(estruturaX, estruturaY + 21.dp.toPx()))
                    drawRect(pedraEstrutura.copy(alpha = .85f),
                        Offset(estruturaX - 43.dp.toPx(), estruturaY + 27.dp.toPx()),
                        Size(13.dp.toPx(), 9.dp.toPx()))
                    drawRect(pedraEstrutura.copy(alpha = .85f),
                        Offset(estruturaX + 30.dp.toPx(), estruturaY + 27.dp.toPx()),
                        Size(13.dp.toPx(), 9.dp.toPx()))
                }
                WorldPointType.RUINS -> {
                    // Portal antigo entre colunas partidas e uma pedra de inscrição.
                    for (lado in listOf(-1f, 1f)) {
                        val x = estruturaX + lado * 29.dp.toPx()
                        drawRect(pedraEstrutura, Offset(x - 6.dp.toPx(),
                            estruturaY - 8.dp.toPx()), Size(12.dp.toPx(), 55.dp.toPx()))
                        drawRect(pedraEstrutura.copy(alpha = .75f),
                            Offset(x - 10.dp.toPx(), estruturaY - 12.dp.toPx()),
                            Size(20.dp.toPx(), 7.dp.toPx()))
                    }
                    drawRect(pedraEstrutura.copy(alpha = .9f),
                        Offset(estruturaX - 34.dp.toPx(), estruturaY - 13.dp.toPx()),
                        Size(68.dp.toPx(), 9.dp.toPx()))
                    drawRect(Color(0xFF29272B), Offset(estruturaX - 19.dp.toPx(),
                        estruturaY - 3.dp.toPx()), Size(38.dp.toPx(), 48.dp.toPx()))
                    drawLine(Color(0xFFD9C18C), Offset(estruturaX - 8.dp.toPx(),
                        estruturaY + 10.dp.toPx()), Offset(estruturaX + 8.dp.toPx(),
                        estruturaY + 25.dp.toPx()), 2.dp.toPx())
                    drawLine(Color(0xFFD9C18C), Offset(estruturaX + 8.dp.toPx(),
                        estruturaY + 10.dp.toPx()), Offset(estruturaX - 8.dp.toPx(),
                        estruturaY + 25.dp.toPx()), 2.dp.toPx())
                }
                WorldPointType.LANDMARK -> {
                    when (pontoMundo.id) {
                        "clareira_inicial" -> {
                            // Marco de madeira e pedra junto ao acampamento inicial.
                            drawOval(Color(0xFF334A35).copy(alpha = .35f),
                                Offset(estruturaX - 42.dp.toPx(), estruturaY + 31.dp.toPx()),
                                Size(84.dp.toPx(), 18.dp.toPx()))
                            drawRect(Color(0xFF8A7958), Offset(estruturaX - 8.dp.toPx(),
                                estruturaY - 9.dp.toPx()), Size(16.dp.toPx(), 48.dp.toPx()))
                            drawRect(Color(0xFFBDA77A), Offset(estruturaX - 18.dp.toPx(),
                                estruturaY - 14.dp.toPx()), Size(36.dp.toPx(), 9.dp.toPx()))
                            drawCircle(Color(0xFFFFD98A), 5.dp.toPx(),
                                Offset(estruturaX, estruturaY + 2.dp.toPx()))
                        }
                        "pico_aurora" -> {
                            val pico = Path().apply {
                                moveTo(estruturaX - 48.dp.toPx(), estruturaY + 43.dp.toPx())
                                lineTo(estruturaX, estruturaY - 48.dp.toPx())
                                lineTo(estruturaX + 48.dp.toPx(), estruturaY + 43.dp.toPx())
                                close()
                            }
                            drawPath(pico, Color(0xFF6F8992))
                            drawPath(Path().apply {
                                moveTo(estruturaX - 17.dp.toPx(), estruturaY - 16.dp.toPx())
                                lineTo(estruturaX, estruturaY - 48.dp.toPx())
                                lineTo(estruturaX + 19.dp.toPx(), estruturaY - 15.dp.toPx())
                                lineTo(estruturaX + 3.dp.toPx(), estruturaY - 23.dp.toPx())
                                lineTo(estruturaX - 5.dp.toPx(), estruturaY - 9.dp.toPx())
                                close()
                            }, Color(0xFFEAF5F0))
                        }
                        "ilha_serpente" -> {
                            drawOval(Color(0xFF426C4D), Offset(estruturaX - 43.dp.toPx(),
                                estruturaY + 17.dp.toPx()), Size(86.dp.toPx(), 29.dp.toPx()))
                            drawLine(Color(0xFF9DBB72), Offset(estruturaX - 20.dp.toPx(),
                                estruturaY + 19.dp.toPx()), Offset(estruturaX + 3.dp.toPx(),
                                estruturaY - 23.dp.toPx()), 8.dp.toPx())
                            drawLine(Color(0xFF9DBB72), Offset(estruturaX + 3.dp.toPx(),
                                estruturaY - 23.dp.toPx()), Offset(estruturaX + 25.dp.toPx(),
                                estruturaY + 5.dp.toPx()), 8.dp.toPx())
                            drawCircle(Color(0xFFFFD36A), 3.dp.toPx(),
                                Offset(estruturaX + 3.dp.toPx(), estruturaY - 23.dp.toPx()))
                        }
                        else -> {
                            drawCircle(pedraEstrutura, 28.dp.toPx(),
                                Offset(estruturaX, estruturaY + 13.dp.toPx()))
                            drawRect(pedraEstrutura.copy(alpha = .8f),
                                Offset(estruturaX - 8.dp.toPx(), estruturaY - 35.dp.toPx()),
                                Size(16.dp.toPx(), 50.dp.toPx()))
                            drawRect(Color(0xFFD8C79B), Offset(estruturaX - 12.dp.toPx(),
                                estruturaY - 39.dp.toPx()), Size(24.dp.toPx(), 7.dp.toPx()))
                        }
                    }
                }
                else -> Unit
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

            // Luz ambiente em camadas: o centro fica legível e as bordas ganham profundidade.
            val luzDia = daylightFactor.coerceIn(0f, 1f)
            if (luzDia > .35f) {
                drawCircle(
                    Color(0xFFFFD58A).copy(alpha = luzDia * .055f),
                    radius = size.maxDimension * .72f,
                    center = Offset(size.width * .72f, size.height * .12f)
                )
            }
            // Vagalumes e poeira mágica se movem sem depender de imagens externas.
            if (forest || darkBiome || ruins) {
                for (i in 0 until 16) {
                    val deslocamento = faseAmbiente * size.width * if (i % 2 == 0) 1f else -1f
                    val x = (i * 97f + deslocamento + cameraX * .08f).mod(size.width)
                    val yBase = (i * 61f + cameraY * .06f).mod(size.height)
                    val y = (yBase + kotlin.math.sin((faseAmbiente * 6.28318f + i) * 1.4f) * 7.dp.toPx())
                    val brilho = (.25f + .55f * kotlin.math.abs(
                        kotlin.math.sin(faseAmbiente * 6.28318f + i * .73f)
                    )).coerceIn(.15f, .85f)
                    val corParticula = if (darkBiome || ruins) Color(0xFFC79BFF) else Color(0xFFFFE6A0)
                    drawCircle(corParticula.copy(alpha = brilho), (1.2f + (i % 3) * .45f).dp.toPx(), Offset(x, y))
                    if (i % 4 == 0) {
                        drawCircle(corParticula.copy(alpha = brilho * .13f), 7.dp.toPx(), Offset(x, y))
                    }
                }
            }
            // Clima animado por bioma: neve, areia e reflexos marítimos.
            if (snow) {
                for (i in 0 until 24) {
                    val x = (i * 83f + faseAmbiente * size.width * .22f + cameraX * .03f).mod(size.width)
                    val y = (i * 59f + faseAmbiente * size.height * .72f).mod(size.height)
                    drawLine(
                        Color.White.copy(alpha = .55f),
                        Offset(x, y),
                        Offset(x - 2.dp.toPx(), y + 5.dp.toPx()),
                        1.4.dp.toPx()
                    )
                }
            } else if (desert) {
                for (i in 0 until 18) {
                    val x = (i * 107f + faseAmbiente * size.width * .38f).mod(size.width)
                    val y = (i * 71f + faseAmbiente * size.height * .16f).mod(size.height)
                    drawLine(
                        Color(0xFFFFE0A0).copy(alpha = .30f),
                        Offset(x, y),
                        Offset(x + 8.dp.toPx(), y - 1.dp.toPx()),
                        1.2.dp.toPx()
                    )
                }
            } else if (mar) {
                for (i in 0 until 14) {
                    val x = size.width * .72f + (i * 23.dp.toPx() + faseAmbiente * 19.dp.toPx()).mod(size.width * .27f)
                    val y = (i * 53f + faseAmbiente * size.height * .08f).mod(size.height)
                    drawLine(
                        Color(0xFFB9F4F0).copy(alpha = .30f),
                        Offset(x, y),
                        Offset(x + 9.dp.toPx(), y - 1.dp.toPx()),
                        1.5.dp.toPx()
                    )
                }
            }

            // Vinheta suave para destacar herói e cenário central sem escurecer o HUD.
            drawRect(
                brush = androidx.compose.ui.graphics.Brush.radialGradient(
                    colors = listOf(Color.Transparent, Color(0x55040A12)),
                    center = Offset(size.width / 2f, size.height / 2f),
                    radius = size.maxDimension * .82f
                )
            )

            
        }


        // Barra superior fixa: retorno ao mapa e status do personagem.
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .align(Alignment.TopCenter)
                .padding(horizontal = 10.dp, vertical = 8.dp),
            horizontalArrangement = androidx.compose.foundation.layout.Arrangement.SpaceBetween,
            verticalAlignment = Alignment.Top
        ) {
            if (estado.modo != ModoCenaMundo.COMBATE) {
                Column(
                    modifier = Modifier
                        .width(132.dp)
                        .background(Color(0xE817202B), RoundedCornerShape(12.dp))
                        .padding(7.dp),
                    verticalArrangement = Arrangement.spacedBy(6.dp)
                ) {
                    Box(
                        Modifier.fillMaxWidth()
                            .background(Color(0xFF72532E), RoundedCornerShape(7.dp))
                            .clickable { aoVoltar() }
                            .padding(vertical = 10.dp),
                        contentAlignment = Alignment.Center
                    ) {
                        Text("MAPA-MÚNDI", color = Color(0xFFFFE4AE), fontSize = 10.sp)
                    }
                    Text("ATALHOS", color = Color(0xFFFFD58E), fontSize = 9.sp)
                    listOf(
                        "BOLSA" to "INVENTARIO",
                        "STATUS" to "STATUS",
                        "BESTIÁRIO" to "BESTIARIO",
                        "MULTI" to "MULTIPLAYER"
                    ).chunked(2).forEach { linha ->
                        Row(
                            Modifier.fillMaxWidth(),
                            horizontalArrangement = Arrangement.spacedBy(5.dp)
                        ) {
                            linha.forEach { (label, key) ->
                                Box(
                                    Modifier.weight(1f)
                                        .background(Color(0xFF35465B), RoundedCornerShape(6.dp))
                                        .clickable { aoAbrirPainel(key) }
                                        .padding(horizontal = 3.dp, vertical = 8.dp),
                                    contentAlignment = Alignment.Center
                                ) {
                                    Text(label, color = Color(0xFFFFE2AE), fontSize = 9.sp,
                                        textAlign = TextAlign.Center, maxLines = 1)
                                }
                            }
                        }
                    }
                    if (ferreiroDisponivel) {
                        Box(
                            Modifier.fillMaxWidth()
                                .background(Color(0xFF59452D), RoundedCornerShape(6.dp))
                                .clickable { aoAbrirPainel("FERREIRO") }
                                .padding(vertical = 7.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text("⚒ FERREIRO", color = Color(0xFFFFE2AE), fontSize = 9.sp)
                        }
                    }
                    if (curandeiroDisponivel) {
                        Box(
                            Modifier.fillMaxWidth()
                                .background(Color(0xFF315C55), RoundedCornerShape(6.dp))
                                .clickable { aoAbrirPainel("CURANDEIRO") }
                                .padding(vertical = 7.dp),
                            contentAlignment = Alignment.Center
                        ) {
                            Text("✚ CURANDEIRO", color = Color(0xFFD4FFE8), fontSize = 9.sp)
                        }
                    }
                }
            } else {
                Spacer(Modifier.width(132.dp))
            }

            Column(
                modifier = Modifier.widthIn(min = 166.dp, max = 184.dp),
                horizontalAlignment = Alignment.End,
                verticalArrangement = Arrangement.spacedBy(5.dp)
            ) {
                if (estado.modo != ModoCenaMundo.COMBATE) {
                    Text(
                        if (areaSegura) "ÁREA SEGURA · SEM INIMIGOS" else "ÁREA SELVAGEM",
                        color = if (areaSegura) Color(0xFFB9E5C0) else Color(0xFFFFC477),
                        fontSize = 8.sp
                    )
                    MiniMapaLocal(
                        pointId = pointId,
                        posicao = estado.posicaoNoMapa,
                        aoAbrirMapa = aoVoltar
                    )
                }
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Color(0xE817202B), RoundedCornerShape(12.dp))
                        .padding(horizontal = 10.dp, vertical = 7.dp),
                    verticalArrangement = Arrangement.spacedBy(3.dp)
                ) {
                    Text("$nomeJogador · Nv. $nivelJogador", color = Color.White, fontSize = 11.sp)
                    Text("VIDA  $vidaJogador / $vidaMaximaJogador", color = Color(0xFFFF8585), fontSize = 10.sp)
                    Box(Modifier.fillMaxWidth().height(6.dp).background(Color(0xFF51383D), RoundedCornerShape(5.dp))) {
                        Box(Modifier.fillMaxWidth(if (vidaMaximaJogador > 0) (vidaJogador.toFloat() / vidaMaximaJogador).coerceIn(0f, 1f) else 0f).height(6.dp).background(Color(0xFFE34E5B), RoundedCornerShape(5.dp)))
                    }
                    Text("MANA  $manaJogador / $manaMaximaJogador", color = Color(0xFF8EDBFF), fontSize = 10.sp)
                    Box(Modifier.fillMaxWidth().height(5.dp).background(Color(0xFF293F50), RoundedCornerShape(5.dp))) {
                        Box(Modifier.fillMaxWidth(if (manaMaximaJogador > 0) (manaJogador.toFloat() / manaMaximaJogador).coerceIn(0f, 1f) else 0f).height(5.dp).background(Color(0xFF36A9E8), RoundedCornerShape(5.dp)))
                    }
                    val xpNecessario = (nivelJogador * 100).coerceAtLeast(100)
                    Text("XP  $xpAtual / $xpNecessario", color = Color(0xFFFFD879), fontSize = 10.sp)
                    Box(Modifier.fillMaxWidth().height(5.dp).background(Color(0xFF51482F), RoundedCornerShape(5.dp))) {
                        Box(Modifier.fillMaxWidth((xpAtual.toFloat() / xpNecessario).coerceIn(0f, 1f)).height(5.dp).background(Color(0xFFE9B94F), RoundedCornerShape(5.dp)))
                    }
                }
            }
        }

        // A criatura também aparece fisicamente ao lado do herói no cenário,
        // em vez de existir apenas como uma mensagem na interface.
        AnimatedVisibility(
            visible = criaturaEncontrada != null && estado.modo != ModoCenaMundo.COMBATE,
            enter = fadeIn(animationSpec = tween(280)) + scaleIn(initialScale = .72f, animationSpec = tween(280)),
            exit = fadeOut(animationSpec = tween(160)),
            modifier = Modifier.align(Alignment.Center).offset(x = 104.dp, y = 18.dp)
        ) {
            criaturaEncontrada?.let { criatura ->
                Column(horizontalAlignment = Alignment.CenterHorizontally) {
                    if (criatura.imagemDetalhadaCaminho.startsWith("https://") ||
                        criatura.imagemDetalhadaCaminho.startsWith("http://")) {
                        AsyncImage(
                            model = criatura.imagemDetalhadaCaminho,
                            contentDescription = criatura.nome,
                            modifier = Modifier.size(104.dp),
                            contentScale = ContentScale.Fit
                        )
                    } else {
                        CriaturaPixelArt(
                            nome = criatura.nome,
                            rank = criatura.rank,
                            chefe = criatura.chefe,
                            modifier = Modifier.size(104.dp)
                        )
                    }
                    Text(
                        criatura.nome,
                        color = if (criatura.chefe) Color(0xFFFFA27F) else Color.White,
                        fontSize = 9.sp,
                        textAlign = TextAlign.Center,
                        maxLines = 1
                    )
                }
            }
        }

        // Criatura descoberta permanece visível no mundo até o jogador decidir enfrentá-la.
        if (criaturaEncontrada != null && estado.modo != ModoCenaMundo.COMBATE) {
            val criatura = criaturaEncontrada
            Column(
                modifier = Modifier.align(Alignment.Center)
                    .offset(y = (-142).dp)
                    .widthIn(min = 190.dp, max = 238.dp)
                    .background(Color(0xF018202B), RoundedCornerShape(14.dp))
                    .padding(10.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(5.dp)
            ) {
                Text(
                    if (criatura.chefe) "CHEFE DESCOBERTO" else "CRIATURA DESCOBERTA",
                    color = if (criatura.chefe) Color(0xFFFF9A73) else Color(0xFFFFD58E),
                    fontSize = 9.sp
                )
                if (criatura.imagemIconeCaminho.startsWith("https://") ||
                    criatura.imagemIconeCaminho.startsWith("http://")) {
                    AsyncImage(
                        model = criatura.imagemIconeCaminho,
                        contentDescription = criatura.nome,
                        modifier = Modifier.size(76.dp),
                        contentScale = ContentScale.Fit
                    )
                } else {
                    CriaturaPixelArt(
                        nome = criatura.nome,
                        rank = criatura.rank,
                        chefe = criatura.chefe,
                        modifier = Modifier.size(88.dp)
                    )
                }
                Text(criatura.nome, color = Color.White, fontSize = 14.sp, textAlign = TextAlign.Center)
                Text(
                    "Rank ${criatura.rank} · ${criatura.raridade} · Nv. ${criatura.nivel}",
                    color = Color(0xFFC9D4E1), fontSize = 9.sp, textAlign = TextAlign.Center
                )
                Text(
                    criatura.descricao,
                    color = Color(0xFFB7C2CF), fontSize = 9.sp,
                    textAlign = TextAlign.Center, maxLines = 2
                )
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                    androidx.compose.material3.OutlinedButton(
                        onClick = aoIgnorarCriatura,
                        modifier = Modifier.weight(1f),
                        contentPadding = PaddingValues(horizontal = 4.dp, vertical = 4.dp)
                    ) { Text("IGNORAR", fontSize = 9.sp) }
                    androidx.compose.material3.Button(
                        onClick = aoEnfrentarCriatura,
                        modifier = Modifier.weight(1f),
                        contentPadding = PaddingValues(horizontal = 4.dp, vertical = 4.dp)
                    ) { Text("ENFRENTAR", fontSize = 9.sp) }
                }
            }
        }

        // Sombra projetada e brilho discreto separam o personagem do terreno.
        Canvas(Modifier.align(Alignment.Center).size(76.dp)) {
            drawOval(
                Color(0x99050A10),
                Offset(size.width * .16f, size.height * .70f),
                Size(size.width * .68f, size.height * .18f)
            )
            if (direcao.x != 0f || direcao.y != 0f) {
                drawOval(
                    Color(0x33F6D58A),
                    Offset(size.width * .25f, size.height * .64f),
                    Size(size.width * .50f, size.height * .16f)
                )
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
                    .offset(
                        x = if (direcao.x != 0f) {
                            if (quadroCaminhada % 2 == 0) (-1).dp else 1.dp
                        } else 0.dp,
                        y = if (direcao.x != 0f || direcao.y != 0f) {
                            if (quadroCaminhada % 2 == 0) (-3).dp else 1.dp
                        } else 0.dp
                    )
                    .size(104.dp),
                equippedEquipment = equipamentosVestidos,
                equipmentLoadout = espacosEquipamento
            )
        }

        criaturasNoCenario.forEach { encontro ->
            val dx = sceneWidth * (encontro.x - estado.posicaoNoMapa.x) * 13f
            val dy = sceneHeight * (encontro.y - estado.posicaoNoMapa.y) * 18f
            if (abs(dx.value) < sceneWidth.value && abs(dy.value) < sceneHeight.value) {
                Column(
                    modifier = Modifier.align(Alignment.Center).offset(dx, dy)
                        .widthIn(max = 104.dp)
                        .background(Color(0xCC17251B), RoundedCornerShape(8.dp))
                        .clickable { aoSelecionarCriaturaNoMundo(encontro.criatura) }
                        .padding(horizontal = 5.dp, vertical = 3.dp),
                    horizontalAlignment = Alignment.CenterHorizontally
                ) {
                    if (encontro.criatura.imagemIconeCaminho.startsWith("https://") ||
                        encontro.criatura.imagemIconeCaminho.startsWith("http://")
                    ) {
                        AsyncImage(
                            model = encontro.criatura.imagemIconeCaminho,
                            contentDescription = encontro.criatura.nome,
                            modifier = Modifier.size(54.dp),
                            contentScale = ContentScale.Fit
                        )
                    } else {
                        CriaturaPixelArt(
                            nome = encontro.criatura.nome,
                            rank = encontro.criatura.rank,
                            chefe = encontro.criatura.chefe,
                            modifier = Modifier.size(54.dp)
                        )
                    }
                    Text(
                        encontro.criatura.nome,
                        color = Color.White,
                        fontSize = 9.sp,
                        textAlign = TextAlign.Center,
                        maxLines = 2
                    )
                    Text(
                        if (encontro.criatura.chefe) "CHEFE · ${encontro.criatura.rank}"
                        else "Rank ${encontro.criatura.rank}",
                        color = if (encontro.criatura.chefe) Color(0xFFFFB45C) else Color(0xFFD6E5C8),
                        fontSize = 8.sp
                    )
                }
            }
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
                    if (outro.imagemPersonagemUrl.startsWith("https://") || outro.imagemPersonagemUrl.startsWith("http://")) {
                        AsyncImage(
                            model = outro.imagemPersonagemUrl,
                            contentDescription = "Personagem de ${outro.nome}",
                            modifier = Modifier.size(42.dp).clip(CircleShape),
                            contentScale = ContentScale.Fit
                        )
                    } else {
                        Text("●", color = Color(0xFF79D7FF), fontSize = 22.sp)
                    }
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
                enabled = !areaSegura && !buscandoCriaturas && criaturaEncontrada == null,
                modifier = Modifier.align(Alignment.BottomEnd).padding(end = 16.dp, bottom = 22.dp),
                contentPadding = PaddingValues(horizontal = 16.dp, vertical = 11.dp)
            ) {
                Text(
                    when {
                        areaSegura -> "Área segura"
                        buscandoCriaturas -> "Rastreando..."
                        criaturaEncontrada != null -> "Criatura encontrada"
                        else -> "Procurar criaturas"
                    },
                    fontSize = 12.sp
                )
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


@Composable
private fun MiniMapaLocal(
    pointId: String,
    posicao: WorldPosition,
    aoAbrirMapa: () -> Unit
) {
    val pontoLocal = WorldMapData.findPoint(pointId)
    val fundo = when {
        pontoLocal?.region == br.com.ascensaodosoberano.world.WorldRegion.MONTANHAS_GELIDAS ->
            Color(0xFFB9D4D5)
        pontoLocal?.region == br.com.ascensaodosoberano.world.WorldRegion.DESERTO_ANCESTRAL ->
            Color(0xFFC7A66A)
        pontoLocal?.region == br.com.ascensaodosoberano.world.WorldRegion.MAR_ETERNAL ->
            Color(0xFF397D91)
        pontoLocal?.region == br.com.ascensaodosoberano.world.WorldRegion.SOMBRAS ||
            pointId.contains("abismo") || pointId.contains("abyss") ->
            Color(0xFF51415F)
        pontoLocal?.region == br.com.ascensaodosoberano.world.WorldRegion.IMPERIO ->
            Color(0xFF9B8157)
        pontoLocal?.region == br.com.ascensaodosoberano.world.WorldRegion.CENTRAL ->
            Color(0xFF8B7848)
        pointId.contains("ruin") || pointId.contains("ruinas") ->
            Color(0xFF858477)
        else -> Color(0xFF527C42)
    }
    Column(
        horizontalAlignment = Alignment.End,
        verticalArrangement = Arrangement.spacedBy(2.dp)
    ) {
        Text("MINIMAPA · ${pontoLocal?.name ?: "ÁREA"}", color = Color.White, fontSize = 8.sp, maxLines = 1)
        Box(
            Modifier.size(92.dp)
                .clip(CircleShape)
                .background(Color(0xE817202B))
                .clickable(onClick = aoAbrirMapa)
                .padding(4.dp)
        ) {
            Canvas(Modifier.fillMaxSize()) {
                drawCircle(fundo)
                // Pequenas manchas de terreno para dar leitura de mapa.
                for (i in 0..8) {
                    val x = size.width * ((i * 37 % 91) / 100f)
                    val y = size.height * ((i * 53 % 89) / 100f)
                    drawCircle(
                        color = if (i % 2 == 0) Color.White.copy(alpha = .13f)
                        else Color(0xFF263B2A).copy(alpha = .22f),
                        radius = size.minDimension * .055f,
                        center = Offset(x, y)
                    )
                }
                // Trilha e curso d'água estilizados.
                val trilha = Path().apply {
                    moveTo(size.width * .08f, size.height * .76f)
                    cubicTo(size.width * .32f, size.height * .58f,
                        size.width * .58f, size.height * .78f,
                        size.width * .94f, size.height * .34f)
                }
                drawPath(trilha, Color(0xFFD7B77D), style = Stroke(size.minDimension * .10f))
                if (!pointId.contains("deserto") && !pointId.contains("abismo")) {
                    val agua = Path().apply {
                        moveTo(size.width * .78f, 0f)
                        cubicTo(size.width * .62f, size.height * .28f,
                            size.width * .92f, size.height * .55f,
                            size.width * .70f, size.height
                        )
                    }
                    drawPath(agua, Color(0xFF55B5CF), style = Stroke(size.minDimension * .055f))
                }
                // O jogador permanece centralizado, como em um minimapa com câmera acompanhando.
                drawCircle(Color(0xFF17202B), size.minDimension * .105f,
                    center = Offset(size.width / 2f, size.height / 2f))
                drawCircle(Color(0xFFFFD36A), size.minDimension * .067f,
                    center = Offset(size.width / 2f, size.height / 2f))
                drawCircle(Color.White, size.minDimension * .025f,
                    center = Offset(size.width / 2f, size.height / 2f))
            }
        }
    }
}
