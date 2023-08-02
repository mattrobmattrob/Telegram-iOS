
import PortSIPVoIPSDK

public final class PortSIPContainer {
    static let portSIPSDK = PortSIPSDK()

    public static func initializePortSIP() {
        portSIPSDK.removeUser()
    }
}
