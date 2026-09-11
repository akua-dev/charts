import akua.ctx

schema Input:
    """Inputs for the public first-app HTTP route."""
    hostname: str
    """Public DNS hostname for this install's HTTPRoute."""

    check:
        len(hostname) > 0, "hostname must not be empty"

input: Input = ctx.input()

_name = "first-app-http"
_labels = {
    "app.kubernetes.io/name" = _name
    "app.kubernetes.io/part-of" = "first-app"
}
_image = "nginxinc/nginx-unprivileged@sha256:65e3e85dbaed8ba248841d9d58a899b6197106c23cb0ff1a132b7bfe0547e4c0"

resources = [
    {
        apiVersion = "apps/v1"
        kind = "Deployment"
        metadata.name = _name
        metadata.labels = _labels
        spec.replicas = 1
        spec.selector.matchLabels = _labels
        spec.template.metadata.labels = _labels
        spec.template.spec.securityContext = {
            runAsNonRoot = True
            seccompProfile.type = "RuntimeDefault"
        }
        spec.template.spec.containers = [
            {
                name = "http"
                image = _image
                imagePullPolicy = "IfNotPresent"
                ports = [{
                    name = "http"
                    containerPort = 8080
                    protocol = "TCP"
                }]
                readinessProbe = {
                    httpGet = {
                        path = "/"
                        port = "http"
                    }
                }
                livenessProbe = {
                    httpGet = {
                        path = "/"
                        port = "http"
                    }
                }
                securityContext = {
                    allowPrivilegeEscalation = False
                    capabilities.drop = ["ALL"]
                }
            }
        ]
    }
    {
        apiVersion = "v1"
        kind = "Service"
        metadata.name = _name
        metadata.labels = _labels
        spec.type = "ClusterIP"
        spec.selector = _labels
        spec.ports = [{
            name = "http"
            port = 80
            targetPort = "http"
            protocol = "TCP"
        }]
    }
    {
        apiVersion = "gateway.networking.k8s.io/v1"
        kind = "HTTPRoute"
        metadata.name = _name
        metadata.labels = _labels
        metadata.annotations = {
            "routing.akua.dev/output-name" = "main"
            "routing.akua.dev/output-protocol" = "http"
        }
        spec.useDefaultGateways = "All"
        spec.hostnames = [input.hostname]
        spec.rules = [{
            backendRefs = [{
                name = _name
                port = 80
            }]
        }]
    }
]
