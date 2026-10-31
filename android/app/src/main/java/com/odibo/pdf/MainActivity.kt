package com.odibo.pdf

import android.content.Intent
import android.net.Uri
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.lifecycle.ViewModelProvider
import com.odibo.pdf.app.OdiboViewModel
import com.odibo.pdf.ui.OdiboApp

class MainActivity : ComponentActivity() {
    private val model: OdiboViewModel by lazy { ViewModelProvider(this)[OdiboViewModel::class.java] }
    private var incoming by mutableStateOf<Uri?>(null)
    private val open = registerForActivityResult(ActivityResultContracts.OpenDocument()) { uri -> if (uri != null) model.open(uri) }
    private val save = registerForActivityResult(ActivityResultContracts.CreateDocument("application/pdf")) { uri -> if (uri != null) model.save(uri) }
    private val combine = registerForActivityResult(ActivityResultContracts.OpenMultipleDocuments()) { uris ->
        if (uris.isNotEmpty()) model.addCombine(uris)
    }
    private val splitFolder = registerForActivityResult(ActivityResultContracts.OpenDocumentTree()) { uri ->
        if (uri != null) model.exportTools(uri)
    }
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        if (savedInstanceState == null && intent.action == Intent.ACTION_VIEW) incoming = intent.data
        setContent {
            OdiboApp(model, incoming, { incoming = null },
                onOpen = { open.launch(arrayOf("application/pdf")) },
                onSave = { save.launch("ODIBO-copy.pdf") },
                onAddCombine = { combine.launch(arrayOf("application/pdf")) },
                onExportSplit = { splitFolder.launch(null) })
        }
    }
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        if (intent.action == Intent.ACTION_VIEW) incoming = intent.data
    }
}
