require 'P4'

begin
  p4 = P4.new
  p4.connect
  p4.run_info.shift
  exit 0
rescue P4Exception
  exit 2
end
