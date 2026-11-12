package br.com.ascensaodosoberano.character

import androidx.compose.foundation.layout.*
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import br.com.ascensaodosoberano.companions.Equipment
import br.com.ascensaodosoberano.companions.EquipmentLoadout
import coil.compose.AsyncImage

@Composable
fun CharacterAppearancePreview(
    appearance: CharacterAppearance,
    modifier: Modifier = Modifier,
    equippedEquipment: List<Equipment> = emptyList(),
    equipmentLoadout: EquipmentLoadout = EquipmentLoadout(),
    className: String = "",
    showLockedPlaceholder: Boolean = false,
    mostrarTodosAngulos: Boolean = false
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .height(300.dp)
    ) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            when {
                appearance.generatedImageUrl.isNotBlank() -> {
                    if (mostrarTodosAngulos) {
                        AsyncImage(
                            model = appearance.generatedImageUrl,
                            contentDescription = "Quatro vistas do personagem: frente, lado esquerdo, costas e lado direito",
                            modifier = Modifier.fillMaxSize(),
                            contentScale = ContentScale.Fit
                        )
                    } else {
                        ImagemAnguloPersonagem(
                            imageUrl = appearance.generatedImageUrl,
                            angulo = AnguloPersonagem.FRENTE,
                            modifier = Modifier.fillMaxHeight().aspectRatio(1f)
                        )
                    }
                }
                showLockedPlaceholder -> {
                    Column(
                        modifier = Modifier.padding(24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(8.dp)
                    ) {
                        Text("AVENTUREIRO OCULTO", style = MaterialTheme.typography.titleMedium)
                        Text("Escolha uma classe para revelar seu personagem.")
                    }
                }
                else -> {
                    Column(
                        modifier = Modifier.padding(24.dp),
                        horizontalAlignment = Alignment.CenterHorizontally,
                        verticalArrangement = Arrangement.spacedBy(10.dp)
                    ) {
                        Text(
                            className.ifBlank { "Aventureiro" },
                            style = MaterialTheme.typography.titleLarge
                        )
                        Text(
                            "A arte 2.5D desta classe será carregada aqui assim que a geração visual for concluída.",
                            style = MaterialTheme.typography.bodyMedium
                        )
                    }
                }
            }
        }
    }
}


enum class AnguloPersonagem { FRENTE, LADO_ESQUERDO, COSTAS, LADO_DIREITO }

/** Recorta uma das quatro células da folha 2x2 sem solicitar outra imagem. */
@Composable
fun ImagemAnguloPersonagem(
    imageUrl: String,
    angulo: AnguloPersonagem,
    modifier: Modifier = Modifier
) {
    BoxWithConstraints(modifier = modifier.clipToBounds()) {
        val largura = maxWidth
        val altura = maxHeight
        val deslocamentoX = if (
            angulo == AnguloPersonagem.LADO_ESQUERDO ||
            angulo == AnguloPersonagem.LADO_DIREITO
        ) -largura else 0.dp
        val deslocamentoY = if (
            angulo == AnguloPersonagem.COSTAS ||
            angulo == AnguloPersonagem.LADO_DIREITO
        ) -altura else 0.dp

        AsyncImage(
            model = imageUrl,
            contentDescription = when (angulo) {
                AnguloPersonagem.FRENTE -> "Personagem de frente"
                AnguloPersonagem.LADO_ESQUERDO -> "Personagem de lado esquerdo"
                AnguloPersonagem.COSTAS -> "Personagem visto de costas"
                AnguloPersonagem.LADO_DIREITO -> "Personagem de lado direito"
            },
            modifier = Modifier
                .size(largura * 2, altura * 2)
                .offset(x = deslocamentoX, y = deslocamentoY),
            contentScale = ContentScale.FillBounds
        )
    }
}
