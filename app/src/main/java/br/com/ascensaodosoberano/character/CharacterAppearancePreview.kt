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
                Column(
                    modifier = Modifier.padding(16.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                    verticalArrangement = Arrangement.spacedBy(8.dp)
                ) {
                    Text(
                        "Pré-visualização",
                        style = MaterialTheme.typography.titleLarge
                    )

                    Text("Pele: ${appearance.skinId}")
                    Text("Cabelo: ${appearance.hairId}")
                    Text("Olhos: ${appearance.eyeId}")
                    Text("Roupa: ${appearance.outfitId}")

                    Text(
                        "A imagem aparecerá aqui quando a geração visual estiver conectada.",
                        style = MaterialTheme.typography.bodySmall
                    )
                }
            }
        }
    }
}
