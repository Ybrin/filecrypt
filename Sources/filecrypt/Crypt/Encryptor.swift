//
//  Encryptor.swift
//  filecrypt
//
//  Created by Koray Koska on 29.09.17.
//

import Foundation
import Cryptor

class Encryptor {

    let reader: BufferedReader
    let logger: Logger?

    init(filepath: String, logger: Logger? = nil) throws {
        self.reader = try BufferedReader(filepath: filepath)
        self.logger = logger
    }

    func crypt(withPassword password: String) throws {
        logger?.debug("Generating password hash and secure random iv...")
        guard let pass = Digest(using: .sha256).update(string: password)?.final(), let iv = try? Random.generate(byteCount: 16) else {
            throw CryptException.Crypt.encryptionFailed(details: "SHA256 digest or random byte generation failed. Consider opening an issue on Github.")
        }
        var clearData: Data = Data()

        logger?.debug("Reading cleartext data...")

        for d in reader {
            clearData.append(d)
        }

        logger?.debug("Zero padding data...")

        var textToCipher = [UInt8](clearData)
        if textToCipher.count % Cryptor.Algorithm.aes256.blockSize != 0 {
            textToCipher = CryptoUtils.zeroPad(byteArray: textToCipher, blockSize: Cryptor.Algorithm.aes256.blockSize)
        }

        logger?.debug("Encrypting...")

        guard let c = Cryptor(operation: .encrypt, algorithm: .aes256, options: .none, key: pass, iv: iv).update(byteArray: textToCipher) else {
            throw CryptException.Crypt.encryptionFailed(details: "Cryptor failed while injecting the clear data. Consider opening an issue on Github.")
        }
        guard let final = c.final() else {
            throw CryptException.Crypt.encryptionFailed(details: "Cryptor failed. Status: \(c.status.description)")
        }

        logger?.debug("Generating HMAC signature...")

        guard let hmac = HMAC(using: .sha256, key: pass).update(byteArray: textToCipher)?.final() else {
            throw CryptException.Crypt.encryptionFailed(details: "HMAC signature generation failed...")
        }

        let encryptedPath = "\(reader.filepath).secured"

        logger?.debug("Writing encrypted data to \(encryptedPath)...")

        let writer = try BufferedWriter(filepath: encryptedPath)
        // Write iv
        writer.write(data: CryptoUtils.data(from: iv))
        // Write hmac
        writer.write(data: CryptoUtils.data(from: hmac))
        // Write encrypted data
        writer.write(data: CryptoUtils.data(from: final))
    }
}
