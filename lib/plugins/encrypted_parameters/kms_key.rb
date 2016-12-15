module Moonshot
  class EncryptedParameters
    # Class that manages KMS keys in AWS.
    class KmsKey
      attr_reader :arn

      def initialize(arn)
        @arn = arn
        @kms_client = Aws::KMS::Client.new
      end

      def self.create
        resp = Aws::KMS::Client.new.create_key
        arn = resp.key_metadata.arn

        new(arn)
      end

      def delete
        @kms_client.schedule_key_deletion(key_id: @arn, pending_window_in_days: 7)
      end
    end
  end
end
