package com.example.miragemobile

import com.example.miragemobile.facetryon.FaceTryOnPlugin
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        // App-local plugin: glasses virtual try-on (camera + MediaPipe + Filament).
        flutterEngine.plugins.add(FaceTryOnPlugin())
    }
}
