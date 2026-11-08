package br.com.ascensaodosoberano.character

import androidx.compose.foundation.layout.*
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage

@Composable
fun CharacterAppearancePreview(
    appearance: CharacterAppearance,
    modifier: Modifier = Modifier
) {
    Card(
        modifier = modifier
            .fillMaxWidth()
            .height(260.dp)
    ) {
        Box(
            modifier = Modifier.fillMaxSize(),
            contentAlignment = Alignment.Center
        ) {
            if (appearance.generatedImageUrl.isNotBlank()) {
                AsyncImage(
                    model = appearance.generatedImageUrl,
                    contentDescription = "Imagem do personagem",
                    modifier = Modifier.fillMaxSize(),
                    contentScale = ContentScale.Fit
                )
            } else {
                Row(
                    modifier = Modifier.fillMaxSize().padding(12.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    PersonagemPixelArt(
                        appearance = appearance,
                        modifier = Modifier.size(138.dp)
                    )
                    Column(
                        verticalArrangement = Arrangement.spacedBy(7.dp)
                    ) {
                        Text("Seu aventureiro", style = MaterialTheme.typography.titleMedium)
                        Text("Pele: ${appearance.skinId}")
                        Text("Cabelo: ${appearance.hairId}")
                        Text("Olhos: ${appearance.eyeId}")
                        Text("Roupa: ${appearance.outfitId}")
                        Text(
                            "A prévia usa as opções escolhidas no criador.",
                            style = MaterialTheme.typography.bodySmall
                        )
                    }
                }
            }
        }
    }
}
