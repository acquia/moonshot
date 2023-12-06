# frozen_string_literal: true

module Moonshot
  module AccountContext
    def self.get
      @get ||= determine_account_name
    end

    def self.set(account_name)
      @account = account_name
    end

    def self.reset
      @account = nil
    end

    def self.determine_account_name
      Aws::IAM::Client.new.list_account_aliases.account_aliases.first
    end
  end
end
