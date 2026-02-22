import Foundation

public enum PairService {
    public static func generateInviteCode(length: Int = 6) -> String {
        let clampedLength = max(6, min(length, 8))
        let characters = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
        var code = ""
        for _ in 0..<clampedLength {
            if let randomChar = characters.randomElement() {
                code.append(randomChar)
            }
        }
        return code
    }
    
    public static func simulatePairing(current: PairProfile, code: String) -> PairProfile {
        return PairProfile(
            myId: current.myId,
            partnerId: current.partnerId ?? "simulated_partner",
            partnerName: current.partnerName.isEmpty ? "Alex" : current.partnerName,
            status: .paired,
            inviteCode: code,
            createdAt: current.createdAt
        )
    }
    
    public static func unpair(_ profile: PairProfile) -> PairProfile {
        return PairProfile(
            myId: profile.myId,
            partnerId: nil,
            partnerName: "",
            status: .none,
            inviteCode: nil,
            createdAt: profile.createdAt
        )
    }
    
    public static func invited(_ profile: PairProfile, code: String) -> PairProfile {
        return PairProfile(
            myId: profile.myId,
            partnerId: nil,
            partnerName: profile.partnerName,
            status: .invited,
            inviteCode: code,
            createdAt: profile.createdAt
        )
    }
    
    public static func todayKey() -> String {
        return Date().dateKey()
    }
}

