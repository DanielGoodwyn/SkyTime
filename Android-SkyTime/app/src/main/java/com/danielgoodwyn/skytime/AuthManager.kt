package com.danielgoodwyn.skytime

import android.content.Context
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import org.json.JSONObject
import java.util.concurrent.TimeUnit

data class SkyUser(
    val uid: String,
    val email: String,
    val displayName: String? = null,
    val idToken: String? = null,
    val refreshToken: String? = null
)

class AuthManager(context: Context) {

    private val prefs = context.getSharedPreferences("skytime_auth", Context.MODE_PRIVATE)
    private val client = OkHttpClient.Builder()
        .connectTimeout(15, TimeUnit.SECONDS)
        .readTimeout(15, TimeUnit.SECONDS)
        .build()

    // Shared Firebase project API key
    var apiKey: String = "AIzaSyCzUEuK46_qHYzxSS07GAprhtupTYsBNbs"

    var currentUser by mutableStateOf<SkyUser?>(null)
    var isLoading by mutableStateOf(false)
    var errorMessage by mutableStateOf<String?>(null)
    var successMessage by mutableStateOf<String?>(null)

    init {
        loadCachedUser()
    }

    private fun loadCachedUser() {
        val uid = prefs.getString("uid", null)
        val email = prefs.getString("email", null)
        if (uid != null && email != null) {
            currentUser = SkyUser(
                uid = uid,
                email = email,
                displayName = prefs.getString("displayName", null),
                idToken = prefs.getString("idToken", null),
                refreshToken = prefs.getString("refreshToken", null)
            )
        }
    }

    fun saveUser(user: SkyUser?) {
        currentUser = user
        prefs.edit().apply {
            if (user != null) {
                putString("uid", user.uid)
                putString("email", user.email)
                putString("displayName", user.displayName)
                putString("idToken", user.idToken)
                putString("refreshToken", user.refreshToken)
            } else {
                clear()
            }
            apply()
        }
    }

    fun signOut() {
        saveUser(null)
        errorMessage = null
        successMessage = "Signed out."
    }

    // Consolidated Begin (Sign In / Sign Up)
    suspend fun begin(emailInput: String, passwordInput: String): Boolean = withContext(Dispatchers.IO) {
        val email = emailInput.trim().lowercase()
        val password = passwordInput.trim()

        if (!email.contains("@") || email.length < 3) {
            errorMessage = "Please enter a valid email address."
            return@withContext false
        }
        if (password.isEmpty()) {
            errorMessage = "Please enter a password."
            return@withContext false
        }

        isLoading = true
        errorMessage = null
        successMessage = null

        try {
            // Attempt 1: Sign In
            val signInResult = executeSignIn(email, password)
            if (signInResult.isSuccess) {
                val user = signInResult.getOrThrow()
                saveUser(user)
                successMessage = "Welcome back, ${user.email}!"
                isLoading = false
                return@withContext true
            }

            val signErr = signInResult.exceptionOrNull()?.message ?: ""

            // If user not found or enumeration protected -> Attempt Sign Up
            if (signErr.contains("EMAIL_NOT_FOUND") || signErr.contains("INVALID_LOGIN_CREDENTIALS") || signErr.contains("INVALID_CREDENTIAL")) {
                val signUpResult = executeSignUp(email, password)
                if (signUpResult.isSuccess) {
                    val newUser = signUpResult.getOrThrow()
                    saveUser(newUser)
                    successMessage = "Account created! Welcome, ${newUser.email}!"
                    isLoading = false
                    return@withContext true
                }

                val signUpErr = signUpResult.exceptionOrNull()?.message ?: ""
                if (signUpErr.contains("EMAIL_EXISTS")) {
                    errorMessage = "Incorrect password. If you forgot your password, tap Forgot Password."
                } else if (signUpErr.contains("WEAK_PASSWORD")) {
                    errorMessage = "Password should be at least 6 characters."
                } else {
                    errorMessage = signUpErr
                }
            } else if (signErr.contains("INVALID_PASSWORD") || signErr.contains("WRONG_PASSWORD")) {
                errorMessage = "Incorrect password. If you forgot your password, tap Forgot Password."
            } else {
                errorMessage = signErr
            }
        } catch (e: Exception) {
            errorMessage = "Network error: ${e.localizedMessage}"
        } finally {
            isLoading = false
        }

        return@withContext false
    }

    suspend fun sendPasswordReset(emailInput: String): Boolean = withContext(Dispatchers.IO) {
        val email = emailInput.trim().lowercase()
        if (!email.contains("@")) {
            errorMessage = "Please enter a valid email address."
            return@withContext false
        }

        isLoading = true
        errorMessage = null
        successMessage = null

        try {
            val url = "https://identitytoolkit.googleapis.com/v1/accounts:sendOobCode?key=$apiKey"
            val json = JSONObject().apply {
                put("requestType", "PASSWORD_RESET")
                put("email", email)
            }
            val body = json.toString().toRequestBody("application/json".toMediaType())
            val req = Request.Builder().url(url).post(body).build()

            client.newCall(req).execute().use { res ->
                val resStr = res.body?.string() ?: ""
                val resJson = JSONObject(resStr)

                if (resJson.has("error")) {
                    val errObj = resJson.getJSONObject("error")
                    errorMessage = errObj.optString("message", "Error sending reset email.")
                    return@withContext false
                }

                successMessage = "Password reset email sent to $email. Check your inbox."
                return@withContext true
            }
        } catch (e: Exception) {
            errorMessage = "Network error: ${e.localizedMessage}"
            return@withContext false
        } finally {
            isLoading = false
        }
    }

    private fun executeSignIn(email: String, pass: String): Result<SkyUser> {
        return try {
            val url = "https://identitytoolkit.googleapis.com/v1/accounts:signInWithPassword?key=$apiKey"
            val json = JSONObject().apply {
                put("email", email)
                put("password", pass)
                put("returnSecureToken", true)
            }
            val body = json.toString().toRequestBody("application/json".toMediaType())
            val req = Request.Builder().url(url).post(body).build()

            client.newCall(req).execute().use { res ->
                val resStr = res.body?.string() ?: ""
                val resJson = JSONObject(resStr)

                if (resJson.has("error")) {
                    val err = resJson.getJSONObject("error").optString("message", "Auth failed")
                    return Result.failure(Exception(err))
                }

                val uid = resJson.getString("localId")
                val token = resJson.optString("idToken")
                val refresh = resJson.optString("refreshToken")
                val disp = resJson.optString("displayName", null)
                Result.success(SkyUser(uid, email, disp, token, refresh))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }

    private fun executeSignUp(email: String, pass: String): Result<SkyUser> {
        return try {
            val url = "https://identitytoolkit.googleapis.com/v1/accounts:signUp?key=$apiKey"
            val json = JSONObject().apply {
                put("email", email)
                put("password", pass)
                put("returnSecureToken", true)
            }
            val body = json.toString().toRequestBody("application/json".toMediaType())
            val req = Request.Builder().url(url).post(body).build()

            client.newCall(req).execute().use { res ->
                val resStr = res.body?.string() ?: ""
                val resJson = JSONObject(resStr)

                if (resJson.has("error")) {
                    val err = resJson.getJSONObject("error").optString("message", "Sign up failed")
                    return Result.failure(Exception(err))
                }

                val uid = resJson.getString("localId")
                val token = resJson.optString("idToken")
                val refresh = resJson.optString("refreshToken")
                Result.success(SkyUser(uid, email, email.substringBefore("@"), token, refresh))
            }
        } catch (e: Exception) {
            Result.failure(e)
        }
    }
}
