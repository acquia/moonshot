# frozen_string_literal: true

# This plugin encrypts parameters of the stack using a KMS Key,
# storing and passing the key used to the stack as a parameter as
# well. The resources in the stack can then use that KMS Key to
# decrypt those values.
#
# Example:
#
# Moonshot.config do |s|
#   # .. mechanism config, etc. ..
#
#   # The user will be prompted for values for SecretParameter1 and
#   # SecretParameter2, which will then be encrypted by this plugins
#   # pre_create and pre_update hooks.
#   c.plugins << Moonshot::Plugins::EncryptedParameters.new(
#     'KMSKey1', %w(SecretParameter1 SecretParameter2)
#
#   # Don't prompt the user for a KMS Key, since the default of 'Auto'
#   # will generate a new key. They can override it with an answer
#   # file or command line parameter if needed.
#   c.parameter_sources['KMSKey1'] = Moonshot::AlwaysUseDefaultSource.new
# end
module Moonshot
  module Plugins
    class EncryptedParameters
      # @param [String] kms_key_parameter_name
      #   The parameter name to store the KMS Key ARN as.
      # @param [Array<String>] parameters
      #   Names of parameters to encrypt, if they are not already set.
      def initialize(kms_key_parameter_name, parameters)
        @kms_key_parameter_name = kms_key_parameter_name
        @parameters = parameters
        @delete_key = true
      end

      def pre_create(res)
        @ilog = res.ilog

        key_arn = find_or_create_kms_key
        pe = ParameterEncrypter.new(key_arn)

        @parameters.each do |parameter_name|
          sp = Moonshot.config.parameters[parameter_name]
          raise "No such parameter #{parameter_name}" unless sp

          @ilog.start_threaded "Handling encrypted parameter #{parameter_name.blue}..." do |s|
            if sp.use_previous?
              # TODO: Remove this and the one below when the upstream race is fixed.
              #       See https://github.com/askreet/interactive-logger/issues/7
              sleep 0.05
              s.success "Using previous encrypted value for #{parameter_name.blue}."
            elsif !sp.set? && !sp.default?
              # If the parameter isn't set, we can't encrypt it. Doing
              # nothing means we will give the user a friendly error message
              # about unset parameters when the controller resumes.
              sleep 0.05
              s.failure "No value to encrypt for #{parameter_name.blue}!"
            else
              s.continue "Encrypting new value for parameter #{parameter_name.blue}..."
              Moonshot.config.parameters[sp.name].set(pe.encrypt(sp.value))
              s.success "Encrypted new value for parameter #{parameter_name.blue}!"
            end
          end
        end
      end
      alias pre_update pre_create

      def post_delete(res)
        key_arn = Moonshot.config.parameters[@kms_key_parameter_name].value

        res.ilog.start_threaded "Cleaning up KMS Key #{@kms_key_parameter_name.blue}..." do |s|
          if @delete_key
            KmsKey.new(key_arn).delete
            s.success "Deleted KMS Key #{@kms_key_parameter_name.blue}!"
          else
            # TODO: See above.
            sleep 0.05
            s.success "Retained KMS Key #{@kms_key_parameter_name.blue}."
          end
        end
      end

      def delete_cli_hook(parser)
        parser.on(
          '--retain-kms-key',
          TrueClass,
          'Do not delete the KMS Key for this environment.'
        ) do
          @delete_key = false
        end
      end

      private

      def find_or_create_kms_key
        key_arn = nil

        @ilog.start_threaded "Checking for KMS Key #{@kms_key_parameter_name}" do |s|
          if Moonshot.config.parameters.key?(@kms_key_parameter_name)
            if Moonshot.config.parameters[@kms_key_parameter_name].value == 'Auto'
              s.continue "Auto-generating KMS Key for #{@kms_key_parameter_name.blue}... "
              key_arn = KmsKey.create.arn
              Moonshot.config.parameters[@kms_key_parameter_name].set(key_arn)
              s.success "Created a new KMS Key for #{@kms_key_parameter_name.blue}!"
            else
              kms = KmsKey.new(Moonshot.config.parameters[@kms_key_parameter_name].value)
              key_arn = kms.arn
              kms.update
              s.success "Using existing KMS Key for #{@kms_key_parameter_name.blue}!"
            end
          end
        end

        raise "No such Stack Parameter #{@kms_key_parameter_name}!" unless key_arn

        key_arn
      end
    end
  end
end
