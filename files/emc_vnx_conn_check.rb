#!/opt/puppet/bin/ruby

require 'fileutils'
require 'hashie'
require 'open3'

def print_usage
  print ("Usage: emc_vnx_conn_check.rb <storage_system> <user> <password> \n")
  print ("<storage> -- storage_system\n")
  print ("<user> -- User name\n")
  print ("<password> -- Password\n")
  exit 1
end

def self.run_command_success(cmd, *args)
  result = run_command(cmd, *args)
  raise("Command failed: #{cmd}\n#{result.stdout}\n#{result.stderr}") unless result.exit_status == 0
  result
end

def self.run_command(cmd, *args)
  result = Hashie::Mash.new
  Open3.popen3(cmd, *args) do |stdin, stdout, stderr, wait_thr|
    stdin.close
    result.stdout      = stdout.read
    result.stderr      = stderr.read
    result.pid         = wait_thr[:pid]
    result.exit_status = wait_thr.value.exitstatus
  end

  result
end

args = ARGV.length
if(args < 3)
  print_usage
end

storage = ARGV[0]
user = ARGV[1]
password = ARGV[2]
failure_exit_code = 1

DEFAULT_ADMIN_SCOPE = "0"
DEFAULT_TIMEOUT = "3"
DEFAULT_CLI_PATH = '/opt/Navisphere/bin/naviseccli'

return failure_exit_code unless File.exists?(DEFAULT_CLI_PATH) && File.executable?(DEFAULT_CLI_PATH)

args = ["-Address", storage,
        "-User", user,
        "-Password", password,
        "-Scope", DEFAULT_ADMIN_SCOPE,
        "-t", DEFAULT_TIMEOUT,
        'getconfig']

output = run_command(DEFAULT_CLI_PATH, *args)
puts output.stdout
exit output.exit_status

