# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'opentelemetry-api'

module OpenTelemetry
  module Instrumentation
    module RSpec
      # An RSpec Formatter that outputs Otel spans
      class Formatter
        attr_reader :output

        ::RSpec::Core::Formatters.register self, :example_started, :example_finished, :example_group_started, :example_group_finished, :start, :stop

        @clock = Time.method(:now)

        def self.current_timestamp
          @clock.call
        end

        def initialize(output)
          @spans_and_tokens = []
          @output = ''
        end

        def tracer
          @tracer ||= OpenTelemetry.tracer_provider.tracer('RSpec')
        end

        def current_timestamp
          self.class.current_timestamp
        end

        def start(notification)
          span = tracer.start_span('RSpec suite', start_timestamp: current_timestamp)
          track_span(span)
        end

        def stop(notification)
          pop_and_finalize_span
        end

        def example_group_started(notification)
          description = notification.group.description
          span = tracer.start_span(description, start_timestamp: current_timestamp)
          track_span(span)
        end

        def example_group_finished(notification)
          pop_and_finalize_span
        end

        def example_started(notification)
          example = notification.example
          attributes = {
            'location' => example.location.to_s,
            'full_description' => example.full_description.to_s,
            'described_class' => example.metadata[:described_class].to_s
          }
          span = tracer.start_span(example.description, attributes: attributes, start_timestamp: current_timestamp)
          track_span(span)
        end

        def example_finished(notification)
          pop_and_finalize_span do |span|
            result = notification.example.execution_result
            notification.example.metadata

            span.set_attribute('result', result.status.to_s)

            if (exception = result.exception)
              span.record_exception(exception)
              span.set_attribute('message', exception.message) if exception.is_a? ::RSpec::Expectations::ExpectationNotMetError
            end
          end
        end

        def track_span(span)
          token = OpenTelemetry::Context.attach(
            OpenTelemetry::Trace.context_with_span(span)
          )
          @spans_and_tokens.unshift([span, token])
        end

        def pop_and_finalize_span
          span, token = *@spans_and_tokens.shift
          return unless span.recording?

          yield span if block_given?

          span.finish(end_timestamp: current_timestamp)
          OpenTelemetry::Context.detach(token)
        end
      end
    end
  end
end
