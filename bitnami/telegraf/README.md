<!--- app-name: Telegraf -->

# Bitnami package for Telegraf

 Telegraf is a server agent for collecting and sending metrics and events from databases, systems, and IoT sensors. It is easily extendable with plugins for collection and output of data operations.

[Overview of Telegraf](https://docs.influxdata.com/telegraf/v1/)

Trademarks: This software listing is packaged by Bitnami. The respective trademarks mentioned in the offering are owned by the respective companies, and use of them does not imply any affiliation or endorsement.

## TL;DR

```console
helm install my-release oci://registry-1.docker.io/bitnamichartsprem/telegraf
```

Looking to use Telegraf in production? Try [VMware Tanzu Application Catalog](https://bitnami.com/enterprise), the commercial edition of the Bitnami catalog.

## Introduction

This chart bootstraps a Tensorfloe deployment on a [Kubernetes](https://kubernetes.io) cluster using the [Helm](https://helm.sh) package manager.

## Prerequisites

- Kubernetes 1.23+
- Helm 3.8.0+

## Installing the Chart

To install the chart with the release name `my-release`:

```console
helm install my-release oci://REGISTRY_NAME/REPOSITORY_NAME/telegraf
```

> Note: You need to substitute the placeholders `REGISTRY_NAME` and `REPOSITORY_NAME` with a reference to your Helm chart registry and repository. For example, in the case of Bitnami, you need to use `REGISTRY_NAME=registry-1.docker.io` and `REPOSITORY_NAME=bitnamichartsprem`.

The command deploys Telegraf on the Kubernetes cluster in the default configuration. The [Parameters](#parameters) section lists the parameters that can be configured during installation.

> **Tip**: List all releases using `helm list`

## Configuration and installation details

### [Rolling VS Immutable tags](https://docs.vmware.com/en/VMware-Tanzu-Application-Catalog/services/tutorials/GUID-understand-rolling-tags-containers-index.html)

It is strongly recommended to use immutable tags in a production environment. This ensures your deployment does not change automatically if the same tag is updated with a different image.

Bitnami will release a new chart updating its containers if a new version of the main container, significant changes, or critical vulnerabilities exist.

### Telegraf configuration

The Telegraf configuration is defined in a ConfigMap, which dictates how Telegraf collects and outputs metrics.

By default, this Helm chart configures Telegraf with a set of common inputs, outputs, and processors:

* **Agent Configuration:** Standard settings for metric collection interval, batch size, buffer limits, and logging.
* **StatsD Input:** Listens for StatsD metrics on UDP port `8125`, configured to calculate 50th, 95th, and 99th percentiles.
* **Health Output:** Exposes a health endpoint on HTTP port `8888`, primarily monitoring internal write operations and buffer size.
* **Enum Processor:** Converts string-based `status` fields (e.g., "healthy", "problem", "critical") into numerical `status_code` values (1, 2, 3 respectively).

This default setup provides basic metric ingestion via StatsD, a health endpoint for monitoring Telegraf's operational status, and a processor for standardizing status fields.

You can provide a complete alternative Telegraf configuration using the `configuration` parameter. For example, to configure OpenTelemetry Input Plugin:

```yaml
configuration: |-
  [[inputs.opentelemetry]]
    service_address = "0.0.0.0:4317"
    timeout = "5s"
```

The default configuration can be alse overridden using the `overrideConfiguration` parameter. This parameter expects a YAML dictionary structured with top-level keys like `agent`, `inputs`, `outputs`, `processors`, and `aggregators`, mirroring the Telegraf configuration file structure. The chart will then convert this YAML into the TOML format required by Telegraf.

For instance, using a configuration like the one below...

```yaml
overrideConfiguration:
  agent:
    interval: "10s"
    round_interval: true
  processors:
    - enum:
        mapping:
          field: "status"
          dest: "status_code"
          value_mappings:
            healthy: 1
            problem: 2
            critical: 3
```

... will generate a telegraf.conf file inside the Pod similar to this:

```toml
    [agent]
      interval = "10s"
      round_interval = true

    [[processors.enum]]
      [[processors.enum.mapping]]
        dest = "status_code"
        fields = [
          "status"
        ]
        [processors.enum.mapping.value_mappings]
          critical = 3
          healthy = 1
          problem = 2
```

**Important:** Each top-level section (e.g. `inputs`, `outputs`, `processors`, `aggregators`, `agent`) defined within `overrideConfiguration` will **completely replace** its corresponding default section. Any sections not defined in `overrideConfiguration` will retain their default values. For example, adding only an `outputs` section in `overrideConfiguration` will replace all default outputs (like the deafult `outputs.health`) with your custom definition, while default `inputs` and `agent` configurations will remain.

Alternatively, you can provide an existing ConfigMap containing your full Telegraf configuration by specifying its name in the `existingConfigmap` value. When `existingConfigmap` is set, `overrideConfiguration` will be ignored.

### External InfluxDB Support

To connect Telegraf to an external InfluxDB database, you must provide the connection details. This is useful for using a managed database service or a centralized database for multiple applications.

To configure this, you need to set the the outputs section of the Telegraf configuration to specify the external database's connection URL, database name, and other credentials.

Here is an example of the required configuration:

```yaml
telegraf:
  overrideConfiguration:
    outputs:
      - influxdb:
          urls:
            - "http://<your-influxdb-host>:<your-influxdb-port>"
          database: "<your-database-name>"
          username: "<your-username>" # if authentication is required
          password: "<your-password>" # if authentication is required
```

Replace the placeholder values (<your-influxdb-host>, <your-influxdb-port>, etc.) with your specific external InfluxDB connection details.

### Additional environment variables

In case you want to add extra environment variables (useful for advanced operations like custom init scripts), you can use the `extraEnvVars` property.

```yaml
Telegraf:
  extraEnvVars:
    - name: LOG_LEVEL
      value: error
```

Alternatively, you can use a ConfigMap or a Secret with the environment variables. To do so, use the `extraEnvVarsCM` or the `extraEnvVarsSecret` values.

### Sidecars

If additional containers are needed in the same pod as Telegraf (such as additional metrics or logging exporters), they can be defined using the `sidecars` parameter.

```yaml
sidecars:
- name: your-image-name
  image: your-image
  imagePullPolicy: Always
  ports:
  - name: portname
    containerPort: 1234
```

If these sidecars export extra ports, extra port definitions can be added using the `service.extraPorts` parameter (where available), as shown in the example below:

```yaml
service:
  extraPorts:
  - name: extraPort
    port: 11311
    targetPort: 11311
```

If additional init containers are needed in the same pod, they can be defined using the `initContainers` parameter. Here is an example:

```yaml
initContainers:
  - name: your-image-name
    image: your-image
    imagePullPolicy: Always
    ports:
      - name: portname
        containerPort: 1234
```

Learn more about [sidecar containers](https://kubernetes.io/docs/concepts/workloads/pods/) and [init containers](https://kubernetes.io/docs/concepts/workloads/pods/init-containers/).

### Pod affinity

This chart allows you to set your custom affinity using the `affinity` parameter. Find more information about Pod affinity in the [kubernetes documentation](https://kubernetes.io/docs/concepts/configuration/assign-pod-node/#affinity-and-anti-affinity).

As an alternative, use one of the preset configurations for pod affinity, pod anti-affinity, and node affinity available at the [bitnami/common](https://github.com/bitnami/charts/tree/main/bitnami/common#affinities) chart. To do so, set the `podAffinityPreset`, `podAntiAffinityPreset`, or `nodeAffinityPreset` parameters.

### Prometheus metrics

This chart can be integrated with Prometheus by setting `metrics.enabled` to true. This will expose the Telegraph native Prometheus endpoint in a `metrics` service, which can be configured under the `metrics.service` section. It will have the necessary annotations to be automatically scraped by Prometheus.

#### Prometheus requirements

It is necessary to have a working installation of Prometheus or Prometheus Operator for the integration to work. Install the [Bitnami Prometheus helm chart](https://github.com/bitnami/charts/tree/main/bitnami/prometheus) or the [Bitnami Kube Prometheus helm chart](https://github.com/bitnami/charts/tree/main/bitnami/kube-prometheus) to easily have a working Prometheus in your cluster.

#### Integration with Prometheus Operator

The chart can deploy `ServiceMonitor` objects for integration with Prometheus Operator installations. To do so, set the value `metrics.serviceMonitor.enabled=true`. Ensure that the Prometheus Operator `CustomResourceDefinitions` are installed in the cluster or it will fail with the following error:

```text
no matches for kind "ServiceMonitor" in version "monitoring.coreos.com/v1"
```

Install the [Bitnami Kube Prometheus helm chart](https://github.com/bitnami/charts/tree/main/bitnami/kube-prometheus) for having the necessary CRDs and the Prometheus Operator.

## Parameters

### Global parameters

| Name                                                  | Description                                                                                                                                                                                                                                                                                                                                                         | Value   |
| ----------------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------- |
| `global.imageRegistry`                                | Global Docker Image registry                                                                                                                                                                                                                                                                                                                                        | `""`    |
| `global.imagePullSecrets`                             | Global Docker registry secret names as an array                                                                                                                                                                                                                                                                                                                     | `[]`    |
| `global.defaultStorageClass`                          | Global default StorageClass for Persistent Volume(s)                                                                                                                                                                                                                                                                                                                | `""`    |
| `global.security.allowInsecureImages`                 | Allows skipping image verification                                                                                                                                                                                                                                                                                                                                  | `false` |
| `global.compatibility.openshift.adaptSecurityContext` | Adapt the securityContext sections of the deployment to make them compatible with Openshift restricted-v2 SCC: remove runAsUser, runAsGroup and fsGroup and let the platform use their allowed default IDs. Possible values: auto (apply if the detected running cluster is Openshift), force (perform the adaptation always), disabled (do not perform adaptation) | `auto`  |
| `global.compatibility.omitEmptySeLinuxOptions`        | If set to true, removes the seLinuxOptions from the securityContexts when it is set to an empty object                                                                                                                                                                                                                                                              | `false` |

### Common parameters

| Name                     | Description                                                                             | Value           |
| ------------------------ | --------------------------------------------------------------------------------------- | --------------- |
| `kubeVersion`            | Override Kubernetes version reported by .Capabilities                                   | `""`            |
| `apiVersions`            | Override Kubernetes API versions reported by .Capabilities                              | `[]`            |
| `nameOverride`           | String to partially override common.names.name                                          | `""`            |
| `fullnameOverride`       | String to fully override common.names.fullname                                          | `""`            |
| `namespaceOverride`      | String to fully override common.names.namespace                                         | `""`            |
| `commonLabels`           | Labels to add to all deployed objects                                                   | `{}`            |
| `commonAnnotations`      | Annotations to add to all deployed objects                                              | `{}`            |
| `clusterDomain`          | Kubernetes cluster domain name                                                          | `cluster.local` |
| `extraDeploy`            | Array of extra objects to deploy with the release                                       | `[]`            |
| `diagnosticMode.enabled` | Enable diagnostic mode (all probes will be disabled and the command will be overridden) | `false`         |
| `diagnosticMode.command` | Command to override all containers in the chart release                                 | `["sleep"]`     |
| `diagnosticMode.args`    | Args to override all containers in the chart release                                    | `["infinity"]`  |

### Telegraf parameters

| Name                                                | Description                                                                                                                                                                                                                | Value                      |
| --------------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- | -------------------------- |
| `image.registry`                                    | Telegraf image registry                                                                                                                                                                                                    | `REGISTRY_NAME`            |
| `image.repository`                                  | Telegraf image repository                                                                                                                                                                                                  | `REPOSITORY_NAME/telegraf` |
| `image.digest`                                      | Telegraf image digest in the way sha256:aa.... Please note this parameter, if set, will override the tag image tag (immutable tags are recommended)                                                                        | `""`                       |
| `image.pullPolicy`                                  | Telegraf image pull policy                                                                                                                                                                                                 | `IfNotPresent`             |
| `image.pullSecrets`                                 | Telegraf image pull secrets                                                                                                                                                                                                | `[]`                       |
| `image.debug`                                       | Enable Telegraf image debug mode                                                                                                                                                                                           | `false`                    |
| `replicaCount`                                      | Number of Telegraf replicas to deploy                                                                                                                                                                                      | `1`                        |
| `overrideConfiguration`                             | Telegraf common configuration override.                                                                                                                                                                                    | `{}`                       |
| `configuration`                                     | Specify full content for Telegraf config file (auto-generated based on other parameters otherwise)                                                                                                                         | `""`                       |
| `existingConfigmap`                                 | The name of an existing ConfigMap with your custom configuration for Telegraf                                                                                                                                              | `""`                       |
| `containerPorts.cisco_telemetry`                    | Telegraf cisco_telemetry container port for collecting Cisco telemetry data.                                                                                                                                               | `57500`                    |
| `containerPorts.health`                             | Telegraf internal health check API container port.                                                                                                                                                                         | `8888`                     |
| `containerPorts.http`                               | Telegraf HTTP container port.                                                                                                                                                                                              | `8080`                     |
| `containerPorts.http_v2`                            | Telegraf HTTP_v2 container port.                                                                                                                                                                                           | `8081`                     |
| `containerPorts.influxdb`                           | Telegraf influxdb container port for receiving InfluxDB line protocol metrics.                                                                                                                                             | `8086`                     |
| `containerPorts.influxdb_v2`                        | Telegraf influxdb_v2 container port for receiving InfluxDB v2 line protocol metrics.                                                                                                                                       | `8087`                     |
| `containerPorts.otlp_grpc`                          | Telegraf opentelemetry gRPC container port.                                                                                                                                                                                | `4317`                     |
| `containerPorts.otlp_http`                          | Telegraf opentelemetry HTTP container port.                                                                                                                                                                                | `4318`                     |
| `containerPorts.prometheus`                         | Telegraf prometheus container port for exposing metrics to be scraped.                                                                                                                                                     | `9273`                     |
| `containerPorts.statsd`                             | Telegraf statsd container port for collecting StatsD metrics.                                                                                                                                                              | `8125`                     |
| `containerPorts.syslog`                             | Telegraf syslog container port for collecting Syslog messages.                                                                                                                                                             | `514`                      |
| `containerPorts.socket`                             | Telegraf socket container port.                                                                                                                                                                                            | `9125`                     |
| `containerPorts.tcp`                                | Telegraf tcp container port for receiving metrics via TCP.                                                                                                                                                                 | `9123`                     |
| `containerPorts.udp`                                | Telegraf udp container port for receiving metrics via UDP.                                                                                                                                                                 | `9124`                     |
| `containerPorts.webhooks`                           | Telegraf webhooks container port for receiving data from webhooks.                                                                                                                                                         | `8082`                     |
| `extraContainerPorts`                               | Optionally specify extra list of additional ports for Telegraf containers                                                                                                                                                  | `[]`                       |
| `livenessProbe.enabled`                             | Enable livenessProbe on Telegraf containers                                                                                                                                                                                | `true`                     |
| `livenessProbe.initialDelaySeconds`                 | Initial delay seconds for livenessProbe                                                                                                                                                                                    | `30`                       |
| `livenessProbe.periodSeconds`                       | Period seconds for livenessProbe                                                                                                                                                                                           | `30`                       |
| `livenessProbe.timeoutSeconds`                      | Timeout seconds for livenessProbe                                                                                                                                                                                          | `2`                        |
| `livenessProbe.failureThreshold`                    | Failure threshold for livenessProbe                                                                                                                                                                                        | `3`                        |
| `livenessProbe.successThreshold`                    | Success threshold for livenessProbe                                                                                                                                                                                        | `1`                        |
| `readinessProbe.enabled`                            | Enable readinessProbe on Telegraf containers                                                                                                                                                                               | `true`                     |
| `readinessProbe.initialDelaySeconds`                | Initial delay seconds for readinessProbe                                                                                                                                                                                   | `30`                       |
| `readinessProbe.periodSeconds`                      | Period seconds for readinessProbe                                                                                                                                                                                          | `30`                       |
| `readinessProbe.timeoutSeconds`                     | Timeout seconds for readinessProbe                                                                                                                                                                                         | `2`                        |
| `readinessProbe.failureThreshold`                   | Failure threshold for readinessProbe                                                                                                                                                                                       | `3`                        |
| `readinessProbe.successThreshold`                   | Success threshold for readinessProbe                                                                                                                                                                                       | `1`                        |
| `startupProbe.enabled`                              | Enable startupProbe on Telegraf containers                                                                                                                                                                                 | `false`                    |
| `startupProbe.initialDelaySeconds`                  | Initial delay seconds for startupProbe                                                                                                                                                                                     | `30`                       |
| `startupProbe.periodSeconds`                        | Period seconds for startupProbe                                                                                                                                                                                            | `30`                       |
| `startupProbe.timeoutSeconds`                       | Timeout seconds for startupProbe                                                                                                                                                                                           | `2`                        |
| `startupProbe.failureThreshold`                     | Failure threshold for startupProbe                                                                                                                                                                                         | `3`                        |
| `startupProbe.successThreshold`                     | Success threshold for startupProbe                                                                                                                                                                                         | `1`                        |
| `customLivenessProbe`                               | Custom livenessProbe that overrides the default one                                                                                                                                                                        | `{}`                       |
| `customReadinessProbe`                              | Custom readinessProbe that overrides the default one                                                                                                                                                                       | `{}`                       |
| `customStartupProbe`                                | Custom startupProbe that overrides the default one                                                                                                                                                                         | `{}`                       |
| `resourcesPreset`                                   | Set Telegraf container resources according to one common preset (allowed values: none, nano, micro, small, medium, large, xlarge, 2xlarge). This is ignored if resources is set (resources is recommended for production). | `nano`                     |
| `resources`                                         | Set Telegraf container requests and limits for different resources like CPU or memory (essential for production workloads)                                                                                                 | `{}`                       |
| `podSecurityContext.enabled`                        | Enable Telegraf pods' Security Context                                                                                                                                                                                     | `true`                     |
| `podSecurityContext.fsGroupChangePolicy`            | Set filesystem group change policy for Telegraf pods                                                                                                                                                                       | `Always`                   |
| `podSecurityContext.sysctls`                        | Set kernel settings using the sysctl interface for Telegraf pods                                                                                                                                                           | `[]`                       |
| `podSecurityContext.supplementalGroups`             | Set filesystem extra groups for Telegraf pods                                                                                                                                                                              | `[]`                       |
| `podSecurityContext.fsGroup`                        | Set fsGroup in Telegraf pods' Security Context                                                                                                                                                                             | `1001`                     |
| `containerSecurityContext.enabled`                  | Enabled Telegraf container' Security Context                                                                                                                                                                               | `true`                     |
| `containerSecurityContext.seLinuxOptions`           | Set SELinux options in Telegraf container                                                                                                                                                                                  | `{}`                       |
| `containerSecurityContext.runAsUser`                | Set runAsUser in Telegraf container' Security Context                                                                                                                                                                      | `1001`                     |
| `containerSecurityContext.runAsGroup`               | Set runAsGroup in Telegraf container' Security Context                                                                                                                                                                     | `1001`                     |
| `containerSecurityContext.runAsNonRoot`             | Set runAsNonRoot in Telegraf container' Security Context                                                                                                                                                                   | `true`                     |
| `containerSecurityContext.readOnlyRootFilesystem`   | Set readOnlyRootFilesystem in Telegraf container' Security Context                                                                                                                                                         | `true`                     |
| `containerSecurityContext.privileged`               | Set privileged in Telegraf container' Security Context                                                                                                                                                                     | `false`                    |
| `containerSecurityContext.allowPrivilegeEscalation` | Set allowPrivilegeEscalation in Telegraf container' Security Context                                                                                                                                                       | `false`                    |
| `containerSecurityContext.capabilities.drop`        | List of capabilities to be dropped in Telegraf container                                                                                                                                                                   | `["ALL"]`                  |
| `containerSecurityContext.seccompProfile.type`      | Set seccomp profile in Telegraf container                                                                                                                                                                                  | `RuntimeDefault`           |
| `command`                                           | Override default Telegraf container command (useful when using custom images)                                                                                                                                              | `[]`                       |
| `args`                                              | Override default Telegraf container args (useful when using custom images)                                                                                                                                                 | `[]`                       |
| `automountServiceAccountToken`                      | Mount Service Account token in Telegraf pods                                                                                                                                                                               | `false`                    |
| `hostAliases`                                       | Telegraf pods host aliases                                                                                                                                                                                                 | `[]`                       |
| `deploymentAnnotations`                             | Annotations for Telegraf deployment                                                                                                                                                                                        | `{}`                       |
| `podLabels`                                         | Extra labels for Telegraf pods                                                                                                                                                                                             | `{}`                       |
| `podAnnotations`                                    | Annotations for Telegraf pods                                                                                                                                                                                              | `{}`                       |
| `podAffinityPreset`                                 | Pod affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`                                                                                                                                        | `""`                       |
| `podAntiAffinityPreset`                             | Pod anti-affinity preset. Ignored if `affinity` is set. Allowed values: `soft` or `hard`                                                                                                                                   | `soft`                     |
| `nodeAffinityPreset.type`                           | Node affinity preset type. Ignored if `affinity` is set. Allowed values: `soft` or `hard`                                                                                                                                  | `""`                       |
| `nodeAffinityPreset.key`                            | Node label key to match. Ignored if `affinity` is set                                                                                                                                                                      | `""`                       |
| `nodeAffinityPreset.values`                         | Node label values to match. Ignored if `affinity` is set                                                                                                                                                                   | `[]`                       |
| `affinity`                                          | Affinity for Telegraf pods assignment                                                                                                                                                                                      | `{}`                       |
| `nodeSelector`                                      | Node labels for Telegraf pods assignment                                                                                                                                                                                   | `{}`                       |
| `tolerations`                                       | Tolerations for Telegraf pods assignment                                                                                                                                                                                   | `[]`                       |
| `updateStrategy.type`                               | Telegraf deployment strategy type                                                                                                                                                                                          | `RollingUpdate`            |
| `priorityClassName`                                 | Telegraf pods' priorityClassName                                                                                                                                                                                           | `""`                       |
| `topologySpreadConstraints`                         | Topology Spread Constraints for Telegraf pod assignment spread across your cluster among failure-domains                                                                                                                   | `[]`                       |
| `schedulerName`                                     | Name of the k8s scheduler (other than default) for Telegraf pods                                                                                                                                                           | `""`                       |
| `terminationGracePeriodSeconds`                     | Seconds Telegraf pods need to terminate gracefully                                                                                                                                                                         | `""`                       |
| `lifecycleHooks`                                    | for Telegraf containers to automate configuration before or after startup                                                                                                                                                  | `{}`                       |
| `extraEnvVars`                                      | Array with extra environment variables to add to Telegraf containers                                                                                                                                                       | `[]`                       |
| `extraEnvVarsCM`                                    | Name of existing ConfigMap containing extra env vars for Telegraf containers                                                                                                                                               | `""`                       |
| `extraEnvVarsSecret`                                | Name of existing Secret containing extra env vars for Telegraf containers                                                                                                                                                  | `""`                       |
| `extraVolumes`                                      | Optionally specify extra list of additional volumes for the Telegraf pods                                                                                                                                                  | `[]`                       |
| `extraVolumeMounts`                                 | Optionally specify extra list of additional volumeMounts for the Telegraf containers                                                                                                                                       | `[]`                       |
| `sidecars`                                          | Add additional sidecar containers to the Telegraf pods                                                                                                                                                                     | `[]`                       |
| `initContainers`                                    | Add additional init containers to the Telegraf pods                                                                                                                                                                        | `[]`                       |
| `pdb.create`                                        | Enable/disable a Pod Disruption Budget creation                                                                                                                                                                            | `true`                     |
| `pdb.minAvailable`                                  | Minimum number/percentage of pods that should remain scheduled                                                                                                                                                             | `""`                       |
| `pdb.maxUnavailable`                                | Maximum number/percentage of pods that may be made unavailable. Defaults to `1` if both `pdb.minAvailable` and `pdb.maxUnavailable` are empty.                                                                             | `""`                       |
| `autoscaling.vpa.enabled`                           | Enable VPA for Telegraf pods                                                                                                                                                                                               | `false`                    |
| `autoscaling.vpa.annotations`                       | Annotations for VPA resource                                                                                                                                                                                               | `{}`                       |
| `autoscaling.vpa.controlledResources`               | VPA List of resources that the vertical pod autoscaler can control. Defaults to cpu and memory                                                                                                                             | `[]`                       |
| `autoscaling.vpa.maxAllowed`                        | VPA Max allowed resources for the pod                                                                                                                                                                                      | `{}`                       |
| `autoscaling.vpa.minAllowed`                        | VPA Min allowed resources for the pod                                                                                                                                                                                      | `{}`                       |
| `autoscaling.vpa.updatePolicy.updateMode`           | Autoscaling update policy                                                                                                                                                                                                  | `Auto`                     |
| `autoscaling.hpa.enabled`                           | Enable HPA for Telegraf pods                                                                                                                                                                                               | `false`                    |
| `autoscaling.hpa.minReplicas`                       | Minimum number of replicas                                                                                                                                                                                                 | `1`                        |
| `autoscaling.hpa.maxReplicas`                       | Maximum number of replicas                                                                                                                                                                                                 | `3`                        |
| `autoscaling.hpa.targetCPU`                         | Target CPU utilization percentage                                                                                                                                                                                          | `75`                       |
| `autoscaling.hpa.targetMemory`                      | Target Memory utilization percentage                                                                                                                                                                                       | `""`                       |

### Traffic Exposure Parameters

| Name                                    | Description                                                                                                                              | Value       |
| --------------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------- | ----------- |
| `service.type`                          | Telegraf service type                                                                                                                    | `ClusterIP` |
| `service.exposeCiscoTelemetry`          | Add the Cisco Telemetry MDT container port to the service.                                                                               | `false`     |
| `service.exposeHealth`                  | Add the Telegraf internal health check API container port to the service.                                                                | `false`     |
| `service.exposeHttp`                    | Add the Telegraf http container port to the service.                                                                                     | `false`     |
| `service.exposeHttpV2`                  | Add the Telegraf http_v2 container port to the service.                                                                                  | `true`      |
| `service.exposeInfluxdb`                | Add the influxdb container port to the service.                                                                                          | `false`     |
| `service.exposeInfluxdbV2`              | Add the influxdb_v2 container port to the service.                                                                                       | `false`     |
| `service.exposeOtlpGrpc`                | Add the opentelemetry gRPC container port to the service.                                                                                | `false`     |
| `service.exposeOtlpHttp`                | Add the opentelemetry HTTP container port to the service.                                                                                | `false`     |
| `service.exposePrometheus`              | Add the prometheus container port to the service.                                                                                        | `false`     |
| `service.exposeSocket`                  | Add the socket container port to the service.                                                                                            | `false`     |
| `service.exposeStatsd`                  | Add the statsd container port to the service.                                                                                            | `false`     |
| `service.exposeSyslog`                  | Add the syslog container port to the service.                                                                                            | `false`     |
| `service.exposeTcp`                     | Add the tcp container port to the service.                                                                                               | `false`     |
| `service.exposeUdp`                     | Add the udp container port to the service.                                                                                               | `false`     |
| `service.exposeWebhooks`                | Add the webhooks container port to the service.                                                                                          | `false`     |
| `service.ports.cisco_telemetry`         | Telegraf cisco_telemetry service port for collecting Cisco telemetry data.                                                               | `57500`     |
| `service.ports.health`                  | Telegraf internal health check API service port.                                                                                         | `8888`      |
| `service.ports.http`                    | Telegraf HTTP service port (deprecated).                                                                                                 | `8080`      |
| `service.ports.http_v2`                 | Telegraf HTTP service port.                                                                                                              | `8081`      |
| `service.ports.influxdb`                | Telegraf influxdb service port for receiving InfluxDB line protocol metrics.                                                             | `8086`      |
| `service.ports.influxdb_v2`             | Telegraf influxdb_v2 service port for receiving InfluxDB v2 line protocol metrics.                                                       | `8087`      |
| `service.ports.otlp_grpc`               | Telegraf opentelemetry gRPC service port.                                                                                                | `4317`      |
| `service.ports.otlp_http`               | Telegraf opentelemetry HTTP service port.                                                                                                | `4318`      |
| `service.ports.prometheus`              | Telegraf prometheus service port for exposing metrics to be scraped.                                                                     | `9273`      |
| `service.ports.statsd`                  | Telegraf statsd service port for collecting StatsD metrics.                                                                              | `8125`      |
| `service.ports.syslog`                  | Telegraf syslog service port for collecting Syslog messages.                                                                             | `514`       |
| `service.ports.socket`                  | Telegraf socket service port.                                                                                                            | `9125`      |
| `service.ports.tcp`                     | Telegraf tcp service port for receiving metrics via TCP.                                                                                 | `9123`      |
| `service.ports.udp`                     | Telegraf udp service port for receiving metrics via UDP.                                                                                 | `9124`      |
| `service.ports.webhooks`                | Telegraf webhooks service port for receiving data from webhooks.                                                                         | `8082`      |
| `service.nodePorts.cisco_telemetry`     | Node port for Telegraf cisco_telemetry.                                                                                                  | `""`        |
| `service.nodePorts.health`              | Node port for Telegraf internal health check API.                                                                                        | `""`        |
| `service.nodePorts.http`                | Node port for Telegraf HTTP.                                                                                                             | `""`        |
| `service.nodePorts.http_v2`             | Node port for Telegraf HTTP.                                                                                                             | `""`        |
| `service.nodePorts.influxdb`            | Node port for Telegraf influxdb.                                                                                                         | `""`        |
| `service.nodePorts.influxdb_v2`         | Node port for Telegraf influxdb_v2.                                                                                                      | `""`        |
| `service.nodePorts.otlp_grpc`           | Node port for Telegraf opentelemetry gRPC.                                                                                               | `""`        |
| `service.nodePorts.otlp_http`           | Node port for Telegraf opentelemetry HTTP.                                                                                               | `""`        |
| `service.nodePorts.prometheus`          | Node port for Telegraf prometheus.                                                                                                       | `""`        |
| `service.nodePorts.statsd`              | Node port for Telegraf statsd.                                                                                                           | `""`        |
| `service.nodePorts.syslog`              | Node port for Telegraf syslog.                                                                                                           | `""`        |
| `service.nodePorts.socket`              | Node port for Telegraf socket.                                                                                                           | `""`        |
| `service.nodePorts.tcp`                 | Node port for Telegraf tcp.                                                                                                              | `""`        |
| `service.nodePorts.udp`                 | Node port for Telegraf udp.                                                                                                              | `""`        |
| `service.nodePorts.webhooks`            | Node port for Telegraf webhooks.                                                                                                         | `""`        |
| `service.clusterIP`                     | Telegraf service Cluster IP                                                                                                              | `""`        |
| `service.loadBalancerIP`                | Telegraf service Load Balancer IP                                                                                                        | `""`        |
| `service.loadBalancerSourceRanges`      | Telegraf service Load Balancer sources                                                                                                   | `[]`        |
| `service.externalTrafficPolicy`         | Telegraf service external traffic policy                                                                                                 | `Cluster`   |
| `service.annotations`                   | Additional custom annotations for Telegraf service                                                                                       | `{}`        |
| `service.extraPorts`                    | Extra ports to expose in Telegraf service (normally used with the `sidecars` value)                                                      | `[]`        |
| `service.sessionAffinity`               | Control where client requests go, to the same pod or round-robin                                                                         | `None`      |
| `service.sessionAffinityConfig`         | Additional settings for the sessionAffinity                                                                                              | `{}`        |
| `networkPolicy.enabled`                 | Specifies whether a NetworkPolicy should be created                                                                                      | `true`      |
| `networkPolicy.allowExternal`           | Don't require server label for connections                                                                                               | `true`      |
| `networkPolicy.allowExternalEgress`     | Allow the pod to access any range of port and all destinations.                                                                          | `true`      |
| `networkPolicy.addExternalClientAccess` | Allow access from pods with client label set to "true". Ignored if `networkPolicy.allowExternal` is true.                                | `true`      |
| `networkPolicy.kubeAPIServerPorts`      | List of possible endpoints to kubernetes components like kube-apiserver or kubelet (limit to your cluster settings to increase security) | `[]`        |
| `networkPolicy.extraIngress`            | Add extra ingress rules to the NetworkPolicy                                                                                             | `[]`        |
| `networkPolicy.extraEgress`             | Add extra ingress rules to the NetworkPolicy (ignored if allowExternalEgress=true)                                                       | `[]`        |
| `networkPolicy.ingressPodMatchLabels`   | Labels to match to allow traffic from other pods. Ignored if `networkPolicy.allowExternal` is true.                                      | `{}`        |
| `networkPolicy.ingressNSMatchLabels`    | Labels to match to allow traffic from other namespaces. Ignored if `networkPolicy.allowExternal` is true.                                | `{}`        |
| `networkPolicy.ingressNSPodMatchLabels` | Pod labels to match to allow traffic from other namespaces. Ignored if `networkPolicy.allowExternal` is true.                            | `{}`        |

### Other Parameters

| Name                                          | Description                                                                                            | Value   |
| --------------------------------------------- | ------------------------------------------------------------------------------------------------------ | ------- |
| `rbac.create`                                 | Specifies whether RBAC resources should be created                                                     | `false` |
| `rbac.clusterWideAccess`                      | Create only for the release namespace or cluster wide (Role vs ClusterRole)                            | `false` |
| `rbac.rules`                                  | Custom RBAC rules to set                                                                               | `[]`    |
| `serviceAccount.create`                       | Specifies whether a ServiceAccount should be created                                                   | `true`  |
| `serviceAccount.name`                         | The name of the ServiceAccount to use.                                                                 | `""`    |
| `serviceAccount.annotations`                  | Additional Service Account annotations (evaluated as a template)                                       | `{}`    |
| `serviceAccount.automountServiceAccountToken` | Automount service account token for the server service account                                         | `false` |
| `metrics.enabled`                             | Enable the export of Prometheus metrics                                                                | `false` |
| `metrics.annotations`                         | Annotations for the server service in order to scrape metrics                                          | `{}`    |
| `metrics.serviceMonitor.enabled`              | if `true`, creates a Prometheus Operator ServiceMonitor (also requires `metrics.enabled` to be `true`) | `false` |
| `metrics.serviceMonitor.namespace`            | Namespace in which Prometheus is running                                                               | `""`    |
| `metrics.serviceMonitor.annotations`          | Additional custom annotations for the ServiceMonitor                                                   | `{}`    |
| `metrics.serviceMonitor.labels`               | Extra labels for the ServiceMonitor                                                                    | `{}`    |
| `metrics.serviceMonitor.jobLabel`             | The name of the label on the target service to use as the job name in Prometheus                       | `""`    |
| `metrics.serviceMonitor.honorLabels`          | honorLabels chooses the metric's labels on collisions with target labels                               | `false` |
| `metrics.serviceMonitor.tlsConfig`            | TLS configuration used for scrape endpoints used by Prometheus                                         | `{}`    |
| `metrics.serviceMonitor.interval`             | Interval at which metrics should be scraped.                                                           | `""`    |
| `metrics.serviceMonitor.scrapeTimeout`        | Timeout after which the scrape is ended                                                                | `""`    |
| `metrics.serviceMonitor.metricRelabelings`    | Specify additional relabeling of metrics                                                               | `[]`    |
| `metrics.serviceMonitor.relabelings`          | Specify general relabeling                                                                             | `[]`    |
| `metrics.serviceMonitor.selector`             | Prometheus instance selector labels                                                                    | `{}`    |

Specify each parameter using the `--set key=value[,key=value]` argument to `helm install`. For example,

```console
helm install my-release \
  --set service.exposeInfluxdb=true \
    REGISTRY_NAME/REPOSITORY_NAME/telegraf
```

The above command exposes the InfluxDB port for Telegraf.

Alternatively, a YAML file that specifies the values for the above parameters can be provided while installing the chart. For example,

```console
helm install my-release -f values.yaml REGISTRY_NAME/REPOSITORY_NAME/telegraf
```

> Note: You need to substitute the placeholders `REGISTRY_NAME` and `REPOSITORY_NAME` with a reference to your Helm chart registry and repository. For example, in the case of Bitnami, you need to use `REGISTRY_NAME=registry-1.docker.io` and `REPOSITORY_NAME=bitnamichartsprem`.
> **Tip**: You can use the default [values.yaml](https://github.com/bitnami/charts-private/tree/main/bitnami/telegraf/values.yaml)

## Troubleshooting

Find more information about how to deal with common errors related to Bitnami's Helm charts in [this troubleshooting guide](https://docs.bitnami.com/general/how-to/troubleshoot-helm-chart-issues).

## License

Copyright &copy; 2025 Broadcom. The term "Broadcom" refers to Broadcom Inc. and/or its subsidiaries.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

<http://www.apache.org/licenses/LICENSE-2.0>

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
