import Foundation
import Amplify
import AWSCognitoAuthPlugin
import AWSAPIPlugin
import AWSCloudWatchLoggingPlugin

enum AmplifyConfiguration {
    static func configure() {
        do {
            let loggingConfiguration = AWSCloudWatchLoggingPluginConfiguration(
                logGroupName: "/watchoverpro/ios",
                region: "ap-northeast-1",
                localStoreMaxSizeInMB: 1,
                flushIntervalInSeconds: 60
            )
            let loggingPlugin = AWSCloudWatchLoggingPlugin(
                loggingPluginConfiguration: loggingConfiguration
            )
            try Amplify.add(plugin: loggingPlugin)
            try Amplify.add(plugin: AWSCognitoAuthPlugin())
            try Amplify.add(plugin: AWSAPIPlugin())
            try Amplify.configure()
            print("Amplify configured successfully")
        } catch {
            print("Failed to configure Amplify: \(error)")
        }
    }
}
