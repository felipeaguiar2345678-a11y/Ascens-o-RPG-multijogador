
package br.com.ascensaodosoberano.world

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.Path
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.unit.dp

@Composable
fun TelaMapaMundi(
    localAtualId: String,
    aoSelecionarDestino: (WorldTravelPlan) -> Unit,
    aoVoltar: () -> Unit,
    modifier: Modifier = Modifier
) {
    var destinoSelecionado by remember {
        mutableStateOf<WorldMapPoint?>(null)
    }

    val plano = destinoSelecionado?.let {
        WorldTravelPlanner.createPlan(
            localAtualId,
            it.id
        )
    }

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(Color(0xFF292319))
            .verticalScroll(rememberScrollState())
            .padding(12.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp)
    ) {
        Text(
    "MAPA-MÚNDI",
    style = MaterialTheme.typography.titleLarge,
    color = Color(0xFFE8D4A5)
)

Button(
    onClick = aoVoltar,
    modifier = Modifier.fillMaxWidth()
) {
    Text("VOLTAR À EXPLORAÇÃO")
}
            

        Text(
            "Selecione uma localidade para planejar sua viagem.",
            color = Color.White
        )

        BoxWithConstraints(
            modifier = Modifier.fillMaxWidth().height(370.dp)
                .background(Color(0xFF234B59), RoundedCornerShape(16.dp))
        ) {
            val alturaMapa = 370.dp
            Canvas(Modifier.fillMaxSize()) {
                drawRect(Color(0xFF234B59))
                // Continentes com contornos irregulares, em vez de círculos decorativos.
                val central = Path().apply {
                    moveTo(size.width * .28f, size.height * .28f)
                    cubicTo(size.width * .36f, size.height * .12f, size.width * .58f, size.height * .17f, size.width * .67f, size.height * .34f)
                    cubicTo(size.width * .75f, size.height * .49f, size.width * .63f, size.height * .62f, size.width * .50f, size.height * .59f)
                    cubicTo(size.width * .39f, size.height * .68f, size.width * .22f, size.height * .51f, size.width * .28f, size.height * .28f)
                    close()
                }
                drawPath(central, Color(0xFF82905A))
                val floresta = Path().apply {
                    moveTo(size.width * .43f, size.height * .05f)
                    cubicTo(size.width * .58f, size.height * .01f, size.width * .78f, size.height * .08f, size.width * .82f, size.height * .23f)
                    cubicTo(size.width * .77f, size.height * .34f, size.width * .60f, size.height * .34f, size.width * .49f, size.height * .26f)
                    close()
                }
                drawPath(floresta, Color(0xFF456B45))
                val montanhas = Path().apply {
                    moveTo(0f, size.height * .08f)
                    cubicTo(size.width * .12f, size.height * .01f, size.width * .27f, size.height * .07f, size.width * .34f, size.height * .22f)
                    cubicTo(size.width * .26f, size.height * .34f, size.width * .12f, size.height * .32f, 0f, size.height * .25f)
                    close()
                }
                drawPath(montanhas, Color(0xFF9CB9B8))
                val imperio = Path().apply {
                    moveTo(0f, size.height * .30f)
                    cubicTo(size.width * .13f, size.height * .28f, size.width * .26f, size.height * .39f, size.width * .29f, size.height * .55f)
                    cubicTo(size.width * .23f, size.height * .70f, size.width * .08f, size.height * .65f, 0f, size.height * .57f)
                    close()
                }
                drawPath(imperio, Color(0xFF9B8157))
                val deserto = Path().apply {
                    moveTo(size.width * .03f, size.height * .65f)
                    cubicTo(size.width * .17f, size.height * .58f, size.width * .36f, size.height * .68f, size.width * .40f, size.height * .88f)
                    cubicTo(size.width * .29f, size.height * 1.02f, size.width * .10f, size.height * .97f, size.width * .03f, size.height * .65f)
                    close()
                }
                drawPath(deserto, Color(0xFFC49A5B))
                val sombras = Path().apply {
                    moveTo(size.width * .72f, size.height * .30f)
                    cubicTo(size.width * .84f, size.height * .23f, size.width * .99f, size.height * .34f, size.width, size.height * .52f)
                    lineTo(size.width, size.height * .76f)
                    cubicTo(size.width * .84f, size.height * .73f, size.width * .70f, size.height * .58f, size.width * .72f, size.height * .30f)
                    close()
                }
                drawPath(sombras, Color(0xFF51475D))
                val mar = Path().apply {
                    moveTo(size.width * .56f, size.height * .70f)
                    cubicTo(size.width * .67f, size.height * .61f, size.width * .88f, size.height * .68f, size.width * .98f, size.height * .86f)
                    cubicTo(size.width * .87f, size.height * 1.02f, size.width * .63f, size.height * .96f, size.width * .56f, size.height * .70f)
                    close()
                }
                drawPath(mar, Color(0xFF397D91))
                // Relevo: cadeias de montanhas, manchas de floresta e dunas.
                for (i in 0..18) {
                    val x = (i * 71f + 19f).mod(size.width)
                    val y = (i * 43f + 13f).mod(size.height)
                    if (i % 3 == 0) {
                        val pico = Path().apply {
                            moveTo(x - 9.dp.toPx(), y + 8.dp.toPx())
                            lineTo(x, y - 9.dp.toPx())
                            lineTo(x + 10.dp.toPx(), y + 8.dp.toPx())
                            close()
                        }
                        drawPath(pico, Color(0xFFD9E3D4).copy(alpha = .75f))
                    } else {
                        drawCircle(Color(0xFF294D35).copy(alpha = .35f), 5.dp.toPx(), Offset(x, y))
                    }
                }
                // Estradas e rotas marítimas ligam os pontos cadastrados.
                WorldRouteSystem.routes.forEach { rota ->
                    val origem = WorldMapData.findPoint(rota.fromId)
                    val destino = WorldMapData.findPoint(rota.toId)
                    if (origem != null && destino != null) {
                        val inicio = Offset(size.width * origem.x, size.height * origem.y)
                        val fim = Offset(size.width * destino.x, size.height * destino.y)
                        val cor = if (rota.type == WorldRouteType.SEA_ROUTE) Color(0xFF9CE5E8)
                            else if (rota.type == WorldRouteType.MAIN_ROAD) Color(0xFFFFD98B)
                            else Color(0xFFD0C29C)
                        drawLine(cor.copy(alpha = .8f), inicio, fim,
                            if (rota.type == WorldRouteType.MAIN_ROAD) 3.dp.toPx() else 1.6.dp.toPx(),
                            pathEffect = if (rota.type == WorldRouteType.SEA_ROUTE)
                                androidx.compose.ui.graphics.PathEffect.dashPathEffect(floatArrayOf(7.dp.toPx(), 5.dp.toPx()))
                            else null)
                    }
                }
                // Moldura cartográfica e marcas de orientação.
                drawRect(Color(0xFFE4D1A4), style = Stroke(2.dp.toPx()))
                drawLine(Color(0xFFE4D1A4), Offset(size.width * .5f, 8.dp.toPx()),
                    Offset(size.width * .5f, 24.dp.toPx()), 2.dp.toPx())
            }
            WorldMapData.points.forEach { ponto ->
                val atual = ponto.id == localAtualId
                val selecionado = ponto.id == destinoSelecionado?.id
                Box(
                    modifier = Modifier
                        .offset(x = maxWidth * ponto.x - 7.dp, y = alturaMapa * ponto.y - 7.dp)
                        .size(if (atual || selecionado) 18.dp else 12.dp)
                        .background(
                            when {
                                atual -> Color(0xFFFFE16B)
                                selecionado -> Color(0xFFFFA64D)
                                ponto.type == WorldPointType.CAPITAL -> Color(0xFFFFE9B0)
                                ponto.type == WorldPointType.CITY || ponto.type == WorldPointType.VILLAGE -> Color(0xFFF0D6A0)
                                else -> Color(0xFFB7D6D0)
                            }, CircleShape
                        )
                        .clickable(enabled = !atual) { destinoSelecionado = ponto }
                )
            }
            Text("N", color = Color(0xFFFFE9B0), modifier = Modifier.align(Alignment.TopCenter).padding(top = 5.dp))
            Text("VOCÊ", color = Color(0xFFFFE16B), style = MaterialTheme.typography.labelSmall,
                modifier = Modifier.align(Alignment.BottomStart).padding(8.dp))
        }

        WorldRegion.values().forEach { region ->

            Text(
                region.displayName,
                style = MaterialTheme.typography.titleMedium,
                color = Color(0xFFE8D4A5)
            )

            WorldMapData.pointsInRegion(region).forEach { point ->

                val isCurrent = point.id == localAtualId

                Card(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable(enabled = !isCurrent) {
                            destinoSelecionado = point
                        },
                    colors = CardDefaults.cardColors(
                        containerColor = if (destinoSelecionado?.id == point.id) {
                            Color(0xFF76613C)
                        } else {
                            Color(0xFF40382B)
                        }
                    )
                ) {
                    Column(
                        modifier = Modifier.padding(12.dp)
                    ) {
                        Text(
                            point.name,
                            color = Color.White
                        )

                        Text(
                            when {
                                isCurrent -> "Localização atual"
                                point.type == WorldPointType.CAPITAL -> "Capital"
                                else -> point.type.name
                            },
                            color = Color(0xFFE8D4A5)
                        )
                    }
                }
            }
        }

        if (destinoSelecionado != null) {
            Divider(color = Color(0xFFE8D4A5))

            Text(
                "PLANEJAMENTO DE VIAGEM",
                color = Color(0xFFE8D4A5),
                style = MaterialTheme.typography.titleMedium
            )

            Text(
                "Destino: ${destinoSelecionado!!.name}",
                color = Color.White
            )

            if (plano == null) {
                Text(
                    "Não existe uma rota disponível para esse destino.",
                    color = Color(0xFFFFB4AB)
                )
            } else {
                Text(
                    "Distância: ${plano.totalDistance}",
                    color = Color.White
                )

                Text(
                    "Tempo estimado: ${plano.estimatedTime}",
                    color = Color.White
                )

                Text(
                    "Trechos da rota: ${plano.route.size}",
                    color = Color.White
                )

                Button(
                    onClick = {
                        aoSelecionarDestino(plano)
                    },
                    modifier = Modifier.fillMaxWidth()
                ) {
                    Text("CONFIRMAR DESTINO")
                }
            }
        }
    }
}
