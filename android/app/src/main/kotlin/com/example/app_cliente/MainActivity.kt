package com.example.app_cliente

import android.content.Intent
import android.media.AudioManager
import android.media.ToneGenerator
import android.net.Uri
import android.os.Handler
import android.os.Looper
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "gym_file_reader")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "readBytes" -> {
                        try {
                            val uri = Uri.parse(call.arguments as String)
                            val bytes = contentResolver.openInputStream(uri)?.readBytes()
                            if (bytes != null) result.success(bytes)
                            else result.error("NULL_STREAM", "Impossibile aprire lo stream", null)
                        } catch (e: Exception) {
                            result.error("READ_ERROR", e.message, null)
                        }
                    }
                    "playBeep" -> {
                        try {
                            val durationMs = (call.arguments as? Int) ?: 300
                            // STREAM_MUSIC: suona sovrapposto alla musica/YouTube senza interrompere
                            val toneMusic = ToneGenerator(AudioManager.STREAM_MUSIC, 100)
                            toneMusic.startTone(ToneGenerator.TONE_PROP_BEEP, durationMs)
                            Handler(Looper.getMainLooper()).postDelayed({
                                toneMusic.release()
                            }, (durationMs + 200).toLong())
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("BEEP_ERROR", e.message, null)
                        }
                    }
                    "shareFile" -> {
                        try {
                            @Suppress("UNCHECKED_CAST")
                            val args = call.arguments as Map<String, Any>
                            val filePath = args["path"] as String
                            val fileName = args["name"] as String
                            val file = File(filePath)
                            val authority = "${packageName}.gym.provider"
                            val uri: Uri = FileProvider.getUriForFile(this, authority, file)
                            val intent = Intent(Intent.ACTION_SEND).apply {
                                type = "application/x-workout"
                                putExtra(Intent.EXTRA_STREAM, uri)
                                putExtra(Intent.EXTRA_SUBJECT, fileName)
                                addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
                            }
                            startActivity(Intent.createChooser(intent, "Condividi"))
                            result.success(null)
                        } catch (e: Exception) {
                            result.error("SHARE_ERROR", e.message, null)
                        }
                    }
                    else -> result.notImplemented()
                }
            }
    }
}
