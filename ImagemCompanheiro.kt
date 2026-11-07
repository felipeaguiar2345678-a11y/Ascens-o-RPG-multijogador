
package br.com.ascensaodosoberano.companions

import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.*
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.layout.ContentScale
import coil.compose.AsyncImage
import com.google.firebase.storage.FirebaseStorage

@Composable
fun ImagemCompanheiro(
    caminho: String,
    modifier: Modifier = Modifier
) {
    var enderecoImagem by remember(caminho) {
        mutableStateOf<String?>(null)
    }

    LaunchedEffect(caminho) {
        enderecoImagem = null

        if (caminho.isNotBlank()) {
            FirebaseStorage.getInstance()
                .reference
                .child(caminho)
                .downloadUrl
                .addOnSuccessListener { uri ->
                    enderecoImagem = uri.toString()
                }
        }
    }

    Box(
        modifier = modifier,
        contentAlignment = Alignment.Center
    ) {
        if (enderecoImagem != null) {
            AsyncImage(
                model = enderecoImagem,
                contentDescription = "Imagem do companheiro",
                modifier = Modifier.fillMaxSize(),
                contentScale = ContentScale.Fit
            )
        } else {
            Text("Companheiro")
        }
    }
}
