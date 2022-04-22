# frozen_string_literal: true

require_relative "nifflers/version"

require 'pp'

module Nifflers
  class CLI
    def self.start
      path = ARGV[0] || "."
      extension = ARGV[1].strip

      Dir.chdir(path) do
        files = `git diff --name-only $(git merge-base master HEAD)`.lines.map(&:strip)

        test_files = find_tests(files, extension)

        files_spaced = test_files.join(" ")

        cmd = "(cd #{path} && bundle exec rspec #{files_spaced})"
        puts cmd
        Kernel.exec(cmd)
      end
    end

    def self.find_tests(files, ext)
      test_files = []

      files.each do |file|
        basename = File.basename(file)
        name = File.basename(file, ".*")
        extension = File.extname(file)

        next if extension != ".#{ext}"

        test_files += Dir["**/#{name}*_spec#{extension}"]

        if !file.end_with?("_spec.rb")
          test_files.delete(file)
        end
      end

      return test_files.uniq
    end
  end
  
  class Error < StandardError; end
  # Your code goes here...
end
