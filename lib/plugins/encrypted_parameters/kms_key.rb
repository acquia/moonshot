require_relative "../stack_tags.rb"

module Moonshot
  module Plugins
    class EncryptedParameters
      # Class that manages KMS keys in AWS.
      class KmsKey
        attr_reader :arn

        def initialize(arn)
          @arn = arn
          @kms_client = Aws::KMS::Client.new
        end

        def self.create
          tags=Moonshot::Plugins::StackTags.new().tags
          resp = Aws::KMS::Client.new.create_key({
            tags: tags, # One or more tags. Each tag consists of a tag key and a tag value.
          })
          arn = resp.key_metadata.arn

          new(arn)
        end

        def delete
          @kms_client.schedule_key_deletion(key_id: @arn, pending_window_in_days: 7)
        end
      end
    end
  end
end
