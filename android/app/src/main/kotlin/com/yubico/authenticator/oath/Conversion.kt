package com.yubico.authenticator.oath

import com.yubico.yubikit.oath.Code
import com.yubico.yubikit.oath.Credential
import com.yubico.yubikit.oath.OathType

fun ByteArray.asString() = joinToString(
    separator = ""
) { b -> "%02x".format(b) }

// convert yubikit types to Model types
fun Credential.model(deviceId: String) = Model.Credential(
    deviceId = deviceId,
    id = id.asString(),
    oathType = when (oathType) {
        OathType.HOTP -> Model.OathType.HOTP
        else -> Model.OathType.TOTP
    },
    period = period,
    issuer = issuer,
    accountName = accountName,
    touchRequired = isTouchRequired
)

fun Code.model() = Model.Code(
    value,
    validFrom / 1000,
    validUntil / 1000
)

fun Map<Credential, Code?>.model(deviceId: String): Map<Model.Credential, Model.Code?> =
    map { (credential, code) ->
        Pair(
            credential.model(deviceId),
            code?.model()
        )
    }.toMap()