package com.example.dosebuddy

import android.net.Uri
import com.google.mlkit.vision.common.InputImage
import com.google.mlkit.vision.text.TextRecognition
import com.google.mlkit.vision.text.latin.TextRecognizerOptions
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "dosebuddy/prescription_ocr")
            .setMethodCallHandler { call, result ->
                if (call.method != "recognize") {
                    result.notImplemented()
                    return@setMethodCallHandler
                }
                val path = call.argument<String>("path")
                if (path.isNullOrBlank()) {
                    result.error("invalid_image", "An image path is required", null)
                    return@setMethodCallHandler
                }
                val recognizer = TextRecognition.getClient(TextRecognizerOptions.DEFAULT_OPTIONS)
                try {
                    val image = InputImage.fromFilePath(this, Uri.fromFile(File(path)))
                    recognizer.process(image)
                        .addOnSuccessListener { text -> result.success(text.text) }
                        .addOnFailureListener { result.error("ocr_failed", "Could not read the image", null) }
                        .addOnCompleteListener { recognizer.close() }
                } catch (error: Exception) {
                    recognizer.close()
                    result.error("invalid_image", "Could not open the image", null)
                }
            }
    }
}
