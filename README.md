# Azure Private Link demo environment

This repo contains the IaC code used to generate a lab environment for testing Azure Private Link endpoints and services.

Execute *deploy.ps1* to provision the lab. If you're having issues with the Custom Script Extension resource, you can just copy&paste the content of *customScriptExtension.ps1* into the *DnsForwarder-VM*, and execute it locally to install and configure the DNS Server and the Web Server.

The environment was used during the following sessions:

- **Cloud Day 2021**