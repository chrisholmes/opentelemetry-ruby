# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

module OpenTelemetry
  module Instrumentation
    module Sinatra
      module Middlewares
        # Middleware to trace Sinatra requests
        class TracerMiddleware
          def initialize(app)
            @app = app
          end

          def call(env)
            extracted_context = OpenTelemetry.propagation.extract(
              env,
              getter: OpenTelemetry::Context::Propagation.rack_env_getter
            )
            OpenTelemetry::Context.with_current(extracted_context) do
              tracer.in_span(
                env['PATH_INFO'],
                attributes: { 'http.method' => env['REQUEST_METHOD'],
                              'http.url' => env['PATH_INFO'] },
                kind: :server
              ) do |span|
                @app.call(env).tap { |resp| trace_response(span, env, resp) }
              end
            end
          end

          private

          def tracer
            OpenTelemetry::Instrumentation::Sinatra::Instrumentation.instance.tracer
          end

          def trace_response(span, env, resp)
            status, _headers, _response_body = resp

            span.set_attribute('http.status_code', status)

            if env['sinatra.route']
              span.name = env['sinatra.route']

              route = env['sinatra.route'].split.last
              span.set_attribute('http.route', route)

              if config[:enable_route_parameter_obfuscation] && span.attributes['http.url']
                url = span.attributes['http.url']
                url = URI.parse(url)
                url.path = URI.parse(route).path
                span.set_attribute('http.url', url.to_s)
              end
            end
            span.status = OpenTelemetry::Trace::Status.http_to_status(status)
          end

          def config
            OpenTelemetry::Instrumentation::Sinatra::Instrumentation.instance.config
          end
        end
      end
    end
  end
end
