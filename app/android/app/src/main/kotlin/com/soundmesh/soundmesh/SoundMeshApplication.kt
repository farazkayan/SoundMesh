package com.soundmesh.soundmesh

import android.app.Application
import android.content.Context
import androidx.multidex.MultiDex

class SoundMeshApplication : Application() {
    override fun attachBaseContext(base: Context) {
        super.attachBaseContext(base)
        MultiDex.install(this)
    }
}