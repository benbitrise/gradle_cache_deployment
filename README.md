# Gradle Cache Deployment

Automate the creation of an EC2 instance that runs the [free Gradle Cache](https://docs.gradle.com/build-cache-node/#docker).

* Uses AWS Cloudformation template
* Automatic spin up and spin down of EC2
* Plus boot script to install docker and run the Gradle docker image

> **⚠️Warning:** This example uses a self-signed cert. For production usage, use a cert from a certificate authority.