package az.vaqif.gelir_cixar

import android.app.KeyguardManager
import android.content.Context
import android.os.Build
import android.os.Bundle
import android.os.Handler
import android.os.Looper
import android.os.SystemClock
import android.security.keystore.KeyGenParameterSpec
import android.security.keystore.KeyPermanentlyInvalidatedException
import android.security.keystore.KeyProperties
import android.security.keystore.UserNotAuthenticatedException
import android.view.WindowManager
import io.flutter.embedding.android.FlutterFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.security.GeneralSecurityException
import java.security.InvalidAlgorithmParameterException
import java.security.KeyStore
import java.security.ProviderException
import java.security.UnrecoverableKeyException
import java.util.concurrent.Executors
import javax.crypto.Cipher
import javax.crypto.KeyGenerator
import javax.crypto.SecretKey

// FlutterFragmentActivity is required by local_auth (BiometricPrompt).
class MainActivity : FlutterFragmentActivity() {

    /// Keystore work (key generation can take a few hundred ms) off the UI thread.
    private val keystoreExecutor = Executors.newSingleThreadExecutor()
    private val mainHandler = Handler(Looper.getMainLooper())

    override fun onCreate(savedInstanceState: Bundle?) {
        // Secure by default until Dart applies the saved setting, so the
        // first frames never show up in screenshots or the recents preview.
        window.setFlags(
            WindowManager.LayoutParams.FLAG_SECURE,
            WindowManager.LayoutParams.FLAG_SECURE,
        )
        // Android 13+: never show balances in the recents thumbnail, even
        // when the user allows screenshots (FLAG_SECURE off).
        if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.TIRAMISU) {
            setRecentsScreenshotEnabled(false)
        }
        super.onCreate(savedInstanceState)
    }

    override fun onDestroy() {
        keystoreExecutor.shutdown()
        super.onDestroy()
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        val messenger = flutterEngine.dartExecutor.binaryMessenger
        MethodChannel(messenger, CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "setSecure" -> {
                        if (call.arguments as? Boolean != false) {
                            window.addFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        } else {
                            window.clearFlags(WindowManager.LayoutParams.FLAG_SECURE)
                        }
                        result.success(null)
                    }
                    "moveToBack" -> {
                        moveTaskToBack(true)
                        result.success(null)
                    }
                    // Monotonic, includes deep sleep, not user-adjustable.
                    "elapsedRealtime" -> result.success(SystemClock.elapsedRealtime())
                    else -> result.notImplemented()
                }
            }

        // Biometric-enrollment tripwire (lib/features/lock/biometric_key.dart).
        MethodChannel(messenger, KEYSTORE_CHANNEL)
            .setMethodCallHandler { call, result ->
                val work: (() -> Any?)? = when (call.method) {
                    "bioKeyCreate" -> ::createBioKey
                    "bioKeyCheck" -> ::checkBioKey
                    "bioKeyDelete" -> { { deleteBioKey(); null } }
                    "isDeviceSecure" -> ::isDeviceSecure
                    else -> null
                }
                // Errors are reported as "error" (or null for the boolean
                // query), never with exception text.
                val failure: Any? = if (call.method == "isDeviceSecure") null else "error"
                if (work == null) {
                    result.notImplemented()
                } else {
                    try {
                        keystoreExecutor.execute {
                            val value = try {
                                work()
                            } catch (e: Exception) {
                                failure
                            }
                            mainHandler.post { result.success(value) }
                        }
                    } catch (e: java.util.concurrent.RejectedExecutionException) {
                        result.success(failure)
                    }
                }
            }
    }

    private fun isDeviceSecure(): Boolean =
        (getSystemService(Context.KEYGUARD_SERVICE) as KeyguardManager).isDeviceSecure

    private fun keyStore(): KeyStore = KeyStore.getInstance(ANDROID_KEYSTORE).apply { load(null) }

    /// AES-256-GCM key that needs a fresh strong biometric for every use and
    /// is invalidated when a new biometric is enrolled (API 24+).
    private fun createBioKey(): String {
        if (!isDeviceSecure()) return "notSecure"
        deleteBioKey()
        val spec = KeyGenParameterSpec.Builder(
            BIO_KEY_ALIAS,
            KeyProperties.PURPOSE_ENCRYPT or KeyProperties.PURPOSE_DECRYPT,
        )
            .setBlockModes(KeyProperties.BLOCK_MODE_GCM)
            .setEncryptionPaddings(KeyProperties.ENCRYPTION_PADDING_NONE)
            .setKeySize(256)
            .setUserAuthenticationRequired(true)
            .setInvalidatedByBiometricEnrollment(true)
            .apply {
                if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                    // Per-use, biometric only (no device-credential fallback).
                    setUserAuthenticationParameters(0, KeyProperties.AUTH_BIOMETRIC_STRONG)
                }
            }
            .build()
        return try {
            KeyGenerator.getInstance(KeyProperties.KEY_ALGORITHM_AES, ANDROID_KEYSTORE).run {
                init(spec)
                generateKey()
            }
            "created"
        } catch (e: InvalidAlgorithmParameterException) {
            // "At least one biometric must be enrolled".
            "noBiometrics"
        } catch (e: IllegalStateException) {
            "noBiometrics"
        } catch (e: GeneralSecurityException) {
            "error"
        } catch (e: ProviderException) {
            "error"
        }
    }

    /// Detects KeyPermanentlyInvalidatedException by initialising a cipher.
    /// With a per-use auth key, init succeeds without authentication; only
    /// doFinal would need the biometric.
    private fun checkBioKey(): String {
        val key = try {
            keyStore().getKey(BIO_KEY_ALIAS, null) as? SecretKey ?: return "missing"
        } catch (e: UnrecoverableKeyException) {
            // Some vendors report an invalidated key this way.
            return "invalidated"
        } catch (e: GeneralSecurityException) {
            return "error"
        }
        return try {
            Cipher.getInstance("AES/GCM/NoPadding").init(Cipher.ENCRYPT_MODE, key)
            "valid"
        } catch (e: KeyPermanentlyInvalidatedException) {
            "invalidated"
        } catch (e: UserNotAuthenticatedException) {
            // Time-bound keys only: still valid, just not unlocked right now.
            "valid"
        } catch (e: GeneralSecurityException) {
            "error"
        } catch (e: ProviderException) {
            "error"
        }
    }

    private fun deleteBioKey() {
        try {
            keyStore().deleteEntry(BIO_KEY_ALIAS)
        } catch (e: GeneralSecurityException) {
            // Nothing to delete.
        }
    }

    private companion object {
        const val CHANNEL = "az.vaqif.gelir_cixar/window"
        const val KEYSTORE_CHANNEL = "az.vaqif.gelir_cixar/keystore"
        const val ANDROID_KEYSTORE = "AndroidKeyStore"
        const val BIO_KEY_ALIAS = "gelir_cixar.biometric_enrollment"
    }
}
