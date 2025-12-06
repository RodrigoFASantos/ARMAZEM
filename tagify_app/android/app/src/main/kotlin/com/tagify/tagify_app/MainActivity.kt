package com.tagify.tagify_app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.EventChannel
import io.flutter.plugin.common.MethodChannel
import android.content.BroadcastReceiver
import android.content.Context
import android.content.Intent
import android.content.IntentFilter
import android.os.Bundle
import android.util.Log

class MainActivity : FlutterActivity() {
    
    companion object {
        private const val TAG = "RFIDScanner"
        private const val RFID_CHANNEL = "com.armazem.rfid"
        private const val RFID_EVENT_CHANNEL = "com.armazem.rfid/scan"
        
        // DataWedge Intent Actions (Zebra)
        private const val DATAWEDGE_ACTION = "com.symbol.datawedge.api.ACTION"
        private const val DATAWEDGE_EXTRA_SEND_RESULT = "SEND_RESULT"
        private const val DATAWEDGE_SCAN_EXTRA_SOURCE = "com.symbol.datawedge.source"
        private const val DATAWEDGE_SCAN_EXTRA_DATA_STRING = "com.symbol.datawedge.data_string"
        private const val DATAWEDGE_SCAN_EXTRA_LABEL_TYPE = "com.symbol.datawedge.label_type"
        
        // Intent filter para receber scans do DataWedge
        private const val DATAWEDGE_INTENT_ACTION = "com.tagify.tagify_app.SCAN"
        private const val DATAWEDGE_INTENT_CATEGORY = "android.intent.category.DEFAULT"
    }
    
    private var eventSink: EventChannel.EventSink? = null
    private var scanReceiver: BroadcastReceiver? = null
    
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        
        // EventChannel para receber scans RFID em stream
        EventChannel(flutterEngine.dartExecutor.binaryMessenger, RFID_EVENT_CHANNEL)
            .setStreamHandler(object : EventChannel.StreamHandler {
                override fun onListen(arguments: Any?, events: EventChannel.EventSink?) {
                    Log.d(TAG, "EventChannel: onListen iniciado")
                    eventSink = events
                    registerScanReceiver()
                }
                
                override fun onCancel(arguments: Any?) {
                    Log.d(TAG, "EventChannel: onCancel")
                    eventSink = null
                    unregisterScanReceiver()
                }
            })
        
        // MethodChannel para comandos (start/stop scan, configurações)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, RFID_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "startScan" -> {
                        startDataWedgeScan()
                        result.success(true)
                    }
                    "stopScan" -> {
                        stopDataWedgeScan()
                        result.success(true)
                    }
                    "isAvailable" -> {
                        // Verifica se DataWedge está disponível (dispositivos Zebra)
                        result.success(isDataWedgeAvailable())
                    }
                    "configureDataWedge" -> {
                        configureDataWedgeProfile()
                        result.success(true)
                    }
                    else -> {
                        result.notImplemented()
                    }
                }
            }
    }
    
    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        // Configura DataWedge automaticamente ao iniciar
        configureDataWedgeProfile()
    }
    
    override fun onDestroy() {
        super.onDestroy()
        unregisterScanReceiver()
    }
    
    private fun registerScanReceiver() {
        if (scanReceiver != null) return
        
        scanReceiver = object : BroadcastReceiver() {
            override fun onReceive(context: Context?, intent: Intent?) {
                intent?.let { processIntent(it) }
            }
        }
        
        val filter = IntentFilter().apply {
            addAction(DATAWEDGE_INTENT_ACTION)
            addCategory(DATAWEDGE_INTENT_CATEGORY)
        }
        
        registerReceiver(scanReceiver, filter, RECEIVER_NOT_EXPORTED)
        Log.d(TAG, "ScanReceiver registado")
    }
    
    private fun unregisterScanReceiver() {
        scanReceiver?.let {
            try {
                unregisterReceiver(it)
                Log.d(TAG, "ScanReceiver removido")
            } catch (e: Exception) {
                Log.e(TAG, "Erro ao remover receiver: ${e.message}")
            }
        }
        scanReceiver = null
    }
    
    private fun processIntent(intent: Intent) {
        val action = intent.action
        Log.d(TAG, "Intent recebido: $action")
        
        if (action == DATAWEDGE_INTENT_ACTION) {
            // Dados do scan
            val source = intent.getStringExtra(DATAWEDGE_SCAN_EXTRA_SOURCE) ?: "unknown"
            val data = intent.getStringExtra(DATAWEDGE_SCAN_EXTRA_DATA_STRING) ?: ""
            val labelType = intent.getStringExtra(DATAWEDGE_SCAN_EXTRA_LABEL_TYPE) ?: ""
            
            Log.d(TAG, "Scan recebido - Source: $source, Data: $data, Type: $labelType")
            
            if (data.isNotEmpty()) {
                // Envia para Flutter via EventChannel
                runOnUiThread {
                    eventSink?.success(data.trim())
                }
            }
        }
    }
    
    private fun startDataWedgeScan() {
        val intent = Intent().apply {
            action = DATAWEDGE_ACTION
            putExtra("com.symbol.datawedge.api.SOFT_SCAN_TRIGGER", "START_SCANNING")
        }
        sendBroadcast(intent)
        Log.d(TAG, "DataWedge: Scan iniciado")
    }
    
    private fun stopDataWedgeScan() {
        val intent = Intent().apply {
            action = DATAWEDGE_ACTION
            putExtra("com.symbol.datawedge.api.SOFT_SCAN_TRIGGER", "STOP_SCANNING")
        }
        sendBroadcast(intent)
        Log.d(TAG, "DataWedge: Scan parado")
    }
    
    private fun isDataWedgeAvailable(): Boolean {
        // Verifica se é um dispositivo Zebra com DataWedge
        val manufacturer = android.os.Build.MANUFACTURER.lowercase()
        val isZebra = manufacturer.contains("zebra") || manufacturer.contains("symbol")
        Log.d(TAG, "Dispositivo Zebra: $isZebra (Manufacturer: $manufacturer)")
        return isZebra
    }
    
    private fun configureDataWedgeProfile() {
        try {
            // Cria/atualiza perfil DataWedge para a app
            val profileConfig = Bundle().apply {
                putString("PROFILE_NAME", "Tagify_Profile")
                putString("PROFILE_ENABLED", "true")
                putString("CONFIG_MODE", "CREATE_IF_NOT_EXIST")
            }
            
            // Configuração da app associada
            val appConfig = Bundle().apply {
                putString("PACKAGE_NAME", packageName)
                putStringArray("ACTIVITY_LIST", arrayOf("*"))
            }
            profileConfig.putBundle("APP_LIST", appConfig)
            
            // Configuração do plugin de Intent Output
            val intentConfig = Bundle().apply {
                putString("PLUGIN_NAME", "INTENT")
                putString("RESET_CONFIG", "true")
            }
            
            val intentProps = Bundle().apply {
                putString("intent_output_enabled", "true")
                putString("intent_action", DATAWEDGE_INTENT_ACTION)
                putString("intent_category", DATAWEDGE_INTENT_CATEGORY)
                putString("intent_delivery", "2") // Broadcast
            }
            intentConfig.putBundle("PARAM_LIST", intentProps)
            
            // Configuração do plugin de Barcode
            val barcodeConfig = Bundle().apply {
                putString("PLUGIN_NAME", "BARCODE")
                putString("RESET_CONFIG", "true")
            }
            
            val barcodeProps = Bundle().apply {
                putString("scanner_input_enabled", "true")
                putString("scanner_selection", "auto")
            }
            barcodeConfig.putBundle("PARAM_LIST", barcodeProps)
            
            // Configuração RFID (se disponível no dispositivo)
            val rfidConfig = Bundle().apply {
                putString("PLUGIN_NAME", "RFID")
                putString("RESET_CONFIG", "true")
            }
            
            val rfidProps = Bundle().apply {
                putString("rfid_input_enabled", "true")
                putString("rfid_beeper_enable", "true")
                putString("rfid_led_enable", "true")
            }
            rfidConfig.putBundle("PARAM_LIST", rfidProps)
            
            // Adiciona plugins ao perfil
            profileConfig.putParcelableArray("PLUGIN_CONFIG", arrayOf(
                intentConfig, 
                barcodeConfig,
                rfidConfig
            ))
            
            // Envia configuração para DataWedge
            val dwIntent = Intent().apply {
                action = DATAWEDGE_ACTION
                putExtra("com.symbol.datawedge.api.SET_CONFIG", profileConfig)
                putExtra(DATAWEDGE_EXTRA_SEND_RESULT, "true")
            }
            sendBroadcast(dwIntent)
            
            Log.d(TAG, "DataWedge: Perfil configurado")
            
        } catch (e: Exception) {
            Log.e(TAG, "Erro ao configurar DataWedge: ${e.message}")
        }
    }
}