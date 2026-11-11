package br.com.ascensaodosoberano.character

import androidx.compose.foundation.layout.*
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
    showLockedPlaceholder: Boolean = false
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
                    AsyncImage(
                        model = appearance.generatedImageUrl,
                        contentDescription = "Personagem: $className",
                        modifier = Modifier.fillMaxSize(),
                        contentScale = ContentScale.Fit
                    )
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
