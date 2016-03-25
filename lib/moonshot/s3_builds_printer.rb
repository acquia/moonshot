# coding: utf-8
require 'colorize'

module Moonshot
  # Display a list of builds for the user.
  class S3BuildsPrinter
    def initialize(builds, limit, filter, table)
      @builds = builds
      @limit = limit
      @filter = filter
      @table = table
    end

    def print
      t = @table.add_leaf('Builds')

      builds = @builds.sort_by(&:last_modified).reverse
      builds.select! { |build| build.key.include?(@filter) } if @filter
      builds = builds.first(@limit) unless @limit == 0

      if builds.count == 0
        t.add_line("No builds were found with the provided parameters.".red)
      end

      rows = builds.map do |build|
        row_for_build(build)
      end

      t.add_table(rows)
    end

    private

    def row_for_build(build)
      [
        build.last_modified.to_s.light_black,
        build.owner.display_name.light_blue,
        build.key.chomp('.tar.gz'),
        ((build.size * 1.0 / (1024 * 1024)).round(2).to_s << ' MB').light_yellow
      ]
    end
  end
end
