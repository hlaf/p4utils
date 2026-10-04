require 'P4'

# The password arrives in P4PASSWD (set on the Exec's environment), which the
# P4 API picks up on its own; it is deliberately not accepted as an argument.
if ENV['P4PASSWD'].nil? || ENV['P4PASSWD'].empty? then
  STDERR.puts 'p4login.rb: P4PASSWD is not set in the environment'
  Kernel.exit(2)
end

p4 = P4.new
p4.connect
p4.run_trust('-y') if p4.port.start_with?('ssl:')
p4.run_login
