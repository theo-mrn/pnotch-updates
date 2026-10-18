//
//  ContactParser.swift
//  PNotch
//
//  Created by Theo Morin on 17/10/2026.
//

import Contacts
import Foundation

/// Reads the vCards put on the pasteboard by Contacts and other address books.
/// Parsing a vCard doesn't require access to the user's contacts.
nonisolated enum ContactParser {
    static func contact(fromVCard data: Data) -> ClipboardContent.ContactPayload? {
        guard let contact = try? CNContactVCardSerialization.contacts(with: data).first else { return nil }

        let formattedName = CNContactFormatter.string(from: contact, style: .fullName)
        let organization = contact.organizationName.nilIfEmpty
        guard let name = formattedName?.nilIfEmpty ?? organization else { return nil }

        return ClipboardContent.ContactPayload(
            name: name,
            organization: formattedName == nil ? nil : organization,
            email: contact.emailAddresses.first.map { $0.value as String },
            phone: contact.phoneNumbers.first?.value.stringValue,
            vCardData: data
        )
    }
}

private extension String {
    nonisolated var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
