require 'P4'

if ARGV.length != 1 then
  STDERR.puts 'usage: p4login.rb password'
  Kernel.exit(1)
end

p4 = P4.new
p4.password = ARGV[0]
p4.connect
p4.run_trust('-y') if p4.port.start_with?('ssl:')
p4.run_login
