# frozen_string_literal: true

module Moonshot
  # Encapsulates Teleport SSH configuration derived from the stack name,
  # SSH user, and AWS region. Determines the correct proxy URL, account ID,
  # and identity file path for both normal users and bot users.
  class TeleportConfig
    PROD_ACCOUNT_ID = '546349603759'
    DEV_ACCOUNT_ID  = '672327909798'
    BOT_USER        = 'clouddatabot'

    PROD_PROXY_TEMPLATE = '%<region>s.teleport.cloudservices.acquia.io'
    DEV_PROXY            = 'teleport.dev.cloudservices.acquia.io'

    PROD_IDENTITY_TEMPLATE = 'tbot-auth-%<region>s/identity'
    DEV_IDENTITY           = '/opt/machine-id/identity'

    attr_reader :proxy_url, :account_id, :region, :ssh_user

    def initialize(stack_name, ssh_user, region)
      @stack_name = stack_name.to_s
      @ssh_user   = ssh_user.to_s
      @region     = region.to_s

      if prod?
        @account_id = PROD_ACCOUNT_ID
        @proxy_url  = format(PROD_PROXY_TEMPLATE, region: @region)
      else
        @account_id = DEV_ACCOUNT_ID
        @proxy_url  = DEV_PROXY
      end
    end

    def bot_user?
      @ssh_user == BOT_USER
    end

    # Returns the Teleport identity file path for bot users; nil for normal users.
    def identity_file
      return nil unless bot_user?

      prod? ? format(PROD_IDENTITY_TEMPLATE, region: @region) : DEV_IDENTITY
    end

    # Constructs the Teleport node name used as SSH hostname.
    # Format: <instance_id>.<region>.<account_id>
    def host_for(instance_id)
      "#{instance_id}.#{@region}.#{@account_id}"
    end

    private

    def prod?
      @stack_name.include?('prod')
    end
  end
end
