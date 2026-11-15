package br.com.ascensaodosoberano.character

import androidx.compose.foundation.layout.*
import androidx.compose.ui.draw.clipToBounds
import androidx.compose.material3.*
import androidx.compose.runtime.Composable
import androidx.compose.runtime.produceState
import com.google.firebase.storage.FirebaseStorage
import kotlinx.coroutines.tasks.await
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.unit.dp
import br.com.ascensaodosoberano.companions.Equipment
import br.com.ascensaodosoberano.companions.EquipmentLoadout
import br.com.ascensaodosoberano.companions.EquipmentType
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
                    when {
                        mostrarTodosAngulos && appearance.visualVersion >= 2 -> {
                            Box(modifier = Modifier.fillMaxSize()) {
                                // Na vista traseira, armas e escudos ficam atrás do corpo.
                                CamadasEquipamentoFolhaCompleta(
                                    equipment = equippedEquipment,
                                    camadaTraseira = true,
                                    modifier = Modifier.fillMaxSize()
                                )
                                AsyncImage(
                                    model = appearance.generatedImageUrl,
                                    contentDescription = "Quatro vistas do personagem: frente, lado esquerdo, costas e lado direito",
                                    modifier = Modifier.fillMaxSize(),
                                    contentScale = ContentScale.Fit
                                )
                                CamadasEquipamentoFolhaCompleta(
                                    equipment = equippedEquipment,
                                    camadaTraseira = false,
                                    modifier = Modifier.fillMaxSize()
                                )
                            }
                        }
                        appearance.visualVersion >= 2 -> {
                            Box(
                                modifier = Modifier.fillMaxHeight().aspectRatio(1f),
                                contentAlignment = Alignment.Center
                            ) {
                                CamadasEquipamentoPersonagem(
                                    equipment = equippedEquipment,
                                    angulo = AnguloPersonagem.FRENTE,
                                    camadaTraseira = true,
                                    modifier = Modifier.fillMaxSize()
                                )
                                ImagemAnguloPersonagem(
                                    imageUrl = appearance.generatedImageUrl,
                                    angulo = AnguloPersonagem.FRENTE,
                                    modifier = Modifier.fillMaxSize()
                                )
                                CamadasEquipamentoPersonagem(
                                    equipment = equippedEquipment,
                                    angulo = AnguloPersonagem.FRENTE,
                                    camadaTraseira = false,
                                    modifier = Modifier.fillMaxSize()
                                )
                            }
                        }
                        else -> {
                            AsyncImage(
                                model = appearance.generatedImageUrl,
                                contentDescription = "Personagem: $className",
                                modifier = Modifier.fillMaxSize(),
                                contentScale = ContentScale.Fit
                            )
                        }
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

/** Armas e escudos da vista traseira são compostos atrás do corpo-base. */
private fun pertenceCamadaTraseira(type: EquipmentType, angulo: AnguloPersonagem): Boolean =
    angulo == AnguloPersonagem.COSTAS &&
        (type == EquipmentType.WEAPON || type == EquipmentType.SHIELD)

/** Resolve a folha da fase de profundidade, mantendo fallback para artes antigas. */
private fun caminhoCamadaEquipamento(
    item: Equipment,
    angulo: AnguloPersonagem,
    camadaTraseira: Boolean
): String {
    val temCamadasSeparadas = item.visualCamadaTraseiraCaminho.isNotBlank() ||
        item.visualCamadaDianteiraCaminho.isNotBlank()
    if (temCamadasSeparadas) {
        return if (camadaTraseira) {
            item.visualCamadaTraseiraCaminho
        } else {
            item.visualCamadaDianteiraCaminho
        }
    }
    if (pertenceCamadaTraseira(item.type, angulo) != camadaTraseira) return ""
    return when (angulo) {
        AnguloPersonagem.FRENTE -> item.visualFrenteCaminho
        AnguloPersonagem.COSTAS -> item.visualCostasCaminho
        AnguloPersonagem.LADO_ESQUERDO -> item.visualLadoEsquerdoCaminho
        AnguloPersonagem.LADO_DIREITO -> item.visualLadoDireitoCaminho
    }
}

/**
 * Ordem única de composição das camadas. Itens de mão ficam por último para
 * permanecerem visíveis sobre luvas e armadura; acessórios ficam abaixo deles.
 * A ordem controla a sobreposição 2D, não cria profundidade parcial por membro.
 */
private fun ordenarCamadasEquipamento(equipment: List<Equipment>): List<Equipment> {
    val ordem = mapOf(
        EquipmentType.BOOTS to 10,
        EquipmentType.ARMOR to 20,
        EquipmentType.NECKLACE to 30,
        EquipmentType.HELMET to 40,
        EquipmentType.GLOVES to 50,
        EquipmentType.RING to 60,
        EquipmentType.SHIELD to 70,
        EquipmentType.WEAPON to 80
    )
    return equipment.sortedBy { ordem[it.type] ?: 999 }
}

/**
 * Sobrepõe artes transparentes à mesma célula do corpo-base.
 * Cada visual deve ser uma folha 2x2 alinhada; ícones não são usados como roupa.
 */
@Composable
private fun CamadasEquipamentoPersonagem(
    equipment: List<Equipment>,
    angulo: AnguloPersonagem,
    camadaTraseira: Boolean,
    modifier: Modifier = Modifier
) {
    Box(modifier = modifier) {
        equipment
            .filter { it.perfilEncaixeVisual in setOf("corpo_base_v1", "corpo_base_v3") && it.versaoVisualEquipamento >= 1 }
            .let(::ordenarCamadasEquipamento)
            .forEach { item ->
                val caminho = caminhoCamadaEquipamento(item, angulo, camadaTraseira)
                if (caminho.isNotBlank()) {
                    ImagemCamadaEquipamento(caminho, angulo, Modifier.fillMaxSize())
                }
            }
    }
}

@Composable
private fun CamadasEquipamentoFolhaCompleta(
    equipment: List<Equipment>,
    camadaTraseira: Boolean,
    modifier: Modifier = Modifier
) {
    BoxWithConstraints(modifier = modifier.clipToBounds()) {
        val larguraCelula = maxWidth / 2
        val alturaCelula = maxHeight / 2
        equipment
            .filter { it.perfilEncaixeVisual in setOf("corpo_base_v1", "corpo_base_v3") && it.versaoVisualEquipamento >= 1 }
            .let(::ordenarCamadasEquipamento)
            .forEach { item ->
                val vistas = listOf(
                    Triple(item.visualFrenteCaminho, Alignment.TopStart, AnguloPersonagem.FRENTE),
                    Triple(item.visualLadoEsquerdoCaminho, Alignment.TopEnd, AnguloPersonagem.LADO_ESQUERDO),
                    Triple(item.visualCostasCaminho, Alignment.BottomStart, AnguloPersonagem.COSTAS),
                    Triple(item.visualLadoDireitoCaminho, Alignment.BottomEnd, AnguloPersonagem.LADO_DIREITO)
                )
                vistas.forEach { (_, alinhamento, angulo) ->
                    val caminho = caminhoCamadaEquipamento(item, angulo, camadaTraseira)
                    if (caminho.isNotBlank()) {
                        Box(
                            modifier = Modifier
                                .align(alinhamento)
                                .width(larguraCelula)
                                .height(alturaCelula)
                        ) {
                            // Cada célula recebe somente o quadrante correspondente da folha 2x2.
                            ImagemCamadaEquipamento(caminho, angulo, Modifier.fillMaxSize())
                        }
                    }
                }
            }
    }
}

@Composable
private fun ImagemCamadaEquipamentoFolha(
    caminho: String,
    modifier: Modifier = Modifier
) {
    val imageUrl = produceState<String?>(initialValue = null, key1 = caminho) {
        value = if (caminho.startsWith("https://")) {
            caminho
        } else {
            runCatching {
                FirebaseStorage.getInstance().reference.child(caminho).downloadUrl.await().toString()
            }.getOrNull()
        }
    }.value ?: return

    AsyncImage(
        model = imageUrl,
        contentDescription = "Camada visual transparente de equipamento",
        modifier = modifier,
        contentScale = ContentScale.Fit
    )
}

@Composable
private fun ImagemCamadaEquipamento(
    caminho: String,
    angulo: AnguloPersonagem,
    modifier: Modifier = Modifier
) {
    val imageUrl = produceState<String?>(initialValue = null, key1 = caminho) {
        value = if (caminho.startsWith("https://")) {
            caminho
        } else {
            runCatching {
                FirebaseStorage.getInstance().reference.child(caminho).downloadUrl.await().toString()
            }.getOrNull()
        }
    }.value ?: return

    ImagemAnguloPersonagem(
        imageUrl = imageUrl,
        angulo = angulo,
        modifier = modifier
    )
}

/** Recorta uma das quatro células da folha 2x2 sem solicitar outra imagem. */
@Composable
fun ImagemAnguloPersonagem(
    imageUrl: String,
    angulo: AnguloPersonagem,
    modifier: Modifier = Modifier,
    onError: () -> Unit = {}
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
                .requiredSize(largura * 2, altura * 2)
                .offset(x = deslocamentoX, y = deslocamentoY),
            contentScale = ContentScale.FillBounds,
            onError = { onError() }
        )
    }
}
