package br.com.ascensaodosoberano.world

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import kotlin.math.absoluteValue

@Composable
fun TelaMapaMundi(
    localAtualId: String,
    aoSelecionarDestino: (WorldTravelPlan) -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier
) {
    var destinoSelecionado by remember(localAtualId) { mutableStateOf<WorldMapPoint?>(null) }
    val plano = destinoSelecionado?.let {
        WorldTravelPlanner.createPlan(localAtualId, it.id)
    }

    Column(
        modifier = modifier.fillMaxSize()
            .background(Color(0xFF151D27))
            .padding(horizontal = 12.dp, vertical = 8.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            verticalAlignment = Alignment.CenterVertically,
            horizontalArrangement = Arrangement.SpaceBetween
        ) {
            Column(Modifier.weight(1f)) {
                Text("MUNDO DE ASCENSÃO", color = Color(0xFFFFD98B), fontSize = 18.sp)
                Text("Selecione um destino para traçar o caminho. A viagem será feita caminhando.", color = Color(0xFFD4DCE5), fontSize = 11.sp)
            }
            OutlinedButton(
                onClick = aoVoltar,
                contentPadding = PaddingValues(horizontal = 12.dp, vertical = 7.dp),
                colors = ButtonDefaults.outlinedButtonColors(contentColor = Color(0xFFFFD98B))
            ) { Text("VOLTAR", fontSize = 11.sp) }
        }

        BoxWithConstraints(
            modifier = Modifier.fillMaxWidth().weight(1f)
                .heightIn(min = 300.dp, max = 510.dp)
                .background(Color(0xFF173D4A), RoundedCornerShape(14.dp))
        ) {
            val mapaAltura = maxHeight
            Canvas(Modifier.fillMaxSize()) {
                drawRect(Color(0xFF173D4A))
                // Massas de terra com contornos orgânicos e cores próprias por região.
                val montanhas = Path().apply {
                    moveTo(0f, size.height * .08f)
                    cubicTo(size.width*.08f, -size.height*.02f, size.width*.27f, size.height*.03f, size.width*.35f, size.height*.22f)
                    cubicTo(size.width*.28f, size.height*.34f, size.width*.12f, size.height*.34f, 0f, size.height*.26f)
                    close()
                }
                drawPath(montanhas, Color(0xFF91B3B4))
                val imperio = Path().apply {
                    moveTo(0f, size.height*.31f)
                    cubicTo(size.width*.13f, size.height*.27f, size.width*.25f, size.height*.38f, size.width*.30f, size.height*.55f)
                    cubicTo(size.width*.22f, size.height*.69f, size.width*.07f, size.height*.66f, 0f, size.height*.58f)
                    close()
                }
                drawPath(imperio, Color(0xFF927B55))
                val central = Path().apply {
                    moveTo(size.width*.28f, size.height*.28f)
                    cubicTo(size.width*.37f, size.height*.12f, size.width*.57f, size.height*.17f, size.width*.68f, size.height*.34f)
                    cubicTo(size.width*.78f, size.height*.51f, size.width*.63f, size.height*.65f, size.width*.49f, size.height*.60f)
                    cubicTo(size.width*.35f, size.height*.69f, size.width*.20f, size.height*.50f, size.width*.28f, size.height*.28f)
                    close()
                }
                drawPath(central, Color(0xFF788B59))
                val floresta = Path().apply {
                    moveTo(size.width*.43f, size.height*.05f)
                    cubicTo(size.width*.57f, size.height*.01f, size.width*.79f, size.height*.07f, size.width*.84f, size.height*.23f)
                    cubicTo(size.width*.77f, size.height*.36f, size.width*.60f, size.height*.34f, size.width*.49f, size.height*.26f)
                    close()
                }
                drawPath(floresta, Color(0xFF3E6848))
                val sombras = Path().apply {
                    moveTo(size.width*.72f, size.height*.30f)
                    cubicTo(size.width*.86f, size.height*.22f, size.width*1.02f, size.height*.34f, size.width*1.02f, size.height*.55f)
                    lineTo(size.width*1.02f, size.height*.77f)
                    cubicTo(size.width*.85f, size.height*.74f, size.width*.70f, size.height*.58f, size.width*.72f, size.height*.30f)
                    close()
                }
                drawPath(sombras, Color(0xFF51465D))
                val deserto = Path().apply {
                    moveTo(size.width*.03f, size.height*.65f)
                    cubicTo(size.width*.17f, size.height*.58f, size.width*.36f, size.height*.68f, size.width*.41f, size.height*.88f)
                    cubicTo(size.width*.29f, size.height*1.02f, size.width*.10f, size.height*.98f, size.width*.03f, size.height*.65f)
                    close()
                }
                drawPath(deserto, Color(0xFFC29A5E))
                val mar = Path().apply {
                    moveTo(size.width*.56f, size.height*.70f)
                    cubicTo(size.width*.68f, size.height*.61f, size.width*.88f, size.height*.68f, size.width*.99f, size.height*.86f)
                    cubicTo(size.width*.86f, size.height*1.02f, size.width*.63f, size.height*.96f, size.width*.56f, size.height*.70f)
                    close()
                }
                drawPath(mar, Color(0xFF347D91))
                // Relevo cartográfico: cordilheiras, copas e dunas.
                for (i in 0..34) {
                    val x = (i * 71f + 19f).mod(size.width)
                    val y = (i * 43f + 13f).mod(size.height)
                    if (i % 3 == 0) {
                        val pico = Path().apply {
                            moveTo(x-8.dp.toPx(), y+7.dp.toPx())
                            lineTo(x, y-8.dp.toPx())
                            lineTo(x+9.dp.toPx(), y+7.dp.toPx())
                            close()
                        }
                        drawPath(pico, Color(0xFFD9E3D4).copy(alpha=.72f))
                    } else {
                        drawCircle(Color(0xFF294D35).copy(alpha=.28f), 4.dp.toPx(), Offset(x,y))
                    }
                }
                // Ilustração do relevo: trilhas de altitude, copas, dunas e ondas.
                // Os detalhes são determinísticos para o mapa manter a mesma leitura em cada abertura.
                for (i in 0..11) {
                    val x = size.width * (0.035f + i * 0.027f)
                    val y = size.height * (0.075f + (i % 4) * 0.035f)
                    val cordilheira = Path().apply {
                        moveTo(x, y + 18.dp.toPx())
                        lineTo(x + 9.dp.toPx(), y)
                        lineTo(x + 18.dp.toPx(), y + 18.dp.toPx())
                    }
                    drawPath(cordilheira, Color(0xFFECF1E5).copy(alpha = .68f), style = Stroke(1.5.dp.toPx()))
                    drawLine(Color(0xFF607D83).copy(alpha = .55f),
                        Offset(x + 5.dp.toPx(), y + 14.dp.toPx()),
                        Offset(x + 13.dp.toPx(), y + 14.dp.toPx()), 1.dp.toPx())
                }
                for (i in 0..22) {
                    val x = size.width * (0.46f + (i % 8) * 0.047f)
                    val y = size.height * (0.075f + (i / 8) * 0.065f)
                    val tronco = Offset(x, y + 5.dp.toPx())
                    drawLine(Color(0xFF493B2B), tronco, Offset(x, y + 10.dp.toPx()), 1.5.dp.toPx())
                    drawCircle(Color(0xFF244B35), 5.dp.toPx(), Offset(x, y))
                    drawCircle(Color(0xFF47744A), 3.dp.toPx(), Offset(x - 2.dp.toPx(), y - 2.dp.toPx()))
                }
                for (i in 0..7) {
                    val y = size.height * (0.69f + i * 0.032f)
                    val duna = Path().apply {
                        moveTo(size.width * .035f, y)
                        cubicTo(size.width * .13f, y - 12.dp.toPx(), size.width * .24f, y + 12.dp.toPx(), size.width * .39f, y - 2.dp.toPx())
                    }
                    drawPath(duna, Color(0xFFFFE0A0).copy(alpha = .48f), style = Stroke(1.4.dp.toPx()))
                }
                for (i in 0..9) {
                    val y = size.height * (0.73f + i * 0.025f)
                    val onda = Path().apply {
                        moveTo(size.width * .58f, y)
                        cubicTo(size.width * .68f, y - 8.dp.toPx(), size.width * .82f, y + 8.dp.toPx(), size.width * .97f, y)
                    }
                    drawPath(onda, Color(0xFF9ADDE0).copy(alpha = .48f), style = Stroke(1.2.dp.toPx()))
                }
                // Pequenos cursos d'água atravessam as Terras Centrais.
                val rio = Path().apply {
                    moveTo(size.width * .38f, size.height * .20f)
                    cubicTo(size.width * .34f, size.height * .34f, size.width * .53f, size.height * .39f, size.width * .48f, size.height * .57f)
                    cubicTo(size.width * .46f, size.height * .65f, size.width * .57f, size.height * .67f, size.width * .61f, size.height * .72f)
                }
                drawPath(rio, Color(0xFF8CCED0).copy(alpha = .82f), style = Stroke(2.2.dp.toPx()))
                drawPath(rio, Color(0xFFD0F0E9).copy(alpha = .6f), style = Stroke(.8.dp.toPx()))

                // Cada estrada usa uma curva cartográfica própria, com desvio lateral
                // determinístico. Assim o traçado acompanha o relevo em vez de ligar
                // cidades por segmentos retos.
                fun caminhoDaEstrada(rota: WorldRoute): Path? {
                    val a = WorldMapData.findPoint(rota.fromId) ?: return null
                    val b = WorldMapData.findPoint(rota.toId) ?: return null
                    val inicio = Offset(size.width * a.x, size.height * a.y)
                    val fim = Offset(size.width * b.x, size.height * b.y)
                    val dx = fim.x - inicio.x
                    val dy = fim.y - inicio.y
                    val comprimento = kotlin.math.sqrt(dx * dx + dy * dy).coerceAtLeast(1f)
                    val lado = if (rota.fromId < rota.toId) 1f else -1f
                    val intensidade = when (rota.type) {
                        WorldRouteType.MAIN_ROAD -> 0.13f
                        WorldRouteType.SECONDARY_ROAD -> 0.19f
                        WorldRouteType.SEA_ROUTE -> 0.10f
                    }
                    val ondulacao = ((rota.fromId.hashCode() xor rota.toId.hashCode()).absoluteValue % 17) / 100f
                    val desvio = comprimento * (intensidade + ondulacao) * lado
                    val nx = -dy / comprimento
                    val ny = dx / comprimento
                    val p = Path().apply {
                        moveTo(inicio.x, inicio.y)
                        cubicTo(
                            inicio.x + dx * .28f + nx * desvio,
                            inicio.y + dy * .28f + ny * desvio,
                            inicio.x + dx * .72f + nx * desvio,
                            inicio.y + dy * .72f + ny * desvio,
                            fim.x, fim.y
                        )
                    }
                    return p
                }

                WorldRouteSystem.routes.forEach { rota ->
                    val estrada = caminhoDaEstrada(rota) ?: return@forEach
                    val cor = when (rota.type) {
                        WorldRouteType.MAIN_ROAD -> Color(0xFFB99A68)
                        WorldRouteType.SECONDARY_ROAD -> Color(0xFF9A896C)
                        WorldRouteType.SEA_ROUTE -> Color(0xFF9CE5E8)
                    }
                    drawPath(
                        estrada,
                        cor.copy(alpha = .88f),
                        style = Stroke(
                            width = if (rota.type == WorldRouteType.MAIN_ROAD) 4.dp.toPx() else 2.2.dp.toPx(),
                            cap = androidx.compose.ui.graphics.StrokeCap.Round,
                            pathEffect = if (rota.type == WorldRouteType.SEA_ROUTE)
                                androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(7.dp.toPx(), 5.dp.toPx()))
                            else null
                        )
                    )
                    if (rota.type != WorldRouteType.SEA_ROUTE) {
                        drawPath(
                            estrada, Color(0xFFE8D6A9).copy(alpha = .62f),
                            style = Stroke(width = .8.dp.toPx(), cap = androidx.compose.ui.graphics.StrokeCap.Round)
                        )
                    }
                }

                // Rota escolhida recebe uma faixa luminosa exatamente sobre as estradas
                // percorridas pelo planejador, inclusive quando há várias conexões.
                plano?.route?.forEach { rota ->
                    val estrada = caminhoDaEstrada(rota) ?: return@forEach
                    drawPath(
                        estrada,
                        Color(0xFF8A4B20).copy(alpha = .92f),
                        style = Stroke(width = 8.dp.toPx(), cap = androidx.compose.ui.graphics.StrokeCap.Round)
                    )
                    drawPath(
                        estrada,
                        Color(0xFFFFC46B),
                        style = Stroke(width = 4.dp.toPx(), cap = androidx.compose.ui.graphics.StrokeCap.Round)
                    )
                    drawPath(
                        estrada,
                        Color(0xFFFFF0C8).copy(alpha = .95f),
                        style = Stroke(width = 1.2.dp.toPx(), cap = androidx.compose.ui.graphics.StrokeCap.Round)
                    )
                }
                drawRect(Color(0xFFE4D1A4), style=Stroke(1.5.dp.toPx()))
            }

            // Nomes regionais gravados no próprio mapa para orientar a leitura do mundo.
            val rotulosRegioes = listOf(
                Triple("MONTANHAS GÉLIDAS", .12f, .09f),
                Triple("FLORESTA ARCANA", .57f, .12f),
                Triple("REGIÃO DO IMPÉRIO", .09f, .43f),
                Triple("REGIÃO CENTRAL", .38f, .49f),
                Triple("REGIÃO DAS SOMBRAS", .77f, .34f),
                Triple("DESERTO ANCESTRAL", .12f, .83f),
                Triple("MAR ETERNO", .72f, .82f)
            )
            rotulosRegioes.forEach { (nome, x, y) ->
                Text(
                    nome,
                    color = Color(0xFFF2E3C2).copy(alpha = .88f),
                    fontSize = 8.sp,
                    modifier = Modifier
                        .offset(x = maxWidth * x, y = mapaAltura * y)
                        .background(Color(0x99202A2D), RoundedCornerShape(4.dp))
                        .padding(horizontal = 4.dp, vertical = 2.dp)
                )
            }

            WorldMapData.points.forEach { point ->
                val atual = point.id == localAtualId
                val selecionado = point.id == destinoSelecionado?.id
                Box(
                    modifier = Modifier
                         .offset(x = maxWidth * point.x - 28.dp, y = mapaAltura * point.y - 28.dp)
                        .size(56.dp)
                        .clickable { if (!atual) destinoSelecionado = point },
                    contentAlignment = Alignment.Center
                ) {
                    Canvas(Modifier.size(if (selecionado || atual) 34.dp else 30.dp)) {
                        val destaque = when {
                            atual -> Color(0xFFFFE16B)
                            selecionado -> Color(0xFFFF9D45)
                            point.type == WorldPointType.CAPITAL -> Color(0xFFFFE9B0)
                            point.type == WorldPointType.CITY || point.type == WorldPointType.VILLAGE -> Color(0xFFF0D6A0)
                            else -> Color(0xFFB7D6D0)
                        }
                        val centro = Offset(size.width / 2f, size.height / 2f)
                        drawCircle(destaque.copy(alpha = if (atual || selecionado) .30f else .16f), size.minDimension * .48f, centro)
                        drawCircle(destaque, size.minDimension * .39f, centro, style = Stroke(1.4.dp.toPx()))
                        val escuro = Color(0xFF29313A)
                        val w = size.width
                        val h = size.height
                        when (point.type) {
                            WorldPointType.CAPITAL -> {
                                drawRect(destaque, Offset(w*.27f,h*.39f), Size(w*.46f,h*.43f))
                                drawRect(destaque, Offset(w*.13f,h*.23f), Size(w*.22f,h*.58f))
                                drawRect(destaque, Offset(w*.65f,h*.23f), Size(w*.22f,h*.58f))
                                drawRect(escuro, Offset(w*.45f,h*.58f), Size(w*.10f,h*.24f))
                                drawLine(escuro, Offset(w*.13f,h*.23f), Offset(w*.24f,h*.08f), 1.8.dp.toPx())
                                drawLine(escuro, Offset(w*.24f,h*.08f), Offset(w*.35f,h*.23f), 1.8.dp.toPx())
                                drawLine(escuro, Offset(w*.65f,h*.23f), Offset(w*.76f,h*.08f), 1.8.dp.toPx())
                                drawLine(escuro, Offset(w*.76f,h*.08f), Offset(w*.87f,h*.23f), 1.8.dp.toPx())
                            }
                            WorldPointType.CITY -> {
                                drawRect(destaque, Offset(w*.25f,h*.38f), Size(w*.50f,h*.44f))
                                drawRect(escuro, Offset(w*.37f,h*.53f), Size(w*.10f,h*.12f))
                                drawRect(escuro, Offset(w*.55f,h*.53f), Size(w*.10f,h*.12f))
                                drawLine(destaque, Offset(w*.18f,h*.38f), Offset(w*.50f,h*.17f), 2.dp.toPx())
                                drawLine(destaque, Offset(w*.50f,h*.17f), Offset(w*.82f,h*.38f), 2.dp.toPx())
                            }
                            WorldPointType.VILLAGE -> {
                                drawRect(destaque, Offset(w*.29f,h*.48f), Size(w*.42f,h*.34f))
                                val telhado = Path().apply {
                                    moveTo(w*.18f,h*.49f); lineTo(w*.50f,h*.20f); lineTo(w*.82f,h*.49f); close()
                                }
                                drawPath(telhado, destaque)
                                drawRect(escuro, Offset(w*.45f,h*.60f), Size(w*.10f,h*.22f))
                            }
                            WorldPointType.DUNGEON -> {
                                val caverna = Path().apply {
                                    moveTo(w*.16f,h*.76f); lineTo(w*.24f,h*.40f); lineTo(w*.43f,h*.19f)
                                    lineTo(w*.66f,h*.26f); lineTo(w*.84f,h*.76f); close()
                                }
                                drawPath(caverna, destaque)
                                drawArc(escuro, 180f, 180f, false, Offset(w*.34f,h*.43f), Size(w*.32f,h*.36f))
                            }
                            WorldPointType.TOWER -> {
                                drawRect(destaque, Offset(w*.37f,h*.25f), Size(w*.26f,h*.62f))
                                val topo = Path().apply {
                                    moveTo(w*.28f,h*.27f); lineTo(w*.50f,h*.05f); lineTo(w*.72f,h*.27f); close()
                                }
                                drawPath(topo, destaque)
                                drawRect(escuro, Offset(w*.45f,h*.53f), Size(w*.10f,h*.13f))
                            }
                            WorldPointType.RUINS -> {
                                drawRect(destaque, Offset(w*.20f,h*.30f), Size(w*.13f,h*.55f))
                                drawRect(destaque, Offset(w*.44f,h*.20f), Size(w*.13f,h*.65f))
                                drawRect(destaque, Offset(w*.68f,h*.34f), Size(w*.13f,h*.51f))
                                drawLine(destaque, Offset(w*.14f,h*.28f), Offset(w*.82f,h*.28f), 2.dp.toPx())
                            }
                            WorldPointType.LANDMARK -> {
                                drawCircle(destaque, size.minDimension*.22f, centro)
                                drawCircle(escuro, size.minDimension*.08f, centro)
                            }
                        }
                    }
                }
                if (selecionado || atual) {
                    Text(
                        if (atual) "VOCÊ · ${point.name}" else point.name,
                        color = Color(0xFFFFF0C9),
                        fontSize = 9.sp,
                        modifier = Modifier
                            .offset(x = maxWidth * point.x - 42.dp, y = mapaAltura * point.y + 17.dp)
                            .background(Color(0xDD17202A), RoundedCornerShape(5.dp))
                            .padding(horizontal=5.dp, vertical=2.dp)
                    )
                }
            }
            Text("N", color=Color(0xFFFFE9B0), modifier=Modifier.align(Alignment.TopCenter).padding(5.dp))
        }

        Text("LOCALIDADES", color=Color(0xFFFFD98B), fontSize=10.sp)
        Row(
            Modifier.fillMaxWidth().horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(6.dp)
        ) {
            WorldMapData.points.filter { it.id != localAtualId }.forEach { point ->
                val selected = point.id == destinoSelecionado?.id
                FilterChip(
                    selected = selected,
                    onClick = { destinoSelecionado = point },
                    label = { Text(point.name, fontSize=10.sp) }
                )
            }
        }

        Card(
            modifier = Modifier.fillMaxWidth(),
            colors = CardDefaults.cardColors(containerColor=Color(0xFF222E3C)),
            shape=RoundedCornerShape(12.dp)
        ) {
            Column(Modifier.fillMaxWidth().padding(10.dp), verticalArrangement=Arrangement.spacedBy(5.dp)) {
                if (destinoSelecionado == null) {
                    Text("Toque em um ponto do mapa ou escolha uma localidade acima.", color=Color(0xFFD4DCE5), fontSize=11.sp)
                } else {
                    Text("DESTINO: ${destinoSelecionado!!.name}", color=Color(0xFFFFE0A5), fontSize=13.sp)
                    if (plano == null) {
                        Text("Não há caminho conectado a partir da sua localização atual.", color=Color(0xFFFFB4AB), fontSize=11.sp)
                    } else {
                        Text("Distância: ${"%.1f".format(plano.totalDistance)} · Tempo estimado: ${"%.1f".format(plano.estimatedTime)}", color=Color.White, fontSize=11.sp)
                        Button(
                            onClick = { aoSelecionarDestino(plano) },
                            modifier=Modifier.fillMaxWidth(),
                            contentPadding=PaddingValues(vertical=8.dp)
                        ) { Text("MARCAR ROTA") }
                    }
                }
            }
        }
    }
}
