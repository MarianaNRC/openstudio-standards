require 'simplecov'
require 'simplecov-json'
# Make sure SimpleCov knows that the project root is two levels up
# from this file (i.e., the folder that contains lib/ and test/)
SimpleCov.root File.expand_path('../..', __dir__)
puts "SimpleCov.root+++++ = #{SimpleCov.root}"

# Configure SimpleCov (must run before any other requires)

SimpleCov.coverage_dir('coverage')
SimpleCov.formatters = SimpleCov::Formatter::MultiFormatter.new([
                                                                  SimpleCov::Formatter::HTMLFormatter,
                                                                  SimpleCov::Formatter::JSONFormatter
                                                                ])

SimpleCov.start do
  add_filter '/vendor/'
  add_filter '/test/'
  add_group 'NECB Standards', 'lib/openstudio-standards/standards/necb/'
  # Add groups for each NECB version
  add_group 'NECB Rules 2011', 'lib/openstudio-standards/standards/necb/NECB2011/'
  add_group 'NECB Rules 2015', 'lib/openstudio-standards/standards/necb/NECB2015/'
  add_group 'NECB Rules 2017', 'lib/openstudio-standards/standards/necb/NECB2017/'
  add_group 'NECB Rules 2020', 'lib/openstudio-standards/standards/necb/NECB2020/'
end

puts 'SimpleCov started” coverage report will be in coverage/index.html'
$LOAD_PATH.unshift File.expand_path('../../../lib', __FILE__)
require 'minitest/autorun'
if ENV['CI'] == 'true'
  require 'minitest/ci'
  puts "Saving test results to #{Minitest::Ci.report_dir}"
end
require 'minitest/reporters'
require 'minitest/reporters/base_reporter'
require 'minitest/reporters/spec_reporter'

require 'openstudio'
require 'openstudio/measure/ShowRunnerOutput'
require 'json'
require 'fileutils'

# Require local version instead of installed version for developers
begin
  require_relative '../../lib/openstudio-standards.rb'
  puts 'DEVELOPERS OF OPENSTUDIO-STANDARDS: Requiring code directly instead of using installed gem.  This avoids having to run rake install every time you make a change.' 
rescue LoadError
  require 'openstudio-standards'
  puts 'Using installed openstudio-standards gem.' 
end

# Set the output reporting format based on the run environment
if ENV['RM_INFO'] || ENV['TEAMCITY_RAKE_RUNNER_MODE'] # RubyMine
  puts "Running tests from RubyMine, using RubyMine test reporter."
  ENV.delete('RM_INFO') # Delete this environment variable because it forces use of only RubyMineReporter
  Minitest::Reporters.use! [Minitest::Reporters::RubyMineReporter.new]
  # line below for PNNL local testing
  # Minitest::Reporters.use! [Minitest::Reporters::RubyMineReporter.new, Minitest::Reporters::JUnitReporter.new(reports_dir="test/reports", empty=false)] 
elsif ENV['JENKINS_HOME'] # Jenkins
  puts "Running tests from Jenkins, using JUnit XML test reporter and console-based test reporter."
  Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new, Minitest::Reporters::JUnitReporter.new(reports_dir = "test/reports", empty = false)]
else # Terminal or other
  puts "Running tests from terminal, using console-based test reporter."
  Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new]
  # line below for PNNL local testing
  # Minitest::Reporters.use! [Minitest::Reporters::SpecReporter.new, Minitest::Reporters::JUnitReporter.new(reports_dir="test/reports", empty=false)] 
end
