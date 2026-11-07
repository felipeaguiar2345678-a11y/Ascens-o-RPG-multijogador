
package br.com.ascensaodosoberano.world

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.*
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
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

        Canvas(
            modifier = Modifier
                .fillMaxWidth()
                .height(300.dp)
                .background(Color(0xFFB69A68))
        ) {
            drawRect(Color(0xFFB69A68))

            drawCircle(
                color = Color(0xFF52734D),
                radius = size.width * 0.18f,
                center = Offset(
                    size.width * 0.48f,
                    size.height * 0.48f
                )
            )

            drawCircle(
                color = Color(0xFF496B78),
                radius = size.width * 0.12f,
                center = Offset(
                    size.width * 0.86f,
                    size.height * 0.78f
                )
            )

            drawCircle(
                color = Color(0xFF7C6546),
                radius = size.width * 0.10f,
                center = Offset(
                    size.width * 0.20f,
                    size.height * 0.20f
                )
            )
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
