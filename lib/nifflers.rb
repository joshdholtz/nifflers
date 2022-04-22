# frozen_string_literal: true

require_relative "nifflers/version"

require 'pp'

require 'commander'

module Nifflers
  class CLI
    include Commander::Methods

    def run
      program :name, 'Niffler'
      program :version, Nifflers::VERSION
      program :description, 'Finds tests to run and runs them'

      default_command :find

      command :find do |c|
        c.syntax = 'nifflers find'
        c.description = 'Finds tests to run'
        c.option '--dest DIR', String, 'Destination directory'
        c.option '--lang STRING', String, 'Language to find tests for'
        c.option '--cmd STRING', String, 'Test command to run (ex: rspec)'

        c.option '--ref STRING', String, 'Reference to compare (defaults to default branch) (ex: HEAD~5, other-branch)'

        c.option '--verbose', 'Verbose'

        c.action do |args, options|
          process = Nifflers::Process.new(options.dest, options.lang, options.cmd, options.ref, options.verbose)
          process.start
        end
      end

      run!
    end
  end
end

module Nifflers
  class Process
    attr_accessor :dest
    attr_accessor :lang
    attr_accessor :test_cmd
    attr_accessor :ref
    attr_accessor :verbose

    def initialize(dest, lang, cmd, ref, verbose)
      self.dest = dest || "."
      self.lang = lang
      self.test_cmd = cmd
      self.ref = ref
      self.verbose = verbose
    end

    def extension(files)
      ext = extension_for_lang
      return ext if extension_for_lang

      hash = {}

      files.each do |file|
        the_ext = File.extname(file)
        the_count = hash[the_ext] || 0
        hash[the_ext] = the_count + 1
      end

      highest_key = nil
      highest_value = 0
      hash.each do |k,v|
        if v > highest_value
          highest_key = k
          highest_value = v
        end
      end

      return highest_key
    end

    def extension_for_lang
      if lang == "ruby"
        return ".rb"
      elsif lang == "python"
        return ".py"
      else
        return nil
      end
    end

    def default_branch
      return sh("git symbolic-ref refs/remotes/origin/HEAD | sed 's@^refs/remotes/origin/@@'").strip
    end

    def compare_ref
      return self.ref || "origin/#{self.default_branch}"
    end

    def sh(cmd)
      return `#{cmd}`
    end

    def start
      Dir.chdir(dest) do
        files = sh("git diff --name-only $(git merge-base #{compare_ref} HEAD)").lines.map(&:strip)

        if self.verbose
          puts "== Files Changed"
          files.each do |file|
            puts "- #{file}"
          end
          puts ""
        end

        ext = self.extension(files)
        test_files = find_tests(files, ext)

        files_spaced = test_files.join(" ")

        puts "== Test Files Discovered"
        test_files.each do |file|
          puts "- #{file}"
        end
        puts ""

        if test_cmd
          cmd = "#{test_cmd} #{files_spaced}"
          puts "#{cmd}"
          puts ""

          Kernel.exec(cmd)

#          IO.popen(cmd) do |io|
#            while (line = io.gets) do
#              puts line
#            end
#          end
        end
      end
    end

    def find_tests(files, ext)
      test_files = []

      files.each do |file|
        basename = File.basename(file)
        name = File.basename(file, ".*")
        extension = File.extname(file)

        next if extension != ext

        test_files += Dir["**/#{name}*_spec#{extension}"]
        test_files += Dir["**/#{name}*_test#{extension}"]
        test_files += Dir["**/#{name}*_tests#{extension}"]

        if file.end_with?("_spec.rb")
          test_files << file
        elsif file.end_with?("_test.py")
          test_files << file
        elsif file.end_with?("_tests.py")
          test_files << file
        end
      end

      return test_files.uniq
    end
  end
  
  class Error < StandardError; end
  # Your code goes here...
end
