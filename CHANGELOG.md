# Changelog

## 1.0.0 (2026-05-13)


### Features

* Add frontend service and update Helm chart for PostgreSQL initialization ([bc49268](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/bc4926899d03620359b1f38cedf4adef264f8b62))
* Add functions for managing Helm release status and clearing pending operations ([b999f7f](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/b999f7fb0ffbccbb3ab21eaf5773df6717268cae))
* Add Helm setup and recovery script for incomplete Terraform states ([c0b3a68](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/c0b3a68d902b7dc3d117eefcf6509df9ffed136f))
* add IAM policy for OpenSearch domain access and corresponding resource ([42d2126](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/42d2126769768586e77f17dfaa35a88a6dcad6df))
* **ci:** automate step 03 - register ArgoCD AppProject and Application after terraform apply ([f92bcb1](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/f92bcb16e582c825ebf5245b2b3489eaf5818a39))
* **docs:** add environment variables, improvements, secrets management, and security setup documentation ([6eb556e](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/6eb556e456b5a42facc485e59a644e9d387d5547))
* Enhance Terraform configurations for EKS and RabbitMQ with additional parameters ([ff417fe](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/ff417fe2704fe7f4f6a76b98ca4d0e114d64326d))
* Integrate RabbitMQ into the platform with in-cluster deployment and secret management ([270d102](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/270d102856996564cd2d45fd1872477d47c56eb3))
* Update AWS configurations to support long session durations and clean up pending secrets ([515d8cd](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/515d8cda098e163fe131909fc3e5854d04de2217))
* update destroy-aws workflow to validate temporary admin credentials and document usage ([b8148a3](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/b8148a31b50d4e965e8bc08c334c9fa55d4db415))
* Update EKS access management and cluster version to 1.35; add support for additional IAM users/roles ([1a4f8ae](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/1a4f8ae778a76b9deec9a967ab1ec6267919f5c4))
* **workflows:** add destroy-aws workflow for safe resource teardown in AWS ([6690e66](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/6690e66dfd7230ade7e14e85c647d7e3584685b5))
* **workflows:** add idempotent resource import step to bootstrap workflow ([35be14a](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/35be14ac6b782fa4f4c44bcc4499364fff4bc00e))
* **workflows:** enhance resource import step with required var-file for Terraform ([d023dea](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/d023deab20db4e0a4860bfb7b4f2571943b817ea))
* **workflows:** enhance secret configuration process with detailed logging and error handling ([77a7d0e](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/77a7d0ef9ce748d1c254379959b408c6750207a7))
* **workflows:** update bootstrap and release workflows for manual triggers and path exclusions ([ee738b5](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/ee738b5e908453cb3476c8f6f3772ec21b208a74))


### Bug Fixes

* **ci:** add SARIF fallback when trivy scan fails to prevent upload-sarif error ([ff4fdee](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/ff4fdee3491c9393afc42384a034c26eabe6e27b))
* **ci:** replace trivy-action with direct trivy v0.70.0 install ([887ada0](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/887ada08be6ab757281a603443ead4494447e046))
* **destroy:** add explicit ALB/ENI/SG cleanup before terraform destroy to prevent subnet dependency errors ([38cbb48](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/38cbb4842bf6ca38485f4e238745d8fc33a5743a))
* **destroy:** add NAT Gateway and Elastic IP cleanup before terraform destroy ([1dc1291](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/1dc1291785fd0be2085ec47ee91e4e480638232d))
* **destroy:** detach IAM policy from all entities before bootstrap destroy ([375b9f7](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/375b9f72e938dbeb8de79c72343e53ac8d7f5a48))
* **destroy:** force-unlock stale state lock before destroy, add -lock=false ([b2a45d7](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/b2a45d74465cf25c9259844b2d9edac7bb358a8a))
* **mq:** change RabbitMQ to mq.m5.large (minimum supported for RabbitMQ engine) ([a29d760](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/a29d760cc8accf1ff54d69e02022d9e2ffc058bf))
* **terraform:** auto force-unlock stale state lock in plan and apply jobs ([88755f0](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/88755f077892cb66919a9433a2fcff6cc6be883e))
* **terraform:** remove force-unlock from apply job, use -lock-timeout=10m instead ([66058ce](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/66058cec5248d459b673e6534df43836c393c9d5))
* **terraform:** remove invalid enable_telemetry arg, add cloudformation perm, eks 1.32, spot nodes ([c3eac5a](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/c3eac5ad03360483dc542915c2107f2f099fc622))
* **terraform:** replace deprecated dynamodb_table backend param with use_lockfile=true ([e681df4](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/e681df47927254f5d735eaf6162ce9100ed82ae8))
* update AuthService base URL to use the correct service name ([9777c77](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/9777c771ebdfb465181e125a5a6a334c1b193d45))
* update readiness and liveness probes to use tcpSocket for consistency ([301ce3e](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/301ce3e430a597abd5007d5fc3bf3e3464abce49))
* update serviceAccount name to external-secrets-sa in values files ([a69937d](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/a69937da2c725cd25ca6b1c72a3b7f725c8794b4))
* Update Trivy SARIF output format to include tool information and results ([871bced](https://github.com/fenixdevsreborn/Fase4-FCG-Orchestrator/commit/871bcedbd0f54d0725e30f8d1318e63ce7d41b8d))
