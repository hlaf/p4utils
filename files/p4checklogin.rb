require 'P4'

begin
  p4 = P4.new
  p4.connect
  result = p4.run_login('-s').shift
  if Integer(result['TicketExpiration']) < 120 then
    exit 9
  end
rescue P4Exception
  exit 2
end