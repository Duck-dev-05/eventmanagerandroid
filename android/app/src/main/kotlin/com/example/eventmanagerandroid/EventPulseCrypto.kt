package com.example.eventmanagerandroid

import android.content.Context
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyProperties
import android.util.Base64
import java.nio.ByteBuffer
import java.security.KeyStore
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey
import javax.crypto.spec.GCMParameterSpec

internal object EventPulseCrypto {
    private const val PREFS = "eventpulse_secure"
    private const val KEY_ALIAS = "eventpulse_device_token_key"

    fun preferences(context: Context) =
        context.getSharedPreferences(PREFS, Context.MODE_PRIVATE)

    fun read(context: Context, key: String): String? =
        preferences(context).getString(key, null)?.let { decrypt(context, it) }

    fun write(context: Context, key: String, value: String) {
        preferences(context).edit().putString(key, encrypt(context, value)).apply()
    }

    fun delete(context: Context, key: String) {
        preferences(context).edit().remove(key).apply()
    }

    private fun secretKey(context: Context): SecretKey {
        val keyStore = KeyStore.getInstance("AndroidKeyStore").apply { load(null) }
        (keyStore.getKey(KEY_ALIAS, null) as? SecretKey)?.let { return it }
        val generator = KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, "AndroidKeyStore")
        generator.init(
            KeyGenParameterSpec.Builder(
                KEY_ALIAS,
                KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
            ).setBlockModes(KeyProperties.BLOCK_MODE_GCM)
                .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
                .setRandomizedEncryptionRequired(true)
                .build(),
        )
        return generator.generateKey()
    }

    private fun encrypt(context: Context, value: String): String {
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.ENCRYPT_MODE, secretKey(context))
        val encrypted = cipher.doFinal(value.toByteArray(Charsets.UTF_8))
        val packed = ByteBuffer.allocate(1 + cipher.iv.size + encrypted.size)
            .put(cipher.iv.size.toByte())
            .put(cipher.iv)
            .put(encrypted)
            .array()
        return Base64.encodeToString(packed, Base64.NO_WRAP)
    }

    private fun decrypt(context: Context, value: String): String {
        val packed = Base64.decode(value, Base64.NO_WRAP)
        val buffer = ByteBuffer.wrap(packed)
        val ivSize = buffer.get().toInt() and 0xff
        require(ivSize > 0 && ivSize <= buffer.remaining())
        val iv = ByteArray(ivSize).also(buffer::get)
        val encrypted = ByteArray(buffer.remaining()).also(buffer::get)
        val cipher = Cipher.getInstance("AES/GCM/NoPadding")
        cipher.init(Cipher.DECRYPT_MODE, secretKey(context), GCMParameterSpec(128, iv))
        return String(cipher.doFinal(encrypted), Charsets.UTF_8)
    }
}
