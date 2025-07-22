# Makes all string literals in this file frozen/immutable for performance
# frozen_string_literal: true

module Moonshot
  # Custom changelog parser to replace the unmaintained Vandamme gem (previously used in Moonshot until v3.0.4)
  class ChangelogParser
    # Parses a changelog and extracts content for a specific version
    #
    # @param changelog_content [String] The full changelog content
    # @param version [String] The version to extract content for
    # @return [String] The changelog content for the specified version
    # @raise [RuntimeError] if the version is not found in the changelog
    def self.parse(changelog_content, version)
      new(changelog_content).parse(version)
    end

    def initialize(changelog_content)
      @content = changelog_content
    end

    def parse(version)
      version = normalize_version(version)
      version_section = find_version_section(version)

      raise "#{version} not found in CHANGELOG.md" unless version_section

      extract_version_content(version_section)
    end

    private

    def normalize_version(version)
      version.to_s.strip
    end

    def find_version_section(version)
      sections = split_into_sections

      sections.find do |section|
        section_matches_version?(section, version)
      end
    end

    def split_into_sections
      @content.split(/^#+\s+/).reject(&:empty?)
    end

    def section_matches_version?(section, version)
      # Match version patterns like:
      # - "1.0.0"
      # - "[1.0.0]"
      # - "v1.0.0"
      # - "1.0.0 - 2023-01-01"
      # - "1.0.0 / 2023-01-01"
      # - "1.0.0 (2023-01-01)"
      version_pattern = %r{^(\[?v?#{Regexp.escape(version)}\]?)(\s+[-–]\s+|\s+/\s+|\s+\(|\s*$)}i
      section.match(version_pattern)
    end

    def extract_version_content(version_section)
      lines = version_section.lines
      content_lines = []

      # Skip the version header line
      lines[1..]&.each do |line|
        # Stop at next version header
        break if next_version_header?(line)

        content_lines << line
      end

      # Clean up and return the content
      content_lines.join.strip
    end

    def next_version_header?(line)
      # Check if this line is the start of another version section
      line.match(/^#+\s+(\[?v?\d+\.\d+\.\d+)/i)
    end
  end
end
