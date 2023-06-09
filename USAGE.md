## Setting up Gradle Cache Instance

> **⚠️Warning:** This example uses a self-signed cert. For production usage, use a cert from a certificate authority.

1. Install the `aws` cli
1. Configure it with your access key and secret key, ensuring that it has permissions to do cloudformation and ec2 things.
1. Create PEM keys in the regions where you'll deploy. For example: `aws ec2 create-key-pair --key-name My_Key_For_EUCentral2 --region eu-central-2 --query 'KeyMaterial' --output text > My_Key_For_EUCentral2.pem`
1. `chmod 600 *.pem`
1. Copy `profiles/profile.properties.example` with the inputs that you want (desired region and key details)
1. Copy `gradle_cache_ec2.yaml.template` to `gradle_cache_ec2.yaml` and update the CIDR range to your IP to limit SSH access.
1. run `sh cache_mgmt.sh create -p path/to/profile`
1. Create a user and password with r/w access in the Gradle UI using info above
    1. Navigate to the IP address generated by the script above
    1. Accept the untrusted cert warnings (the build cache node generated its own, untrusted cert)
    1. In settings section, create the username/password entries that your developers will use
    1. Take note of them for usage in the next step...
1. Proceed to the "On Your Project" section below for instructions on connecting your development environment to the build cache node.
1. When you're done with the cache node, run `sh cache_mgmt.sh destroy -p path/to/profile` to destroy it.


## On Your Project
[Docs](https://docs.gradle.org/current/userguide/build_cache.html)
1. Ensure that `org.gradle.caching=true` is set on your `gradle.properties`.
1. Create a file `aws-cache.gradle`, and add:
```
gradle.settingsEvaluated { settings ->
    settings.buildCache {
        local {
            enabled = false
        }

        remote(HttpBuildCache) {
            url = "https://<ec2 ip>/cache/"
            credentials {
                username = "<username you created in gradle ui>"
                password = "<pw you created in gradle ui>"
            }
            push = true // recommend true for CI environment and false for local developer environment
            enabled = true

            // This example uses a self-signed cert that isn't trusted, so this settings is needed
            // The setting not needed when using a cert provided by a certificate authority
            allowUntrustedServer = true 
        }
    }
}
```
1. `./gradlew clean`
1. `.gradlew assembleDebug --scan --init-`
1. `./gradlew clean`
1. `.gradlew assembleDebug --scan`