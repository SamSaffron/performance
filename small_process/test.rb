require 'memory_profiler'

MemoryProfiler.start
require 'prometheus_exporter'
require 'prometheus_exporter/server'

server = PrometheusExporter::Server::WebServer.new port: 12344
server.start
sleep 4
MemoryProfiler.stop.pretty_print
