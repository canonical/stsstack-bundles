# Monitoring

## Simple

The bundle `prometheus.yaml` deploys the following applications:

* prometheus, monitoring system.
* grafana, graph and dashboard builder for visualizing
time series metrics.
* telegraf, is an agent written in Go for collecting metrics from the system
  it's running on

### Juju Controller

It's possible to monitor the juju controller running the
`configure-juju-controller.sh` script. It will add a new user and configure
prometheus to scrape juju's endpoint.

To add a dashboard in grafana with the juju metrics import
`controller-dashboard.json` file. See [Importing a
dashboard](http://docs.grafana.org/reference/export_import/#importing-a-dashboard)
for more details.
