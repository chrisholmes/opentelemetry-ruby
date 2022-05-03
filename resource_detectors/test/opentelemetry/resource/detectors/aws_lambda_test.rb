# frozen_string_literal: true

# Copyright The OpenTelemetry Authors
#
# SPDX-License-Identifier: Apache-2.0

require 'test_helper'
require 'opentelemetry/resource/detectors/aws_lambda'

describe OpenTelemetry::Resource::Detectors::AwsLambda do
  let(:detector) { OpenTelemetry::Resource::Detectors::AwsLambda }

  describe '.detect' do
    let(:detected_resource) { detector.detect }
    let(:detected_resource_attributes) { detected_resource.attribute_enumerator.to_h }
    let(:expected_resource_attributes) { {} }

    it 'returns an empty resource' do
      _(detected_resource).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
      _(detected_resource_attributes).must_equal(expected_resource_attributes)
    end

    describe 'when in a aws lambda environment' do
      let(:env_stub) do
        {
          'AWS_LAMBDA_FUNCTION_NAME' => function_name,
          'AWS_LAMBDA_FUNCTION_VERSION' => '1',
          'AWS_REGION' => 'eu-west-1'
        }
      end

      before do
        ENV.stub(:[], ->(key) { env_stub[key] }) { detected_resource }
      end

      let(:function_name) { 'my-function-name' }

      let(:expected_resource_attributes) do
        {
          'cloud.provider' => 'aws',
          'cloud.platform' => 'aws_lambda',
          'faas.name' => 'my-function-name',
          'faas.version' => '1'
        }
      end

      it 'returns a resource with gcp attributes' do
        _(detected_resource).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
        _(detected_resource_attributes).must_equal(expected_resource_attributes)
      end

      describe 'when a value is nil' do
        let(:function_name) { nil }

        it 'returns a resource without that value' do
          _(detected_resource).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
          _(detected_resource_attributes.key?('faas.name')).must_equal(false)
        end
      end

      describe 'when a value is empty string' do
        let(:function_name) { '' }

        it 'returns a resource without that value' do
          _(detected_resource).must_be_instance_of(OpenTelemetry::SDK::Resources::Resource)
          _(detected_resource_attributes.key?('faas.name')).must_equal(false)
        end
      end
    end
  end
end
