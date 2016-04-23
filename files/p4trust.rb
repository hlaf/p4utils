require 'P4'

p4 = P4.new
p4.connect
p4.run_trust('-y') if p4.port.start_with?('ssl:')
