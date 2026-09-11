package com.chesslab

import android.app.Application
import com.chesslab.settings.SettingsStore

class ChessLabApp : Application() {
    override fun onCreate() {
        super.onCreate()
        SettingsStore.start(this)
    }
}
