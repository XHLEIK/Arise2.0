package com.arise.util;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Component;

import javax.crypto.Cipher;
import javax.crypto.spec.GCMParameterSpec;
import javax.crypto.spec.SecretKeySpec;
import java.nio.ByteBuffer;
import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
import java.util.Base64;

@Component
public class EncryptionUtil {

    private static final String ALGORITHM = "AES/GCM/NoPadding";
    private static final String LEGACY_ALGORITHM = "AES";
    private static final int GCM_IV_LENGTH = 12;
    private static final int GCM_TAG_LENGTH = 128;

    private final SecretKeySpec secretKey;
    private final SecureRandom secureRandom = new SecureRandom();

    public EncryptionUtil(@Value("${arise.encryption-key:Ar1s3S3cur3K3y2024Pr0duct10nR3ady}") String key) {
        // Requires exactly 32 bytes for AES-256
        byte[] keyBytes = key.getBytes(StandardCharsets.UTF_8);
        if (keyBytes.length < 32) {
            // Pad to 32 bytes if shorter
            byte[] padded = new byte[32];
            System.arraycopy(keyBytes, 0, padded, 0, Math.min(keyBytes.length, 32));
            keyBytes = padded;
        } else if (keyBytes.length > 32) {
            byte[] trimmed = new byte[32];
            System.arraycopy(keyBytes, 0, trimmed, 0, 32);
            keyBytes = trimmed;
        }
        this.secretKey = new SecretKeySpec(keyBytes, "AES");
    }

    public String encrypt(String rawText) {
        try {
            byte[] iv = new byte[GCM_IV_LENGTH];
            secureRandom.nextBytes(iv);

            Cipher cipher = Cipher.getInstance(ALGORITHM);
            cipher.init(Cipher.ENCRYPT_MODE, secretKey, new GCMParameterSpec(GCM_TAG_LENGTH, iv));
            byte[] encrypted = cipher.doFinal(rawText.getBytes(StandardCharsets.UTF_8));

            // Prepend IV to ciphertext: [IV (12 bytes) | ciphertext + tag]
            ByteBuffer byteBuffer = ByteBuffer.allocate(iv.length + encrypted.length);
            byteBuffer.put(iv);
            byteBuffer.put(encrypted);

            return Base64.getEncoder().encodeToString(byteBuffer.array());
        } catch (Exception e) {
            throw new RuntimeException("Error encrypting data", e);
        }
    }

    public String decrypt(String encryptedText) {
        try {
            return decryptGcm(encryptedText);
        } catch (Exception gcmException) {
            // Fallback: try legacy ECB mode for data encrypted before the GCM upgrade
            try {
                return decryptLegacyEcb(encryptedText);
            } catch (Exception legacyException) {
                throw new RuntimeException("Error decrypting data (tried GCM and legacy ECB)", gcmException);
            }
        }
    }

    private String decryptGcm(String encryptedText) throws Exception {
        byte[] decoded = Base64.getDecoder().decode(encryptedText);

        // Extract IV from first 12 bytes
        byte[] iv = new byte[GCM_IV_LENGTH];
        System.arraycopy(decoded, 0, iv, 0, GCM_IV_LENGTH);

        // Extract ciphertext (rest of the bytes)
        byte[] ciphertext = new byte[decoded.length - GCM_IV_LENGTH];
        System.arraycopy(decoded, GCM_IV_LENGTH, ciphertext, 0, ciphertext.length);

        Cipher cipher = Cipher.getInstance(ALGORITHM);
        cipher.init(Cipher.DECRYPT_MODE, secretKey, new GCMParameterSpec(GCM_TAG_LENGTH, iv));
        byte[] decrypted = cipher.doFinal(ciphertext);

        return new String(decrypted, StandardCharsets.UTF_8);
    }

    private String decryptLegacyEcb(String encryptedText) throws Exception {
        Cipher cipher = Cipher.getInstance(LEGACY_ALGORITHM);
        cipher.init(Cipher.DECRYPT_MODE, secretKey);
        byte[] decodedBytes = Base64.getDecoder().decode(encryptedText);
        byte[] decrypted = cipher.doFinal(decodedBytes);
        return new String(decrypted, StandardCharsets.UTF_8);
    }
}
