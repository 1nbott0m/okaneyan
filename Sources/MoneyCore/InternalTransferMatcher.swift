import Foundation

/// A value-only view of an imported operation used for suggesting (never confirming)
/// that an outgoing and incoming transfer are the two sides of one account movement.
public struct TransferMatchRecord: Sendable, Equatable {
    public let id: UUID
    public let accountID: UUID?
    public let accountIncluded: Bool
    public let date: Date
    public let amount: Money
    public let kind: TransactionKind

    public init(id: UUID, accountID: UUID?, accountIncluded: Bool = true,
                date: Date, amount: Money, kind: TransactionKind) {
        self.id = id
        self.accountID = accountID
        self.accountIncluded = accountIncluded
        self.date = date
        self.amount = amount
        self.kind = kind
    }
}

public struct InternalTransferCandidate: Sendable, Equatable, Identifiable {
    public let outgoingID: UUID
    public let incomingID: UUID
    public let timeDifference: TimeInterval

    public var id: String { "\(outgoingID.uuidString)|\(incomingID.uuidString)" }

    public init(outgoingID: UUID, incomingID: UUID, timeDifference: TimeInterval) {
        self.outgoingID = outgoingID
        self.incomingID = incomingID
        self.timeDifference = timeDifference
    }
}

public enum InternalTransferMatcher {
    public static let defaultWindow: TimeInterval = 72 * 60 * 60

    /// Returns all plausible pairs in deterministic order. Multiple candidates are
    /// retained so an ambiguous match is shown to the user instead of guessed.
    public static func candidates(
        among records: [TransferMatchRecord],
        within window: TimeInterval = defaultWindow
    ) -> [InternalTransferCandidate] {
        guard window.isFinite, window >= 0 else { return [] }

        var matches: [InternalTransferCandidate] = []
        for leftIndex in records.indices {
            let left = records[leftIndex]
            guard left.amount > .zero, left.accountIncluded, let leftAccount = left.accountID else { continue }
            for rightIndex in records.indices where rightIndex > leftIndex {
                let right = records[rightIndex]
                guard left.id != right.id,
                      right.amount == left.amount,
                      right.accountIncluded,
                      let rightAccount = right.accountID,
                      rightAccount != leftAccount else { continue }

                let outgoing: TransferMatchRecord
                let incoming: TransferMatchRecord
                if left.kind == .transfer && right.kind == .incomingTransfer {
                    outgoing = left
                    incoming = right
                } else if right.kind == .transfer && left.kind == .incomingTransfer {
                    outgoing = right
                    incoming = left
                } else {
                    continue
                }

                let difference = abs(outgoing.date.timeIntervalSince(incoming.date))
                guard difference.isFinite, difference <= window else { continue }
                matches.append(InternalTransferCandidate(outgoingID: outgoing.id,
                    incomingID: incoming.id, timeDifference: difference))
            }
        }
        return matches.sorted {
            if $0.timeDifference != $1.timeDifference { return $0.timeDifference < $1.timeDifference }
            if $0.outgoingID != $1.outgoingID { return $0.outgoingID.uuidString < $1.outgoingID.uuidString }
            return $0.incomingID.uuidString < $1.incomingID.uuidString
        }
    }
}
