package br.com.ascensaodosoberano.character

import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.*
import androidx.compose.foundation.rememberScrollState
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp

@Composable
fun CharacterAppearanceScreen(
    appearance: CharacterAppearance,
    onAppearanceChange: (CharacterAppearance) -> Unit
) {
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(16.dp),
        verticalArrangement = Arrangement.spacedBy(16.dp)
    ) {
        Text(
            text = "Personalização do Personagem",
            style = MaterialTheme.typography.headlineSmall
        )

        AppearanceSection(
            title = "Tom de pele",
            options = AppearanceOptions.skinTones,
            selectedId = appearance.skinId,
            onSelect = {
                onAppearanceChange(
                    AppearanceEditor.changeSkin(appearance, it)
                )
            }
        )

        AppearanceSection(
            title = "Rosto",
            options = AppearanceOptions.faces,
            selectedId = appearance.faceId,
            onSelect = {
                onAppearanceChange(
                    AppearanceEditor.changeFace(appearance, it)
                )
            }
        )

        AppearanceSection(
            title = "Cabelo",
            options = AppearanceOptions.hairstyles,
            selectedId = appearance.hairId,
            onSelect = {
                onAppearanceChange(
                    AppearanceEditor.changeHair(appearance, it)
                )
            }
        )

        AppearanceSection(
            title = "Cor do cabelo",
            options = AppearanceOptions.hairColors,
            selectedId = appearance.hairColorId,
            onSelect = {
                onAppearanceChange(
                    AppearanceEditor.changeHairColor(appearance, it)
                )
            }
        )

        AppearanceSection(
            title = "Olhos",
            options = AppearanceOptions.eyeStyles,
            selectedId = appearance.eyeId,
            onSelect = {
                onAppearanceChange(
                    AppearanceEditor.changeEyes(appearance, it)
                )
            }
        )

        AppearanceSection(
            title = "Roupas",
            options = AppearanceOptions.outfits,
            selectedId = appearance.outfitId,
            onSelect = {
                onAppearanceChange(
                    AppearanceEditor.changeOutfit(appearance, it)
                )
            }
        )

        OutlinedButton(
            onClick = {
                onAppearanceChange(
                    AppearanceEditor.randomize(appearance)
                )
            },
            modifier = Modifier.fillMaxWidth()
        ) {
            Text("Aparência aleatória")
        }
    }
}

@Composable
private fun AppearanceSection(
    title: String,
    options: List<AppearanceOption>,
    selectedId: String,
    onSelect: (String) -> Unit
) {
    Column(
        verticalArrangement = Arrangement.spacedBy(8.dp)
    ) {
        Text(
            text = title,
            style = MaterialTheme.typography.titleMedium
        )

        Row(
            modifier = Modifier.horizontalScroll(
                rememberScrollState()
            ),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            options.forEach { option ->
                FilterChip(
                    selected = selectedId == option.id,
                    onClick = {
                        onSelect(option.id)
                    },
                    label = {
                        Text(option.name)
                    }
                )
            }
        }
    }
}