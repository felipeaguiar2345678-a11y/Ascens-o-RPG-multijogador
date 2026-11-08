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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

@Composable
fun TelaMapaMundi(
    localAtualId: String,
    aoSelecionarDestino: (WorldTravelPlan) -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier
) {
    var destinoSelecionado by remember { mutableStateOf<WorldMapPoint?>(null) }
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
                Text("Escolha para onde deseja viajar", color = Color(0xFFD4DCE5), fontSize = 11.sp)
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
                WorldRouteSystem.routes.forEach { rota ->
                    val a = WorldMapData.findPoint(rota.fromId)
                    val b = WorldMapData.findPoint(rota.toId)
                    if (a != null && b != null) {
                        val start = Offset(size.width*a.x, size.height*a.y)
                        val end = Offset(size.width*b.x, size.height*b.y)
                        val color = when (rota.type) {
                            WorldRouteType.MAIN_ROAD -> Color(0xFFFFD98B)
                            WorldRouteType.SECONDARY_ROAD -> Color(0xFFD5C39B)
                            WorldRouteType.SEA_ROUTE -> Color(0xFF9CE5E8)
                        }
                        drawLine(
                            color.copy(alpha=.82f), start, end,
                            if (rota.type == WorldRouteType.MAIN_ROAD) 3.dp.toPx() else 1.6.dp.toPx(),
                            pathEffect = if (rota.type == WorldRouteType.SEA_ROUTE)
                                androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(7.dp.toPx(),5.dp.toPx()))
                            else null
                        )
                    }
                }
                drawRect(Color(0xFFE4D1A4), style=Stroke(1.5.dp.toPx()))
            }

            WorldMapData.points.forEach { point ->
                val atual = point.id == localAtualId
                val selecionado = point.id == destinoSelecionado?.id
                Box(
                    modifier = Modifier
                        .offset(x = maxWidth * point.x - 21.dp, y = mapaAltura * point.y - 21.dp)
                        .size(42.dp)
                        .clickable { if (!atual) destinoSelecionado = point },
                    contentAlignment = Alignment.Center
                ) {
                    Box(
                        Modifier.size(if (selecionado || atual) 19.dp else 13.dp)
                            .background(
                                when {
                                    atual -> Color(0xFFFFE16B)
                                    selecionado -> Color(0xFFFF9D45)
                                    point.type == WorldPointType.CAPITAL -> Color(0xFFFFE9B0)
                                    point.type == WorldPointType.CITY || point.type == WorldPointType.VILLAGE -> Color(0xFFF0D6A0)
                                    else -> Color(0xFFB7D6D0)
                                }, CircleShape
                            )
                    )
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
                        ) { Text("CONFIRMAR VIAGEM") }
                    }
                }
            }
        }
    }
}
