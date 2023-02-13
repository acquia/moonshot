# frozen_string_literal: true

require 'base64'
module Moonshot
  module Plugins
    class EncryptedParameters
      # Class that can encrypt and decrypt parameters using KMS.
      class ParameterEncrypter
        # @param [String] key_arn The ARN for the KMS key.
        def initialize(key_arn)
          @kms_client = Aws::KMS::Client.new
          @key_arn = key_arn
        end

        # Encrypt and base64 encode the parameter value.
        #
        # @param [String] param_value The parameter to encrypt.
        # @return [String] base64 encoded encrypted ciphertext.
        def encrypt(param_value)
          resp = @kms_client.encrypt(key_id: @key_arn, plaintext: param_value)

          # Use strict here to avoid newlines which cause issues with parameters.
          Base64.strict_encode64(resp.ciphertext_blob)
        end
      end
    end
  end
end
