# Test changelog content for the ChangelogParser
sample_changelog = <<~CHANGELOG
  # Changelog

  All notable changes to this project will be documented in this file.

  ## [1.2.0] - 2023-07-18

  ### Added
  - New feature A
  - New feature B

  ### Changed
  - Updated dependency X

  ## [1.1.0] - 2023-06-15

  ### Added
  - Previous feature C

  ### Fixed
  - Bug fix D

  ## [1.0.0] - 2023-05-01

  ### Added
  - Initial release
CHANGELOG

# Test the parser
require_relative '../lib/moonshot/changelog_parser'

begin
  result = Moonshot::ChangelogParser.parse(sample_changelog, '1.2.0')
  puts "Success! Parsed content for version 1.2.0:"
  puts result
rescue => e
  puts "Error: #{e.message}"
end
