require 'P4'

# The password arrives in P4PASSWD, set on the Exec's environment, and is
# assigned to the API explicitly. P4.new does read P4PASSWD -- P4#password
# reflects it -- but the API does NOT submit an environment-sourced value as
# the credential for 'p4 login': the server answers "Password invalid." for
# the very bytes it accepts when they are assigned here. Measured on p4d
# 2016.2 with P4Ruby 2015.2 in a minimal environment, which is what an Exec
# gets; reading the variable is not the same as the login command sending it.
#
# It is deliberately not taken as an argument: argv is world-readable through
# ps for the life of the process, and Puppet prints a failing Exec's whole
# command line into the agent log and the report.
if ENV['P4PASSWD'].nil? || ENV['P4PASSWD'].empty? then
  STDERR.puts 'p4login.rb: P4PASSWD is not set in the environment'
  Kernel.exit(2)
end

p4 = P4.new
p4.password = ENV['P4PASSWD']
p4.connect
p4.run_trust('-y') if p4.port.start_with?('ssl:')
p4.run_login
