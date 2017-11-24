- job_name: juju
  metrics_path: /introspection/metrics
  scheme: https
  static_configs:
    - targets: ['__CONTROLLER_IP__']
  basic_auth:
    username: user-prometheus
    password: ubuntu
  tls_config:
    insecure_skip_verify: true
