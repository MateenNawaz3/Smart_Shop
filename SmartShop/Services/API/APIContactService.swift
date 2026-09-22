//
//  APIContactService.swift
//  SmartShop
//

import Foundation

/// `ContactService` over the Mobile API.
///
/// Both calls work signed out: someone who cannot get through the door is
/// exactly the person who needs the contact form.
nonisolated struct APIContactService: ContactService {
    var client: any APIClient

    init(client: any APIClient) {
        self.client = client
    }

    init(configuration: APIConfiguration = .current) {
        self.init(client: LiveAPIClient(configuration: configuration))
    }

    @discardableResult
    func send(_ message: ContactMessage) async throws -> ContactReceipt {
        let request = try APIRequest.json(
            .post,
            "/mobile/contact",
            body: ContactMessageDTO(
                name: message.name,
                email: message.email,
                subject: message.subject,
                body: message.body
            ),
            auth: .forbidden
        )
        let receipt: ContactReceiptDTO = try await client.send(request)
        return ContactReceipt(id: receipt.id, delivered: receipt.delivered)
    }

    func unsubscribe(email: String) async throws {
        let request = try APIRequest.json(
            .post,
            "/mobile/unsubscribe",
            body: UnsubscribeRequestDTO(email: email),
            auth: .forbidden
        )
        // Always 202, and `data` is null — there is nothing to read, and
        // nothing that would say whether the address existed.
        let _: EmptyResponse = try await client.send(request)
    }
}
