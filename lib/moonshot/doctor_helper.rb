# -*- coding: utf-8 -*-
require 'colorize'

module Moonshot
  DoctorCritical = Class.new(RuntimeError)

  #
  # A series of methods for adding "doctor" checks to a mechanism.
  #
  module DoctorHelper
    def self.included(klass)
      class << klass
        attr_accessor :doctor_checks
      end
      klass.doctor_checks = {}
      klass.extend ClassMethods
    end

    def doctor_hook(options = {})
      checks = self.class.doctor_checks
      checks.delete_if { |_k, v| v[:is_local] == false } if options[:local]
      checks.delete_if { |_k, v| v[:is_config] == false } if options[:config]
      run_checks(checks)
    end

    # Contains class methods
    module ClassMethods
      def add_doctor_check(method, flags = {})
        default_flags = {
          is_local: false,
          is_config: false
        }
        doctor_checks[method] = default_flags.merge(flags)
      end
    end

    private

    def run_checks(checks)
      return true if checks.empty?
      success = true

      puts
      puts self.class.name.split('::').last

      checks.each do |meth, _|
        begin
          send(meth)
        rescue DoctorCritical
          # Stop running checks in this Mechanism.
          success = false
          break
        rescue => e
          success = false
          print '  ✗ '.red
          puts "Exception while running check: #{e.class}: #{e.message.lines.first}"
          break
        end
      end

      success
    end

    def success(str)
      print '  ✓ '.green
      puts str
    end

    def warning(str, additional_info = nil)
      print '  ? '.yellow
      puts str
      additional_info.lines.each { |l| puts "      #{l}" } if additional_info
    end

    def critical(str, additional_info = nil)
      print '  ✗ '.red
      puts str
      additional_info.lines.each { |l| puts "      #{l}" } if additional_info
      raise DoctorCritical
    end
  end
end
